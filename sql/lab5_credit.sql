SET search_path TO clothing_factory;

-- ЛР5: Получение и обслуживание кредита для бизнеса

CREATE OR REPLACE FUNCTION take_loan(
    p_bank_name TEXT,
    p_principal NUMERIC,
    p_interest_rate NUMERIC,
    p_term_months INT,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_account_id INT DEFAULT 1
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_loan_id INT;
    v_monthly_rate NUMERIC;
    v_payment NUMERIC(14,2);
    v_remaining NUMERIC(14,2);
    v_interest NUMERIC(14,2);
    v_principal_due NUMERIC(14,2);
    v_due_date DATE;
    i INT;
BEGIN
    IF p_principal IS NULL OR p_principal <= 0 THEN
        RAISE EXCEPTION 'Сумма кредита должна быть больше 0';
    END IF;

    IF p_term_months IS NULL OR p_term_months <= 0 THEN
        RAISE EXCEPTION 'Срок кредита должен быть больше 0 месяцев';
    END IF;

    IF p_interest_rate IS NULL OR p_interest_rate < 0 THEN
        RAISE EXCEPTION 'Процентная ставка не может быть отрицательной';
    END IF;

    INSERT INTO loans (
        bank_name,
        start_date,
        principal_amount,
        interest_rate,
        term_months,
        status,
        current_principal
    )
    VALUES (
        p_bank_name,
        p_start_date,
        p_principal,
        p_interest_rate,
        p_term_months,
        'active',
        p_principal
    )
    RETURNING loan_id INTO v_loan_id;

    v_monthly_rate := p_interest_rate / 100.0 / 12.0;

    IF v_monthly_rate = 0 THEN
        v_payment := ROUND(p_principal / p_term_months, 2);
    ELSE
        v_payment := ROUND(
            p_principal * v_monthly_rate / (1 - POWER(1 + v_monthly_rate, -p_term_months)),
            2
        );
    END IF;

    v_remaining := p_principal;

    FOR i IN 1..p_term_months LOOP
        v_interest := ROUND(v_remaining * v_monthly_rate, 2);
        v_principal_due := ROUND(v_payment - v_interest, 2);

        IF i = p_term_months OR v_principal_due > v_remaining THEN
            v_principal_due := v_remaining;
        END IF;

        v_due_date := (p_start_date + make_interval(months => i))::DATE;

        INSERT INTO loan_schedule (
            loan_id,
            installment_no,
            due_date,
            principal_due,
            interest_due,
            paid
        )
        VALUES (
            v_loan_id,
            i,
            v_due_date,
            v_principal_due,
            v_interest,
            FALSE
        );

        v_remaining := ROUND(v_remaining - v_principal_due, 2);
    END LOOP;

    PERFORM fn_record_cash_movement(
        p_account_id,
        'in',
        p_principal,
        'loan_received',
        'loans',
        v_loan_id,
        format('Получен кредит от банка %s', p_bank_name)
    );

    RETURN v_loan_id;
END;
$$;

CREATE OR REPLACE FUNCTION pay_loan_installment(
    p_loan_id INT,
    p_installment_no INT,
    p_payment_date DATE DEFAULT CURRENT_DATE,
    p_account_id INT DEFAULT 1
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_schedule RECORD;
    v_new_principal NUMERIC(14,2);
BEGIN
    SELECT *
    INTO v_schedule
    FROM loan_schedule
    WHERE loan_id = p_loan_id
      AND installment_no = p_installment_no
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Платеж % по кредиту % не найден', p_installment_no, p_loan_id;
    END IF;

    IF v_schedule.paid THEN
        RAISE EXCEPTION 'Платеж % по кредиту % уже оплачен', p_installment_no, p_loan_id;
    END IF;

    UPDATE loan_schedule
    SET
        paid = TRUE,
        paid_at = p_payment_date
    WHERE schedule_id = v_schedule.schedule_id;

    INSERT INTO loan_payments (
        loan_id,
        schedule_id,
        payment_date,
        principal_paid,
        interest_paid
    )
    VALUES (
        p_loan_id,
        v_schedule.schedule_id,
        p_payment_date,
        v_schedule.principal_due,
        v_schedule.interest_due
    );

    UPDATE loans
    SET current_principal = GREATEST(ROUND(current_principal - v_schedule.principal_due, 2), 0)
    WHERE loan_id = p_loan_id
    RETURNING current_principal INTO v_new_principal;

    UPDATE loans
    SET status = CASE WHEN v_new_principal <= 0 THEN 'closed' ELSE 'active' END
    WHERE loan_id = p_loan_id;

    PERFORM fn_record_cash_movement(
        p_account_id,
        'out',
        v_schedule.total_due,
        'loan_payment',
        'loan_schedule',
        v_schedule.schedule_id,
        format('Оплата платежа %s по кредиту %s', p_installment_no, p_loan_id)
    );

    RETURN v_schedule.total_due;
END;
$$;
