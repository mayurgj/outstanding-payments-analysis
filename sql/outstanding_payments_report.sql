-- Step 1: Combine all bills
WITH bill_combined AS (
  SELECT bill_date AS date, ledger, name, opening_balance AS amount, 'New Ref' AS billtype, bill_credit_period
  FROM `tallydb_24_25.mst_opening_bill_allocation`
  UNION ALL
  SELECT v.date, b.ledger, b.name, b.amount, b.billtype, b.bill_credit_period
  FROM `tallydb_24_25.trn_bill` AS b
  JOIN `tallydb_24_25.trn_voucher` AS v ON v.guid = b.guid
),
-- Separate New/Advance vs Agst Ref
tbl_newref AS (
  SELECT * FROM bill_combined WHERE billtype IN ('New Ref', 'Advance')
),
tbl_agstref AS (
  SELECT * FROM bill_combined WHERE billtype = 'Agst Ref'
),
-- Step 2: Compute outstanding amount
tbl_outstanding AS (
  SELECT
    nr.ledger,
    nr.name,
    COALESCE(MAX(nr.amount), 0) AS billed_amount,
    COALESCE(SUM(ar.amount), 0) AS adjusted_amount,
    (COALESCE(MAX(nr.amount), 0) + COALESCE(SUM(ar.amount), 0)) AS outstanding_amount,
    DATE_DIFF(CURRENT_DATE(), MAX(nr.date), DAY) - MAX(nr.bill_credit_period) AS overdue_days,
    DATE_ADD(MAX(nr.date), INTERVAL MAX(nr.bill_credit_period) DAY) AS overdue_date,
    DATE_DIFF(CURRENT_DATE(), MAX(nr.date), DAY) AS oustanding_days,
    MAX(nr.date) AS bill_date,
    MAX(nr.bill_credit_period) AS bill_credit_period
  FROM tbl_newref AS nr
  LEFT JOIN tbl_agstref AS ar ON nr.ledger = ar.ledger AND nr.name = ar.name
  GROUP BY nr.ledger, nr.name
),
-- Step 3: Final structure with classifications
out_report AS (
  SELECT bill_date AS date, name AS ref_number, ledger AS party_name,
         outstanding_amount AS pending_amount, overdue_date AS due_on,
         overdue_days AS overdue_by_days,
         "payable" AS type
  FROM tbl_outstanding
  WHERE outstanding_amount > 0
  UNION ALL
  SELECT bill_date, name, ledger, outstanding_amount, overdue_date,
         overdue_days, "receivable"
  FROM tbl_outstanding
  WHERE outstanding_amount < 0
)
-- Step 4: Main output
SELECT 
  o.date,
  o.ref_number,
  o.party_name,
  ABS(o.pending_amount) AS pending_amount,
  o.due_on,
  o.overdue_by_days,
  o.type,
  CASE
      WHEN overdue_by_days > 45 THEN 'Over 45'
      WHEN overdue_by_days BETWEEN 31 AND 45 THEN '31–45 Days'
      WHEN overdue_by_days BETWEEN 15 AND 30 THEN '15–30 Days'
      WHEN overdue_by_days BETWEEN 0 AND 14 THEN '0–14 Days'
      ELSE 'Not Due Yet'
  END AS aging_bucket,
  CASE
      WHEN overdue_by_days > 45 THEN 'A5'
      WHEN overdue_by_days BETWEEN 31 AND 45 THEN 'A4'
      WHEN overdue_by_days BETWEEN 15 AND 30 THEN 'A3'
      WHEN overdue_by_days BETWEEN 0 AND 14 THEN 'A2'
      ELSE 'A1'
  END AS aging_bucket_code,
  CASE
      WHEN overdue_by_days > 0 THEN 'Overdue'
      WHEN overdue_by_days = 0 THEN 'Due Today'
      ELSE 'Upcoming'
  END AS status
FROM out_report o
