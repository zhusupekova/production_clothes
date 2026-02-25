SET NOCOUNT ON;
GO

INSERT INTO clothing_factory.cash_accounts (account_name, balance, currency_code)
VALUES (N'Основной расчетный счет', 15000000, 'KZT');

INSERT INTO clothing_factory.suppliers (supplier_name, contact_person, phone, email)
VALUES
    (N'Textile Asia', N'Aidar Suleimenov', N'+7-701-100-1001', N'sales@textileasia.kz'),
    (N'Cotton Market', N'Dana Mukanova', N'+7-701-100-1002', N'manager@cottonmarket.kz'),
    (N'Furnitura Plus', N'Askar Baimagambetov', N'+7-701-100-1003', N'contact@furnituraplus.kz');

INSERT INTO clothing_factory.raw_materials (material_name, unit, min_stock)
VALUES
    (N'Хлопковая ткань', N'м', 500),
    (N'Полиэстеровая ткань', N'м', 300),
    (N'Нитки швейные', N'катушка', 100),
    (N'Пуговицы', N'шт', 1000),
    (N'Молнии', N'шт', 500),
    (N'Резинка', N'м', 200);

INSERT INTO clothing_factory.supplier_material_prices (supplier_id, raw_material_id, unit_price, effective_from)
VALUES
    (1, 1, 1450, CAST(GETDATE() AS DATE)),
    (1, 2, 1200, CAST(GETDATE() AS DATE)),
    (2, 1, 1400, CAST(GETDATE() AS DATE)),
    (2, 6, 500, CAST(GETDATE() AS DATE)),
    (3, 3, 280, CAST(GETDATE() AS DATE)),
    (3, 4, 35, CAST(GETDATE() AS DATE)),
    (3, 5, 220, CAST(GETDATE() AS DATE));

INSERT INTO clothing_factory.raw_inventory (raw_material_id, quantity, avg_cost)
SELECT raw_material_id, 0, 0
FROM clothing_factory.raw_materials;

INSERT INTO clothing_factory.products (sku, product_name, category, size_label, sale_price)
VALUES
    (N'TSHIRT-UNI', N'Футболка базовая', N'Футболки', N'M', 8500),
    (N'HOODIE-UNI', N'Худи утепленное', N'Худи', N'L', 16500),
    (N'PANTS-SPR', N'Брюки спортивные', N'Брюки', N'M', 12500);

INSERT INTO clothing_factory.bill_of_materials (product_id, raw_material_id, qty_per_unit)
VALUES
    (1, 1, 1.20),
    (1, 3, 0.05),
    (2, 2, 1.80),
    (2, 3, 0.08),
    (2, 5, 1.00),
    (3, 2, 1.40),
    (3, 3, 0.06),
    (3, 6, 0.70);

INSERT INTO clothing_factory.finished_inventory (product_id, quantity, avg_cost)
SELECT product_id, 0, 0
FROM clothing_factory.products;

INSERT INTO clothing_factory.customers (customer_name, phone, email)
VALUES
    (N'Fashion Store Almaty', N'+7-701-200-2001', N'purchase@fashionstore.kz'),
    (N'Online Boutique KZ', N'+7-701-200-2002', N'orders@obkz.kz'),
    (N'Mega Retail', N'+7-701-200-2003', N'wholesale@megaretail.kz');

INSERT INTO clothing_factory.departments (department_name)
VALUES
    (N'Производство'),
    (N'Продажи'),
    (N'Администрация');

INSERT INTO clothing_factory.positions (department_id, position_name, base_salary)
VALUES
    (1, N'Швея', 220000),
    (1, N'Закройщик', 210000),
    (2, N'Менеджер по продажам', 260000),
    (3, N'Бухгалтер', 300000);

INSERT INTO clothing_factory.employees (full_name, hire_date, position_id, is_active)
VALUES
    (N'Ainur Kenzhebek', '2024-01-10', 1, 1),
    (N'Madiyar Nurbol', '2023-11-21', 2, 1),
    (N'Zhanar Iskak', '2024-05-03', 1, 1),
    (N'Dias Abdrakhman', '2024-02-15', 3, 1),
    (N'Kamila Serik', '2022-09-01', 4, 1);

INSERT INTO clothing_factory.timesheets (employee_id, period_month, worked_days, bonus, deductions)
VALUES
    (1, '2026-01-01', 22, 15000, 0),
    (2, '2026-01-01', 21, 10000, 5000),
    (3, '2026-01-01', 22, 12000, 0),
    (4, '2026-01-01', 22, 20000, 0),
    (5, '2026-01-01', 22, 0, 0);
GO
