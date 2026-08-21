# Производство одежды - SQL проект на MS SQL Server

Проект моделирует основные бизнес-процессы швейного производства в базе данных MS SQL Server. Внутри есть схема БД, тестовые данные, хранимые процедуры, представления и демонстрационный сценарий полного цикла.

## Реализованные процессы

1. Закупка сырья
2. Производство готовой продукции
3. Продажа готовой продукции
4. Выдача зарплаты сотрудникам
5. Получение кредита для бизнеса
6. Отчеты по всем процессам предприятия

## Стек

- MS SQL Server
- T-SQL
- Stored Procedures
- Views
- JSON input для табличных операций

## Файлы

- `sql/00_schema.sql` - структура БД
- `sql/01_seed.sql` - начальные данные
- `sql/02_common_functions.sql` - общая процедура движения денег
- `sql/lab1_procurement.sql` - закупка сырья
- `sql/lab2_production.sql` - производство готовой продукции
- `sql/lab3_sales.sql` - продажи
- `sql/lab4_payroll.sql` - расчет и выплата зарплаты
- `sql/lab5_credit.sql` - кредитный модуль
- `sql/lab6_reports.sql` - отчеты и аналитические представления
- `sql/run_all.sql` - полный деплой всех SQL-объектов
- `sql/demo_scenario.sql` - демонстрация полного бизнес-цикла

## Как запустить в SSMS

1. Создайте базу, например `production_clothes`.
2. Выберите эту базу в SSMS.
3. Выполните файл `sql/run_all.sql`.
4. Выполните файл `sql/demo_scenario.sql`.

## Примеры вызова процедур

### ЛР1
```sql
DECLARE @purchase_id INT;
EXEC clothing_factory.sp_create_purchase_order
    @supplier_id = 1,
    @expected_date = '2026-03-01',
    @items_json = N'[{"raw_material_id":1,"quantity":500,"unit_price":1450}]',
    @purchase_id = @purchase_id OUTPUT;

EXEC clothing_factory.sp_receive_purchase_order
    @purchase_id = @purchase_id,
    @account_id = 1;
```

### ЛР2
```sql
DECLARE @production_order_id INT;
EXEC clothing_factory.sp_run_production
    @product_id = 1,
    @quantity = 100,
    @order_date = GETDATE(),
    @production_order_id = @production_order_id OUTPUT;
```

### ЛР3
```sql
DECLARE @sales_id INT;
EXEC clothing_factory.sp_create_sale
    @customer_id = 1,
    @items_json = N'[{"product_id":1,"quantity":50,"unit_price":9000}]',
    @sale_date = GETDATE(),
    @account_id = 1,
    @sales_id = @sales_id OUTPUT;
```

### ЛР4
```sql
DECLARE @processed_count INT;
EXEC clothing_factory.sp_calculate_payroll
    @period_month = '2026-02-01',
    @processed_count = @processed_count OUTPUT;

DECLARE @total_paid DECIMAL(14,2);
EXEC clothing_factory.sp_pay_payroll
    @period_month = '2026-02-01',
    @account_id = 1,
    @paid_date = GETDATE(),
    @total_paid = @total_paid OUTPUT;
```

### ЛР5
```sql
DECLARE @loan_id INT;
EXEC clothing_factory.sp_take_loan
    @bank_name = N'Business Bank KZ',
    @principal = 5000000,
    @interest_rate = 18,
    @term_months = 12,
    @start_date = GETDATE(),
    @account_id = 1,
    @loan_id = @loan_id OUTPUT;

DECLARE @loan_payment DECIMAL(14,2);
EXEC clothing_factory.sp_pay_loan_installment
    @loan_id = @loan_id,
    @installment_no = 1,
    @payment_date = GETDATE(),
    @account_id = 1,
    @total_paid = @loan_payment OUTPUT;
```

### ЛР6
```sql
SELECT * FROM clothing_factory.v_raw_material_balance;
SELECT * FROM clothing_factory.v_finished_product_balance;
SELECT * FROM clothing_factory.v_production_summary;
SELECT * FROM clothing_factory.v_sales_summary;
SELECT * FROM clothing_factory.v_monthly_payroll;
SELECT * FROM clothing_factory.v_loans_status;
SELECT * FROM clothing_factory.v_company_kpi_monthly;

EXEC clothing_factory.sp_report_period_summary
    @date_from = '2026-01-01',
    @date_to = '2026-12-31';
```
