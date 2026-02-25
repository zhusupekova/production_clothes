SET search_path TO clothing_factory;

-- ЛР1: Закупка сырья
-- p_items формат:
-- [
--   {"raw_material_id": 1, "quantity": 500, "unit_price": 1450},
--   {"raw_material_id": 3, "quantity": 200, "unit_price": 280}
-- ]

CREATE OR REPLACE FUNCTION create_purchase_order(
    p_supplier_id INT,
    p_expected_date DATE,
    p_items JSONB
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_purchase_id INT;
    v_total NUMERIC(14,2) := 0;
    v_item JSONB;
    v_raw_material_id INT;
    v_quantity NUMERIC(14,3);
    v_unit_price NUMERIC(14,2);
BEGIN
    IF NOT EXISTS (SELECT 1 FROM suppliers WHERE supplier_id = p_supplier_id) THEN
        RAISE EXCEPTION 'Поставщик % не найден', p_supplier_id;
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Список закупаемых материалов пуст или неверного формата';
    END IF;

    INSERT INTO purchase_orders (supplier_id, expected_date, status)
    VALUES (p_supplier_id, p_expected_date, 'ordered')
    RETURNING purchase_id INTO v_purchase_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_raw_material_id := (v_item ->> 'raw_material_id')::INT;
        v_quantity := (v_item ->> 'quantity')::NUMERIC;
        v_unit_price := (v_item ->> 'unit_price')::NUMERIC;

        IF v_raw_material_id IS NULL OR v_quantity IS NULL OR v_unit_price IS NULL THEN
            RAISE EXCEPTION 'В позиции закупки отсутствуют обязательные поля';
        END IF;

        IF v_quantity <= 0 OR v_unit_price <= 0 THEN
            RAISE EXCEPTION 'Количество и цена должны быть больше 0';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM raw_materials WHERE raw_material_id = v_raw_material_id) THEN
            RAISE EXCEPTION 'Сырье % не найдено', v_raw_material_id;
        END IF;

        INSERT INTO purchase_order_items (
            purchase_id,
            raw_material_id,
            quantity,
            unit_price
        )
        VALUES (
            v_purchase_id,
            v_raw_material_id,
            v_quantity,
            v_unit_price
        );

        v_total := v_total + (v_quantity * v_unit_price);
    END LOOP;

    UPDATE purchase_orders
    SET total_amount = ROUND(v_total, 2)
    WHERE purchase_id = v_purchase_id;

    RETURN v_purchase_id;
END;
$$;

CREATE OR REPLACE FUNCTION receive_purchase_order(
    p_purchase_id INT,
    p_account_id INT DEFAULT 1
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_po RECORD;
    v_row RECORD;
    v_old_qty NUMERIC(14,3);
    v_old_cost NUMERIC(14,2);
    v_new_qty NUMERIC(14,3);
    v_new_cost NUMERIC(14,2);
BEGIN
    SELECT *
    INTO v_po
    FROM purchase_orders
    WHERE purchase_id = p_purchase_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Закупка % не найдена', p_purchase_id;
    END IF;

    IF v_po.status <> 'ordered' THEN
        RAISE EXCEPTION 'Закупка % не может быть принята. Текущий статус: %', p_purchase_id, v_po.status;
    END IF;

    FOR v_row IN
        SELECT raw_material_id, quantity, unit_price
        FROM purchase_order_items
        WHERE purchase_id = p_purchase_id
    LOOP
        SELECT quantity, avg_cost
        INTO v_old_qty, v_old_cost
        FROM raw_inventory
        WHERE raw_material_id = v_row.raw_material_id
        FOR UPDATE;

        IF NOT FOUND THEN
            v_old_qty := 0;
            v_old_cost := 0;
        END IF;

        v_new_qty := v_old_qty + v_row.quantity;
        v_new_cost := CASE
            WHEN v_new_qty = 0 THEN 0
            ELSE ROUND(((v_old_qty * v_old_cost) + (v_row.quantity * v_row.unit_price)) / v_new_qty, 2)
        END;

        INSERT INTO raw_inventory (raw_material_id, quantity, avg_cost, updated_at)
        VALUES (v_row.raw_material_id, v_new_qty, v_new_cost, NOW())
        ON CONFLICT (raw_material_id)
        DO UPDATE SET
            quantity = EXCLUDED.quantity,
            avg_cost = EXCLUDED.avg_cost,
            updated_at = NOW();
    END LOOP;

    UPDATE purchase_orders
    SET
        status = 'received',
        received_date = CURRENT_DATE
    WHERE purchase_id = p_purchase_id;

    PERFORM fn_record_cash_movement(
        p_account_id,
        'out',
        v_po.total_amount,
        'purchase',
        'purchase_orders',
        p_purchase_id,
        'Оплата закупки сырья'
    );
END;
$$;
