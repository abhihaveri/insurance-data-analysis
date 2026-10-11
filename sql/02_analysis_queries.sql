-- 02_analysis_queries.sql
-- Core business questions an insurance analytics team would actually ask.

-- 1. Loss ratio by policy type (claims paid / EARNED premium)
--    Loss ratio is the single most important underwriting KPI in insurance.
--    Earned premium (not one year of annual premium) is the correct denominator
--    because claims accumulate over the whole 2022-2025 window.
WITH policy_base AS (
    -- one row per policy, with earned premium = annual premium x years of exposure,
    -- capped at the 4-year observation window (same logic as the DAX / Python)
    SELECT
        p.policy_id,
        p.policy_type,
        p.agent_id,
        p.annual_premium_eur,
        p.annual_premium_eur
            * MIN(4.0, (julianday('2025-12-31') - julianday(p.start_date)) / 365.25) AS earned_premium_eur
        -- PostgreSQL: LEAST(4.0, ('2025-12-31'::date - p.start_date) / 365.25)
        -- MSSQL: CASE WHEN DATEDIFF(day, p.start_date, '2025-12-31') / 365.25 > 4 THEN 4
        --             ELSE DATEDIFF(day, p.start_date, '2025-12-31') / 365.25 END
    FROM policies p
),
paid AS (
    -- paid claims aggregated per policy BEFORE joining, so a policy's premium is
    -- never repeated when it has several claims (join fan-out)
    SELECT policy_id, SUM(claim_amount_eur) AS paid_eur
    FROM claims
    WHERE claim_status = 'Paid'
    GROUP BY policy_id
)
SELECT
    b.policy_type,
    ROUND(SUM(b.earned_premium_eur), 2)                                   AS earned_premium_eur,
    ROUND(COALESCE(SUM(pd.paid_eur), 0), 2)                               AS total_claims_paid_eur,
    ROUND(COALESCE(SUM(pd.paid_eur), 0) / SUM(b.earned_premium_eur) * 100, 1) AS loss_ratio_pct
FROM policy_base b
LEFT JOIN paid pd ON pd.policy_id = b.policy_id
GROUP BY b.policy_type
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


-- 3. Agent performance ranking — loss ratio on earned premium and book size (window function)
WITH policy_base AS (
    -- one row per policy, with earned premium = annual premium x years of exposure,
    -- capped at the 4-year observation window (same logic as the DAX / Python)
    SELECT
        p.policy_id,
        p.policy_type,
        p.agent_id,
        p.annual_premium_eur,
        p.annual_premium_eur
            * MIN(4.0, (julianday('2025-12-31') - julianday(p.start_date)) / 365.25) AS earned_premium_eur
        -- PostgreSQL: LEAST(4.0, ('2025-12-31'::date - p.start_date) / 365.25)
        -- MSSQL: CASE WHEN DATEDIFF(day, p.start_date, '2025-12-31') / 365.25 > 4 THEN 4
        --             ELSE DATEDIFF(day, p.start_date, '2025-12-31') / 365.25 END
    FROM policies p
),
paid AS (
    -- paid claims aggregated per policy BEFORE joining, so a policy's premium is
    -- never repeated when it has several claims (join fan-out)
    SELECT policy_id, SUM(claim_amount_eur) AS paid_eur
    FROM claims
    WHERE claim_status = 'Paid'
    GROUP BY policy_id
),
agent_book AS (
    SELECT
        b.agent_id,
        COUNT(*)                              AS policies_sold,
        SUM(b.annual_premium_eur)             AS premium_written,
        SUM(b.earned_premium_eur)             AS earned_premium,
        COALESCE(SUM(pd.paid_eur), 0)         AS claims_paid
    FROM policy_base b
    LEFT JOIN paid pd ON pd.policy_id = b.policy_id
    GROUP BY b.agent_id
)
SELECT
    agent_id,
    policies_sold,
    ROUND(premium_written, 2)   AS premium_written_eur,
    ROUND(earned_premium, 2)    AS earned_premium_eur,
    ROUND(claims_paid, 2)       AS claims_paid_eur,
    ROUND(claims_paid / NULLIF(earned_premium, 0) * 100, 1) AS loss_ratio_pct,
    RANK() OVER (ORDER BY premium_written DESC)                          AS rank_by_volume,
    RANK() OVER (ORDER BY claims_paid / NULLIF(earned_premium, 0) ASC)   AS rank_by_profitability
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
