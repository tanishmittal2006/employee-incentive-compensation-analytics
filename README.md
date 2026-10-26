# Employee Incentive & Compensation Analytics

A compensation equity and incentive analytics project built on HR data to model pay equity, simulate incentive eligibility, and compare the cost of fixing pay gaps with the cost of losing high-risk employees.

---

## Problem Statement

Incentive programs fail when pay structures don't reflect performance, tenure, or market rate, leaving high performers underpaid and raising attrition. This project investigates those failure points using a public HR dataset, modelling compensation equity, incentive eligibility, and the financial trade-off between closing pay gaps and absorbing replacement costs.

---

## Dataset

**IBM HR Analytics Employee Attrition & Performance** (Kaggle)
1,470 employee records · 35 variables.

Fields used include department, job role, monthly income, performance rating, stock option level, years at company, job satisfaction, overtime, and attrition status.

---

## Key Findings

- **39.3% of the workforce (578 of 1,470) is underpaid** relative to a regression-based expected salary (R² = 0.61). Underpaid means a compa-ratio below 0.85.
- **Employees with no stock options show 24.4% attrition**, compared with 7.6–9.4% at stock option levels 1 and 2. Level 3 shows 17.6%, but it covers only 85 employees, so it is not a reliable trend.
- **Employees on overtime with no stock options show 45.1% attrition**, the highest of any group examined.
- **The incentive gap is $11.76M.** It is the annual cost of raising all 371 underpaid, incentive-eligible employees to their expected salary.
- **The replacement exposure for the 272 high-risk employees is $8.06M**, assuming replacement costs 50% of annual salary.
- **Net result: closing every gap costs about $3.7M more than the projected replacement exposure.** Full equity correction is therefore not cost-justified on these numbers alone, so any intervention should be targeted and phased.


---

## Methodology

### Layer 1: Compensation Equity Model (Python)
- **Expected salary:** a linear regression predicts monthly income from performance rating, total working years, education, department, job role, years at company, and years in current role. Department and job role are label-encoded.
- **Compa-ratio:** actual salary divided by expected salary. Segments: **Underpaid** (< 0.85), **Fair** (0.85–1.15), **Overpaid** (> 1.15). Result: 578 underpaid, 377 fair, 515 overpaid.
- **Incentive eligibility:** an employee is eligible only if all four hold: performance rating ≥ 3, at least 2 years at the company, no overtime, and compa-ratio ≤ 1.15. Result: 607 eligible (41.3%).
- **Simulated payout:** `MonthlyIncome × 12 × (PercentSalaryHike ÷ 100) × StockMultiplier` for eligible employees, and 0 otherwise. Stock multipliers are 1.0, 1.1, 1.2 and 1.3 for option levels 0–3. Total pool: $6,128,518.
- **Attrition risk score (rule-based, not a trained model):** underpaid +30, overtime +25, more than 3 years since last promotion +20, job satisfaction ≤ 2 +15, eligible with zero payout +10. Tiers: High ≥ 50, Medium 25–49, Stable < 25. Result: 272 High, 622 Medium, 576 Stable.
- **ROI framework:** replacement cost is assumed to be 50% of annual salary. The incentive gap is `(ExpectedSalary − MonthlyIncome) × 12` for underpaid, eligible employees.

### Layer 2: SQL Business Queries (DuckDB)
Six queries, saved in `sql/incentive_queries.sql` and `notebooks/02_sql_incentive_queries.ipynb`:
1. Attrition by department and compensation band
2. Compa-ratio distribution by job role
3. Overtime burden versus stock option level
4. Flight-risk register of underpaid high performers
5. Department incentive-gap cost and ROI
6. Eligibility reconciliation audit

Selected results:
- Attrition is highest in the lowest pay band (under $3K a month) in every department, reaching 41.2% in Sales.
- Laboratory Technicians (63%), Research Scientists (60%) and Sales Representatives (53%) have the highest underpaid share.
- Overall attrition by department: Human Resources 19.0%, Sales 20.6%, Research & Development 13.8%.
- Net ROI is negative in all three departments (HR −$53K, Sales −$135K, R&D −$3.5M).

### Layer 3: Power BI Dashboard
A four-page dashboard on a star schema (one fact table, `Fact_Employee`, and four dimensions: `Dim_Department`, `Dim_JobRole`, `Dim_Education`, `Dim_CompBand`).
- **Executive Summary:** workforce KPIs, attrition breakdown, compa-ratio and compensation segments by department
- **Compensation Equity Analysis:** expected versus actual salary, underpaid % by job role, education × performance rating matrix
- **Incentive Program Tracker:** attrition by stock option level, eligibility rate by department, job satisfaction × pay band matrix
- **Participant Eligibility Register:** filterable employee register with compa-ratio, risk tier and eligibility status

Dashboard totals were checked against the Python and SQL results (1,470 employees, 16.1% attrition, 272 high-risk, $11.76M gap cost, $8.06M replacement exposure).

---

## Limitations

- **No performance variation:** no employee is rated below 3 on the 1–4 scale, so the performance condition in the eligibility rule never excludes anyone. This reflects the dataset and is not treated as an error.
- **The reconciliation audit finds nothing by design:** payouts are simulated from the same eligibility rule, so no eligible employee can have a zero payout. Query 6 returns no rows. On real payroll data, mismatches would be expected, and the fifth risk factor (+10 points) can never apply here.
- **Pay position is a weak predictor of attrition:** attrition is 17.1% for underpaid, 15.9% for overpaid and 14.9% for fair-paid employees. Overtime and stock options differ much more.
- **In-sample model:** the regression is fitted and scored on the same 1,470 records, so R² (0.6053) describes fit to this data and not out-of-sample accuracy.
- **Assumptions, not measurements:** the 50% replacement cost and the risk-score weights are business assumptions.
- **Overlapping groups:** the gap cost covers underpaid, eligible employees (371) and the replacement cost covers high-risk employees (272). Net ROI is a rough comparison of the two.
- **Label encoding** of department and job role implies an order that does not exist.

---

## Business Recommendations

1. **Phase and target pay corrections.** Fixing every gap costs about $3.7M more than the replacement exposure, so start with high-risk, underpaid employees, and use the flight-risk register (Query 4) to prioritise.
2. **Review stock option eligibility** for employees at level 0, who show 24.4% attrition against 7.6–9.4% at levels 1 and 2.
3. **Review overtime workloads,** especially for employees with no stock options (45.1% attrition). Under the current rule, overtime workers are ineligible for incentives, which is a policy question to examine.
4. **Run a reconciliation audit** on real payout data to catch eligible employees who were excluded from payouts.

---

## Technical Approach

**Languages and libraries:** Python 3.14, pandas, NumPy, scikit-learn, matplotlib, seaborn, DuckDB, SQL
**Visualisation:** Power BI Desktop
**Notes:**
- DuckDB reads CSV files directly and needs no database server.
- DuckDB detects Yes/No columns as booleans, so the load step forces `OverTime` and `Attrition` to text with `types = {...}`.
- DuckDB's `ROUND()` can return `decimal.Decimal`, so values are cast with `float()` before Python arithmetic.

### How to run

```bash
# 1. Create a virtual environment and install dependencies
pip install -r requirements.txt

# 2. Place the dataset (Kaggle: "IBM HR Analytics Employee Attrition & Performance")
#    Save as: data/raw/WA_Fn-UseC_-HR-Employee-Attrition.csv

# 3. Run Layer 1. This creates data/processed/employee_incentive_final.csv
#    Open and run notebooks/01_compensation_equity_model.ipynb

# 4. Run Layer 2. Run notebooks/02_sql_incentive_queries.ipynb,
#    or run sql/incentive_queries.sql from the project root

# 5. Power BI: open powerbi/incentive_dashboard.pbix, then use
#    Home > Transform data > Data source settings > Change Source
#    to point at data/processed/employee_incentive_final.csv
```

The notebooks use relative paths such as `../data/raw/...`, so run them with the `notebooks` folder as the working directory.

---

## Repository Structure

```
employee-incentive-compensation-analytics/
├── README.md
├── requirements.txt
├── data/
│   ├── raw/
│   └── processed/
├── notebooks/
│   ├── 01_compensation_equity_model.ipynb
│   └── 02_sql_incentive_queries.ipynb
├── sql/
│   └── incentive_queries.sql
└── powerbi/
    ├── incentive_dashboard.pbix
    └── screenshots/
```