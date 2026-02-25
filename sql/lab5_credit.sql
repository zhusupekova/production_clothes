SET NOCOUNT ON;
GO

/*
ЛР5: Функционал получения кредита для бизнеса
*/

CREATE OR ALTER PROCEDURE clothing_factory.sp_take_loan
    @bank_name NVARCHAR(200),
    @principal DECIMAL(14,2),
    @interest_rate DECIMAL(7,4),
    @term_months INT,
    @start_date DATE = NULL,
    @account_id INT = 1,
    @loan_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @start_date IS NULL
        SET @start_date = CAST(GETDATE() AS DATE);

    IF @principal IS NULL OR @principal <= 0
        THROW 55001, N'Сумма кредита должна быть больше 0', 1;

    IF @interest_rate IS NULL OR @interest_rate < 0
        THROW 55002, N'Процентная ставка не может быть отрицательной', 1;

    IF @term_months IS NULL OR @term_months <= 0
        THROW 55003, N'Срок кредита должен быть больше 0 месяцев', 1;

    DECLARE @monthly_rate DECIMAL(18,10);
    DECLARE @payment DECIMAL(14,2);
    DECLARE @remaining DECIMAL(14,2);
    DECLARE @interest_due DECIMAL(14,2);
    DECLARE @principal_due DECIMAL(14,2);
    DECLARE @due_date DATE;
    DECLARE @i INT = 1;

    SET @monthly_rate = @interest_rate / 100.0 / 12.0;

    IF @monthly_rate = 0
        SET @payment = ROUND(@principal / @term_months, 2);
    ELSE
        SET @payment = ROUND(
            @principal * @monthly_rate / (1 - POWER(1 + @monthly_rate, -@term_months)),
            2
        );

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO clothing_factory.loans (
            bank_name,
            start_date,
            principal_amount,
            interest_rate,
            term_months,
            status,
            current_principal
        )
        VALUES (
            @bank_name,
            @start_date,
            @principal,
            @interest_rate,
            @term_months,
            N'active',
            @principal
        );

        SET @loan_id = CAST(SCOPE_IDENTITY() AS INT);
        SET @remaining = @principal;

        WHILE @i <= @term_months
        BEGIN
            SET @interest_due = ROUND(@remaining * @monthly_rate, 2);
            SET @principal_due = ROUND(@payment - @interest_due, 2);

            IF @i = @term_months OR @principal_due > @remaining
                SET @principal_due = @remaining;

            SET @due_date = DATEADD(MONTH, @i, @start_date);

            INSERT INTO clothing_factory.loan_schedule (
                loan_id,
                installment_no,
                due_date,
                principal_due,
                interest_due,
                paid,
                paid_at
            )
            VALUES (
                @loan_id,
                @i,
                @due_date,
                @principal_due,
                @interest_due,
                0,
                NULL
            );

            SET @remaining = ROUND(@remaining - @principal_due, 2);
            SET @i += 1;
        END

        DECLARE @movement_id INT;
        EXEC clothing_factory.sp_record_cash_movement
            @account_id = @account_id,
            @direction = N'in',
            @amount = @principal,
            @category = N'loan_received',
            @reference_table = N'loans',
            @reference_id = @loan_id,
            @description = N'Получен банковский кредит',
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

CREATE OR ALTER PROCEDURE clothing_factory.sp_pay_loan_installment
    @loan_id INT,
    @installment_no INT,
    @payment_date DATE = NULL,
    @account_id INT = 1,
    @total_paid DECIMAL(14,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @payment_date IS NULL
        SET @payment_date = CAST(GETDATE() AS DATE);

    DECLARE @schedule_id INT;
    DECLARE @principal_due DECIMAL(14,2);
    DECLARE @interest_due DECIMAL(14,2);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @schedule_id = schedule_id,
            @principal_due = principal_due,
            @interest_due = interest_due
        FROM clothing_factory.loan_schedule WITH (UPDLOCK, HOLDLOCK)
        WHERE loan_id = @loan_id
          AND installment_no = @installment_no
          AND paid = 0;

        IF @schedule_id IS NULL
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM clothing_factory.loan_schedule
                WHERE loan_id = @loan_id
                  AND installment_no = @installment_no
                  AND paid = 1
            )
                THROW 55004, N'Платеж уже оплачен', 1;

            THROW 55005, N'Платеж по кредиту не найден', 1;
        END

        SET @total_paid = ROUND(@principal_due + @interest_due, 2);

        UPDATE clothing_factory.loan_schedule
        SET
            paid = 1,
            paid_at = @payment_date
        WHERE schedule_id = @schedule_id;

        INSERT INTO clothing_factory.loan_payments (
            loan_id,
            schedule_id,
            payment_date,
            principal_paid,
            interest_paid
        )
        VALUES (
            @loan_id,
            @schedule_id,
            @payment_date,
            @principal_due,
            @interest_due
        );

        UPDATE clothing_factory.loans
        SET current_principal = CASE
            WHEN current_principal - @principal_due < 0 THEN 0
            ELSE ROUND(current_principal - @principal_due, 2)
        END
        WHERE loan_id = @loan_id;

        UPDATE clothing_factory.loans
        SET status = CASE WHEN current_principal <= 0 THEN N'closed' ELSE N'active' END
        WHERE loan_id = @loan_id;

        DECLARE @movement_id INT;
        EXEC clothing_factory.sp_record_cash_movement
            @account_id = @account_id,
            @direction = N'out',
            @amount = @total_paid,
            @category = N'loan_payment',
            @reference_table = N'loan_schedule',
            @reference_id = @schedule_id,
            @description = N'Оплата платежа по кредиту',
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
