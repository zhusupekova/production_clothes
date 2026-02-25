-- Лабораторный проект: Производство одежды
-- Общая схема базы данных PostgreSQL

DROP SCHEMA IF EXISTS clothing_factory CASCADE;
CREATE SCHEMA clothing_factory;
SET search_path TO clothing_factory;

CREATE TABLE suppliers (
    supplier_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_name    TEXT NOT NULL,
    contact_person   TEXT,
    phone            TEXT,
    email            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE raw_materials (
    raw_material_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    material_name    TEXT NOT NULL UNIQUE,
    unit             TEXT NOT NULL,
    min_stock        NUMERIC(14,3) NOT NULL DEFAULT 0 CHECK (min_stock >= 0),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE supplier_material_prices (
    supplier_id      INT NOT NULL REFERENCES suppliers(supplier_id) ON DELETE CASCADE,
    raw_material_id  INT NOT NULL REFERENCES raw_materials(raw_material_id) ON DELETE CASCADE,
    unit_price       NUMERIC(14,2) NOT NULL CHECK (unit_price > 0),
    effective_from   DATE NOT NULL DEFAULT CURRENT_DATE,
    PRIMARY KEY (supplier_id, raw_material_id, effective_from)
);

CREATE TABLE raw_inventory (
    raw_material_id  INT PRIMARY KEY REFERENCES raw_materials(raw_material_id) ON DELETE RESTRICT,
    quantity         NUMERIC(14,3) NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    avg_cost         NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (avg_cost >= 0),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE cash_accounts (
    account_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_name     TEXT NOT NULL UNIQUE,
    balance          NUMERIC(14,2) NOT NULL DEFAULT 0,
    currency_code    CHAR(3) NOT NULL DEFAULT 'KZT',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE cash_movements (
    movement_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    movement_date    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    account_id       INT NOT NULL REFERENCES cash_accounts(account_id),
    direction        TEXT NOT NULL CHECK (direction IN ('in', 'out')),
    amount           NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    category         TEXT NOT NULL,
    reference_table  TEXT,
    reference_id     INT,
    description      TEXT
);

CREATE TABLE purchase_orders (
    purchase_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_id      INT NOT NULL REFERENCES suppliers(supplier_id),
    order_date       DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_date    DATE,
    received_date    DATE,
    status           TEXT NOT NULL CHECK (status IN ('draft', 'ordered', 'received', 'cancelled')),
    total_amount     NUMERIC(14,2) NOT NULL DEFAULT 0
);

CREATE TABLE purchase_order_items (
    purchase_item_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purchase_id      INT NOT NULL REFERENCES purchase_orders(purchase_id) ON DELETE CASCADE,
    raw_material_id  INT NOT NULL REFERENCES raw_materials(raw_material_id),
    quantity         NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
    unit_price       NUMERIC(14,2) NOT NULL CHECK (unit_price > 0),
    line_total       NUMERIC(14,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE TABLE products (
    product_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku              TEXT NOT NULL UNIQUE,
    product_name     TEXT NOT NULL,
    category         TEXT NOT NULL,
    size_label       TEXT,
    sale_price       NUMERIC(14,2) NOT NULL CHECK (sale_price >= 0),
    standard_cost    NUMERIC(14,2) NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE bill_of_materials (
    product_id       INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    raw_material_id  INT NOT NULL REFERENCES raw_materials(raw_material_id),
    qty_per_unit     NUMERIC(14,3) NOT NULL CHECK (qty_per_unit > 0),
    PRIMARY KEY (product_id, raw_material_id)
);

CREATE TABLE production_orders (
    production_order_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id          INT NOT NULL REFERENCES products(product_id),
    order_date          DATE NOT NULL DEFAULT CURRENT_DATE,
    planned_qty         NUMERIC(14,3) NOT NULL CHECK (planned_qty > 0),
    produced_qty        NUMERIC(14,3) NOT NULL DEFAULT 0,
    completion_date     DATE,
    status              TEXT NOT NULL CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
    total_cost          NUMERIC(14,2) NOT NULL DEFAULT 0
);

CREATE TABLE production_consumption (
    consumption_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    production_order_id INT NOT NULL REFERENCES production_orders(production_order_id) ON DELETE CASCADE,
    raw_material_id     INT NOT NULL REFERENCES raw_materials(raw_material_id),
    quantity            NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
    unit_cost           NUMERIC(14,2) NOT NULL CHECK (unit_cost >= 0),
    line_cost           NUMERIC(14,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED
);

CREATE TABLE finished_inventory (
    product_id          INT PRIMARY KEY REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity            NUMERIC(14,3) NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    avg_cost            NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (avg_cost >= 0),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE customers (
    customer_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_name       TEXT NOT NULL,
    phone               TEXT,
    email               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE sales_orders (
    sales_id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id         INT NOT NULL REFERENCES customers(customer_id),
    sales_date          DATE NOT NULL DEFAULT CURRENT_DATE,
    status              TEXT NOT NULL CHECK (status IN ('draft', 'paid', 'cancelled')),
    total_amount        NUMERIC(14,2) NOT NULL DEFAULT 0
);

CREATE TABLE sales_order_items (
    sales_item_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sales_id            INT NOT NULL REFERENCES sales_orders(sales_id) ON DELETE CASCADE,
    product_id          INT NOT NULL REFERENCES products(product_id),
    quantity            NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
    unit_price          NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
    unit_cost           NUMERIC(14,2) NOT NULL CHECK (unit_cost >= 0),
    line_total          NUMERIC(14,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE TABLE departments (
    department_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department_name     TEXT NOT NULL UNIQUE
);

CREATE TABLE positions (
    position_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department_id       INT NOT NULL REFERENCES departments(department_id),
    position_name       TEXT NOT NULL,
    base_salary         NUMERIC(14,2) NOT NULL CHECK (base_salary >= 0)
);

CREATE TABLE employees (
    employee_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name           TEXT NOT NULL,
    hire_date           DATE NOT NULL,
    position_id         INT NOT NULL REFERENCES positions(position_id),
    is_active           BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE timesheets (
    timesheet_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id         INT NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    period_month        DATE NOT NULL,
    worked_days         INT NOT NULL CHECK (worked_days BETWEEN 0 AND 31),
    bonus               NUMERIC(14,2) NOT NULL DEFAULT 0,
    deductions          NUMERIC(14,2) NOT NULL DEFAULT 0,
    UNIQUE (employee_id, period_month),
    CHECK (period_month = date_trunc('month', period_month)::DATE)
);

CREATE TABLE payroll (
    payroll_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id         INT NOT NULL REFERENCES employees(employee_id),
    period_month        DATE NOT NULL,
    gross_salary        NUMERIC(14,2) NOT NULL CHECK (gross_salary >= 0),
    tax_amount          NUMERIC(14,2) NOT NULL CHECK (tax_amount >= 0),
    net_salary          NUMERIC(14,2) NOT NULL CHECK (net_salary >= 0),
    status              TEXT NOT NULL CHECK (status IN ('calculated', 'paid')),
    paid_date           DATE,
    UNIQUE (employee_id, period_month),
    CHECK (period_month = date_trunc('month', period_month)::DATE)
);

CREATE TABLE loans (
    loan_id             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bank_name           TEXT NOT NULL,
    start_date          DATE NOT NULL,
    principal_amount    NUMERIC(14,2) NOT NULL CHECK (principal_amount > 0),
    interest_rate       NUMERIC(7,4) NOT NULL CHECK (interest_rate >= 0),
    term_months         INT NOT NULL CHECK (term_months > 0),
    status              TEXT NOT NULL CHECK (status IN ('active', 'closed')),
    current_principal   NUMERIC(14,2) NOT NULL CHECK (current_principal >= 0)
);

CREATE TABLE loan_schedule (
    schedule_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    loan_id             INT NOT NULL REFERENCES loans(loan_id) ON DELETE CASCADE,
    installment_no      INT NOT NULL CHECK (installment_no > 0),
    due_date            DATE NOT NULL,
    principal_due       NUMERIC(14,2) NOT NULL CHECK (principal_due >= 0),
    interest_due        NUMERIC(14,2) NOT NULL CHECK (interest_due >= 0),
    total_due           NUMERIC(14,2) GENERATED ALWAYS AS (principal_due + interest_due) STORED,
    paid                BOOLEAN NOT NULL DEFAULT FALSE,
    paid_at             DATE,
    UNIQUE (loan_id, installment_no),
    UNIQUE (loan_id, due_date)
);

CREATE TABLE loan_payments (
    payment_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    loan_id             INT NOT NULL REFERENCES loans(loan_id),
    schedule_id         INT NOT NULL REFERENCES loan_schedule(schedule_id),
    payment_date        DATE NOT NULL,
    principal_paid      NUMERIC(14,2) NOT NULL CHECK (principal_paid >= 0),
    interest_paid       NUMERIC(14,2) NOT NULL CHECK (interest_paid >= 0),
    total_paid          NUMERIC(14,2) GENERATED ALWAYS AS (principal_paid + interest_paid) STORED
);

CREATE INDEX idx_purchase_orders_date ON purchase_orders(order_date);
CREATE INDEX idx_purchase_orders_status ON purchase_orders(status);
CREATE INDEX idx_production_orders_date ON production_orders(order_date);
CREATE INDEX idx_sales_orders_date ON sales_orders(sales_date);
CREATE INDEX idx_sales_orders_status ON sales_orders(status);
CREATE INDEX idx_payroll_period ON payroll(period_month);
CREATE INDEX idx_cash_movements_date ON cash_movements(movement_date);
CREATE INDEX idx_loan_schedule_due ON loan_schedule(due_date);
