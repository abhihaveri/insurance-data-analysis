-- 02_analysis_queries.sql
-- Core business questions an insurance analytics team would actually ask.

-- 1. Loss ratio by policy type (claims paid / premium collected)
--    Loss ratio is the single most important underwriting KPI in insurance.
SELECT
    p.policy_type,
    ROUND(SUM(p.annual_premium_eur), 2)                         AS total_premium_eur,
    ROUND(COALESCE(SUM(c.claim_amount_eur), 0), 2)               AS total_claims_paid_eur,
    ROUND(COALESCE(SUM(c.claim_amount_eur), 0) / SUM(p.annual_premium_eur) * 100, 1) AS loss_ratio_pct
FROM policies p
LEFT JOIN claims c
    ON c.policy_id = p.policy_id AND c.claim_status = 'Paid'
GROUP BY p.policy_type
ORDER BY loss_ratio_pct DESC;


-- 2. Claims frequency and average severity by region
SELECT
    p.region,
    COUNT(DISTINCT p.policy_id)                          AS policy_count,
    COUNT(c.claim_id)                                    AS claim_count,
    ROUND(COUNT(c.claim_id) * 1.0 / COUNT(DISTINCT p.policy_id), 3) AS claims_per_policy,
    ROUND(AVG(c.claim_amount_eur), 2)                    AS avg_claim_severity_eur
FROM policies p
LEFT JOIN claims c ON c.policy_id = p.policy_id
GROUP BY p.region
ORDER BY claims_per_policy DESC;


-- 3. Agent performance ranking — loss ratio and book size (window function)
WITH agent_book AS (
    SELECT
        p.agent_id,
        SUM(p.annual_premium_eur)                       AS premium_written,
        COALESCE(SUM(c.claim_amount_eur), 0)            AS claims_paid,
        COUNT(DISTINCT p.policy_id)                     AS policies_sold
    FROM policies p
    LEFT JOIN claims c ON c.policy_id = p.policy_id AND c.claim_status = 'Paid'
    GROUP BY p.agent_id
)
SELECT
    agent_id,
    policies_sold,
    ROUND(premium_written, 2)  AS premium_written_eur,
    ROUND(claims_paid, 2)      AS claims_paid_eur,
    ROUND(claims_paid / NULLIF(premium_written, 0) * 100, 1) AS loss_ratio_pct,
    RANK() OVER (ORDER BY premium_written DESC)         AS rank_by_volume,
    RANK() OVER (ORDER BY claims_paid / NULLIF(premium_written, 0) ASC) AS rank_by_profitability
FROM agent_book
ORDER BY rank_by_volume;


-- 4. Fraud-flagged claim rate by policy type
SELECT
    p.policy_type,
    COUNT(c.claim_id)                                          AS total_claims,
    SUM(CASE WHEN c.fraud_flag = 1 THEN 1 ELSE 0 END)          AS flagged_claims,
    ROUND(SUM(CASE WHEN c.fraud_flag = 1 THEN 1 ELSE 0 END) * 100.0
          / NULLIF(COUNT(c.claim_id), 0), 2)                   AS flagged_rate_pct
FROM claims c
JOIN policies p ON p.policy_id = c.policy_id
GROUP BY p.policy_type
ORDER BY flagged_rate_pct DESC;


-- 5. Customer churn signal — lapsed/cancelled rate by credit score band
SELECT
    cu.credit_score_band,
    COUNT(*)                                                    AS total_policies,
    SUM(CASE WHEN p.status IN ('Lapsed', 'Cancelled') THEN 1 ELSE 0 END) AS churned_policies,
    ROUND(SUM(CASE WHEN p.status IN ('Lapsed', 'Cancelled') THEN 1 ELSE 0 END) * 100.0
          / COUNT(*), 1)                                        AS churn_rate_pct
FROM policies p
JOIN customers cu ON cu.customer_id = p.customer_id
GROUP BY cu.credit_score_band
ORDER BY churn_rate_pct DESC;


-- 6. Monthly premium written trend with running total (window function)
WITH monthly AS (
    SELECT
        FORMAT(start_date, 'yyyy-MM')          AS month,   -- MSSQL: FORMAT(start_date, 'yyyy-MM')
        SUM(annual_premium_eur)                AS premium_written
    FROM policies
    GROUP BY month
)
SELECT
    month,
    ROUND(premium_written, 2)                          AS premium_written_eur,
    ROUND(SUM(premium_written) OVER (ORDER BY month), 2) AS running_total_eur
FROM monthly
ORDER BY month;


-- 7. Average days-to-settle by claim status (operational efficiency KPI)
SELECT
    claim_status,
    COUNT(*)                             AS claim_count,
    ROUND(AVG(days_to_settle), 1)        AS avg_days_to_settle
FROM claims
WHERE days_to_settle IS NOT NULL
GROUP BY claim_status
ORDER BY avg_days_to_settle DESC;
