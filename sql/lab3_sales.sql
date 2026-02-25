SET NOCOUNT ON;
GO

/*
ЛР3: Функционал продажи готовой продукции
@items_json формат:
[
  {"product_id": 1, "quantity": 100, "unit_price": 9000},
  {"product_id": 2, "quantity": 30}
]
Если unit_price не передан, используется products.sale_price.
*/

CREATE OR ALTER PROCEDURE clothing_factory.sp_create_sale
    @customer_id INT,
    @items_json NVARCHAR(MAX),
    @sale_date DATE = NULL,
    @account_id INT = 1,
    @sales_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @sale_date IS NULL
        SET @sale_date = CAST(GETDATE() AS DATE);

    IF NOT EXISTS (SELECT 1 FROM clothing_factory.customers WHERE customer_id = @customer_id)
        THROW 53001, N'Клиент не найден', 1;

    IF ISJSON(@items_json) <> 1
        THROW 53002, N'Неверный JSON формата продажи', 1;

    DECLARE @items TABLE (
        product_id INT NOT NULL,
        quantity DECIMAL(14,3) NOT NULL,
        unit_price DECIMAL(14,2) NULL
    );

    INSERT INTO @items (product_id, quantity, unit_price)
    SELECT product_id, quantity, unit_price
    FROM OPENJSON(@items_json)
    WITH (
        product_id INT '$.product_id',
        quantity DECIMAL(14,3) '$.quantity',
        unit_price DECIMAL(14,2) '$.unit_price'
    );

    IF NOT EXISTS (SELECT 1 FROM @items)
        THROW 53003, N'Список продаваемой продукции пуст', 1;

    IF EXISTS (
        SELECT 1
        FROM @items
        WHERE product_id IS NULL OR quantity IS NULL OR quantity <= 0 OR (unit_price IS NOT NULL AND unit_price < 0)
    )
        THROW 53004, N'В позициях продажи есть некорректные значения', 1;

    IF EXISTS (
        SELECT 1
        FROM @items i
        LEFT JOIN clothing_factory.products p ON p.product_id = i.product_id
        WHERE p.product_id IS NULL
    )
        THROW 53005, N'Некоторые товары не найдены', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @need TABLE (
            product_id INT PRIMARY KEY,
            qty_needed DECIMAL(14,3) NOT NULL
        );

        INSERT INTO @need (product_id, qty_needed)
        SELECT product_id, SUM(quantity)
        FROM @items
        GROUP BY product_id;

        IF EXISTS (
            SELECT 1
            FROM @need n
            LEFT JOIN clothing_factory.finished_inventory fi WITH (UPDLOCK, HOLDLOCK)
                ON fi.product_id = n.product_id
            WHERE fi.product_id IS NULL
        )
            THROW 53006, N'Для некоторых товаров отсутствует запись склада готовой продукции', 1;

        IF EXISTS (
            SELECT 1
            FROM @need n
            JOIN clothing_factory.finished_inventory fi WITH (UPDLOCK, HOLDLOCK)
                ON fi.product_id = n.product_id
            WHERE fi.quantity < n.qty_needed
        )
            THROW 53007, N'Недостаточно товара на складе для продажи', 1;

        INSERT INTO clothing_factory.sales_orders (customer_id, sales_date, status, total_amount)
        VALUES (@customer_id, @sale_date, N'draft', 0);

        SET @sales_id = CAST(SCOPE_IDENTITY() AS INT);

        DECLARE @normalized TABLE (
            product_id INT NOT NULL,
            quantity DECIMAL(14,3) NOT NULL,
            unit_price DECIMAL(14,2) NOT NULL,
            unit_cost DECIMAL(14,2) NOT NULL
        );

        INSERT INTO @normalized (product_id, quantity, unit_price, unit_cost)
        SELECT
            i.product_id,
            i.quantity,
            ISNULL(i.unit_price, p.sale_price) AS final_unit_price,
            fi.avg_cost AS unit_cost
        FROM @items i
        JOIN clothing_factory.products p ON p.product_id = i.product_id
        JOIN clothing_factory.finished_inventory fi ON fi.product_id = i.product_id;

        UPDATE fi
        SET
            fi.quantity = ROUND(fi.quantity - n.qty_needed, 3),
            fi.updated_at = SYSDATETIME()
        FROM clothing_factory.finished_inventory fi
        JOIN @need n ON n.product_id = fi.product_id;

        INSERT INTO clothing_factory.sales_order_items (
            sales_id,
            product_id,
            quantity,
            unit_price,
            unit_cost
        )
        SELECT
            @sales_id,
            product_id,
            quantity,
            unit_price,
            unit_cost
        FROM @normalized;

        DECLARE @total_amount DECIMAL(14,2);
        SET @total_amount = (
            SELECT ROUND(SUM(quantity * unit_price), 2)
            FROM @normalized
        );

        UPDATE clothing_factory.sales_orders
        SET
            total_amount = @total_amount,
            status = N'paid'
        WHERE sales_id = @sales_id;

        DECLARE @movement_id INT;
        EXEC clothing_factory.sp_record_cash_movement
            @account_id = @account_id,
            @direction = N'in',
            @amount = @total_amount,
            @category = N'sale',
            @reference_table = N'sales_orders',
            @reference_id = @sales_id,
            @description = N'Поступление от реализации продукции',
            @movement_id = @movement_id OUTPUT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
