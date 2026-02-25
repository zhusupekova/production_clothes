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
