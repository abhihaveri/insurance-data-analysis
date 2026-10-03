"""
eda.py
------
Exploratory analysis on the insurance dataset. Produces the charts used in
the README and mirrors the KPIs later rebuilt as a Power BI report.

Run:
    python eda.py
"""

import pandas as pd
import matplotlib.pyplot as plt

plt.style.use("seaborn-v0_8-whitegrid")

customers = pd.read_csv("../data/raw/customers.csv", parse_dates=["customer_since"])
policies = pd.read_csv("../data/raw/policies.csv", parse_dates=["start_date"])
claims = pd.read_csv("../data/raw/claims.csv", parse_dates=["claim_date"])

OUT = "../screenshots"

# Earned premium = annual premium x years of exposure in the observation
# window (2022-01-01 to 2025-12-31). Comparing total claims paid across a
# 4-year window against a single year of premium overstates loss ratio, so
# this mirrors how insurers actually compute "earned" premium for a KPI.
OBS_END = pd.Timestamp("2025-12-31")
policies["exposure_years"] = ((OBS_END - policies["start_date"]).dt.days / 365.25).clip(upper=4.0)
policies["earned_premium_eur"] = policies["annual_premium_eur"] * policies["exposure_years"]

# --- 1. Loss ratio by policy type ---------------------------------------
paid = claims[claims["claim_status"] == "Paid"]
premium_by_type = policies.groupby("policy_type")["earned_premium_eur"].sum()
claims_by_type = paid.merge(policies[["policy_id", "policy_type"]], on="policy_id")
claims_by_type = claims_by_type.groupby("policy_type")["claim_amount_eur"].sum()
loss_ratio = (claims_by_type / premium_by_type * 100).sort_values(ascending=False)

fig, ax = plt.subplots(figsize=(8, 5))
loss_ratio.plot(kind="bar", ax=ax, color="#2E5C8A")
ax.set_ylabel("Loss ratio (%)")
ax.set_title("Loss Ratio by Policy Type")
plt.xticks(rotation=30, ha="right")
plt.tight_layout()
plt.savefig(f"{OUT}/loss_ratio_by_policy_type.png", dpi=150)
plt.close()

# --- 2. Claims volume over time ------------------------------------------
monthly_claims = claims.set_index("claim_date").resample("ME")["claim_amount_eur"].sum()

fig, ax = plt.subplots(figsize=(9, 5))
monthly_claims.plot(ax=ax, color="#C0392B")
ax.set_ylabel("Total claim amount (EUR)")
ax.set_title("Monthly Claims Paid Trend")
plt.tight_layout()
plt.savefig(f"{OUT}/monthly_claims_trend.png", dpi=150)
plt.close()

# --- 3. Policy distribution by region -------------------------------------
region_counts = policies["region"].value_counts().sort_values(ascending=True)

fig, ax = plt.subplots(figsize=(8, 7))
region_counts.plot(kind="barh", ax=ax, color="#27AE60")
ax.set_xlabel("Number of policies")
ax.set_title("Policy Distribution by German State")
plt.tight_layout()
plt.savefig(f"{OUT}/policy_distribution_by_region.png", dpi=150)
plt.close()

# --- 4. Fraud-flagged rate by policy type ---------------------------------
merged = claims.merge(policies[["policy_id", "policy_type"]], on="policy_id")
fraud_rate = merged.groupby("policy_type")["fraud_flag"].mean().sort_values(ascending=False) * 100

fig, ax = plt.subplots(figsize=(8, 5))
fraud_rate.plot(kind="bar", ax=ax, color="#8E44AD")
ax.set_ylabel("Flagged rate (%)")
ax.set_title("Fraud-Flagged Claim Rate by Policy Type")
plt.xticks(rotation=30, ha="right")
plt.tight_layout()
plt.savefig(f"{OUT}/fraud_flag_rate.png", dpi=150)
plt.close()

# --- Print summary KPIs for the README ------------------------------------
total_premium = policies["earned_premium_eur"].sum()
total_claims_paid = paid["claim_amount_eur"].sum()
overall_loss_ratio = total_claims_paid / total_premium * 100
churn_rate = (policies["status"].isin(["Lapsed", "Cancelled"])).mean() * 100

print(f"Total premium written:   EUR {total_premium:,.0f}")
print(f"Total claims paid:       EUR {total_claims_paid:,.0f}")
print(f"Overall loss ratio:      {overall_loss_ratio:.1f}%")
print(f"Overall churn rate:      {churn_rate:.1f}%")
print("Charts written to ../screenshots/")
