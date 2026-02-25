SET search_path TO clothing_factory;

-- ЛР6: Отчеты по всем процессам предприятия

CREATE OR REPLACE VIEW v_raw_material_balance AS
SELECT
    rm.raw_material_id,
    rm.material_name,
    rm.unit,
    COALESCE(ri.quantity, 0) AS quantity,
    COALESCE(ri.avg_cost, 0) AS avg_cost,
    ROUND(COALESCE(ri.quantity, 0) * COALESCE(ri.avg_cost, 0), 2) AS stock_value,
    rm.min_stock,
    GREATEST(rm.min_stock - COALESCE(ri.quantity, 0), 0) AS shortage
FROM raw_materials rm
LEFT JOIN raw_inventory ri ON ri.raw_material_id = rm.raw_material_id
ORDER BY rm.material_name;

CREATE OR REPLACE VIEW v_finished_product_balance AS
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    COALESCE(fi.quantity, 0) AS quantity,
    COALESCE(fi.avg_cost, 0) AS avg_cost,
    p.sale_price,
    ROUND(COALESCE(fi.quantity, 0) * COALESCE(fi.avg_cost, 0), 2) AS inventory_cost,
    ROUND(COALESCE(fi.quantity, 0) * p.sale_price, 2) AS inventory_retail_value
FROM products p
LEFT JOIN finished_inventory fi ON fi.product_id = p.product_id
ORDER BY p.product_name;

CREATE OR REPLACE VIEW v_production_summary AS
SELECT
    po.production_order_id,
    po.order_date,
    po.completion_date,
    po.status,
    p.product_name,
    po.produced_qty,
    po.total_cost,
    CASE WHEN po.produced_qty = 0 THEN 0 ELSE ROUND(po.total_cost / po.produced_qty, 2) END AS unit_cost
FROM production_orders po
JOIN products p ON p.product_id = po.product_id
ORDER BY po.production_order_id;

CREATE OR REPLACE VIEW v_sales_summary AS
SELECT
    so.sales_id,
    so.sales_date,
    c.customer_name,
    so.status,
    ROUND(COALESCE(SUM(soi.line_total), 0), 2) AS revenue,
    ROUND(COALESCE(SUM(soi.quantity * soi.unit_cost), 0), 2) AS cogs,
    ROUND(COALESCE(SUM(soi.line_total - (soi.quantity * soi.unit_cost)), 0), 2) AS gross_profit
FROM sales_orders so
JOIN customers c ON c.customer_id = so.customer_id
LEFT JOIN sales_order_items soi ON soi.sales_id = so.sales_id
GROUP BY so.sales_id, so.sales_date, c.customer_name, so.status
ORDER BY so.sales_id;

CREATE OR REPLACE VIEW v_monthly_payroll AS
SELECT
    period_month,
    COUNT(*) AS employees_count,
    ROUND(SUM(gross_salary), 2) AS total_gross_salary,
    ROUND(SUM(tax_amount), 2) AS total_tax,
    ROUND(SUM(net_salary), 2) AS total_net_salary
FROM payroll
GROUP BY period_month
ORDER BY period_month;

CREATE OR REPLACE VIEW v_loans_status AS
SELECT
    l.loan_id,
    l.bank_name,
    l.start_date,
    l.principal_amount,
    l.interest_rate,
    l.term_months,
    l.status,
    l.current_principal,
    COALESCE(SUM(CASE WHEN ls.paid THEN 1 ELSE 0 END), 0) AS paid_installments,
    COUNT(ls.schedule_id) AS total_installments,
    COALESCE(MIN(ls.due_date) FILTER (WHERE ls.paid = FALSE), NULL) AS next_due_date
FROM loans l
LEFT JOIN loan_schedule ls ON ls.loan_id = l.loan_id
GROUP BY l.loan_id
ORDER BY l.loan_id;

CREATE OR REPLACE VIEW v_company_kpi_monthly AS
WITH sales_data AS (
    SELECT
        date_trunc('month', so.sales_date)::DATE AS month,
        ROUND(SUM(soi.line_total), 2) AS revenue,
        ROUND(SUM(soi.quantity * soi.unit_cost), 2) AS cogs
    FROM sales_orders so
    JOIN sales_order_items soi ON soi.sales_id = so.sales_id
    WHERE so.status = 'paid'
    GROUP BY date_trunc('month', so.sales_date)
),
purchase_data AS (
    SELECT
        date_trunc('month', po.received_date)::DATE AS month,
        ROUND(SUM(po.total_amount), 2) AS purchase_expense
    FROM purchase_orders po
    WHERE po.status = 'received'
      AND po.received_date IS NOT NULL
    GROUP BY date_trunc('month', po.received_date)
),
payroll_data AS (
    SELECT
        date_trunc('month', p.paid_date)::DATE AS month,
        ROUND(SUM(p.net_salary), 2) AS payroll_expense
    FROM payroll p
    WHERE p.status = 'paid'
      AND p.paid_date IS NOT NULL
    GROUP BY date_trunc('month', p.paid_date)
),
loan_interest_data AS (
    SELECT
        date_trunc('month', lp.payment_date)::DATE AS month,
        ROUND(SUM(lp.interest_paid), 2) AS loan_interest_expense
    FROM loan_payments lp
    GROUP BY date_trunc('month', lp.payment_date)
),
all_months AS (
    SELECT month FROM sales_data
    UNION
    SELECT month FROM purchase_data
    UNION
    SELECT month FROM payroll_data
    UNION
    SELECT month FROM loan_interest_data
)
SELECT
    m.month,
    COALESCE(s.revenue, 0) AS revenue,
    COALESCE(s.cogs, 0) AS cogs,
    ROUND(COALESCE(s.revenue, 0) - COALESCE(s.cogs, 0), 2) AS gross_profit,
    COALESCE(pu.purchase_expense, 0) AS purchase_expense,
    COALESCE(pa.payroll_expense, 0) AS payroll_expense,
    COALESCE(li.loan_interest_expense, 0) AS loan_interest_expense,
    ROUND(
        COALESCE(s.revenue, 0)
        - COALESCE(s.cogs, 0)
        - COALESCE(pa.payroll_expense, 0)
        - COALESCE(li.loan_interest_expense, 0),
        2
    ) AS operating_profit
FROM all_months m
LEFT JOIN sales_data s ON s.month = m.month
LEFT JOIN purchase_data pu ON pu.month = m.month
LEFT JOIN payroll_data pa ON pa.month = m.month
LEFT JOIN loan_interest_data li ON li.month = m.month
ORDER BY m.month;

CREATE OR REPLACE FUNCTION report_period_summary(
    p_date_from DATE,
    p_date_to DATE
)
RETURNS TABLE (
    date_from DATE,
    date_to DATE,
    revenue NUMERIC,
    cogs NUMERIC,
    gross_profit NUMERIC,
    purchase_expense NUMERIC,
    payroll_expense NUMERIC,
    loan_interest_expense NUMERIC,
    operating_profit NUMERIC,
    current_cash_balance NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_revenue NUMERIC(14,2);
    v_cogs NUMERIC(14,2);
    v_purchase NUMERIC(14,2);
    v_payroll NUMERIC(14,2);
    v_loan_interest NUMERIC(14,2);
    v_cash NUMERIC(14,2);
BEGIN
    SELECT COALESCE(SUM(soi.line_total), 0), COALESCE(SUM(soi.quantity * soi.unit_cost), 0)
    INTO v_revenue, v_cogs
    FROM sales_orders so
    JOIN sales_order_items soi ON soi.sales_id = so.sales_id
    WHERE so.status = 'paid'
      AND so.sales_date BETWEEN p_date_from AND p_date_to;

    SELECT COALESCE(SUM(total_amount), 0)
    INTO v_purchase
    FROM purchase_orders
    WHERE status = 'received'
      AND received_date BETWEEN p_date_from AND p_date_to;

    SELECT COALESCE(SUM(net_salary), 0)
    INTO v_payroll
    FROM payroll
    WHERE status = 'paid'
      AND paid_date BETWEEN p_date_from AND p_date_to;

    SELECT COALESCE(SUM(interest_paid), 0)
    INTO v_loan_interest
    FROM loan_payments
    WHERE payment_date BETWEEN p_date_from AND p_date_to;

    SELECT COALESCE(SUM(balance), 0)
    INTO v_cash
    FROM cash_accounts;

    RETURN QUERY
    SELECT
        p_date_from,
        p_date_to,
        ROUND(v_revenue, 2),
        ROUND(v_cogs, 2),
        ROUND(v_revenue - v_cogs, 2),
        ROUND(v_purchase, 2),
        ROUND(v_payroll, 2),
        ROUND(v_loan_interest, 2),
        ROUND(v_revenue - v_cogs - v_payroll - v_loan_interest, 2),
        ROUND(v_cash, 2);
END;
$$;
