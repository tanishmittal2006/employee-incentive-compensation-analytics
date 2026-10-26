-- ============================================================
-- Employee Incentive & Compensation Analytics
-- Layer 2: SQL business queries (DuckDB)
-- Source : data/processed/employee_incentive_final.csv
-- Run from the PROJECT ROOT folder so the relative path works.
-- ============================================================

-- SETUP: load the processed CSV as a table
CREATE OR REPLACE TABLE employees AS
SELECT * FROM read_csv_auto('data/processed/employee_incentive_final.csv',
    types = {'OverTime': 'VARCHAR', 'Attrition': 'VARCHAR'});


-- ------------------------------------------------------------
-- Query 1: Attrition rate by department and compensation band
-- ------------------------------------------------------------
SELECT
    Department,
    CASE
        WHEN MonthlyIncome <  3000 THEN '1_Low (<3K)'
        WHEN MonthlyIncome <  7000 THEN '2_Mid (3K-7K)'
        WHEN MonthlyIncome < 12000 THEN '3_High (7K-12K)'
        ELSE                            '4_Senior (12K+)'
    END AS CompBand,
    COUNT(*)                                AS HeadCount,
    SUM(AttritionFlag)                      AS AttritionCount,
    ROUND(AVG(AttritionFlag) * 100, 1)     AS AttritionRate_Pct,
    ROUND(AVG(MonthlyIncome), 0)           AS AvgMonthlyIncome,
    ROUND(AVG(CompRatio), 3)              AS AvgCompRatio
FROM employees
GROUP BY Department, CompBand
ORDER BY Department, AttritionRate_Pct DESC;





-- ------------------------------------------------------------
-- Query 2: Compa-ratio distribution by job role
-- ------------------------------------------------------------
SELECT
    JobRole,
    COUNT(*)                                AS HeadCount,
    ROUND(AVG(CompRatio), 3)              AS AvgCompRatio,
    ROUND(MIN(CompRatio), 3)              AS MinCompRatio,
    ROUND(MAX(CompRatio), 3)              AS MaxCompRatio,
    SUM(CASE WHEN CompSegment = 'Underpaid' THEN 1 ELSE 0 END) AS UnderpaidCount,
    SUM(CASE WHEN CompSegment = 'Fair'      THEN 1 ELSE 0 END) AS FairCount,
    SUM(CASE WHEN CompSegment = 'Overpaid'  THEN 1 ELSE 0 END) AS OverpaidCount,
    ROUND(
        SUM(CASE WHEN CompSegment = 'Underpaid' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1
    )                                       AS UnderpaidPct
FROM employees
GROUP BY JobRole
ORDER BY AvgCompRatio ASC;


-- ------------------------------------------------------------
-- Query 3: Overtime burden vs incentive level cross-tab
-- ------------------------------------------------------------
SELECT
    OverTime,
    StockOptionLevel,
    COUNT(*)                                        AS HeadCount,
    ROUND(AVG(AttritionFlag) * 100, 1)            AS AttritionRate_Pct,
    ROUND(AVG(MonthlyIncome), 0)                  AS AvgMonthlyIncome,
    ROUND(AVG(CompRatio), 3)                      AS AvgCompRatio,
    ROUND(AVG(IncentiveEligible) * 100, 1)       AS EligibilityRate_Pct,
    ROUND(AVG(CASE WHEN IncentiveEligible = 1
                   THEN SimulatedPayout ELSE NULL END), 0) AS AvgPayoutIfEligible
FROM employees
GROUP BY OverTime, StockOptionLevel
ORDER BY OverTime, StockOptionLevel;





-- ------------------------------------------------------------
-- Query 4: Flight-risk register (underpaid high performers)
-- ------------------------------------------------------------
SELECT
    EmployeeNumber,
    Department,
    JobRole,
    PerformanceRating,
    YearsAtCompany,
    MonthlyIncome,
    ROUND(ExpectedSalary, 0)                        AS ExpectedSalary,
    ROUND(CompRatio, 3)                             AS CompRatio,
    ROUND((ExpectedSalary - MonthlyIncome) * 12, 0) AS AnnualIncentiveGap,
    AttritionRisk,
    RiskScore,
    OverTime
FROM employees
WHERE
    PerformanceRating >= 3
    AND CompSegment = 'Underpaid'
    AND AttritionRisk IN ('High', 'Medium')
ORDER BY RiskScore DESC, AnnualIncentiveGap DESC
LIMIT 25;


-- ------------------------------------------------------------
-- Query 5: Incentive gap cost by department, ranked by ROI
-- ------------------------------------------------------------
SELECT
    Department,
    COUNT(*)                                                    AS TotalEmployees,
    SUM(CASE WHEN CompSegment = 'Underpaid'
             AND IncentiveEligible = 1 THEN 1 ELSE 0 END)      AS UnderpaidEligible,
    ROUND(
        SUM(CASE WHEN CompSegment = 'Underpaid' AND IncentiveEligible = 1
                 THEN (ExpectedSalary - MonthlyIncome) * 12
                 ELSE 0 END), 0
    )                                                           AS TotalIncentiveGapCost,
    ROUND(
        SUM(CASE WHEN AttritionRisk = 'High'
                 THEN MonthlyIncome * 12 * 0.5
                 ELSE 0 END), 0
    )                                                           AS ReplacementCostIfNoAction,
    ROUND(
        SUM(CASE WHEN AttritionRisk = 'High'
                 THEN MonthlyIncome * 12 * 0.5
                 ELSE 0 END) -
        SUM(CASE WHEN CompSegment = 'Underpaid' AND IncentiveEligible = 1
                 THEN (ExpectedSalary - MonthlyIncome) * 12
                 ELSE 0 END), 0
    )                                                           AS NetROI,
    ROUND(AVG(CompRatio), 3)                                   AS AvgCompRatio,
    ROUND(AVG(AttritionFlag) * 100, 1)                        AS AttritionRate_Pct
FROM employees
GROUP BY Department
ORDER BY NetROI DESC;




-- ------------------------------------------------------------
-- Query 6: Reconciliation audit (eligible but excluded)
-- ------------------------------------------------------------
SELECT
    Department,
    JobRole,
    COUNT(*)                                        AS EligibleButExcluded,
    ROUND(AVG(MonthlyIncome), 0)                   AS AvgIncome,
    ROUND(AVG(CompRatio), 3)                       AS AvgCompRatio,
    ROUND(AVG(PerformanceRating), 2)               AS AvgPerfRating,
    ROUND(AVG(YearsAtCompany), 1)                  AS AvgTenure,
    ROUND(AVG(AttritionFlag) * 100, 1)            AS AttritionRate_Pct,
    ROUND(
        SUM(MonthlyIncome * 12 * (PercentSalaryHike / 100.0) * StockMultiplier), 0
    )                                               AS MissedPayoutValue
FROM employees
WHERE IncentiveEligible = 1 AND SimulatedPayout = 0
GROUP BY Department, JobRole
HAVING COUNT(*) > 0
ORDER BY MissedPayoutValue DESC;