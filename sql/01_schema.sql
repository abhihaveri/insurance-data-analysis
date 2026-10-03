-- 01_schema.sql
-- Schema for the German insurance book-of-business dataset.
-- Designed for SQLite/PostgreSQL/SQL Server (minor type tweaks for MSSQL noted inline).

CREATE TABLE customers (
    customer_id        VARCHAR(10) PRIMARY KEY,
    age                INT NOT NULL,
    gender              CHAR(1),
    state               VARCHAR(40),
    city                VARCHAR(60),
    customer_since      DATE,
    credit_score_band   VARCHAR(20)
);

CREATE TABLE policies (
    policy_id           VARCHAR(10) PRIMARY KEY,
    customer_id         VARCHAR(10) REFERENCES customers(customer_id),
    policy_type         VARCHAR(30) NOT NULL,
    agent_id            VARCHAR(10),
    start_date          DATE NOT NULL,
    annual_premium_eur  DECIMAL(10, 2) NOT NULL,
    status              VARCHAR(20),
    region              VARCHAR(40)
);

CREATE TABLE claims (
    claim_id            VARCHAR(10) PRIMARY KEY,
    policy_id           VARCHAR(10) REFERENCES policies(policy_id),
    claim_date          DATE NOT NULL,
    claim_amount_eur    DECIMAL(10, 2) NOT NULL,
    claim_status        VARCHAR(20),
    fraud_flag          BOOLEAN,          -- MSSQL: use BIT instead of BOOLEAN
    days_to_settle      INT
);

CREATE INDEX idx_policies_customer ON policies(customer_id);
CREATE INDEX idx_claims_policy ON claims(policy_id);
