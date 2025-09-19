-- Use the catalog DB
USE catalog;

-- 1. Fix product table
DROP TABLE IF EXISTS product;
CREATE TABLE product (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2),
    count INT DEFAULT 0
);

-- 2. Fix product_tag table
DROP TABLE IF EXISTS product_tag;
CREATE TABLE product_tag (
    tag_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    tag VARCHAR(100) NOT NULL,
    FOREIGN KEY (product_id) REFERENCES product(product_id) ON DELETE CASCADE
);

-- 3. Seed products
INSERT INTO product (name, description, price, count) VALUES
('T-Shirt', 'Cotton T-Shirt', 19.99, 100),
('Sneakers', 'Running Shoes', 49.99, 50),
('Jeans', 'Blue Denim Jeans', 39.99, 75),
('Hat', 'Baseball Cap', 14.99, 200);

-- 4. Seed tags
INSERT INTO product_tag (product_id, tag) VALUES
(1, 'clothing'),
(1, 'summer'),
(2, 'footwear'),
(3, 'clothing'),
(4, 'accessory');
