# German Insurance Book Analysis

End-to-end analysis of a synthetic but realistic German personal-lines
insurance book — underwriting KPIs (loss ratio, claims frequency, fraud
signals, churn) across Kfz (auto), Haftpflicht (liability), Hausrat
(household contents), Wohngebaeude (building), and Lebensversicherung
(life) policies.

## Business problem

An insurer's underwriting and claims teams need visibility into which
product lines and regions are profitable, where fraud risk concentrates,
and which customer segments are churning — the same KPIs used at
insurance carriers and their software vendors (e.g. Sapiens core systems)
across the DACH market.

## Dataset

Synthetic data generated with `Faker` (seeded for reproducibility) to
resemble a mid-sized German insurer's book:
- **4,000 customers** across all 16 German states
- **7,000 policies** across 5 product lines, 2022–2025
- **~1,500 claims** with realistic frequency/severity by product line

Schema: `data/raw/customers.csv`, `policies.csv`, `claims.csv`

## Key findings

| Metric | Value |
|---|---|
| Total earned premium | €8.35M |
| Total claims paid | €5.29M |
| **Overall loss ratio** | **63.4%** |
| Overall policy churn rate | 22.0% |

- **Wohngebaeude (building) insurance runs the highest loss ratio (~100%)** —
  this line is the one to re-underwrite or re-price first.
- **Lebensversicherung (life) has the lowest loss ratio (~35%)** but also the
  lowest claim frequency by design — expected given the product structure.
- Fraud-flagged claims cluster more heavily in Kfz and Hausrat, the two
  highest-frequency product lines.

See `screenshots/` for the supporting charts (loss ratio by policy type,
monthly claims trend, regional distribution, fraud-flag rate).

## Tech stack

- **Python** (pandas, matplotlib, Faker) — data generation and EDA
- **SQL** (schema + 7 analysis queries with CTEs and window functions)
- **Power BI** — interactive dashboard (see `powerbi/BUILD_GUIDE.md` for
  the exact DAX measures and report layout)

## Repository structure

```
insurance-data-analysis/
├── data/raw/              customers.csv, policies.csv, claims.csv
├── python/
│   ├── generate_data.py   synthetic data generator
│   └── eda.py             exploratory analysis + chart generation
├── sql/
│   ├── 01_schema.sql       table definitions
│   └── 02_analysis_queries.sql   7 business-question queries
├── powerbi/
│   └── BUILD_GUIDE.md      DAX measures + report page spec
└── screenshots/            chart outputs / dashboard exports
```

## How to run

```bash
cd python
pip install pandas numpy matplotlib faker
python generate_data.py   # regenerates the CSVs in data/raw/
python eda.py              # runs EDA, writes charts to screenshots/
```

Load the schema and run the analysis queries against SQLite, PostgreSQL,
or SQL Server using the files in `sql/`.

## Note on methodology

Loss ratio compares claims paid against **earned premium** (annual premium
× years of policy exposure within the observation window), not raw annual
premium — comparing multi-year claims against a single year of premium
would overstate the ratio. This mirrors how insurers actually calculate
the KPI.
