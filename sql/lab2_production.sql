SET NOCOUNT ON;
GO

/*
ЛР2: Функционал производства готовой продукции
*/

CREATE OR ALTER PROCEDURE clothing_factory.sp_run_production
    @product_id INT,
    @quantity DECIMAL(14,3),
    @order_date DATE = NULL,
    @production_order_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @quantity IS NULL OR @quantity <= 0
        THROW 52001, N'Количество выпуска должно быть больше 0', 1;

    IF @order_date IS NULL
        SET @order_date = CAST(GETDATE() AS DATE);

    IF NOT EXISTS (SELECT 1 FROM clothing_factory.products WHERE product_id = @product_id)
        THROW 52002, N'Продукт не найден', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO clothing_factory.production_orders (
            product_id,
            order_date,
            planned_qty,
            produced_qty,
            status,
            total_cost
        )
        VALUES (
            @product_id,
            @order_date,
            @quantity,
            0,
            N'in_progress',
            0
        );

        SET @production_order_id = CAST(SCOPE_IDENTITY() AS INT);

        DECLARE @consumption TABLE (
            raw_material_id INT PRIMARY KEY,
            required_qty DECIMAL(14,3) NOT NULL,
            unit_cost DECIMAL(14,2) NOT NULL,
            stock_qty DECIMAL(14,3) NULL
        );

        INSERT INTO @consumption (raw_material_id, required_qty, unit_cost, stock_qty)
        SELECT
            b.raw_material_id,
            ROUND(b.qty_per_unit * @quantity, 3) AS required_qty,
            ISNULL(ri.avg_cost, 0) AS unit_cost,
            ri.quantity AS stock_qty
        FROM clothing_factory.bill_of_materials b
        LEFT JOIN clothing_factory.raw_inventory ri WITH (UPDLOCK, HOLDLOCK)
            ON ri.raw_material_id = b.raw_material_id
        WHERE b.product_id = @product_id;

        IF NOT EXISTS (SELECT 1 FROM @consumption)
            THROW 52003, N'Для продукта не задана спецификация BOM', 1;

        IF EXISTS (SELECT 1 FROM @consumption WHERE stock_qty IS NULL)
            THROW 52004, N'Не для всех материалов создана строка склада сырья', 1;

        IF EXISTS (SELECT 1 FROM @consumption WHERE stock_qty < required_qty)
            THROW 52005, N'Недостаточно сырья для выполнения производства', 1;

        UPDATE ri
        SET
            ri.quantity = ROUND(ri.quantity - c.required_qty, 3),
            ri.updated_at = SYSDATETIME()
        FROM clothing_factory.raw_inventory ri
        JOIN @consumption c ON c.raw_material_id = ri.raw_material_id;

        INSERT INTO clothing_factory.production_consumption (
            production_order_id,
            raw_material_id,
            quantity,
            unit_cost
        )
        SELECT
            @production_order_id,
            raw_material_id,
            required_qty,
            unit_cost
        FROM @consumption;

        DECLARE @total_cost DECIMAL(14,2);
        SET @total_cost = (
            SELECT ROUND(SUM(required_qty * unit_cost), 2)
            FROM @consumption
        );

        MERGE clothing_factory.finished_inventory AS tgt
        USING (
            SELECT
                @product_id AS product_id,
                @quantity AS produced_qty,
                @total_cost AS production_cost
        ) AS src
            ON tgt.product_id = src.product_id
        WHEN MATCHED THEN
            UPDATE SET
                quantity = ROUND(tgt.quantity + src.produced_qty, 3),
                avg_cost = CASE
                    WHEN (tgt.quantity + src.produced_qty) = 0 THEN 0
                    ELSE ROUND(((tgt.quantity * tgt.avg_cost) + src.production_cost) / (tgt.quantity + src.produced_qty), 2)
                END,
                updated_at = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (product_id, quantity, avg_cost, updated_at)
            VALUES (
                src.product_id,
                src.produced_qty,
                CASE WHEN src.produced_qty = 0 THEN 0 ELSE ROUND(src.production_cost / src.produced_qty, 2) END,
                SYSDATETIME()
            );

        UPDATE clothing_factory.production_orders
        SET
            produced_qty = @quantity,
            completion_date = CAST(GETDATE() AS DATE),
            total_cost = @total_cost,
            status = N'completed'
        WHERE production_order_id = @production_order_id;

        UPDATE clothing_factory.products
        SET standard_cost = CASE WHEN @quantity = 0 THEN standard_cost ELSE ROUND(@total_cost / @quantity, 2) END
        WHERE product_id = @product_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
