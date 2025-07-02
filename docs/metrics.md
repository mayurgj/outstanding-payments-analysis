# 📊 Metrics Used in Outstanding Payments Report

This document outlines all the calculated metrics used in the Looker Studio report and how they are derived from the underlying data.

---

## ✅ Summary Metrics

| Metric Name                | Description                                | Formula |
|---------------------------|--------------------------------------------|---------|
| **Total Receivable**      | Total amount owed *to* us (customers)       | `SUM(IF(type='receivable', pending_amount, 0))` |
| **Total Payable**         | Total amount we *owe* (to vendors)          | `SUM(IF(type='payable', pending_amount, 0))` |
| **Net Outstanding**       | Net position = Receivable - Payable         | `SUM(CASE WHEN type = 'receivable' THEN pending_amount ELSE 0 END) + SUM(CASE WHEN type = 'payable' THEN pending_amount * -1 ELSE 0 END)` |

---

## 🕓 Overdue Metrics

| Metric Name                   | Description                                              | Formula |
|------------------------------|----------------------------------------------------------|---------|
| **Overdue % of Receivable**  | Portion of receivables that are overdue                  | `ROUND(SUM(CASE WHEN type = 'receivable' AND overdue_by_days > 0 THEN ABS(pending_amount) ELSE 0 END) * 100 / NULLIF(SUM(ABS(pending_amount)), 0), 2)` |
| **Overdue % of Payable**     | Portion of payables that are overdue                     | `ROUND(SUM(CASE WHEN type = 'payable' AND overdue_by_days > 0 THEN ABS(pending_amount) ELSE 0 END) * 100 / NULLIF(SUM(ABS(pending_amount)), 0), 2)` |
| **Overdue Receivables**      | Total overdue receivables                                | `SUM(IF(type='receivable' AND overdue_by_days > 0, pending_amount, 0))` |
| **Overdue Payables**         | Total overdue payables                                   | `SUM(IF(type='payable' AND overdue_by_days > 0, pending_amount, 0))` |

---

## 📅 Aging Bucket Classification

| Aging Bucket     | Condition                         | Code |
|------------------|-----------------------------------|------|
| Not Due Yet      | `overdue_by_days < 0`             | A1   |
| 0–14 Days        | `BETWEEN 0 AND 14`                | A2   |
| 15–30 Days       | `BETWEEN 15 AND 30`               | A3   |
| 31–45 Days       | `BETWEEN 31 AND 45`               | A4   |
| Over 45 Days     | `> 45`                            | A5   |

---

## 📌 Status Tags

| Status     | Logic                      |
|------------|----------------------------|
| Upcoming   | `overdue_by_days < 0`      |
| Due Today  | `overdue_by_days = 0`      |
| Overdue    | `overdue_by_days > 0`      |
