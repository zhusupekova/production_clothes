SET NOCOUNT ON;
GO

/*
ЛР1: Функционал закупки сырья
@items_json формат:
[
  {"raw_material_id": 1, "quantity": 500, "unit_price": 1450},
  {"raw_material_id": 3, "quantity": 200, "unit_price": 280}
]
*/

CREATE OR ALTER PROCEDURE clothing_factory.sp_create_purchase_order
    @supplier_id INT,
    @expected_date DATE = NULL,
    @items_json NVARCHAR(MAX),
    @purchase_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM clothing_factory.suppliers WHERE supplier_id = @supplier_id)
        THROW 51001, N'Поставщик не найден', 1;

    IF ISJSON(@items_json) <> 1
        THROW 51002, N'Неверный JSON формата закупки', 1;

    DECLARE @items TABLE (
        raw_material_id INT NOT NULL,
        quantity DECIMAL(14,3) NOT NULL,
        unit_price DECIMAL(14,2) NOT NULL
    );

    INSERT INTO @items (raw_material_id, quantity, unit_price)
    SELECT raw_material_id, quantity, unit_price
    FROM OPENJSON(@items_json)
    WITH (
        raw_material_id INT '$.raw_material_id',
        quantity DECIMAL(14,3) '$.quantity',
        unit_price DECIMAL(14,2) '$.unit_price'
    );

    IF NOT EXISTS (SELECT 1 FROM @items)
        THROW 51003, N'Список закупаемых материалов пуст', 1;

    IF EXISTS (
        SELECT 1
        FROM @items
        WHERE raw_material_id IS NULL OR quantity IS NULL OR unit_price IS NULL
           OR quantity <= 0 OR unit_price <= 0
    )
        THROW 51004, N'В позициях закупки есть некорректные значения', 1;

    IF EXISTS (
        SELECT 1
        FROM @items i
        LEFT JOIN clothing_factory.raw_materials rm ON rm.raw_material_id = i.raw_material_id
        WHERE rm.raw_material_id IS NULL
    )
        THROW 51005, N'Некоторые виды сырья не найдены', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO clothing_factory.purchase_orders (supplier_id, order_date, expected_date, status, total_amount)
        VALUES (@supplier_id, CAST(GETDATE() AS DATE), @expected_date, N'ordered', 0);

        SET @purchase_id = CAST(SCOPE_IDENTITY() AS INT);

        INSERT INTO clothing_factory.purchase_order_items (purchase_id, raw_material_id, quantity, unit_price)
        SELECT @purchase_id, raw_material_id, quantity, unit_price
        FROM @items;

        UPDATE clothing_factory.purchase_orders
        SET total_amount = (
            SELECT ROUND(SUM(quantity * unit_price), 2)
            FROM @items
        )
        WHERE purchase_id = @purchase_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE clothing_factory.sp_receive_purchase_order
    @purchase_id INT,
    @account_id INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @status NVARCHAR(20);
    DECLARE @total_amount DECIMAL(14,2);
    DECLARE @movement_id INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @status = status,
            @total_amount = total_amount
        FROM clothing_factory.purchase_orders WITH (UPDLOCK, HOLDLOCK)
        WHERE purchase_id = @purchase_id;

        IF @status IS NULL
            THROW 51006, N'Закупка не найдена', 1;

        IF @status <> N'ordered'
            THROW 51007, N'Закупка не может быть принята в текущем статусе', 1;

        ;WITH receipt AS (
            SELECT
                raw_material_id,
                SUM(quantity) AS qty,
                SUM(quantity * unit_price) AS total_cost
            FROM clothing_factory.purchase_order_items
            WHERE purchase_id = @purchase_id
            GROUP BY raw_material_id
        )
        MERGE clothing_factory.raw_inventory AS tgt
        USING receipt AS src
            ON tgt.raw_material_id = src.raw_material_id
        WHEN MATCHED THEN
            UPDATE SET
                quantity = ROUND(tgt.quantity + src.qty, 3),
                avg_cost = CASE
                    WHEN (tgt.quantity + src.qty) = 0 THEN 0
                    ELSE ROUND(((tgt.quantity * tgt.avg_cost) + src.total_cost) / (tgt.quantity + src.qty), 2)
                END,
                updated_at = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (raw_material_id, quantity, avg_cost, updated_at)
            VALUES (
                src.raw_material_id,
                ROUND(src.qty, 3),
                CASE WHEN src.qty = 0 THEN 0 ELSE ROUND(src.total_cost / src.qty, 2) END,
                SYSDATETIME()
            );

        UPDATE clothing_factory.purchase_orders
        SET
            status = N'received',
            received_date = CAST(GETDATE() AS DATE)
        WHERE purchase_id = @purchase_id;

        EXEC clothing_factory.sp_record_cash_movement
            @account_id = @account_id,
            @direction = N'out',
            @amount = @total_amount,
            @category = N'purchase',
            @reference_table = N'purchase_orders',
            @reference_id = @purchase_id,
            @description = N'Оплата закупки сырья',
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
