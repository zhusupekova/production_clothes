SET search_path TO clothing_factory;

-- ЛР2: Производство готовой продукции
CREATE OR REPLACE FUNCTION run_production(
    p_product_id INT,
    p_quantity NUMERIC,
    p_order_date DATE DEFAULT CURRENT_DATE
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_production_order_id INT;
    v_row RECORD;
    v_required_qty NUMERIC(14,3);
    v_total_cost NUMERIC(14,2) := 0;
    v_components_count INT := 0;

    v_finished_qty NUMERIC(14,3);
    v_finished_avg_cost NUMERIC(14,2);
    v_new_finished_qty NUMERIC(14,3);
    v_new_finished_cost NUMERIC(14,2);
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Количество выпуска должно быть больше 0';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM products WHERE product_id = p_product_id) THEN
        RAISE EXCEPTION 'Продукт % не найден', p_product_id;
    END IF;

    INSERT INTO production_orders (product_id, order_date, planned_qty, status)
    VALUES (p_product_id, p_order_date, p_quantity, 'in_progress')
    RETURNING production_order_id INTO v_production_order_id;

    FOR v_row IN
        SELECT
            b.raw_material_id,
            b.qty_per_unit,
            COALESCE(ri.quantity, 0) AS stock_qty,
            COALESCE(ri.avg_cost, 0) AS avg_cost
        FROM bill_of_materials b
        LEFT JOIN raw_inventory ri ON ri.raw_material_id = b.raw_material_id
        WHERE b.product_id = p_product_id
    LOOP
        v_components_count := v_components_count + 1;
        v_required_qty := ROUND(v_row.qty_per_unit * p_quantity, 3);

        IF v_row.stock_qty < v_required_qty THEN
            RAISE EXCEPTION 'Недостаточно сырья %: требуется %, на складе %',
                v_row.raw_material_id, v_required_qty, v_row.stock_qty;
        END IF;

        v_total_cost := v_total_cost + (v_required_qty * v_row.avg_cost);
    END LOOP;

    IF v_components_count = 0 THEN
        RAISE EXCEPTION 'Для продукта % не задана спецификация (BOM)', p_product_id;
    END IF;

    FOR v_row IN
        SELECT
            b.raw_material_id,
            b.qty_per_unit,
            ri.avg_cost
        FROM bill_of_materials b
        JOIN raw_inventory ri ON ri.raw_material_id = b.raw_material_id
        WHERE b.product_id = p_product_id
        FOR UPDATE OF ri
    LOOP
        v_required_qty := ROUND(v_row.qty_per_unit * p_quantity, 3);

        UPDATE raw_inventory
        SET quantity = quantity - v_required_qty,
            updated_at = NOW()
        WHERE raw_material_id = v_row.raw_material_id;

        INSERT INTO production_consumption (
            production_order_id,
            raw_material_id,
            quantity,
            unit_cost
        )
        VALUES (
            v_production_order_id,
            v_row.raw_material_id,
            v_required_qty,
            v_row.avg_cost
        );
    END LOOP;

    SELECT quantity, avg_cost
    INTO v_finished_qty, v_finished_avg_cost
    FROM finished_inventory
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        v_finished_qty := 0;
        v_finished_avg_cost := 0;
    END IF;

    v_new_finished_qty := v_finished_qty + p_quantity;
    v_new_finished_cost := CASE
        WHEN v_new_finished_qty = 0 THEN 0
        ELSE ROUND(((v_finished_qty * v_finished_avg_cost) + v_total_cost) / v_new_finished_qty, 2)
    END;

    INSERT INTO finished_inventory (product_id, quantity, avg_cost, updated_at)
    VALUES (p_product_id, v_new_finished_qty, v_new_finished_cost, NOW())
    ON CONFLICT (product_id)
    DO UPDATE SET
        quantity = EXCLUDED.quantity,
        avg_cost = EXCLUDED.avg_cost,
        updated_at = NOW();

    UPDATE production_orders
    SET
        produced_qty = p_quantity,
        completion_date = CURRENT_DATE,
        total_cost = ROUND(v_total_cost, 2),
        status = 'completed'
    WHERE production_order_id = v_production_order_id;

    UPDATE products
    SET standard_cost = ROUND(v_total_cost / p_quantity, 2)
    WHERE product_id = p_product_id;

    RETURN v_production_order_id;
END;
$$;
