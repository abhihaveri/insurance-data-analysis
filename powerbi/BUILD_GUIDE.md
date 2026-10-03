# Power BI Build Guide

 Power BI Desktop on your machine, then export
screenshots and the .pbix into this folder before pushing to GitHub.

## 1. Get Data
Import the three CSVs from `../data/raw/`:
`customers.csv`, `policies.csv`, `claims.csv`

## 2. Model relationships
- `customers[customer_id]` → `policies[customer_id]` (1:many)
- `policies[policy_id]` → `claims[policy_id]` (1:many)

Mark `policies` as the fact table hub. Set `claims[claim_date]` and
`policies[start_date]` as Date columns; build a standalone Date table
(Modeling → New Table) and relate both to it for proper time intelligence.

## 3. DAX measures to create

```dax
Total Premium Written =
SUM ( policies[annual_premium_eur] )

Earned Premium =
SUMX (
    policies,
    policies[annual_premium_eur]
        * MIN ( 4, DATEDIFF ( policies[start_date], DATE(2025,12,31), YEAR ) + 1 )
)

Total Claims Paid =
CALCULATE (
    SUM ( claims[claim_amount_eur] ),
    claims[claim_status] = "Paid"
)

Loss Ratio % =
DIVIDE ( [Total Claims Paid], [Earned Premium] )

Claim Count =
COUNTROWS ( claims )

Claims per Policy =
DIVIDE ( [Claim Count], DISTINCTCOUNT ( policies[policy_id] ) )

Fraud Flagged Rate % =
DIVIDE (
    CALCULATE ( COUNTROWS ( claims ), claims[fraud_flag] = TRUE() ),
    [Claim Count]
)

Churn Rate % =
DIVIDE (
    CALCULATE ( COUNTROWS ( policies ), policies[status] IN { "Lapsed", "Cancelled" } ),
    COUNTROWS ( policies )
)

Avg Days to Settle =
AVERAGE ( claims[days_to_settle] )
```

## 4. Report pages to build

**Page 1 — Executive Overview**
- KPI cards: Total Premium Written, Total Claims Paid, Loss Ratio %, Churn Rate %
- Bar chart: Loss Ratio % by `policy_type`
- Map visual: policy count by `region` (use the Germany shape map or a filled map)

**Page 2 — Claims Deep Dive**
- Line chart: Total Claims Paid by month (`claim_date`)
- Bar chart: Fraud Flagged Rate % by `policy_type`
- Table: Claim Status breakdown with Avg Days to Settle

**Page 3 — Agent & Customer Performance**
- Table: Agent performance (premium written, loss ratio, rank) — matches
  the ranking query in `sql/02_analysis_queries.sql`
- Bar chart: Churn Rate % by `credit_score_band`

## 5. Formatting
- Use a consistent color: blue for premium/volume metrics, red for
  loss/claims metrics — makes the loss ratio story readable at a glance.
- Add a title bar with your name and "German Insurance Book Analysis."
- Export each page as PNG into `../screenshots/powerbi_page1.png` etc.
- Save the .pbix into this folder before committing to GitHub (GitHub
  renders .pbix as a downloadable binary, not inline — that's expected).
