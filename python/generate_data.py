"""
generate_data.py
-----------------
Generates a synthetic but realistic German insurance dataset for analysis.
Simulates a mid-sized insurer's book of business across the common German
personal-lines products: Kfz (auto), Haftpflicht (liability), Hausrat
(household contents), Wohngebaeude (building), and Lebensversicherung (life).

Run:
    python generate_data.py

Outputs:
    ../data/raw/customers.csv
    ../data/raw/policies.csv
    ../data/raw/claims.csv
"""

import random
from datetime import date, timedelta

import numpy as np
import pandas as pd
from faker import Faker

fake = Faker("de_DE")
random.seed(42)
np.random.seed(42)

N_CUSTOMERS = 4000
N_POLICIES = 7000
CLAIM_RATE = 0.28  # ~28% of policies have at least one claim in the window

GERMAN_STATES = [
    "Bavaria", "North Rhine-Westphalia", "Baden-Wuerttemberg", "Lower Saxony",
    "Hesse", "Saxony", "Berlin", "Rhineland-Palatinate", "Schleswig-Holstein",
    "Brandenburg", "Thuringia", "Saxony-Anhalt", "Mecklenburg-Vorpommern",
    "Hamburg", "Bremen", "Saarland",
]

POLICY_TYPES = {
    "Kfz": {"premium_range": (350, 1400), "claim_freq": 0.30, "claim_severity": (400, 8000)},
    "Haftpflicht": {"premium_range": (40, 120), "claim_freq": 0.07, "claim_severity": (200, 4500)},
    "Hausrat": {"premium_range": (60, 250), "claim_freq": 0.13, "claim_severity": (150, 3500)},
    "Wohngebaeude": {"premium_range": (200, 900), "claim_freq": 0.10, "claim_severity": (500, 18000)},
    "Lebensversicherung": {"premium_range": (300, 2500), "claim_freq": 0.025, "claim_severity": (3000, 50000)},
}

AGENTS = [f"AGT-{i:03d}" for i in range(1, 41)]
START = date(2022, 1, 1)
END = date(2025, 12, 31)


def random_date(start: date, end: date) -> date:
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))


def gen_customers(n: int) -> pd.DataFrame:
    rows = []
    for i in range(1, n + 1):
        dob = fake.date_of_birth(minimum_age=18, maximum_age=85)
        rows.append(
            {
                "customer_id": f"CUST-{i:05d}",
                "age": date.today().year - dob.year,
                "gender": random.choice(["M", "F"]),
                "state": random.choice(GERMAN_STATES),
                "city": fake.city(),
                "customer_since": random_date(date(2015, 1, 1), date(2024, 1, 1)),
                "credit_score_band": random.choices(
                    ["Excellent", "Good", "Fair", "Poor"], weights=[0.25, 0.4, 0.25, 0.10]
                )[0],
            }
        )
    return pd.DataFrame(rows)


def gen_policies(customers: pd.DataFrame, n: int) -> pd.DataFrame:
    rows = []
    cust_ids = customers["customer_id"].tolist()
    for i in range(1, n + 1):
        ptype = random.choices(
            list(POLICY_TYPES.keys()), weights=[0.35, 0.25, 0.18, 0.14, 0.08]
        )[0]
        cfg = POLICY_TYPES[ptype]
        start_date = random_date(START, date(2025, 6, 30))
        premium = round(random.uniform(*cfg["premium_range"]), 2)
        rows.append(
            {
                "policy_id": f"POL-{i:06d}",
                "customer_id": random.choice(cust_ids),
                "policy_type": ptype,
                "agent_id": random.choice(AGENTS),
                "start_date": start_date,
                "annual_premium_eur": premium,
                "status": random.choices(
                    ["Active", "Lapsed", "Cancelled"], weights=[0.78, 0.14, 0.08]
                )[0],
                "region": random.choice(GERMAN_STATES),
            }
        )
    return pd.DataFrame(rows)


def gen_claims(policies: pd.DataFrame) -> pd.DataFrame:
    rows = []
    claim_id = 1
    for _, pol in policies.iterrows():
        cfg = POLICY_TYPES[pol["policy_type"]]
        if random.random() < cfg["claim_freq"]:
            n_claims = np.random.choice([1, 2, 3], p=[0.75, 0.20, 0.05])
            for _ in range(n_claims):
                claim_date = random_date(pol["start_date"], END)
                amount = round(random.uniform(*cfg["claim_severity"]), 2)
                is_fraud_flag = random.random() < 0.035  # ~3.5% flagged for review
                rows.append(
                    {
                        "claim_id": f"CLM-{claim_id:06d}",
                        "policy_id": pol["policy_id"],
                        "claim_date": claim_date,
                        "claim_amount_eur": amount,
                        "claim_status": random.choices(
                            ["Paid", "Rejected", "Under Review"], weights=[0.72, 0.13, 0.15]
                        )[0],
                        "fraud_flag": is_fraud_flag,
                        "days_to_settle": (
                            random.randint(3, 90) if random.random() > 0.1 else None
                        ),
                    }
                )
                claim_id += 1
    return pd.DataFrame(rows)


if __name__ == "__main__":
    customers = gen_customers(N_CUSTOMERS)
    policies = gen_policies(customers, N_POLICIES)
    claims = gen_claims(policies)

    customers.to_csv("../data/raw/customers.csv", index=False)
    policies.to_csv("../data/raw/policies.csv", index=False)
    claims.to_csv("../data/raw/claims.csv", index=False)

    print(f"customers: {len(customers)} rows")
    print(f"policies:  {len(policies)} rows")
    print(f"claims:    {len(claims)} rows")
