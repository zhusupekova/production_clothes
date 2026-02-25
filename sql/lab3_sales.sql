SET search_path TO clothing_factory;

-- ЛР3: Продажа готовой продукции
-- p_items формат:
-- [
--   {"product_id": 1, "quantity": 100, "unit_price": 9000},
--   {"product_id": 2, "quantity": 30}
-- ]
-- Если unit_price не передан, используется products.sale_price.

CREATE OR REPLACE FUNCTION create_sale(
    p_customer_id INT,
    p_items JSONB,
    p_sale_date DATE DEFAULT CURRENT_DATE,
    p_account_id INT DEFAULT 1
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_sales_id INT;
    v_total NUMERIC(14,2) := 0;
    v_item JSONB;

    v_product_id INT;
    v_quantity NUMERIC(14,3);
    v_unit_price NUMERIC(14,2);
    v_stock_qty NUMERIC(14,3);
    v_avg_cost NUMERIC(14,2);
BEGIN
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'Клиент % не найден', p_customer_id;
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Список продаваемых товаров пуст или неверного формата';
    END IF;

    INSERT INTO sales_orders (customer_id, sales_date, status)
    VALUES (p_customer_id, p_sale_date, 'draft')
    RETURNING sales_id INTO v_sales_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item ->> 'product_id')::INT;
        v_quantity := (v_item ->> 'quantity')::NUMERIC;

        IF v_product_id IS NULL OR v_quantity IS NULL THEN
            RAISE EXCEPTION 'В позиции продажи отсутствуют обязательные поля';
        END IF;

        IF v_quantity <= 0 THEN
            RAISE EXCEPTION 'Количество для продажи должно быть больше 0';
        END IF;

        SELECT sale_price INTO v_unit_price
        FROM products
        WHERE product_id = v_product_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Товар % не найден', v_product_id;
        END IF;

        IF v_item ? 'unit_price' THEN
            v_unit_price := (v_item ->> 'unit_price')::NUMERIC;
        END IF;

        IF v_unit_price < 0 THEN
            RAISE EXCEPTION 'Цена продажи не может быть отрицательной';
        END IF;

        SELECT quantity, avg_cost
        INTO v_stock_qty, v_avg_cost
        FROM finished_inventory
        WHERE product_id = v_product_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Для товара % не найден складской остаток', v_product_id;
        END IF;

        IF v_stock_qty < v_quantity THEN
            RAISE EXCEPTION 'Недостаточно товара %: требуется %, на складе %',
                v_product_id, v_quantity, v_stock_qty;
        END IF;

        UPDATE finished_inventory
        SET quantity = quantity - v_quantity,
            updated_at = NOW()
        WHERE product_id = v_product_id;

        INSERT INTO sales_order_items (
            sales_id,
            product_id,
            quantity,
            unit_price,
            unit_cost
        )
        VALUES (
            v_sales_id,
            v_product_id,
            v_quantity,
            v_unit_price,
            v_avg_cost
        );

        v_total := v_total + (v_quantity * v_unit_price);
    END LOOP;

    UPDATE sales_orders
    SET
        total_amount = ROUND(v_total, 2),
        status = 'paid'
    WHERE sales_id = v_sales_id;

    PERFORM fn_record_cash_movement(
        p_account_id,
        'in',
        ROUND(v_total, 2),
        'sale',
        'sales_orders',
        v_sales_id,
        'Поступление от реализации продукции'
    );

    RETURN v_sales_id;
END;
$$;
