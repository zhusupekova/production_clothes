/*
Run this file in SSMS to deploy the whole project on MS SQL Server
Generated from component scripts
*/

/* ===== FILE: 00_schema.sql ===== */
/*
Лабораторный проект: Производство одежды
MS SQL Server (T-SQL)
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'clothing_factory') IS NULL
    EXEC(N'CREATE SCHEMA clothing_factory');
GO

DROP VIEW IF EXISTS clothing_factory.v_company_kpi_monthly;
DROP VIEW IF EXISTS clothing_factory.v_loans_status;
DROP VIEW IF EXISTS clothing_factory.v_monthly_payroll;
DROP VIEW IF EXISTS clothing_factory.v_sales_summary;
DROP VIEW IF EXISTS clothing_factory.v_production_summary;
DROP VIEW IF EXISTS clothing_factory.v_finished_product_balance;
DROP VIEW IF EXISTS clothing_factory.v_raw_material_balance;
GO

DROP PROCEDURE IF EXISTS clothing_factory.sp_report_period_summary;
DROP PROCEDURE IF EXISTS clothing_factory.sp_pay_loan_installment;
DROP PROCEDURE IF EXISTS clothing_factory.sp_take_loan;
DROP PROCEDURE IF EXISTS clothing_factory.sp_pay_payroll;
DROP PROCEDURE IF EXISTS clothing_factory.sp_calculate_payroll;
DROP PROCEDURE IF EXISTS clothing_factory.sp_create_sale;
DROP PROCEDURE IF EXISTS clothing_factory.sp_run_production;
DROP PROCEDURE IF EXISTS clothing_factory.sp_receive_purchase_order;
DROP PROCEDURE IF EXISTS clothing_factory.sp_create_purchase_order;
DROP PROCEDURE IF EXISTS clothing_factory.sp_record_cash_movement;
GO

IF OBJECT_ID(N'clothing_factory.loan_payments', N'U') IS NOT NULL DROP TABLE clothing_factory.loan_payments;
IF OBJECT_ID(N'clothing_factory.loan_schedule', N'U') IS NOT NULL DROP TABLE clothing_factory.loan_schedule;
IF OBJECT_ID(N'clothing_factory.loans', N'U') IS NOT NULL DROP TABLE clothing_factory.loans;
IF OBJECT_ID(N'clothing_factory.payroll', N'U') IS NOT NULL DROP TABLE clothing_factory.payroll;
IF OBJECT_ID(N'clothing_factory.timesheets', N'U') IS NOT NULL DROP TABLE clothing_factory.timesheets;
IF OBJECT_ID(N'clothing_factory.employees', N'U') IS NOT NULL DROP TABLE clothing_factory.employees;
IF OBJECT_ID(N'clothing_factory.positions', N'U') IS NOT NULL DROP TABLE clothing_factory.positions;
IF OBJECT_ID(N'clothing_factory.departments', N'U') IS NOT NULL DROP TABLE clothing_factory.departments;
IF OBJECT_ID(N'clothing_factory.sales_order_items', N'U') IS NOT NULL DROP TABLE clothing_factory.sales_order_items;
IF OBJECT_ID(N'clothing_factory.sales_orders', N'U') IS NOT NULL DROP TABLE clothing_factory.sales_orders;
IF OBJECT_ID(N'clothing_factory.customers', N'U') IS NOT NULL DROP TABLE clothing_factory.customers;
IF OBJECT_ID(N'clothing_factory.finished_inventory', N'U') IS NOT NULL DROP TABLE clothing_factory.finished_inventory;
IF OBJECT_ID(N'clothing_factory.production_consumption', N'U') IS NOT NULL DROP TABLE clothing_factory.production_consumption;
IF OBJECT_ID(N'clothing_factory.production_orders', N'U') IS NOT NULL DROP TABLE clothing_factory.production_orders;
IF OBJECT_ID(N'clothing_factory.bill_of_materials', N'U') IS NOT NULL DROP TABLE clothing_factory.bill_of_materials;
IF OBJECT_ID(N'clothing_factory.products', N'U') IS NOT NULL DROP TABLE clothing_factory.products;
IF OBJECT_ID(N'clothing_factory.purchase_order_items', N'U') IS NOT NULL DROP TABLE clothing_factory.purchase_order_items;
IF OBJECT_ID(N'clothing_factory.purchase_orders', N'U') IS NOT NULL DROP TABLE clothing_factory.purchase_orders;
IF OBJECT_ID(N'clothing_factory.cash_movements', N'U') IS NOT NULL DROP TABLE clothing_factory.cash_movements;
IF OBJECT_ID(N'clothing_factory.cash_accounts', N'U') IS NOT NULL DROP TABLE clothing_factory.cash_accounts;
IF OBJECT_ID(N'clothing_factory.raw_inventory', N'U') IS NOT NULL DROP TABLE clothing_factory.raw_inventory;
IF OBJECT_ID(N'clothing_factory.supplier_material_prices', N'U') IS NOT NULL DROP TABLE clothing_factory.supplier_material_prices;
IF OBJECT_ID(N'clothing_factory.raw_materials', N'U') IS NOT NULL DROP TABLE clothing_factory.raw_materials;
IF OBJECT_ID(N'clothing_factory.suppliers', N'U') IS NOT NULL DROP TABLE clothing_factory.suppliers;
GO

CREATE TABLE clothing_factory.suppliers (
    supplier_id      INT IDENTITY(1,1) PRIMARY KEY,
    supplier_name    NVARCHAR(200) NOT NULL,
    contact_person   NVARCHAR(200) NULL,
    phone            NVARCHAR(50) NULL,
    email            NVARCHAR(200) NULL,
    created_at       DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE TABLE clothing_factory.raw_materials (
    raw_material_id  INT IDENTITY(1,1) PRIMARY KEY,
    material_name    NVARCHAR(200) NOT NULL UNIQUE,
    unit             NVARCHAR(30) NOT NULL,
    min_stock        DECIMAL(14,3) NOT NULL DEFAULT 0,
    created_at       DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_raw_materials_min_stock CHECK (min_stock >= 0)
);
GO

CREATE TABLE clothing_factory.supplier_material_prices (
    supplier_id      INT NOT NULL,
    raw_material_id  INT NOT NULL,
    unit_price       DECIMAL(14,2) NOT NULL,
    effective_from   DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    CONSTRAINT PK_supplier_material_prices PRIMARY KEY (supplier_id, raw_material_id, effective_from),
    CONSTRAINT FK_smp_supplier FOREIGN KEY (supplier_id) REFERENCES clothing_factory.suppliers(supplier_id),
    CONSTRAINT FK_smp_material FOREIGN KEY (raw_material_id) REFERENCES clothing_factory.raw_materials(raw_material_id),
    CONSTRAINT CK_smp_price CHECK (unit_price > 0)
);
GO

CREATE TABLE clothing_factory.raw_inventory (
    raw_material_id  INT PRIMARY KEY,
    quantity         DECIMAL(14,3) NOT NULL DEFAULT 0,
    avg_cost         DECIMAL(14,2) NOT NULL DEFAULT 0,
    updated_at       DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_raw_inventory_material FOREIGN KEY (raw_material_id) REFERENCES clothing_factory.raw_materials(raw_material_id),
    CONSTRAINT CK_raw_inventory_quantity CHECK (quantity >= 0),
    CONSTRAINT CK_raw_inventory_cost CHECK (avg_cost >= 0)
);
GO

CREATE TABLE clothing_factory.cash_accounts (
    account_id       INT IDENTITY(1,1) PRIMARY KEY,
    account_name     NVARCHAR(200) NOT NULL UNIQUE,
    balance          DECIMAL(14,2) NOT NULL DEFAULT 0,
    currency_code    CHAR(3) NOT NULL DEFAULT 'KZT',
    created_at       DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE TABLE clothing_factory.cash_movements (
    movement_id      INT IDENTITY(1,1) PRIMARY KEY,
    movement_date    DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    account_id       INT NOT NULL,
    direction        NVARCHAR(3) NOT NULL,
    amount           DECIMAL(14,2) NOT NULL,
    category         NVARCHAR(100) NOT NULL,
    reference_table  NVARCHAR(128) NULL,
    reference_id     INT NULL,
    description      NVARCHAR(400) NULL,
    CONSTRAINT FK_cash_movements_account FOREIGN KEY (account_id) REFERENCES clothing_factory.cash_accounts(account_id),
    CONSTRAINT CK_cash_movements_direction CHECK (direction IN ('in', 'out')),
    CONSTRAINT CK_cash_movements_amount CHECK (amount > 0)
);
GO

CREATE TABLE clothing_factory.purchase_orders (
    purchase_id      INT IDENTITY(1,1) PRIMARY KEY,
    supplier_id      INT NOT NULL,
    order_date       DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    expected_date    DATE NULL,
    received_date    DATE NULL,
    status           NVARCHAR(20) NOT NULL,
    total_amount     DECIMAL(14,2) NOT NULL DEFAULT 0,
    CONSTRAINT FK_purchase_orders_supplier FOREIGN KEY (supplier_id) REFERENCES clothing_factory.suppliers(supplier_id),
    CONSTRAINT CK_purchase_orders_status CHECK (status IN ('draft', 'ordered', 'received', 'cancelled'))
);
GO

CREATE TABLE clothing_factory.purchase_order_items (
    purchase_item_id INT IDENTITY(1,1) PRIMARY KEY,
    purchase_id      INT NOT NULL,
    raw_material_id  INT NOT NULL,
    quantity         DECIMAL(14,3) NOT NULL,
    unit_price       DECIMAL(14,2) NOT NULL,
    line_total       AS (quantity * unit_price) PERSISTED,
    CONSTRAINT FK_poi_purchase FOREIGN KEY (purchase_id) REFERENCES clothing_factory.purchase_orders(purchase_id),
    CONSTRAINT FK_poi_material FOREIGN KEY (raw_material_id) REFERENCES clothing_factory.raw_materials(raw_material_id),
    CONSTRAINT CK_poi_quantity CHECK (quantity > 0),
    CONSTRAINT CK_poi_price CHECK (unit_price > 0)
);
GO

CREATE TABLE clothing_factory.products (
    product_id       INT IDENTITY(1,1) PRIMARY KEY,
    sku              NVARCHAR(50) NOT NULL UNIQUE,
    product_name     NVARCHAR(200) NOT NULL,
    category         NVARCHAR(100) NOT NULL,
    size_label       NVARCHAR(20) NULL,
    sale_price       DECIMAL(14,2) NOT NULL,
    standard_cost    DECIMAL(14,2) NOT NULL DEFAULT 0,
    created_at       DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_products_sale_price CHECK (sale_price >= 0),
    CONSTRAINT CK_products_standard_cost CHECK (standard_cost >= 0)
);
GO

CREATE TABLE clothing_factory.bill_of_materials (
    product_id       INT NOT NULL,
    raw_material_id  INT NOT NULL,
    qty_per_unit     DECIMAL(14,3) NOT NULL,
    CONSTRAINT PK_bill_of_materials PRIMARY KEY (product_id, raw_material_id),
    CONSTRAINT FK_bom_product FOREIGN KEY (product_id) REFERENCES clothing_factory.products(product_id),
    CONSTRAINT FK_bom_material FOREIGN KEY (raw_material_id) REFERENCES clothing_factory.raw_materials(raw_material_id),
    CONSTRAINT CK_bom_qty CHECK (qty_per_unit > 0)
);
GO

CREATE TABLE clothing_factory.production_orders (
    production_order_id INT IDENTITY(1,1) PRIMARY KEY,
    product_id          INT NOT NULL,
    order_date          DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    planned_qty         DECIMAL(14,3) NOT NULL,
    produced_qty        DECIMAL(14,3) NOT NULL DEFAULT 0,
    completion_date     DATE NULL,
    status              NVARCHAR(20) NOT NULL,
    total_cost          DECIMAL(14,2) NOT NULL DEFAULT 0,
    CONSTRAINT FK_production_orders_product FOREIGN KEY (product_id) REFERENCES clothing_factory.products(product_id),
    CONSTRAINT CK_production_orders_qty CHECK (planned_qty > 0),
    CONSTRAINT CK_production_orders_status CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled'))
);
GO

CREATE TABLE clothing_factory.production_consumption (
    consumption_id      INT IDENTITY(1,1) PRIMARY KEY,
    production_order_id INT NOT NULL,
    raw_material_id     INT NOT NULL,
    quantity            DECIMAL(14,3) NOT NULL,
    unit_cost           DECIMAL(14,2) NOT NULL,
    line_cost           AS (quantity * unit_cost) PERSISTED,
    CONSTRAINT FK_production_consumption_order FOREIGN KEY (production_order_id) REFERENCES clothing_factory.production_orders(production_order_id),
    CONSTRAINT FK_production_consumption_material FOREIGN KEY (raw_material_id) REFERENCES clothing_factory.raw_materials(raw_material_id),
    CONSTRAINT CK_production_consumption_qty CHECK (quantity > 0),
    CONSTRAINT CK_production_consumption_cost CHECK (unit_cost >= 0)
);
GO

CREATE TABLE clothing_factory.finished_inventory (
    product_id          INT PRIMARY KEY,
    quantity            DECIMAL(14,3) NOT NULL DEFAULT 0,
    avg_cost            DECIMAL(14,2) NOT NULL DEFAULT 0,
    updated_at          DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_finished_inventory_product FOREIGN KEY (product_id) REFERENCES clothing_factory.products(product_id),
    CONSTRAINT CK_finished_inventory_qty CHECK (quantity >= 0),
    CONSTRAINT CK_finished_inventory_cost CHECK (avg_cost >= 0)
);
GO

CREATE TABLE clothing_factory.customers (
    customer_id         INT IDENTITY(1,1) PRIMARY KEY,
    customer_name       NVARCHAR(200) NOT NULL,
    phone               NVARCHAR(50) NULL,
    email               NVARCHAR(200) NULL,
    created_at          DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE TABLE clothing_factory.sales_orders (
    sales_id            INT IDENTITY(1,1) PRIMARY KEY,
    customer_id         INT NOT NULL,
    sales_date          DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    status              NVARCHAR(20) NOT NULL,
    total_amount        DECIMAL(14,2) NOT NULL DEFAULT 0,
    CONSTRAINT FK_sales_orders_customer FOREIGN KEY (customer_id) REFERENCES clothing_factory.customers(customer_id),
    CONSTRAINT CK_sales_orders_status CHECK (status IN ('draft', 'paid', 'cancelled'))
);
GO

CREATE TABLE clothing_factory.sales_order_items (
    sales_item_id       INT IDENTITY(1,1) PRIMARY KEY,
    sales_id            INT NOT NULL,
    product_id          INT NOT NULL,
    quantity            DECIMAL(14,3) NOT NULL,
    unit_price          DECIMAL(14,2) NOT NULL,
    unit_cost           DECIMAL(14,2) NOT NULL,
    line_total          AS (quantity * unit_price) PERSISTED,
    CONSTRAINT FK_soi_sales FOREIGN KEY (sales_id) REFERENCES clothing_factory.sales_orders(sales_id),
    CONSTRAINT FK_soi_product FOREIGN KEY (product_id) REFERENCES clothing_factory.products(product_id),
    CONSTRAINT CK_soi_quantity CHECK (quantity > 0),
    CONSTRAINT CK_soi_price CHECK (unit_price >= 0),
    CONSTRAINT CK_soi_cost CHECK (unit_cost >= 0)
);
GO

CREATE TABLE clothing_factory.departments (
    department_id       INT IDENTITY(1,1) PRIMARY KEY,
    department_name     NVARCHAR(100) NOT NULL UNIQUE
);
GO

CREATE TABLE clothing_factory.positions (
    position_id         INT IDENTITY(1,1) PRIMARY KEY,
    department_id       INT NOT NULL,
    position_name       NVARCHAR(100) NOT NULL,
    base_salary         DECIMAL(14,2) NOT NULL,
    CONSTRAINT FK_positions_department FOREIGN KEY (department_id) REFERENCES clothing_factory.departments(department_id),
    CONSTRAINT CK_positions_salary CHECK (base_salary >= 0)
);
GO

CREATE TABLE clothing_factory.employees (
    employee_id         INT IDENTITY(1,1) PRIMARY KEY,
    full_name           NVARCHAR(200) NOT NULL,
    hire_date           DATE NOT NULL,
    position_id         INT NOT NULL,
    is_active           BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_employees_position FOREIGN KEY (position_id) REFERENCES clothing_factory.positions(position_id)
);
GO

CREATE TABLE clothing_factory.timesheets (
    timesheet_id        INT IDENTITY(1,1) PRIMARY KEY,
    employee_id         INT NOT NULL,
    period_month        DATE NOT NULL,
    worked_days         INT NOT NULL,
    bonus               DECIMAL(14,2) NOT NULL DEFAULT 0,
    deductions          DECIMAL(14,2) NOT NULL DEFAULT 0,
    CONSTRAINT FK_timesheets_employee FOREIGN KEY (employee_id) REFERENCES clothing_factory.employees(employee_id),
    CONSTRAINT UQ_timesheets_employee_month UNIQUE (employee_id, period_month),
    CONSTRAINT CK_timesheets_days CHECK (worked_days BETWEEN 0 AND 31),
    CONSTRAINT CK_timesheets_month_start CHECK (DAY(period_month) = 1)
);
GO

CREATE TABLE clothing_factory.payroll (
    payroll_id          INT IDENTITY(1,1) PRIMARY KEY,
    employee_id         INT NOT NULL,
    period_month        DATE NOT NULL,
    gross_salary        DECIMAL(14,2) NOT NULL,
    tax_amount          DECIMAL(14,2) NOT NULL,
    net_salary          DECIMAL(14,2) NOT NULL,
    status              NVARCHAR(20) NOT NULL,
    paid_date           DATE NULL,
    CONSTRAINT FK_payroll_employee FOREIGN KEY (employee_id) REFERENCES clothing_factory.employees(employee_id),
    CONSTRAINT UQ_payroll_employee_month UNIQUE (employee_id, period_month),
    CONSTRAINT CK_payroll_month_start CHECK (DAY(period_month) = 1),
    CONSTRAINT CK_payroll_gross CHECK (gross_salary >= 0),
    CONSTRAINT CK_payroll_tax CHECK (tax_amount >= 0),
    CONSTRAINT CK_payroll_net CHECK (net_salary >= 0),
    CONSTRAINT CK_payroll_status CHECK (status IN ('calculated', 'paid'))
);
GO

CREATE TABLE clothing_factory.loans (
    loan_id             INT IDENTITY(1,1) PRIMARY KEY,
    bank_name           NVARCHAR(200) NOT NULL,
    start_date          DATE NOT NULL,
    principal_amount    DECIMAL(14,2) NOT NULL,
    interest_rate       DECIMAL(7,4) NOT NULL,
    term_months         INT NOT NULL,
    status              NVARCHAR(20) NOT NULL,
    current_principal   DECIMAL(14,2) NOT NULL,
    CONSTRAINT CK_loans_principal CHECK (principal_amount > 0),
    CONSTRAINT CK_loans_rate CHECK (interest_rate >= 0),
    CONSTRAINT CK_loans_term CHECK (term_months > 0),
    CONSTRAINT CK_loans_status CHECK (status IN ('active', 'closed')),
    CONSTRAINT CK_loans_current_principal CHECK (current_principal >= 0)
);
GO

CREATE TABLE clothing_factory.loan_schedule (
    schedule_id         INT IDENTITY(1,1) PRIMARY KEY,
    loan_id             INT NOT NULL,
    installment_no      INT NOT NULL,
    due_date            DATE NOT NULL,
    principal_due       DECIMAL(14,2) NOT NULL,
    interest_due        DECIMAL(14,2) NOT NULL,
    total_due           AS (principal_due + interest_due) PERSISTED,
    paid                BIT NOT NULL DEFAULT 0,
    paid_at             DATE NULL,
    CONSTRAINT FK_loan_schedule_loan FOREIGN KEY (loan_id) REFERENCES clothing_factory.loans(loan_id),
    CONSTRAINT UQ_loan_schedule_no UNIQUE (loan_id, installment_no),
    CONSTRAINT UQ_loan_schedule_due UNIQUE (loan_id, due_date),
    CONSTRAINT CK_loan_schedule_installment CHECK (installment_no > 0),
    CONSTRAINT CK_loan_schedule_principal CHECK (principal_due >= 0),
    CONSTRAINT CK_loan_schedule_interest CHECK (interest_due >= 0)
);
GO

CREATE TABLE clothing_factory.loan_payments (
    payment_id          INT IDENTITY(1,1) PRIMARY KEY,
    loan_id             INT NOT NULL,
    schedule_id         INT NOT NULL,
    payment_date        DATE NOT NULL,
    principal_paid      DECIMAL(14,2) NOT NULL,
    interest_paid       DECIMAL(14,2) NOT NULL,
    total_paid          AS (principal_paid + interest_paid) PERSISTED,
    CONSTRAINT FK_loan_payments_loan FOREIGN KEY (loan_id) REFERENCES clothing_factory.loans(loan_id),
    CONSTRAINT FK_loan_payments_schedule FOREIGN KEY (schedule_id) REFERENCES clothing_factory.loan_schedule(schedule_id),
    CONSTRAINT CK_loan_payments_principal CHECK (principal_paid >= 0),
    CONSTRAINT CK_loan_payments_interest CHECK (interest_paid >= 0)
);
GO

CREATE INDEX IX_purchase_orders_date ON clothing_factory.purchase_orders(order_date);
CREATE INDEX IX_purchase_orders_status ON clothing_factory.purchase_orders(status);
CREATE INDEX IX_production_orders_date ON clothing_factory.production_orders(order_date);
CREATE INDEX IX_sales_orders_date ON clothing_factory.sales_orders(sales_date);
CREATE INDEX IX_sales_orders_status ON clothing_factory.sales_orders(status);
CREATE INDEX IX_payroll_period ON clothing_factory.payroll(period_month);
CREATE INDEX IX_cash_movements_date ON clothing_factory.cash_movements(movement_date);
CREATE INDEX IX_loan_schedule_due ON clothing_factory.loan_schedule(due_date);
GO

/* ===== FILE: 01_seed.sql ===== */
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

/* ===== FILE: 02_common_functions.sql ===== */
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE clothing_factory.sp_record_cash_movement
    @account_id INT,
    @direction NVARCHAR(3),
    @amount DECIMAL(14,2),
    @category NVARCHAR(100),
    @reference_table NVARCHAR(128) = NULL,
    @reference_id INT = NULL,
    @description NVARCHAR(400) = NULL,
    @movement_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @amount IS NULL OR @amount <= 0
        THROW 50001, N'Сумма движения должна быть больше 0', 1;

    IF @direction NOT IN (N'in', N'out')
        THROW 50002, N'Направление должно быть in или out', 1;

    BEGIN TRANSACTION;

    IF @direction = N'in'
    BEGIN
        UPDATE clothing_factory.cash_accounts
        SET balance = ROUND(balance + @amount, 2)
        WHERE account_id = @account_id;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50003, N'Счет не найден', 1;
        END
    END
    ELSE
    BEGIN
        UPDATE clothing_factory.cash_accounts
        SET balance = ROUND(balance - @amount, 2)
        WHERE account_id = @account_id
          AND balance >= @amount;

        IF @@ROWCOUNT = 0
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM clothing_factory.cash_accounts WHERE account_id = @account_id)
            BEGIN
                ROLLBACK TRANSACTION;
                THROW 50004, N'Счет не найден', 1;
            END

            ROLLBACK TRANSACTION;
            THROW 50005, N'Недостаточно средств на счете', 1;
        END
    END

    INSERT INTO clothing_factory.cash_movements (
        account_id,
        direction,
        amount,
        category,
        reference_table,
        reference_id,
        description
    )
    VALUES (
        @account_id,
        @direction,
        @amount,
        @category,
        @reference_table,
        @reference_id,
        @description
    );

    SET @movement_id = CAST(SCOPE_IDENTITY() AS INT);

    COMMIT TRANSACTION;
END;
GO

/* ===== FILE: lab1_procurement.sql ===== */
SET NOCOUNT ON;
GO

/*
ЛР1: Функционал закупки сырья
@items_json формат:
[
  {"raw_material_id": 1, "quantity": 500, "unit_price": 1450},
  {"raw_material_id": 3, "quantity": 200, "unit_price": 280}
]
*/

CREATE OR ALTER PROCEDURE clothing_factory.sp_create_purchase_order
    @supplier_id INT,
    @expected_date DATE = NULL,
    @items_json NVARCHAR(MAX),
    @purchase_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM clothing_factory.suppliers WHERE supplier_id = @supplier_id)
        THROW 51001, N'Поставщик не найден', 1;

    IF ISJSON(@items_json) <> 1
        THROW 51002, N'Неверный JSON формата закупки', 1;

    DECLARE @items TABLE (
        raw_material_id INT NOT NULL,
        quantity DECIMAL(14,3) NOT NULL,
        unit_price DECIMAL(14,2) NOT NULL
    );

    INSERT INTO @items (raw_material_id, quantity, unit_price)
    SELECT raw_material_id, quantity, unit_price
    FROM OPENJSON(@items_json)
    WITH (
        raw_material_id INT '$.raw_material_id',
        quantity DECIMAL(14,3) '$.quantity',
        unit_price DECIMAL(14,2) '$.unit_price'
    );

    IF NOT EXISTS (SELECT 1 FROM @items)
        THROW 51003, N'Список закупаемых материалов пуст', 1;

    IF EXISTS (
        SELECT 1
        FROM @items
        WHERE raw_material_id IS NULL OR quantity IS NULL OR unit_price IS NULL
           OR quantity <= 0 OR unit_price <= 0
    )
        THROW 51004, N'В позициях закупки есть некорректные значения', 1;

    IF EXISTS (
        SELECT 1
        FROM @items i
        LEFT JOIN clothing_factory.raw_materials rm ON rm.raw_material_id = i.raw_material_id
        WHERE rm.raw_material_id IS NULL
    )
        THROW 51005, N'Некоторые виды сырья не найдены', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO clothing_factory.purchase_orders (supplier_id, order_date, expected_date, status, total_amount)
        VALUES (@supplier_id, CAST(GETDATE() AS DATE), @expected_date, N'ordered', 0);

        SET @purchase_id = CAST(SCOPE_IDENTITY() AS INT);

        INSERT INTO clothing_factory.purchase_order_items (purchase_id, raw_material_id, quantity, unit_price)
        SELECT @purchase_id, raw_material_id, quantity, unit_price
        FROM @items;

        UPDATE clothing_factory.purchase_orders
        SET total_amount = (
            SELECT ROUND(SUM(quantity * unit_price), 2)
            FROM @items
        )
        WHERE purchase_id = @purchase_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE clothing_factory.sp_receive_purchase_order
    @purchase_id INT,
    @account_id INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @status NVARCHAR(20);
    DECLARE @total_amount DECIMAL(14,2);
    DECLARE @movement_id INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @status = status,
            @total_amount = total_amount
        FROM clothing_factory.purchase_orders WITH (UPDLOCK, HOLDLOCK)
        WHERE purchase_id = @purchase_id;

        IF @status IS NULL
            THROW 51006, N'Закупка не найдена', 1;

        IF @status <> N'ordered'
            THROW 51007, N'Закупка не может быть принята в текущем статусе', 1;

        ;WITH receipt AS (
            SELECT
                raw_material_id,
                SUM(quantity) AS qty,
                SUM(quantity * unit_price) AS total_cost
            FROM clothing_factory.purchase_order_items
            WHERE purchase_id = @purchase_id
            GROUP BY raw_material_id
        )
        MERGE clothing_factory.raw_inventory AS tgt
        USING receipt AS src
            ON tgt.raw_material_id = src.raw_material_id
        WHEN MATCHED THEN
            UPDATE SET
                quantity = ROUND(tgt.quantity + src.qty, 3),
                avg_cost = CASE
                    WHEN (tgt.quantity + src.qty) = 0 THEN 0
                    ELSE ROUND(((tgt.quantity * tgt.avg_cost) + src.total_cost) / (tgt.quantity + src.qty), 2)
                END,
                updated_at = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (raw_material_id, quantity, avg_cost, updated_at)
            VALUES (
                src.raw_material_id,
                ROUND(src.qty, 3),
                CASE WHEN src.qty = 0 THEN 0 ELSE ROUND(src.total_cost / src.qty, 2) END,
                SYSDATETIME()
            );

        UPDATE clothing_factory.purchase_orders
        SET
            status = N'received',
            received_date = CAST(GETDATE() AS DATE)
        WHERE purchase_id = @purchase_id;

        EXEC clothing_factory.sp_record_cash_movement
            @account_id = @account_id,
            @direction = N'out',
            @amount = @total_amount,
            @category = N'purchase',
            @reference_table = N'purchase_orders',
            @reference_id = @purchase_id,
            @description = N'Оплата закупки сырья',
            @movement_id = @movement_id OUTPUT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ===== FILE: lab2_production.sql ===== */
SET NOCOUNT ON;
GO

/*
ЛР2: Функционал производства готовой продукции
*/

CREATE OR ALTER PROCEDURE clothing_factory.sp_run_production
    @product_id INT,
    @quantity DECIMAL(14,3),
    @order_date DATE = NULL,
    @production_order_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @quantity IS NULL OR @quantity <= 0
        THROW 52001, N'Количество выпуска должно быть больше 0', 1;

    IF @order_date IS NULL
        SET @order_date = CAST(GETDATE() AS DATE);

    IF NOT EXISTS (SELECT 1 FROM clothing_factory.products WHERE product_id = @product_id)
        THROW 52002, N'Продукт не найден', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO clothing_factory.production_orders (
            product_id,
            order_date,
            planned_qty,
            produced_qty,
            status,
            total_cost
        )
        VALUES (
            @product_id,
            @order_date,
            @quantity,
            0,
            N'in_progress',
            0
        );

        SET @production_order_id = CAST(SCOPE_IDENTITY() AS INT);

        DECLARE @consumption TABLE (
            raw_material_id INT PRIMARY KEY,
            required_qty DECIMAL(14,3) NOT NULL,
            unit_cost DECIMAL(14,2) NOT NULL,
            stock_qty DECIMAL(14,3) NULL
        );

        INSERT INTO @consumption (raw_material_id, required_qty, unit_cost, stock_qty)
        SELECT
            b.raw_material_id,
            ROUND(b.qty_per_unit * @quantity, 3) AS required_qty,
            ISNULL(ri.avg_cost, 0) AS unit_cost,
            ri.quantity AS stock_qty
        FROM clothing_factory.bill_of_materials b
        LEFT JOIN clothing_factory.raw_inventory ri WITH (UPDLOCK, HOLDLOCK)
            ON ri.raw_material_id = b.raw_material_id
        WHERE b.product_id = @product_id;

        IF NOT EXISTS (SELECT 1 FROM @consumption)
            THROW 52003, N'Для продукта не задана спецификация BOM', 1;

        IF EXISTS (SELECT 1 FROM @consumption WHERE stock_qty IS NULL)
            THROW 52004, N'Не для всех материалов создана строка склада сырья', 1;

        IF EXISTS (SELECT 1 FROM @consumption WHERE stock_qty < required_qty)
            THROW 52005, N'Недостаточно сырья для выполнения производства', 1;

        UPDATE ri
        SET
            ri.quantity = ROUND(ri.quantity - c.required_qty, 3),
            ri.updated_at = SYSDATETIME()
        FROM clothing_factory.raw_inventory ri
        JOIN @consumption c ON c.raw_material_id = ri.raw_material_id;

        INSERT INTO clothing_factory.production_consumption (
            production_order_id,
            raw_material_id,
            quantity,
            unit_cost
        )
        SELECT
            @production_order_id,
            raw_material_id,
            required_qty,
            unit_cost
        FROM @consumption;

        DECLARE @total_cost DECIMAL(14,2);
        SET @total_cost = (
            SELECT ROUND(SUM(required_qty * unit_cost), 2)
            FROM @consumption
        );

        MERGE clothing_factory.finished_inventory AS tgt
        USING (
            SELECT
                @product_id AS product_id,
                @quantity AS produced_qty,
                @total_cost AS production_cost
        ) AS src
            ON tgt.product_id = src.product_id
        WHEN MATCHED THEN
            UPDATE SET
                quantity = ROUND(tgt.quantity + src.produced_qty, 3),
                avg_cost = CASE
                    WHEN (tgt.quantity + src.produced_qty) = 0 THEN 0
                    ELSE ROUND(((tgt.quantity * tgt.avg_cost) + src.production_cost) / (tgt.quantity + src.produced_qty), 2)
                END,
                updated_at = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (product_id, quantity, avg_cost, updated_at)
            VALUES (
                src.product_id,
                src.produced_qty,
                CASE WHEN src.produced_qty = 0 THEN 0 ELSE ROUND(src.production_cost / src.produced_qty, 2) END,
                SYSDATETIME()
            );

        UPDATE clothing_factory.production_orders
        SET
            produced_qty = @quantity,
            completion_date = CAST(GETDATE() AS DATE),
            total_cost = @total_cost,
            status = N'completed'
        WHERE production_order_id = @production_order_id;

        UPDATE clothing_factory.products
        SET standard_cost = CASE WHEN @quantity = 0 THEN standard_cost ELSE ROUND(@total_cost / @quantity, 2) END
        WHERE product_id = @product_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ===== FILE: lab3_sales.sql ===== */
SET NOCOUNT ON;
GO

/*
ЛР3: Функционал продажи готовой продукции
@items_json формат:
[
  {"product_id": 1, "quantity": 100, "unit_price": 9000},
  {"product_id": 2, "quantity": 30}
]
Если unit_price не передан, используется products.sale_price.
*/

CREATE OR ALTER PROCEDURE clothing_factory.sp_create_sale
    @customer_id INT,
    @items_json NVARCHAR(MAX),
    @sale_date DATE = NULL,
    @account_id INT = 1,
    @sales_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @sale_date IS NULL
        SET @sale_date = CAST(GETDATE() AS DATE);

    IF NOT EXISTS (SELECT 1 FROM clothing_factory.customers WHERE customer_id = @customer_id)
        THROW 53001, N'Клиент не найден', 1;

    IF ISJSON(@items_json) <> 1
        THROW 53002, N'Неверный JSON формата продажи', 1;

    DECLARE @items TABLE (
        product_id INT NOT NULL,
        quantity DECIMAL(14,3) NOT NULL,
        unit_price DECIMAL(14,2) NULL
    );

    INSERT INTO @items (product_id, quantity, unit_price)
    SELECT product_id, quantity, unit_price
    FROM OPENJSON(@items_json)
    WITH (
        product_id INT '$.product_id',
        quantity DECIMAL(14,3) '$.quantity',
        unit_price DECIMAL(14,2) '$.unit_price'
    );

    IF NOT EXISTS (SELECT 1 FROM @items)
        THROW 53003, N'Список продаваемой продукции пуст', 1;

    IF EXISTS (
        SELECT 1
        FROM @items
        WHERE product_id IS NULL OR quantity IS NULL OR quantity <= 0 OR (unit_price IS NOT NULL AND unit_price < 0)
    )
        THROW 53004, N'В позициях продажи есть некорректные значения', 1;

    IF EXISTS (
        SELECT 1
        FROM @items i
        LEFT JOIN clothing_factory.products p ON p.product_id = i.product_id
        WHERE p.product_id IS NULL
    )
        THROW 53005, N'Некоторые товары не найдены', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @need TABLE (
            product_id INT PRIMARY KEY,
            qty_needed DECIMAL(14,3) NOT NULL
        );

        INSERT INTO @need (product_id, qty_needed)
        SELECT product_id, SUM(quantity)
        FROM @items
        GROUP BY product_id;

        IF EXISTS (
            SELECT 1
            FROM @need n
            LEFT JOIN clothing_factory.finished_inventory fi WITH (UPDLOCK, HOLDLOCK)
                ON fi.product_id = n.product_id
            WHERE fi.product_id IS NULL
        )
            THROW 53006, N'Для некоторых товаров отсутствует запись склада готовой продукции', 1;

        IF EXISTS (
            SELECT 1
            FROM @need n
            JOIN clothing_factory.finished_inventory fi WITH (UPDLOCK, HOLDLOCK)
                ON fi.product_id = n.product_id
            WHERE fi.quantity < n.qty_needed
        )
            THROW 53007, N'Недостаточно товара на складе для продажи', 1;

        INSERT INTO clothing_factory.sales_orders (customer_id, sales_date, status, total_amount)
        VALUES (@customer_id, @sale_date, N'draft', 0);

        SET @sales_id = CAST(SCOPE_IDENTITY() AS INT);

        DECLARE @normalized TABLE (
            product_id INT NOT NULL,
            quantity DECIMAL(14,3) NOT NULL,
            unit_price DECIMAL(14,2) NOT NULL,
            unit_cost DECIMAL(14,2) NOT NULL
        );

        INSERT INTO @normalized (product_id, quantity, unit_price, unit_cost)
        SELECT
            i.product_id,
            i.quantity,
            ISNULL(i.unit_price, p.sale_price) AS final_unit_price,
            fi.avg_cost AS unit_cost
        FROM @items i
        JOIN clothing_factory.products p ON p.product_id = i.product_id
        JOIN clothing_factory.finished_inventory fi ON fi.product_id = i.product_id;

        UPDATE fi
        SET
            fi.quantity = ROUND(fi.quantity - n.qty_needed, 3),
            fi.updated_at = SYSDATETIME()
        FROM clothing_factory.finished_inventory fi
        JOIN @need n ON n.product_id = fi.product_id;

        INSERT INTO clothing_factory.sales_order_items (
            sales_id,
            product_id,
            quantity,
            unit_price,
            unit_cost
        )
        SELECT
            @sales_id,
            product_id,
            quantity,
            unit_price,
            unit_cost
        FROM @normalized;

        DECLARE @total_amount DECIMAL(14,2);
        SET @total_amount = (
            SELECT ROUND(SUM(quantity * unit_price), 2)
            FROM @normalized
        );

        UPDATE clothing_factory.sales_orders
        SET
            total_amount = @total_amount,
            status = N'paid'
        WHERE sales_id = @sales_id;

        DECLARE @movement_id INT;
        EXEC clothing_factory.sp_record_cash_movement
            @account_id = @account_id,
            @direction = N'in',
            @amount = @total_amount,
            @category = N'sale',
            @reference_table = N'sales_orders',
            @reference_id = @sales_id,
            @description = N'Поступление от реализации продукции',
            @movement_id = @movement_id OUTPUT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ===== FILE: lab4_payroll.sql ===== */
SET NOCOUNT ON;
GO

/*
ЛР4: Выдача зарплаты сотрудникам
*/

CREATE OR ALTER PROCEDURE clothing_factory.sp_calculate_payroll
    @period_month DATE,
    @processed_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @period_month = DATEFROMPARTS(YEAR(@period_month), MONTH(@period_month), 1);

    DECLARE @src TABLE (
        employee_id INT PRIMARY KEY,
        period_month DATE NOT NULL,
        gross_salary DECIMAL(14,2) NOT NULL,
        tax_amount DECIMAL(14,2) NOT NULL,
        net_salary DECIMAL(14,2) NOT NULL
    );

    INSERT INTO @src (employee_id, period_month, gross_salary, tax_amount, net_salary)
    SELECT
        s.employee_id,
        @period_month,
        s.gross_salary,
        ROUND(s.gross_salary * 0.10, 2) AS tax_amount,
        ROUND(s.gross_salary - ROUND(s.gross_salary * 0.10, 2), 2) AS net_salary
    FROM (
        SELECT
            e.employee_id,
            CASE
                WHEN ROUND(((p.base_salary / 22.0) * ISNULL(ts.worked_days, 22)) + ISNULL(ts.bonus, 0) - ISNULL(ts.deductions, 0), 2) < 0
                    THEN 0
                ELSE ROUND(((p.base_salary / 22.0) * ISNULL(ts.worked_days, 22)) + ISNULL(ts.bonus, 0) - ISNULL(ts.deductions, 0), 2)
            END AS gross_salary
        FROM clothing_factory.employees e
        JOIN clothing_factory.positions p ON p.position_id = e.position_id
        LEFT JOIN clothing_factory.timesheets ts
            ON ts.employee_id = e.employee_id
           AND ts.period_month = @period_month
        WHERE e.is_active = 1
    ) s;

    BEGIN TRY
        BEGIN TRANSACTION;

        MERGE clothing_factory.payroll AS tgt
        USING @src AS src
            ON tgt.employee_id = src.employee_id
           AND tgt.period_month = src.period_month
        WHEN MATCHED THEN
            UPDATE SET
                gross_salary = src.gross_salary,
                tax_amount = src.tax_amount,
                net_salary = src.net_salary,
                status = N'calculated',
                paid_date = NULL
        WHEN NOT MATCHED THEN
            INSERT (
                employee_id,
                period_month,
                gross_salary,
                tax_amount,
                net_salary,
                status,
                paid_date
            )
            VALUES (
                src.employee_id,
                src.period_month,
                src.gross_salary,
                src.tax_amount,
                src.net_salary,
                N'calculated',
                NULL
            );

        SET @processed_count = (SELECT COUNT(*) FROM @src);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE clothing_factory.sp_pay_payroll
    @period_month DATE,
    @account_id INT = 1,
    @paid_date DATE = NULL,
    @total_paid DECIMAL(14,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @period_month = DATEFROMPARTS(YEAR(@period_month), MONTH(@period_month), 1);

    IF @paid_date IS NULL
        SET @paid_date = CAST(GETDATE() AS DATE);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @total_paid = ROUND(ISNULL(SUM(net_salary), 0), 2)
        FROM clothing_factory.payroll
        WHERE period_month = @period_month
          AND status = N'calculated';

        IF @total_paid <= 0
            THROW 54001, N'Нет рассчитанной зарплаты за указанный период', 1;

        UPDATE clothing_factory.payroll
        SET
            status = N'paid',
            paid_date = @paid_date
        WHERE period_month = @period_month
          AND status = N'calculated';

        DECLARE @movement_id INT;
        EXEC clothing_factory.sp_record_cash_movement
            @account_id = @account_id,
            @direction = N'out',
            @amount = @total_paid,
            @category = N'payroll',
            @reference_table = N'payroll',
            @reference_id = NULL,
            @description = N'Выплата зарплаты',
            @movement_id = @movement_id OUTPUT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ===== FILE: lab5_credit.sql ===== */
SET NOCOUNT ON;
GO

/*
ЛР5: Функционал получения кредита для бизнеса
*/

CREATE OR ALTER PROCEDURE clothing_factory.sp_take_loan
    @bank_name NVARCHAR(200),
    @principal DECIMAL(14,2),
    @interest_rate DECIMAL(7,4),
    @term_months INT,
    @start_date DATE = NULL,
    @account_id INT = 1,
    @loan_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @start_date IS NULL
        SET @start_date = CAST(GETDATE() AS DATE);

    IF @principal IS NULL OR @principal <= 0
        THROW 55001, N'Сумма кредита должна быть больше 0', 1;

    IF @interest_rate IS NULL OR @interest_rate < 0
        THROW 55002, N'Процентная ставка не может быть отрицательной', 1;

    IF @term_months IS NULL OR @term_months <= 0
        THROW 55003, N'Срок кредита должен быть больше 0 месяцев', 1;

    DECLARE @monthly_rate DECIMAL(18,10);
    DECLARE @payment DECIMAL(14,2);
    DECLARE @remaining DECIMAL(14,2);
    DECLARE @interest_due DECIMAL(14,2);
    DECLARE @principal_due DECIMAL(14,2);
    DECLARE @due_date DATE;
    DECLARE @i INT = 1;

    SET @monthly_rate = @interest_rate / 100.0 / 12.0;

    IF @monthly_rate = 0
        SET @payment = ROUND(@principal / @term_months, 2);
    ELSE
        SET @payment = ROUND(
            @principal * @monthly_rate / (1 - POWER(1 + @monthly_rate, -@term_months)),
            2
        );

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO clothing_factory.loans (
            bank_name,
            start_date,
            principal_amount,
            interest_rate,
            term_months,
            status,
            current_principal
        )
        VALUES (
            @bank_name,
            @start_date,
            @principal,
            @interest_rate,
            @term_months,
            N'active',
            @principal
        );

        SET @loan_id = CAST(SCOPE_IDENTITY() AS INT);
        SET @remaining = @principal;

        WHILE @i <= @term_months
        BEGIN
            SET @interest_due = ROUND(@remaining * @monthly_rate, 2);
            SET @principal_due = ROUND(@payment - @interest_due, 2);

            IF @i = @term_months OR @principal_due > @remaining
                SET @principal_due = @remaining;

            SET @due_date = DATEADD(MONTH, @i, @start_date);

            INSERT INTO clothing_factory.loan_schedule (
                loan_id,
                installment_no,
                due_date,
                principal_due,
                interest_due,
                paid,
                paid_at
            )
            VALUES (
                @loan_id,
                @i,
                @due_date,
                @principal_due,
                @interest_due,
                0,
                NULL
            );

            SET @remaining = ROUND(@remaining - @principal_due, 2);
            SET @i += 1;
        END

        DECLARE @movement_id INT;
        EXEC clothing_factory.sp_record_cash_movement
            @account_id = @account_id,
            @direction = N'in',
            @amount = @principal,
            @category = N'loan_received',
            @reference_table = N'loans',
            @reference_id = @loan_id,
            @description = N'Получен банковский кредит',
            @movement_id = @movement_id OUTPUT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE clothing_factory.sp_pay_loan_installment
    @loan_id INT,
    @installment_no INT,
    @payment_date DATE = NULL,
    @account_id INT = 1,
    @total_paid DECIMAL(14,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @payment_date IS NULL
        SET @payment_date = CAST(GETDATE() AS DATE);

    DECLARE @schedule_id INT;
    DECLARE @principal_due DECIMAL(14,2);
    DECLARE @interest_due DECIMAL(14,2);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @schedule_id = schedule_id,
            @principal_due = principal_due,
            @interest_due = interest_due
        FROM clothing_factory.loan_schedule WITH (UPDLOCK, HOLDLOCK)
        WHERE loan_id = @loan_id
          AND installment_no = @installment_no
          AND paid = 0;

        IF @schedule_id IS NULL
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM clothing_factory.loan_schedule
                WHERE loan_id = @loan_id
                  AND installment_no = @installment_no
                  AND paid = 1
            )
                THROW 55004, N'Платеж уже оплачен', 1;

            THROW 55005, N'Платеж по кредиту не найден', 1;
        END

        SET @total_paid = ROUND(@principal_due + @interest_due, 2);

        UPDATE clothing_factory.loan_schedule
        SET
            paid = 1,
            paid_at = @payment_date
        WHERE schedule_id = @schedule_id;

        INSERT INTO clothing_factory.loan_payments (
            loan_id,
            schedule_id,
            payment_date,
            principal_paid,
            interest_paid
        )
        VALUES (
            @loan_id,
            @schedule_id,
            @payment_date,
            @principal_due,
            @interest_due
        );

        UPDATE clothing_factory.loans
        SET current_principal = CASE
            WHEN current_principal - @principal_due < 0 THEN 0
            ELSE ROUND(current_principal - @principal_due, 2)
        END
        WHERE loan_id = @loan_id;

        UPDATE clothing_factory.loans
        SET status = CASE WHEN current_principal <= 0 THEN N'closed' ELSE N'active' END
        WHERE loan_id = @loan_id;

        DECLARE @movement_id INT;
        EXEC clothing_factory.sp_record_cash_movement
            @account_id = @account_id,
            @direction = N'out',
            @amount = @total_paid,
            @category = N'loan_payment',
            @reference_table = N'loan_schedule',
            @reference_id = @schedule_id,
            @description = N'Оплата платежа по кредиту',
            @movement_id = @movement_id OUTPUT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ===== FILE: lab6_reports.sql ===== */
SET NOCOUNT ON;
GO

/*
ЛР6: Отчеты по всем процессам предприятия
*/

CREATE OR ALTER VIEW clothing_factory.v_raw_material_balance
AS
SELECT
    rm.raw_material_id,
    rm.material_name,
    rm.unit,
    ISNULL(ri.quantity, 0) AS quantity,
    ISNULL(ri.avg_cost, 0) AS avg_cost,
    ROUND(ISNULL(ri.quantity, 0) * ISNULL(ri.avg_cost, 0), 2) AS stock_value,
    rm.min_stock,
    CASE
        WHEN rm.min_stock - ISNULL(ri.quantity, 0) > 0 THEN rm.min_stock - ISNULL(ri.quantity, 0)
        ELSE 0
    END AS shortage
FROM clothing_factory.raw_materials rm
LEFT JOIN clothing_factory.raw_inventory ri ON ri.raw_material_id = rm.raw_material_id;
GO

CREATE OR ALTER VIEW clothing_factory.v_finished_product_balance
AS
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    ISNULL(fi.quantity, 0) AS quantity,
    ISNULL(fi.avg_cost, 0) AS avg_cost,
    p.sale_price,
    ROUND(ISNULL(fi.quantity, 0) * ISNULL(fi.avg_cost, 0), 2) AS inventory_cost,
    ROUND(ISNULL(fi.quantity, 0) * p.sale_price, 2) AS inventory_retail_value
FROM clothing_factory.products p
LEFT JOIN clothing_factory.finished_inventory fi ON fi.product_id = p.product_id;
GO

CREATE OR ALTER VIEW clothing_factory.v_production_summary
AS
SELECT
    po.production_order_id,
    po.order_date,
    po.completion_date,
    po.status,
    p.product_name,
    po.produced_qty,
    po.total_cost,
    CASE WHEN po.produced_qty = 0 THEN 0 ELSE ROUND(po.total_cost / po.produced_qty, 2) END AS unit_cost
FROM clothing_factory.production_orders po
JOIN clothing_factory.products p ON p.product_id = po.product_id;
GO

CREATE OR ALTER VIEW clothing_factory.v_sales_summary
AS
SELECT
    so.sales_id,
    so.sales_date,
    c.customer_name,
    so.status,
    ROUND(ISNULL(SUM(soi.line_total), 0), 2) AS revenue,
    ROUND(ISNULL(SUM(soi.quantity * soi.unit_cost), 0), 2) AS cogs,
    ROUND(ISNULL(SUM(soi.line_total - (soi.quantity * soi.unit_cost)), 0), 2) AS gross_profit
FROM clothing_factory.sales_orders so
JOIN clothing_factory.customers c ON c.customer_id = so.customer_id
LEFT JOIN clothing_factory.sales_order_items soi ON soi.sales_id = so.sales_id
GROUP BY so.sales_id, so.sales_date, c.customer_name, so.status;
GO

CREATE OR ALTER VIEW clothing_factory.v_monthly_payroll
AS
SELECT
    period_month,
    COUNT(*) AS employees_count,
    ROUND(SUM(gross_salary), 2) AS total_gross_salary,
    ROUND(SUM(tax_amount), 2) AS total_tax,
    ROUND(SUM(net_salary), 2) AS total_net_salary
FROM clothing_factory.payroll
GROUP BY period_month;
GO

CREATE OR ALTER VIEW clothing_factory.v_loans_status
AS
SELECT
    l.loan_id,
    l.bank_name,
    l.start_date,
    l.principal_amount,
    l.interest_rate,
    l.term_months,
    l.status,
    l.current_principal,
    ISNULL(SUM(CASE WHEN ls.paid = 1 THEN 1 ELSE 0 END), 0) AS paid_installments,
    COUNT(ls.schedule_id) AS total_installments,
    MIN(CASE WHEN ls.paid = 0 THEN ls.due_date END) AS next_due_date
FROM clothing_factory.loans l
LEFT JOIN clothing_factory.loan_schedule ls ON ls.loan_id = l.loan_id
GROUP BY
    l.loan_id,
    l.bank_name,
    l.start_date,
    l.principal_amount,
    l.interest_rate,
    l.term_months,
    l.status,
    l.current_principal;
GO

CREATE OR ALTER VIEW clothing_factory.v_company_kpi_monthly
AS
WITH sales_data AS (
    SELECT
        DATEFROMPARTS(YEAR(so.sales_date), MONTH(so.sales_date), 1) AS month_start,
        ROUND(SUM(soi.line_total), 2) AS revenue,
        ROUND(SUM(soi.quantity * soi.unit_cost), 2) AS cogs
    FROM clothing_factory.sales_orders so
    JOIN clothing_factory.sales_order_items soi ON soi.sales_id = so.sales_id
    WHERE so.status = N'paid'
    GROUP BY DATEFROMPARTS(YEAR(so.sales_date), MONTH(so.sales_date), 1)
),
purchase_data AS (
    SELECT
        DATEFROMPARTS(YEAR(po.received_date), MONTH(po.received_date), 1) AS month_start,
        ROUND(SUM(po.total_amount), 2) AS purchase_expense
    FROM clothing_factory.purchase_orders po
    WHERE po.status = N'received'
      AND po.received_date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(po.received_date), MONTH(po.received_date), 1)
),
payroll_data AS (
    SELECT
        DATEFROMPARTS(YEAR(p.paid_date), MONTH(p.paid_date), 1) AS month_start,
        ROUND(SUM(p.net_salary), 2) AS payroll_expense
    FROM clothing_factory.payroll p
    WHERE p.status = N'paid'
      AND p.paid_date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(p.paid_date), MONTH(p.paid_date), 1)
),
loan_interest_data AS (
    SELECT
        DATEFROMPARTS(YEAR(lp.payment_date), MONTH(lp.payment_date), 1) AS month_start,
        ROUND(SUM(lp.interest_paid), 2) AS loan_interest_expense
    FROM clothing_factory.loan_payments lp
    GROUP BY DATEFROMPARTS(YEAR(lp.payment_date), MONTH(lp.payment_date), 1)
),
all_months AS (
    SELECT month_start FROM sales_data
    UNION
    SELECT month_start FROM purchase_data
    UNION
    SELECT month_start FROM payroll_data
    UNION
    SELECT month_start FROM loan_interest_data
)
SELECT
    m.month_start AS [month],
    ISNULL(s.revenue, 0) AS revenue,
    ISNULL(s.cogs, 0) AS cogs,
    ROUND(ISNULL(s.revenue, 0) - ISNULL(s.cogs, 0), 2) AS gross_profit,
    ISNULL(pu.purchase_expense, 0) AS purchase_expense,
    ISNULL(pa.payroll_expense, 0) AS payroll_expense,
    ISNULL(li.loan_interest_expense, 0) AS loan_interest_expense,
    ROUND(
        ISNULL(s.revenue, 0)
        - ISNULL(s.cogs, 0)
        - ISNULL(pa.payroll_expense, 0)
        - ISNULL(li.loan_interest_expense, 0),
        2
    ) AS operating_profit
FROM all_months m
LEFT JOIN sales_data s ON s.month_start = m.month_start
LEFT JOIN purchase_data pu ON pu.month_start = m.month_start
LEFT JOIN payroll_data pa ON pa.month_start = m.month_start
LEFT JOIN loan_interest_data li ON li.month_start = m.month_start;
GO

CREATE OR ALTER PROCEDURE clothing_factory.sp_report_period_summary
    @date_from DATE,
    @date_to DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @revenue DECIMAL(14,2);
    DECLARE @cogs DECIMAL(14,2);
    DECLARE @purchase_expense DECIMAL(14,2);
    DECLARE @payroll_expense DECIMAL(14,2);
    DECLARE @loan_interest_expense DECIMAL(14,2);
    DECLARE @current_cash_balance DECIMAL(14,2);

    SELECT
        @revenue = ROUND(ISNULL(SUM(soi.line_total), 0), 2),
        @cogs = ROUND(ISNULL(SUM(soi.quantity * soi.unit_cost), 0), 2)
    FROM clothing_factory.sales_orders so
    JOIN clothing_factory.sales_order_items soi ON soi.sales_id = so.sales_id
    WHERE so.status = N'paid'
      AND so.sales_date BETWEEN @date_from AND @date_to;

    SELECT @purchase_expense = ROUND(ISNULL(SUM(total_amount), 0), 2)
    FROM clothing_factory.purchase_orders
    WHERE status = N'received'
      AND received_date BETWEEN @date_from AND @date_to;

    SELECT @payroll_expense = ROUND(ISNULL(SUM(net_salary), 0), 2)
    FROM clothing_factory.payroll
    WHERE status = N'paid'
      AND paid_date BETWEEN @date_from AND @date_to;

    SELECT @loan_interest_expense = ROUND(ISNULL(SUM(interest_paid), 0), 2)
    FROM clothing_factory.loan_payments
    WHERE payment_date BETWEEN @date_from AND @date_to;

    SELECT @current_cash_balance = ROUND(ISNULL(SUM(balance), 0), 2)
    FROM clothing_factory.cash_accounts;

    SELECT
        @date_from AS date_from,
        @date_to AS date_to,
        @revenue AS revenue,
        @cogs AS cogs,
        ROUND(@revenue - @cogs, 2) AS gross_profit,
        @purchase_expense AS purchase_expense,
        @payroll_expense AS payroll_expense,
        @loan_interest_expense AS loan_interest_expense,
        ROUND(@revenue - @cogs - @payroll_expense - @loan_interest_expense, 2) AS operating_profit,
        @current_cash_balance AS current_cash_balance;
END;
GO

