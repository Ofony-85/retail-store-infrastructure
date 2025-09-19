-- Drop tables if exist
DROP TABLE IF EXISTS product_tag;
DROP TABLE IF EXISTS tag;
DROP TABLE IF EXISTS product;

-- Create product table
CREATE TABLE product (
    product_id  VARCHAR(64) NOT NULL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    price       DECIMAL(10,2) NOT NULL,
    count       INT,
    image_url   VARCHAR(255)
);

-- Create tag table
CREATE TABLE tag (
    tag_id VARCHAR(64) NOT NULL PRIMARY KEY,
    name   VARCHAR(100) NOT NULL
);

-- Create product_tag table
CREATE TABLE product_tag (
    product_id VARCHAR(64) NOT NULL,
    tag_id     VARCHAR(64) NOT NULL,
    PRIMARY KEY (product_id, tag_id),
    FOREIGN KEY (product_id) REFERENCES product(product_id),
    FOREIGN KEY (tag_id) REFERENCES tag(tag_id)
);

-- Seed sample products
INSERT INTO product (product_id, name, description, price, count, image_url) VALUES
('1', 'T-Shirt', 'Cotton T-Shirt', 19.99, 100, 'tshirt.png'),
('2', 'Sneakers', 'Running Shoes', 49.99, 50, 'sneakers.png'),
('3', 'Jeans', 'Blue Denim Jeans', 39.99, 75, 'jeans.png'),
('4', 'Hat', 'Baseball Cap', 14.99, 200, 'hat.png');
