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
