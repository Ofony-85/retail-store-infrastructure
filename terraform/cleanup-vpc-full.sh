#!/usr/bin/env bash
# cleanup-vpc-full.sh
# Usage: ./cleanup-vpc-full.sh <vpc-id>
# WARNING: destructive. Deletes load balancers, target groups, listeners, ENIs, NATs, EIPs, endpoints, peering, NACLs, SGs, subnets, route tables, IGWs, VPC.

set -euo pipefail
VPC_ID="$1"

if [ -z "$VPC_ID" ]; then
  echo "Usage: $0 <vpc-id>"
  exit 1
fi

echo "🧹 Starting full cleanup for VPC: $VPC_ID"
echo "Make sure you REALLY want to delete resources in this VPC."

# helper to sleep between destructive calls to allow propagation
wait_short() { sleep 3; }
wait_long()  { sleep 6; }

# 0) Remove ELB (classic) load balancers in the VPC
echo "➡️ Removing classic ELBs in VPC..."
for lb in $(aws elb describe-load-balancers --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text); do
  if [ -n "$lb" ]; then
    echo "  - Deleting CLB: $lb"
    aws elb delete-load-balancer --load-balancer-name "$lb" || true
  fi
done
wait_long

# 1) Delete ALBs / NLBs (v2)
echo "➡️ Removing ALBs/NLBs (ELBv2) in VPC..."
for lb_arn in $(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text); do
  if [ -n "$lb_arn" ]; then
    echo "  - Found LB: $lb_arn"
    # Delete listeners
    for listener in $(aws elbv2 describe-listeners --load-balancer-arn "$lb_arn" --query "Listeners[].ListenerArn" --output text || true); do
      if [ -n "$listener" ]; then
        echo "    - Deleting listener: $listener"
        aws elbv2 delete-listener --listener-arn "$listener" || true
      fi
    done
    # Delete LB
    echo "  - Deleting LB: $lb_arn"
    aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" || true
  fi
done
wait_long

# 2) Delete target groups in this VPC
echo "➡️ Deleting target groups in VPC..."
for tg in $(aws elbv2 describe-target-groups --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" --output text); do
  if [ -n "$tg" ]; then
    echo "  - Deleting target group: $tg"
    aws elbv2 delete-target-group --target-group-arn "$tg" || true
  fi
done
wait_short

# 3) Delete network interfaces (ENIs) — detach if possible then delete
echo "➡️ Removing ENIs (network interfaces) in VPC..."
for eni in $(aws ec2 describe-network-interfaces --filters Name=vpc-id,Values="$VPC_ID" --query "NetworkInterfaces[].NetworkInterfaceId" --output text); do
  if [ -n "$eni" ]; then
    echo "  - ENI: $eni"
    # try to detach if attached
    attachment_id=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni" --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text)
    if [ "$attachment_id" != "None" ] && [ -n "$attachment_id" ]; then
      echo "    - detaching attachment: $attachment_id"
      aws ec2 detach-network-interface --attachment-id "$attachment_id" --force || true
      wait_short
    fi
    echo "    - deleting eni: $eni"
    aws ec2 delete-network-interface --network-interface-id "$eni" || true
  fi
done
wait_short

# 4) VPC endpoints
echo "➡️ Deleting VPC endpoints..."
for vpce in $(aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values="$VPC_ID" --query "VpcEndpoints[].VpcEndpointId" --output text); do
  if [ -n "$vpce" ]; then
    echo "  - Deleting VPC endpoint: $vpce"
    aws ec2 delete-vpc-endpoints --vpc-endpoint-ids "$vpce" || true
  fi
done
wait_short

# 5) VPC peering connections (requester or accepter)
echo "➡️ Deleting VPC peering connections..."
for pcx in $(aws ec2 describe-vpc-peering-connections --query "VpcPeeringConnections[?RequesterVpcInfo.VpcId=='$VPC_ID' || AccepterVpcInfo.VpcId=='$VPC_ID'].VpcPeeringConnectionId" --output text); do
  if [ -n "$pcx" ]; then
    echo "  - Deleting peering: $pcx"
    aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id "$pcx" || true
  fi
done
wait_short

# 6) NAT Gateways & their EIPs
echo "➡️ Deleting NAT Gateways and releasing Elastic IPs..."
for nat in $(aws ec2 describe-nat-gateways --filter Name=vpc-id,Values="$VPC_ID" --query "NatGateways[].NatGatewayId" --output text); do
  if [ -n "$nat" ]; then
    echo "  - Deleting NAT: $nat"
    aws ec2 delete-nat-gateway --nat-gateway-id "$nat" || true
  fi
done
wait_long

# release EIPs not associated
for alloc in $(aws ec2 describe-addresses --filters Name=domain,Values=vpc --query "Addresses[?NetworkBorderGroup!=null && AllocationId!=null && (VpcId=='$VPC_ID')].AllocationId" --output text); do
  if [ -n "$alloc" ]; then
    echo "  - Releasing EIP allocation: $alloc"
    aws ec2 release-address --allocation-id "$alloc" || true
  fi
done
wait_short

# 7) Internet Gateways — detach then delete
echo "➡️ Detaching and deleting Internet Gateways..."
for igw in $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values="$VPC_ID" --query "InternetGateways[].InternetGatewayId" --output text); do
  if [ -n "$igw" ]; then
    echo "  - Detaching IGW: $igw"
    aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$VPC_ID" || true
    echo "  - Deleting IGW: $igw"
    aws ec2 delete-internet-gateway --internet-gateway-id "$igw" || true
  fi
done
wait_short

# 8) Network ACLs (delete non-default)
echo "➡️ Deleting non-default Network ACLs..."
for nacl in $(aws ec2 describe-network-acls --filters Name=vpc-id,Values="$VPC_ID" --query "NetworkAcls[?IsDefault==\`false\`].NetworkAclId" --output text); do
  if [ -n "$nacl" ]; then
    echo "  - Deleting NACL: $nacl"
    aws ec2 delete-network-acl --network-acl-id "$nacl" || true
  fi
done
wait_short

# 9) Route Tables: try to delete non-main; replace main with new RT then delete old after disassociation
echo "➡️ Handling route tables..."
MAIN_RTB=""
for rtb in $(aws ec2 describe-route-tables --filters Name=vpc-id,Values="$VPC_ID" --query "RouteTables[].RouteTableId" --output text); do
  if [ -z "$rtb" ]; then
    continue
  fi
  is_main=$(aws ec2 describe-route-tables --route-table-ids "$rtb" --query "RouteTables[0].Associations[?Main==\`true\`].Main" --output text || true)
  if [ "$is_main" == "True" ]; then
    MAIN_RTB="$rtb"
    echo "  - Found main RT: $rtb"
    continue
  fi
  echo "  - Deleting RT: $rtb"
  aws ec2 delete-route-table --route-table-id "$rtb" || true
done

if [ -n "$MAIN_RTB" ]; then
  echo "  - Replacing main route table to allow deletion..."
  # create a new RT, it will become non-main; associations are per-subnet; main remains, but creating a new one can allow deletion of old associations
  NEW_RTB=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query "RouteTable.RouteTableId" --output text)
  echo "    - Created replacement RT: $NEW_RTB"
  # Disassociate any associations pointing to the old main RT (except the main association which cannot be disassociated)
  for assoc in $(aws ec2 describe-route-tables --route-table-ids "$MAIN_RTB" --query "RouteTables[0].Associations[?Main==\`false\`].RouteTableAssociationId" --output text); do
    if [ -n "$assoc" ]; then
      echo "    - Disassociating: $assoc"
      aws ec2 disassociate-route-table --association-id "$assoc" || true
    fi
  done
  # Try deleting the main RT (may still fail; AWS manages main; but attempt)
  echo "    - Attempting to delete old main RT: $MAIN_RTB (this may fail if still main)"
  aws ec2 delete-route-table --route-table-id "$MAIN_RTB" || true
fi
wait_short

# 10) Delete subnets (if any)
echo "➡️ Deleting subnets..."
for subnet in $(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" --query "Subnets[].SubnetId" --output text); do
  if [ -n "$subnet" ]; then
    echo "  - Deleting subnet: $subnet"
    aws ec2 delete-subnet --subnet-id "$subnet" || true
  fi
done
wait_short

# 11) Security Groups: delete non-default and non-in-use (try many times)
echo "➡️ Deleting non-default Security Groups..."
for sg in $(aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text); do
  if [ -n "$sg" ]; then
    echo "  - Deleting SG: $sg"
    aws ec2 delete-security-group --group-id "$sg" || true
  fi
done
wait_short

# 12) Release any remaining Elastic IPs (all in this account associated with VPC)
echo "➡️ Releasing Elastic IPs associated with this VPC..."
for alloc in $(aws ec2 describe-addresses --filters Name=domain,Values=vpc --query "Addresses[?VpcId=='$VPC_ID'].AllocationId" --output text); do
  if [ -n "$alloc" ]; then
    echo "  - Releasing EIP: $alloc"
    aws ec2 release-address --allocation-id "$alloc" || true
  fi
done
wait_short

# 13) Final VPC endpoints (again, just in case)
for vpce in $(aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values="$VPC_ID" --query "VpcEndpoints[].VpcEndpointId" --output text); do
  if [ -n "$vpce" ]; then
    echo "  - Deleting VPC endpoint: $vpce"
    aws ec2 delete-vpc-endpoints --vpc-endpoint-ids "$vpce" || true
  fi
done
wait_short

# 14) Final attempt to delete the VPC
echo "➡️ Attempting final delete of VPC: $VPC_ID"
aws ec2 delete-vpc --vpc-id "$VPC_ID" || {
  echo "⚠️ Final VPC delete failed. Showing remaining resources for debug:"
  echo "Remaining ENIs:"
  aws ec2 describe-network-interfaces --filters Name=vpc-id,Values="$VPC_ID" --query "NetworkInterfaces[].NetworkInterfaceId" --output text || true
  echo "Remaining SGs:"
  aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPC_ID" --output json || true
  echo "Remaining route tables:"
  aws ec2 describe-route-tables --filters Name=vpc-id,Values="$VPC_ID" --output json || true
  echo "Remaining subnets:"
  aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" --output json || true
  exit 1
}

echo "✅ VPC $VPC_ID deleted (or delete request accepted). Cleanup complete."
