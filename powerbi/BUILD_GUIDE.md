# Power BI Build Guide

How the dashboard in `German Insurance Book Analysis.pbix` is built. Follow
it in Power BI Desktop, then export the page screenshots and save the
.pbix into this folder.

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
// annual premium x years of exposure (fractional), capped at the 4-year
// observation window. Use DAY / 365.25, not YEAR: DATEDIFF with YEAR only
// counts calendar-year boundaries and under-counts exposure.
SUMX (
    policies,
    policies[annual_premium_eur]
        * MIN ( 4, DATEDIFF ( policies[start_date], DATE ( 2025, 12, 31 ), DAY ) / 365.25 )
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
- Line chart: Total Claims Paid by month. Add a calculated column
  `Month Start = DATE ( YEAR ( claims[claim_date] ), MONTH ( claims[claim_date] ), 1 )`
  and use it as a continuous date axis (46 points, Feb 2022 to Dec 2025).
  Do not use only the Month level of the date hierarchy or a month-name
  column: that sums each calendar month across all 4 years and sorts the
  names alphabetically (Apr, Aug, Dec, Feb, ...), which is not a trend.
  Turn **Smooth** off for the line.
- Bar chart: Fraud Flagged Rate % by `policy_type`
- Table: Claim Status breakdown with Avg Days to Settle

**Page 3 — Agent & Customer Performance**
- Table: Agent performance — `agent_id`, policy count, `[Total Premium Written]`,
  `[Earned Premium]`, `[Total Claims Paid]` and `[Loss Ratio %]`. Use these
  **measures**, not the raw `claim_amount_eur` column: the raw column sums
  every claim status (EUR 7.05M, including Rejected and Under Review) instead
  of paid claims (EUR 5.29M), so the visible columns could not reproduce the
  loss ratio. Matches the ranking query in `sql/02_analysis_queries.sql`.
- Bar chart: Churn Rate % by `credit_score_band`

## 5. Formatting
- Use a consistent color: blue for premium/volume metrics, red for
  loss/claims metrics — makes the loss ratio story readable at a glance.
- Add a title bar with your name and "German Insurance Book Analysis."
- Export each page as PNG into `../screenshots/` as `powerbi_page1_overview.png`,
  `powerbi_page2_claims.png` and `powerbi_page3_agents.png`.
- Number format: group thousands as 207,610, not 2,07,610 (Indian grouping).
  If your Power BI regional setting produces the latter, change it to
  English (United States) or German (Germany) before exporting.
- Set Display units to None on count cards so Claim Count reads 1,562 and
  Policy Count 7,000 (not 2K, 1.562K or 7K).
- Save the .pbix into this folder before committing to GitHub (GitHub
  renders .pbix as a downloadable binary, not inline — that's expected).

## 6. Check your numbers

| Where | Expected |
|---|---|
| Page 1: Total Premium Written / Total Claims Paid | about EUR 3.8M / EUR 5.29M |
| Page 1: Loss Ratio % / Churn Rate % | 63.4% / 22.0% |
| Page 1: loss ratio by policy type | Wohngebaeude 100.2%, Haftpflicht 85.7%, Hausrat 70.9%, Kfz 61.9%, Lebensversicherung 35.6% |
| Page 2: Claim Count / Fraud Flagged Rate % / Avg Days to Settle | 1,562 / 3.9% / 46 |
| Page 2: Monthly Claims Paid Trend | 46 monthly points, Feb 2022 to Dec 2025; low about EUR 1K (Feb 2022), high about EUR 364K (Aug 2025) |
| Page 3: agent table, Total row Loss Ratio % | 63.4% |
| Page 3: highest agents | AGT-012 103.8%, AGT-028 101.0%, AGT-011 93.4% (range 25% to 104%) |
| Page 3: worked example, AGT-012 | claims paid 172,039 / earned premium 165,723 = 103.8% (premium written 80,640; raw all-status claims 207,610 are not used) |

Earned Premium itself is about EUR 8.35M. `Total Premium Written` (about
EUR 3.8M) is one year of premium per policy and must never be the Loss
Ratio denominator: a loss ratio of about 140% anywhere in the report means
that visual divides by `Total Premium Written`.
