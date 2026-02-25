SET NOCOUNT ON;
GO

/*
ЛР4: Выдача зарплаты сотрудникам
*/

CREATE OR ALTER PROCEDURE clothing_factory.sp_calculate_payroll
    @period_month DATE,
    @processed_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @period_month = DATEFROMPARTS(YEAR(@period_month), MONTH(@period_month), 1);

    DECLARE @src TABLE (
        employee_id INT PRIMARY KEY,
        period_month DATE NOT NULL,
        gross_salary DECIMAL(14,2) NOT NULL,
        tax_amount DECIMAL(14,2) NOT NULL,
        net_salary DECIMAL(14,2) NOT NULL
    );

    INSERT INTO @src (employee_id, period_month, gross_salary, tax_amount, net_salary)
    SELECT
        s.employee_id,
        @period_month,
        s.gross_salary,
        ROUND(s.gross_salary * 0.10, 2) AS tax_amount,
        ROUND(s.gross_salary - ROUND(s.gross_salary * 0.10, 2), 2) AS net_salary
    FROM (
        SELECT
            e.employee_id,
            CASE
                WHEN ROUND(((p.base_salary / 22.0) * ISNULL(ts.worked_days, 22)) + ISNULL(ts.bonus, 0) - ISNULL(ts.deductions, 0), 2) < 0
                    THEN 0
                ELSE ROUND(((p.base_salary / 22.0) * ISNULL(ts.worked_days, 22)) + ISNULL(ts.bonus, 0) - ISNULL(ts.deductions, 0), 2)
            END AS gross_salary
        FROM clothing_factory.employees e
        JOIN clothing_factory.positions p ON p.position_id = e.position_id
        LEFT JOIN clothing_factory.timesheets ts
            ON ts.employee_id = e.employee_id
           AND ts.period_month = @period_month
        WHERE e.is_active = 1
    ) s;

    BEGIN TRY
        BEGIN TRANSACTION;

        MERGE clothing_factory.payroll AS tgt
        USING @src AS src
            ON tgt.employee_id = src.employee_id
           AND tgt.period_month = src.period_month
        WHEN MATCHED THEN
            UPDATE SET
                gross_salary = src.gross_salary,
                tax_amount = src.tax_amount,
                net_salary = src.net_salary,
                status = N'calculated',
                paid_date = NULL
        WHEN NOT MATCHED THEN
            INSERT (
                employee_id,
                period_month,
                gross_salary,
                tax_amount,
                net_salary,
                status,
                paid_date
            )
            VALUES (
                src.employee_id,
                src.period_month,
                src.gross_salary,
                src.tax_amount,
                src.net_salary,
                N'calculated',
                NULL
            );

        SET @processed_count = (SELECT COUNT(*) FROM @src);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE clothing_factory.sp_pay_payroll
    @period_month DATE,
    @account_id INT = 1,
    @paid_date DATE = NULL,
    @total_paid DECIMAL(14,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @period_month = DATEFROMPARTS(YEAR(@period_month), MONTH(@period_month), 1);

    IF @paid_date IS NULL
        SET @paid_date = CAST(GETDATE() AS DATE);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @total_paid = ROUND(ISNULL(SUM(net_salary), 0), 2)
        FROM clothing_factory.payroll
        WHERE period_month = @period_month
          AND status = N'calculated';

        IF @total_paid <= 0
            THROW 54001, N'Нет рассчитанной зарплаты за указанный период', 1;

        UPDATE clothing_factory.payroll
        SET
            status = N'paid',
            paid_date = @paid_date
        WHERE period_month = @period_month
          AND status = N'calculated';

        DECLARE @movement_id INT;
        EXEC clothing_factory.sp_record_cash_movement
            @account_id = @account_id,
            @direction = N'out',
            @amount = @total_paid,
            @category = N'payroll',
            @reference_table = N'payroll',
            @reference_id = NULL,
            @description = N'Выплата зарплаты',
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
