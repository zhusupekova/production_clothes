SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE clothing_factory.sp_record_cash_movement
    @account_id INT,
    @direction NVARCHAR(3),
    @amount DECIMAL(14,2),
    @category NVARCHAR(100),
    @reference_table NVARCHAR(128) = NULL,
    @reference_id INT = NULL,
    @description NVARCHAR(400) = NULL,
    @movement_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @amount IS NULL OR @amount <= 0
        THROW 50001, N'Сумма движения должна быть больше 0', 1;

    IF @direction NOT IN (N'in', N'out')
        THROW 50002, N'Направление должно быть in или out', 1;

    BEGIN TRANSACTION;

    IF @direction = N'in'
    BEGIN
        UPDATE clothing_factory.cash_accounts
        SET balance = ROUND(balance + @amount, 2)
        WHERE account_id = @account_id;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50003, N'Счет не найден', 1;
        END
    END
    ELSE
    BEGIN
        UPDATE clothing_factory.cash_accounts
        SET balance = ROUND(balance - @amount, 2)
        WHERE account_id = @account_id
          AND balance >= @amount;

        IF @@ROWCOUNT = 0
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM clothing_factory.cash_accounts WHERE account_id = @account_id)
            BEGIN
                ROLLBACK TRANSACTION;
                THROW 50004, N'Счет не найден', 1;
            END

            ROLLBACK TRANSACTION;
            THROW 50005, N'Недостаточно средств на счете', 1;
        END
    END

    INSERT INTO clothing_factory.cash_movements (
        account_id,
        direction,
        amount,
        category,
        reference_table,
        reference_id,
        description
    )
    VALUES (
        @account_id,
        @direction,
        @amount,
        @category,
        @reference_table,
        @reference_id,
        @description
    );

    SET @movement_id = CAST(SCOPE_IDENTITY() AS INT);

    COMMIT TRANSACTION;
END;
GO
