/**************************************************************
 E-commerce Store - Complete MySQL Schema (single .sql file)
 - Run in MySQL (InnoDB assumed)
 - Idempotent (drops existing objects with same names)
**************************************************************/

-- DROP DATABASE if exists (so the script is repeatable)
DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_db;

-- ###########################################################
-- Customers
-- ###########################################################
DROP TABLE IF EXISTS Customers;
CREATE TABLE Customers (
    customer_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    first_name       VARCHAR(100) NOT NULL,
    last_name        VARCHAR(100) NOT NULL,
    email            VARCHAR(255) NOT NULL UNIQUE,
    phone            VARCHAR(30),
    password_hash    VARCHAR(255) NOT NULL,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id)
) ENGINE=InnoDB;

-- ###########################################################
-- Addresses (one customer can have many addresses) - 1:N
-- ###########################################################
DROP TABLE IF EXISTS Addresses;
CREATE TABLE Addresses (
    address_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id      BIGINT UNSIGNED NOT NULL,
    label            VARCHAR(50) DEFAULT 'home', -- e.g. 'home', 'work'
    address_line1    VARCHAR(255) NOT NULL,
    address_line2    VARCHAR(255),
    city             VARCHAR(100) NOT NULL,
    state            VARCHAR(100),
    postal_code      VARCHAR(20),
    country          VARCHAR(100) NOT NULL,
    is_default       TINYINT(1) NOT NULL DEFAULT 0,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (address_id),
    CONSTRAINT fk_addresses_customer FOREIGN KEY (customer_id)
        REFERENCES Customers(customer_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ###########################################################
-- Categories (product taxonomy)
-- ###########################################################
DROP TABLE IF EXISTS Categories;
CREATE TABLE Categories (
    category_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name             VARCHAR(100) NOT NULL,
    slug             VARCHAR(120) NOT NULL UNIQUE,
    description      TEXT,
    parent_id        INT UNSIGNED, -- self-referencing for hierarchical categories (optional)
    PRIMARY KEY (category_id),
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_id) REFERENCES Categories(category_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ###########################################################
-- Suppliers
-- ###########################################################
DROP TABLE IF EXISTS Suppliers;
CREATE TABLE Suppliers (
    supplier_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name             VARCHAR(200) NOT NULL,
    contact_email    VARCHAR(255),
    phone            VARCHAR(50),
    address          VARCHAR(255),
    PRIMARY KEY (supplier_id)
) ENGINE=InnoDB;

-- ###########################################################
-- Products
-- ###########################################################
DROP TABLE IF EXISTS Products;
CREATE TABLE Products (
    product_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sku              VARCHAR(64) NOT NULL UNIQUE,
    name             VARCHAR(255) NOT NULL,
    description      TEXT,
    price            DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    cost_price       DECIMAL(10,2) DEFAULT 0.00,
    weight_kg        DECIMAL(6,3) DEFAULT 0.000,
    active           TINYINT(1) NOT NULL DEFAULT 1,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id)
) ENGINE=InnoDB;

-- ###########################################################
-- Product <-> Category (many-to-many)
-- ###########################################################
DROP TABLE IF EXISTS ProductCategories;
CREATE TABLE ProductCategories (
    product_id       BIGINT UNSIGNED NOT NULL,
    category_id      INT UNSIGNED NOT NULL,
    PRIMARY KEY (product_id, category_id),
    CONSTRAINT fk_pc_product FOREIGN KEY (product_id) REFERENCES Products(product_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pc_category FOREIGN KEY (category_id) REFERENCES Categories(category_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ###########################################################
-- Product <-> Supplier (many-to-many) - optional
-- ###########################################################
DROP TABLE IF EXISTS ProductSuppliers;
CREATE TABLE ProductSuppliers (
    product_id       BIGINT UNSIGNED NOT NULL,
    supplier_id      INT UNSIGNED NOT NULL,
    supplier_sku     VARCHAR(100),
    lead_time_days   INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (product_id, supplier_id),
    CONSTRAINT fk_ps_product FOREIGN KEY (product_id) REFERENCES Products(product_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ps_supplier FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ###########################################################
-- Inventory (tracks stock per product - 1:1 or 1:N depending on location)
-- ###########################################################
DROP TABLE IF EXISTS Inventory;
CREATE TABLE Inventory (
    inventory_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id       BIGINT UNSIGNED NOT NULL,
    quantity_on_hand INT UNSIGNED NOT NULL DEFAULT 0,
    reorder_level    INT UNSIGNED NOT NULL DEFAULT 0,
    updated_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (inventory_id),
    UNIQUE KEY uq_inventory_product (product_id),
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES Products(product_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ###########################################################
-- Orders (1 customer can have many orders) - header table
-- ###########################################################
DROP TABLE IF EXISTS Orders;
CREATE TABLE Orders (
    order_id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id      BIGINT UNSIGNED NOT NULL,
    billing_address_id BIGINT UNSIGNED,
    shipping_address_id BIGINT UNSIGNED,
    order_date       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status           ENUM('pending','processing','shipped','delivered','cancelled','refunded') NOT NULL DEFAULT 'pending',
    subtotal         DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    shipping_cost    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    tax_amount       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_amount     DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    payment_method   VARCHAR(50),
    payment_status   ENUM('unpaid','paid','refunded','failed') NOT NULL DEFAULT 'unpaid',
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id),
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_order_billing_addr FOREIGN KEY (billing_address_id) REFERENCES Addresses(address_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_order_shipping_addr FOREIGN KEY (shipping_address_id) REFERENCES Addresses(address_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ###########################################################
-- OrderItems (junction table between Orders and Products) - Order has many items
-- Composite PK ensures Quantity depends on both order_id and product_id
-- ###########################################################
DROP TABLE IF EXISTS OrderItems;
CREATE TABLE OrderItems (
    order_id         BIGINT UNSIGNED NOT NULL,
    product_id       BIGINT UNSIGNED NOT NULL,
    unit_price       DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    quantity         INT UNSIGNED NOT NULL CHECK (quantity > 0),
    discount         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    line_total       DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES Orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_oi_product FOREIGN KEY (product_id) REFERENCES Products(product_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ###########################################################
-- Payments (1 order -> many payments possible for partial payments/refunds)
-- ###########################################################
DROP TABLE IF EXISTS Payments;
CREATE TABLE Payments (
    payment_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id         BIGINT UNSIGNED NOT NULL,
    amount           DECIMAL(12,2) NOT NULL,
    method           VARCHAR(50),
    transaction_ref  VARCHAR(255),
    status           ENUM('pending','completed','failed','refunded') NOT NULL DEFAULT 'pending',
    paid_at          TIMESTAMP NULL,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (payment_id),
    CONSTRAINT fk_pay_order FOREIGN KEY (order_id) REFERENCES Orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ###########################################################
-- ProductReviews (customer reviews for products) - 1 product:many reviews
-- ###########################################################
DROP TABLE IF EXISTS ProductReviews;
CREATE TABLE ProductReviews (
    review_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id       BIGINT UNSIGNED NOT NULL,
    customer_id      BIGINT UNSIGNED,
    rating           TINYINT UNSIGNED NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title            VARCHAR(255),
    body             TEXT,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (review_id),
    CONSTRAINT fk_review_product FOREIGN KEY (product_id) REFERENCES Products(product_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_review_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ###########################################################
-- Wishlists (a customer may have many wishlist items)
-- ###########################################################
DROP TABLE IF EXISTS Wishlists;
CREATE TABLE Wishlists (
    wishlist_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id      BIGINT UNSIGNED NOT NULL,
    name             VARCHAR(100) DEFAULT 'My Wishlist',
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (wishlist_id),
    CONSTRAINT fk_wl_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS WishlistItems;
CREATE TABLE WishlistItems (
    wishlist_id      BIGINT UNSIGNED NOT NULL,
    product_id       BIGINT UNSIGNED NOT NULL,
    added_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (wishlist_id, product_id),
    CONSTRAINT fk_wli_wishlist FOREIGN KEY (wishlist_id) REFERENCES Wishlists(wishlist_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_wli_product FOREIGN KEY (product_id) REFERENCES Products(product_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ###########################################################
-- Example: Unique constraints and helpful indexes
-- ###########################################################
-- Index on Orders for customer lookup and status queries
CREATE INDEX idx_orders_customer_status ON Orders (customer_id, status);

-- Index on Products name for searching (simple example)
CREATE INDEX idx_products_name ON Products (name(80));

-- ###########################################################
-- Sample inserts (optional) - uncomment to add some demo data
-- ###########################################################
/*
INSERT INTO Customers (first_name, last_name, email, phone, password_hash)
VALUES ('John','Doe','john@example.com','+254700000000','hash1'),
       ('Jane','Smith','jane@example.com','+254711111111','hash2');

INSERT INTO Addresses (customer_id, label, address_line1, city, country, is_default)
VALUES (1,'home','123 Nairobi Rd','Nairobi','Kenya',1),
       (2,'home','456 Mombasa Rd','Mombasa','Kenya',1);

INSERT INTO Categories (name, slug) VALUES ('Electronics','electronics'), ('Accessories','accessories');

INSERT INTO Suppliers (name, contact_email) VALUES ('Acme Supplies','acme@example.com');

INSERT INTO Products (sku, name, description, price) VALUES
 ('SKU-001','Laptop Pro','High performance laptop',1200.00),
 ('SKU-002','Wireless Mouse','Ergonomic wireless mouse',25.00),
 ('SKU-003','Keyboard','Mechanical keyboard',60.00);

INSERT INTO ProductCategories (product_id, category_id) VALUES (1,1), (2,2), (3,2);
INSERT INTO ProductSuppliers (product_id, supplier_id, supplier_sku) VALUES (1,1,'A-100');

-- Create a sample order
INSERT INTO Orders (customer_id, billing_address_id, shipping_address_id, subtotal, shipping_cost, tax_amount, total_amount, payment_method, payment_status)
VALUES (1, 1, 1, 1225.00, 10.00, 123.50, 1358.50, 'card','paid');

INSERT INTO OrderItems (order_id, product_id, unit_price, quantity, discount, line_total)
VALUES (1, 1, 1200.00, 1, 0.00, 1200.00),
       (1, 2, 25.00, 1, 0.00, 25.00);

INSERT INTO Payments (order_id, amount, method, transaction_ref, status, paid_at)
VALUES (1, 1358.50, 'card', 'txn_12345', 'completed', NOW());
*/

-- ###########################################################
-- End of schema
-- ###########################################################
