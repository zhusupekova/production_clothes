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
