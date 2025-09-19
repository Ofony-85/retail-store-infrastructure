-- Drop old tables if they exist
DROP TABLE IF EXISTS product_tag;
DROP TABLE IF EXISTS tag;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS schema_migrations;

-- Create schema_migrations (if the service uses it)
CREATE TABLE schema_migrations (
    version VARCHAR(255) PRIMARY KEY
);

-- Create product table (with product_id as primary key string)
CREATE TABLE product (
    product_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL
);

-- Create tag table (singular tag name)
CREATE TABLE tag (
    tag VARCHAR(255) PRIMARY KEY
);

-- Create joining table product_tag
CREATE TABLE product_tag (
    product_id VARCHAR(255) NOT NULL,
    tag VARCHAR(255) NOT NULL,
    PRIMARY KEY (product_id, tag),
    FOREIGN KEY (product_id) REFERENCES product(product_id) ON DELETE CASCADE,
    FOREIGN KEY (tag) REFERENCES tag(tag) ON DELETE CASCADE
);

-- Seed data: insert some products
INSERT INTO product (product_id, name, description, price) VALUES
('1', 'T-Shirt', 'Cotton T-Shirt', 19.99),
('2', 'Sneakers', 'Running Shoes', 49.99),
('3', 'Jeans', 'Blue Denim Jeans', 39.99),
('4', 'Hat', 'Baseball Cap', 14.99);

-- Seed tags
INSERT INTO tag (tag) VALUES
('clothing'),
('top'),
('footwear'),
('sport'),
('bottom'),
('accessories'),
('headwear');

-- Seed product_tag relationships
INSERT INTO product_tag (product_id, tag) VALUES
('1', 'clothing'),
('1', 'top'),
('2', 'footwear'),
('2', 'sport'),
('3', 'clothing'),
('3', 'bottom'),
('4', 'accessories'),
('4', 'headwear');
