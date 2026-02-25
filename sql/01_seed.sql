SET search_path TO clothing_factory;

INSERT INTO cash_accounts (account_name, balance, currency_code)
VALUES ('Основной расчетный счет', 15000000, 'KZT');

INSERT INTO suppliers (supplier_name, contact_person, phone, email)
VALUES
    ('Textile Asia', 'Aidar Suleimenov', '+7-701-100-1001', 'sales@textileasia.kz'),
    ('Cotton Market', 'Dana Mukanova', '+7-701-100-1002', 'manager@cottonmarket.kz'),
    ('Furnitura Plus', 'Askar Baimagambetov', '+7-701-100-1003', 'contact@furnituraplus.kz');

INSERT INTO raw_materials (material_name, unit, min_stock)
VALUES
    ('Хлопковая ткань', 'м', 500),
    ('Полиэстеровая ткань', 'м', 300),
    ('Нитки швейные', 'катушка', 100),
    ('Пуговицы', 'шт', 1000),
    ('Молнии', 'шт', 500),
    ('Резинка', 'м', 200);

INSERT INTO supplier_material_prices (supplier_id, raw_material_id, unit_price, effective_from)
VALUES
    (1, 1, 1450, CURRENT_DATE),
    (1, 2, 1200, CURRENT_DATE),
    (2, 1, 1400, CURRENT_DATE),
    (2, 6, 500, CURRENT_DATE),
    (3, 3, 280, CURRENT_DATE),
    (3, 4, 35, CURRENT_DATE),
    (3, 5, 220, CURRENT_DATE);

INSERT INTO raw_inventory (raw_material_id, quantity, avg_cost)
SELECT raw_material_id, 0, 0
FROM raw_materials;

INSERT INTO products (sku, product_name, category, size_label, sale_price)
VALUES
    ('TSHIRT-UNI', 'Футболка базовая', 'Футболки', 'M', 8500),
    ('HOODIE-UNI', 'Худи утепленное', 'Худи', 'L', 16500),
    ('PANTS-SPR', 'Брюки спортивные', 'Брюки', 'M', 12500);

INSERT INTO bill_of_materials (product_id, raw_material_id, qty_per_unit)
VALUES
    (1, 1, 1.20),
    (1, 3, 0.05),
    (2, 2, 1.80),
    (2, 3, 0.08),
    (2, 5, 1.00),
    (3, 2, 1.40),
    (3, 3, 0.06),
    (3, 6, 0.70);

INSERT INTO finished_inventory (product_id, quantity, avg_cost)
SELECT product_id, 0, 0
FROM products;

INSERT INTO customers (customer_name, phone, email)
VALUES
    ('Fashion Store Almaty', '+7-701-200-2001', 'purchase@fashionstore.kz'),
    ('Online Boutique KZ', '+7-701-200-2002', 'orders@obkz.kz'),
    ('Mega Retail', '+7-701-200-2003', 'wholesale@megaretail.kz');

INSERT INTO departments (department_name)
VALUES
    ('Производство'),
    ('Продажи'),
    ('Администрация');

INSERT INTO positions (department_id, position_name, base_salary)
VALUES
    (1, 'Швея', 220000),
    (1, 'Закройщик', 210000),
    (2, 'Менеджер по продажам', 260000),
    (3, 'Бухгалтер', 300000);

INSERT INTO employees (full_name, hire_date, position_id, is_active)
VALUES
    ('Ainur Kenzhebek', '2024-01-10', 1, TRUE),
    ('Madiyar Nurbol', '2023-11-21', 2, TRUE),
    ('Zhanar Iskak', '2024-05-03', 1, TRUE),
    ('Dias Abdrakhman', '2024-02-15', 3, TRUE),
    ('Kamila Serik', '2022-09-01', 4, TRUE);

INSERT INTO timesheets (employee_id, period_month, worked_days, bonus, deductions)
VALUES
    (1, '2026-01-01', 22, 15000, 0),
    (2, '2026-01-01', 21, 10000, 5000),
    (3, '2026-01-01', 22, 12000, 0),
    (4, '2026-01-01', 22, 20000, 0),
    (5, '2026-01-01', 22, 0, 0);
