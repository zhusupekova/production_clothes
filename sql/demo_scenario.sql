SET NOCOUNT ON;
GO

/*
Демонстрационный сценарий по всем лабораторным работам
*/

DECLARE @today DATE = CAST(GETDATE() AS DATE);
DECLARE @plus_5_days DATE = DATEADD(DAY, 5, @today);
DECLARE @plus_30_days DATE = DATEADD(DAY, 30, @today);
DECLARE @from_date DATE = DATEADD(DAY, -60, @today);
DECLARE @to_date DATE = DATEADD(DAY, 60, @today);

DECLARE @purchase_id INT;
EXEC clothing_factory.sp_create_purchase_order
    @supplier_id = 1,
    @expected_date = @plus_5_days,
    @items_json = N'[
       {"raw_material_id": 1, "quantity": 700, "unit_price": 1450},
       {"raw_material_id": 2, "quantity": 600, "unit_price": 1200},
       {"raw_material_id": 3, "quantity": 350, "unit_price": 280},
       {"raw_material_id": 4, "quantity": 3000, "unit_price": 35},
       {"raw_material_id": 5, "quantity": 500, "unit_price": 220},
       {"raw_material_id": 6, "quantity": 400, "unit_price": 500}
     ]',
    @purchase_id = @purchase_id OUTPUT;

EXEC clothing_factory.sp_receive_purchase_order
    @purchase_id = @purchase_id,
    @account_id = 1;

DECLARE @production_order_id INT;
EXEC clothing_factory.sp_run_production @product_id = 1, @quantity = 200, @order_date = @today, @production_order_id = @production_order_id OUTPUT;
EXEC clothing_factory.sp_run_production @product_id = 2, @quantity = 120, @order_date = @today, @production_order_id = @production_order_id OUTPUT;
EXEC clothing_factory.sp_run_production @product_id = 3, @quantity = 150, @order_date = @today, @production_order_id = @production_order_id OUTPUT;

DECLARE @sales_id INT;
EXEC clothing_factory.sp_create_sale
    @customer_id = 1,
    @items_json = N'[
      {"product_id": 1, "quantity": 120, "unit_price": 9000},
      {"product_id": 2, "quantity": 50, "unit_price": 17500}
    ]',
    @sale_date = @today,
    @account_id = 1,
    @sales_id = @sales_id OUTPUT;

EXEC clothing_factory.sp_create_sale
    @customer_id = 2,
    @items_json = N'[
      {"product_id": 3, "quantity": 70}
    ]',
    @sale_date = @today,
    @account_id = 1,
    @sales_id = @sales_id OUTPUT;

MERGE clothing_factory.timesheets AS tgt
USING (
    SELECT * FROM (VALUES
        (1, CAST('2026-02-01' AS DATE), 22, 18000.00, 0.00),
        (2, CAST('2026-02-01' AS DATE), 20, 12000.00, 5000.00),
        (3, CAST('2026-02-01' AS DATE), 22, 10000.00, 0.00),
        (4, CAST('2026-02-01' AS DATE), 22, 25000.00, 0.00),
        (5, CAST('2026-02-01' AS DATE), 22, 0.00, 0.00)
    ) v(employee_id, period_month, worked_days, bonus, deductions)
) AS src
ON tgt.employee_id = src.employee_id
AND tgt.period_month = src.period_month
WHEN MATCHED THEN
    UPDATE SET
        worked_days = src.worked_days,
        bonus = src.bonus,
        deductions = src.deductions
WHEN NOT MATCHED THEN
    INSERT (employee_id, period_month, worked_days, bonus, deductions)
    VALUES (src.employee_id, src.period_month, src.worked_days, src.bonus, src.deductions);

DECLARE @processed_count INT;
EXEC clothing_factory.sp_calculate_payroll
    @period_month = '2026-02-01',
    @processed_count = @processed_count OUTPUT;

DECLARE @total_payroll DECIMAL(14,2);
EXEC clothing_factory.sp_pay_payroll
    @period_month = '2026-02-01',
    @account_id = 1,
    @paid_date = @today,
    @total_paid = @total_payroll OUTPUT;

DECLARE @loan_id INT;
EXEC clothing_factory.sp_take_loan
    @bank_name = N'Business Bank KZ',
    @principal = 5000000,
    @interest_rate = 18,
    @term_months = 12,
    @start_date = @today,
    @account_id = 1,
    @loan_id = @loan_id OUTPUT;

DECLARE @loan_payment DECIMAL(14,2);
EXEC clothing_factory.sp_pay_loan_installment
    @loan_id = @loan_id,
    @installment_no = 1,
    @payment_date = @plus_30_days,
    @account_id = 1,
    @total_paid = @loan_payment OUTPUT;

SELECT * FROM clothing_factory.v_raw_material_balance ORDER BY material_name;
SELECT * FROM clothing_factory.v_finished_product_balance ORDER BY product_name;
SELECT * FROM clothing_factory.v_production_summary ORDER BY production_order_id;
SELECT * FROM clothing_factory.v_sales_summary ORDER BY sales_id;
SELECT * FROM clothing_factory.v_monthly_payroll ORDER BY period_month;
SELECT * FROM clothing_factory.v_loans_status ORDER BY loan_id;
SELECT * FROM clothing_factory.v_company_kpi_monthly ORDER BY [month];

EXEC clothing_factory.sp_report_period_summary
    @date_from = @from_date,
    @date_to = @to_date;
GO
