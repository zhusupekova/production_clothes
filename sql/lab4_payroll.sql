SET search_path TO clothing_factory;

-- ЛР4: Выплата зарплаты сотрудникам

CREATE OR REPLACE FUNCTION calculate_payroll(
    p_period_month DATE
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_period DATE := date_trunc('month', p_period_month)::DATE;
    v_row RECORD;
    v_worked_days INT;
    v_bonus NUMERIC(14,2);
    v_deductions NUMERIC(14,2);
    v_gross NUMERIC(14,2);
    v_tax NUMERIC(14,2);
    v_net NUMERIC(14,2);
    v_count INT := 0;
BEGIN
    FOR v_row IN
        SELECT
            e.employee_id,
            p.base_salary,
            ts.worked_days,
            ts.bonus,
            ts.deductions
        FROM employees e
        JOIN positions p ON p.position_id = e.position_id
        LEFT JOIN timesheets ts
            ON ts.employee_id = e.employee_id
           AND ts.period_month = v_period
        WHERE e.is_active = TRUE
    LOOP
        v_worked_days := COALESCE(v_row.worked_days, 22);
        v_bonus := COALESCE(v_row.bonus, 0);
        v_deductions := COALESCE(v_row.deductions, 0);

        v_gross := ROUND(((v_row.base_salary / 22.0) * v_worked_days) + v_bonus - v_deductions, 2);

        IF v_gross < 0 THEN
            v_gross := 0;
        END IF;

        v_tax := ROUND(v_gross * 0.10, 2);
        v_net := ROUND(v_gross - v_tax, 2);

        INSERT INTO payroll (
            employee_id,
            period_month,
            gross_salary,
            tax_amount,
            net_salary,
            status
        )
        VALUES (
            v_row.employee_id,
            v_period,
            v_gross,
            v_tax,
            v_net,
            'calculated'
        )
        ON CONFLICT (employee_id, period_month)
        DO UPDATE SET
            gross_salary = EXCLUDED.gross_salary,
            tax_amount = EXCLUDED.tax_amount,
            net_salary = EXCLUDED.net_salary,
            status = 'calculated',
            paid_date = NULL;

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION pay_payroll(
    p_period_month DATE,
    p_account_id INT DEFAULT 1,
    p_paid_date DATE DEFAULT CURRENT_DATE
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_period DATE := date_trunc('month', p_period_month)::DATE;
    v_total NUMERIC(14,2);
BEGIN
    SELECT COALESCE(SUM(net_salary), 0)
    INTO v_total
    FROM payroll
    WHERE period_month = v_period
      AND status = 'calculated';

    IF v_total <= 0 THEN
        RAISE EXCEPTION 'Нет рассчитанной зарплаты за период %', v_period;
    END IF;

    UPDATE payroll
    SET
        status = 'paid',
        paid_date = p_paid_date
    WHERE period_month = v_period
      AND status = 'calculated';

    PERFORM fn_record_cash_movement(
        p_account_id,
        'out',
        v_total,
        'payroll',
        'payroll',
        NULL,
        format('Выплата зарплаты за %s', to_char(v_period, 'YYYY-MM'))
    );

    RETURN v_total;
END;
$$;
