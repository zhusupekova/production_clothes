# Производство одежды - SQL лабораторные работы (1-6)

Проект реализует полный цикл предприятия по теме **«Производство одежды»**:

1. Закупка сырья
2. Производство готовой продукции
3. Продажа готовой продукции
4. Выдача зарплаты сотрудникам
5. Получение кредита для бизнеса
6. Отчеты по всем процессам

## Структура

- `/Users/sezimzhusupekova/university/SQL/production_clothes/sql/00_schema.sql` - структура БД
- `/Users/sezimzhusupekova/university/SQL/production_clothes/sql/01_seed.sql` - начальные справочные данные
- `/Users/sezimzhusupekova/university/SQL/production_clothes/sql/02_common_functions.sql` - общие функции (движение денег)
- `/Users/sezimzhusupekova/university/SQL/production_clothes/sql/lab1_procurement.sql` - ЛР1
- `/Users/sezimzhusupekova/university/SQL/production_clothes/sql/lab2_production.sql` - ЛР2
- `/Users/sezimzhusupekova/university/SQL/production_clothes/sql/lab3_sales.sql` - ЛР3
- `/Users/sezimzhusupekova/university/SQL/production_clothes/sql/lab4_payroll.sql` - ЛР4
- `/Users/sezimzhusupekova/university/SQL/production_clothes/sql/lab5_credit.sql` - ЛР5
- `/Users/sezimzhusupekova/university/SQL/production_clothes/sql/lab6_reports.sql` - ЛР6
- `/Users/sezimzhusupekova/university/SQL/production_clothes/sql/run_all.sql` - запуск всех скриптов
- `/Users/sezimzhusupekova/university/SQL/production_clothes/sql/demo_scenario.sql` - демонстрационный сценарий для защиты

## Быстрый запуск

```bash
createdb production_clothes
psql -d production_clothes -f sql/run_all.sql
psql -d production_clothes -f sql/demo_scenario.sql
```

Если база уже есть и нужно перезапустить все с нуля:

```bash
psql -d production_clothes -f sql/run_all.sql
```

`00_schema.sql` использует `DROP SCHEMA ... CASCADE`, поэтому данные будут пересозданы.

## Примеры вызовов функций по лабораторным

### ЛР1. Закупка сырья

```sql
SELECT create_purchase_order(
  1,
  CURRENT_DATE + 3,
  '[{"raw_material_id":1,"quantity":500,"unit_price":1450}]'::jsonb
);

SELECT receive_purchase_order(1);
```

### ЛР2. Производство

```sql
SELECT run_production(1, 100, CURRENT_DATE);
```

### ЛР3. Продажа

```sql
SELECT create_sale(
  1,
  '[{"product_id":1,"quantity":50,"unit_price":9000}]'::jsonb,
  CURRENT_DATE
);
```

### ЛР4. Зарплата

```sql
SELECT calculate_payroll('2026-02-01');
SELECT pay_payroll('2026-02-01');
```

### ЛР5. Кредит

```sql
SELECT take_loan('Business Bank KZ', 5000000, 18, 12, CURRENT_DATE);
SELECT pay_loan_installment(1, 1, CURRENT_DATE + 30);
```

### ЛР6. Отчеты

```sql
SELECT * FROM v_raw_material_balance;
SELECT * FROM v_finished_product_balance;
SELECT * FROM v_production_summary;
SELECT * FROM v_sales_summary;
SELECT * FROM v_monthly_payroll;
SELECT * FROM v_loans_status;
SELECT * FROM v_company_kpi_monthly;
SELECT * FROM report_period_summary(CURRENT_DATE - 30, CURRENT_DATE);
```

## Что важно для защиты

- Все процессы связаны между собой через остатки и денежные движения.
- В продажах хранится и цена продажи, и себестоимость (для прибыли).
- Зарплата считается отдельно и затем выплачивается отдельной операцией.
- Кредит создает график платежей и уменьшает остаток долга при оплате.
- Отчеты строятся на реальных данных всех предыдущих лабораторных.
