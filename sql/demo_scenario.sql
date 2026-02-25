\set ON_ERROR_STOP on
SET search_path TO clothing_factory;

-- ЛР1: Закупка сырья и приемка
DO $$
DECLARE
    v_purchase_id INT;
BEGIN
    v_purchase_id := create_purchase_order(
        1,
        CURRENT_DATE + 5,
        '[
           {"raw_material_id": 1, "quantity": 700, "unit_price": 1450},
           {"raw_material_id": 2, "quantity": 600, "unit_price": 1200},
           {"raw_material_id": 3, "quantity": 350, "unit_price": 280},
           {"raw_material_id": 4, "quantity": 3000, "unit_price": 35},
           {"raw_material_id": 5, "quantity": 500, "unit_price": 220},
           {"raw_material_id": 6, "quantity": 400, "unit_price": 500}
         ]'::jsonb
    );

    PERFORM receive_purchase_order(v_purchase_id);
END;
$$;

-- ЛР2: Производство продукции
SELECT run_production(1, 200, CURRENT_DATE);
SELECT run_production(2, 120, CURRENT_DATE);
SELECT run_production(3, 150, CURRENT_DATE);

-- ЛР3: Продажа готовой продукции
SELECT create_sale(
    1,
    '[
       {"product_id": 1, "quantity": 120, "unit_price": 9000},
       {"product_id": 2, "quantity": 50, "unit_price": 17500}
     ]'::jsonb,
    CURRENT_DATE
);

SELECT create_sale(
    2,
    '[
       {"product_id": 3, "quantity": 70}
     ]'::jsonb,
    CURRENT_DATE
);

-- ЛР4: Расчет и выплата зарплаты за февраль 2026
INSERT INTO timesheets (employee_id, period_month, worked_days, bonus, deductions)
VALUES
    (1, '2026-02-01', 22, 18000, 0),
    (2, '2026-02-01', 20, 12000, 5000),
    (3, '2026-02-01', 22, 10000, 0),
    (4, '2026-02-01', 22, 25000, 0),
    (5, '2026-02-01', 22, 0, 0)
ON CONFLICT (employee_id, period_month)
DO UPDATE SET
    worked_days = EXCLUDED.worked_days,
    bonus = EXCLUDED.bonus,
    deductions = EXCLUDED.deductions;

SELECT calculate_payroll('2026-02-01');
SELECT pay_payroll('2026-02-01');

-- ЛР5: Получение кредита и оплата первого платежа
SELECT take_loan('Business Bank KZ', 5000000, 18, 12, CURRENT_DATE);
SELECT pay_loan_installment(1, 1, CURRENT_DATE + 30);

-- ЛР6: Отчеты
SELECT * FROM v_raw_material_balance;
SELECT * FROM v_finished_product_balance;
SELECT * FROM v_production_summary;
SELECT * FROM v_sales_summary;
SELECT * FROM v_monthly_payroll;
SELECT * FROM v_loans_status;
SELECT * FROM v_company_kpi_monthly ORDER BY month;
SELECT * FROM report_period_summary(CURRENT_DATE - 60, CURRENT_DATE + 60);
