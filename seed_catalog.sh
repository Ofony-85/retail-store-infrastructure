#!/bin/bash
set -e

# === Variables ===
NAMESPACE="retail-store"
MYSQL_POD=$(kubectl get pod -n $NAMESPACE -l app=mysql -o jsonpath='{.items[0].metadata.name}')
DB_USER="catalog_user"
DB_PASS="password"
DB_NAME="catalog"

echo "Using MySQL pod: $MYSQL_POD"

# === 1. Create SQL seed file ===
cat > catalog_seed.sql <<'EOF'
DROP TABLE IF EXISTS product_tag;
DROP TABLE IF EXISTS product;

CREATE TABLE product (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL
);

CREATE TABLE product_tag (
    product_id INT NOT NULL,
    tag VARCHAR(255) NOT NULL,
    PRIMARY KEY (product_id, tag),
    FOREIGN KEY (product_id) REFERENCES product(id) ON DELETE CASCADE
);

INSERT INTO product (name, description, price) VALUES
('T-Shirt', 'Cotton T-Shirt', 19.99),
('Sneakers', 'Running Shoes', 49.99),
('Jeans', 'Blue Denim Jeans', 39.99),
('Hat', 'Baseball Cap', 14.99);

INSERT INTO product_tag (product_id, tag) VALUES
(1, 'clothing'),
(1, 'top'),
(2, 'footwear'),
(2, 'sport'),
(3, 'clothing'),
(3, 'bottom'),
(4, 'accessories'),
(4, 'headwear');
EOF

# === 2. Copy file into MySQL pod ===
echo "Copying catalog_seed.sql into pod..."
kubectl cp catalog_seed.sql $NAMESPACE/$MYSQL_POD:/tmp/catalog_seed.sql

# === 3. Run SQL inside MySQL ===
echo "Seeding database..."
kubectl exec -i -n $NAMESPACE $MYSQL_POD -- \
  mysql -u $DB_USER -p$DB_PASS -D $DB_NAME < /tmp/catalog_seed.sql

# === 4. Verify tables ===
echo "Verifying tables..."
kubectl exec -it -n $NAMESPACE $MYSQL_POD -- \
  mysql -u $DB_USER -p$DB_PASS -D $DB_NAME -e "SHOW TABLES;"

# === 5. Restart catalog service ===
echo "Restarting catalog deployment..."
kubectl rollout restart deployment/catalog -n $NAMESPACE

# === 6. Show catalog logs ===
echo "Checking catalog logs..."
sleep 5
kubectl logs -n $NAMESPACE deployment/catalog --tail=20
