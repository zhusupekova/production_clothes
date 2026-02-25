SET search_path TO clothing_factory;

CREATE OR REPLACE FUNCTION fn_record_cash_movement(
    p_account_id INT,
    p_direction TEXT,
    p_amount NUMERIC,
    p_category TEXT,
    p_reference_table TEXT DEFAULT NULL,
    p_reference_id INT DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_balance NUMERIC(14,2);
    v_new_balance NUMERIC(14,2);
    v_movement_id INT;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Сумма движения должна быть больше 0';
    END IF;

    IF p_direction NOT IN ('in', 'out') THEN
        RAISE EXCEPTION 'Направление должно быть in или out';
    END IF;

    SELECT balance
    INTO v_current_balance
    FROM cash_accounts
    WHERE account_id = p_account_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Счет % не найден', p_account_id;
    END IF;

    IF p_direction = 'in' THEN
        v_new_balance := v_current_balance + p_amount;
    ELSE
        v_new_balance := v_current_balance - p_amount;
        IF v_new_balance < 0 THEN
            RAISE EXCEPTION 'Недостаточно денег на счете %: доступно %, требуется %',
                p_account_id, v_current_balance, p_amount;
        END IF;
    END IF;

    UPDATE cash_accounts
    SET balance = v_new_balance
    WHERE account_id = p_account_id;

    INSERT INTO cash_movements (
        account_id,
        direction,
        amount,
        category,
        reference_table,
        reference_id,
        description
    )
    VALUES (
        p_account_id,
        p_direction,
        p_amount,
        p_category,
        p_reference_table,
        p_reference_id,
        p_description
    )
    RETURNING movement_id INTO v_movement_id;

    RETURN v_movement_id;
END;
$$;
