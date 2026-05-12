-- ====================================================================
-- SALES PIPELINE & KNOWLEDGE GRAPH ONTOLOGY - COMPLETE SETUP SCRIPT
-- ====================================================================
-- This script creates:
-- - Sales/CRM domain tables with sample data (accounts, deals, activity, notes)
-- - Semantic view for Cortex Analyst (SALES_PIPELINE_ANALYST)
-- - Cortex Search service for deal notes discovery
-- - Knowledge graph ontology tables (nodes, edges, triples) linking
--   Sales/CRM and Marketing Campaigns domains for cross-domain agent context
--
-- Prerequisites:
-- - Run SETUP.sql first (creates MARKETING_CAMPAIGNS_DB, AGENT_EVAL_ROLE, git integration)
-- - AGENT_EVAL_ROLE granted to your user
-- - COMPUTE_WH warehouse available
--
-- Estimated runtime: 3-5 minutes
-- ====================================================================

-- ====================================================================
-- SECTION 1: DATABASE AND SCHEMA CREATION
-- ====================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SALES_PIPELINE_DB;
CREATE OR REPLACE SCHEMA SALES_PIPELINE_DB.AGENTS;
USE SCHEMA SALES_PIPELINE_DB.AGENTS;

-- ====================================================================
-- SECTION 2: ROLE GRANTS FOR SALES_PIPELINE_DB
-- ====================================================================

-- Grant AGENT_EVAL_ROLE access to the new database
GRANT USAGE ON DATABASE SALES_PIPELINE_DB TO ROLE AGENT_EVAL_ROLE;
GRANT USAGE ON SCHEMA SALES_PIPELINE_DB.AGENTS TO ROLE AGENT_EVAL_ROLE;
GRANT CREATE TABLE ON SCHEMA SALES_PIPELINE_DB.AGENTS TO ROLE AGENT_EVAL_ROLE;
GRANT CREATE STAGE ON SCHEMA SALES_PIPELINE_DB.AGENTS TO ROLE AGENT_EVAL_ROLE;
GRANT CREATE FILE FORMAT ON SCHEMA SALES_PIPELINE_DB.AGENTS TO ROLE AGENT_EVAL_ROLE;
GRANT CREATE SEMANTIC VIEW ON SCHEMA SALES_PIPELINE_DB.AGENTS TO ROLE AGENT_EVAL_ROLE;
GRANT CREATE CORTEX SEARCH SERVICE ON SCHEMA SALES_PIPELINE_DB.AGENTS TO ROLE AGENT_EVAL_ROLE;

-- ====================================================================
-- SECTION 3: SWITCH TO AGENT_EVAL_ROLE
-- ====================================================================

USE ROLE AGENT_EVAL_ROLE;
USE SCHEMA SALES_PIPELINE_DB.AGENTS;

-- Reuse the same Workspace imported in SETUP.sql:
--   snow://workspace/USER$.PUBLIC."Ontology_HOL_Squadron"/versions/live/
-- If you haven't imported it yet, see SETUP.sql Section 3 for instructions.

-- Verify new data files are visible
LS 'snow://workspace/USER$.PUBLIC."Ontology_HOL_Squadron"/versions/live/data/';

-- ====================================================================
-- SECTION 4: CREATE FILE FORMAT
-- ====================================================================

CREATE OR REPLACE FILE FORMAT SALES_CSV_FORMAT
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  COMPRESSION = 'AUTO';

-- ====================================================================
-- SECTION 5: CREATE AND POPULATE SALES/CRM TABLES
-- ====================================================================

-- ============================================================================
-- ACCOUNTS
-- ============================================================================
CREATE OR REPLACE TABLE ACCOUNTS (
    account_id INT,
    account_name VARCHAR(200) NOT NULL,
    industry VARCHAR(100),
    company_size VARCHAR(50),
    annual_revenue DECIMAL(15,2),
    region VARCHAR(50),
    account_owner VARCHAR(100),
    account_tier VARCHAR(50),
    created_date DATE
);

INSERT INTO ACCOUNTS (account_id, account_name, industry, company_size, annual_revenue, region, account_owner, account_tier, created_date)
SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9
FROM 'snow://workspace/USER$.PUBLIC."Ontology_HOL_Squadron"/versions/live/data/ACCOUNTS.csv' (FILE_FORMAT=>SALES_CSV_FORMAT);

-- ============================================================================
-- DEALS
-- ============================================================================
CREATE OR REPLACE TABLE DEALS (
    deal_id INT,
    account_id INT,
    deal_name VARCHAR(300) NOT NULL,
    deal_stage VARCHAR(50),
    deal_amount DECIMAL(12,2),
    close_date DATE,
    created_date DATE,
    deal_owner VARCHAR(100),
    product_line VARCHAR(100),
    lead_source VARCHAR(50),
    is_won INT,
    is_closed INT
);

INSERT INTO DEALS (deal_id, account_id, deal_name, deal_stage, deal_amount, close_date, created_date, deal_owner, product_line, lead_source, is_won, is_closed)
SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12
FROM 'snow://workspace/USER$.PUBLIC."Ontology_HOL_Squadron"/versions/live/data/DEALS.csv' (FILE_FORMAT=>SALES_CSV_FORMAT);

-- ============================================================================
-- DEAL_ACTIVITY
-- ============================================================================
CREATE OR REPLACE TABLE DEAL_ACTIVITY (
    activity_id INT,
    deal_id INT,
    activity_date DATE,
    emails_sent INT,
    calls_made INT,
    meetings_held INT,
    stage_change VARCHAR(50),
    deal_amount_change DECIMAL(12,2),
    win_probability DECIMAL(5,1),
    days_in_stage INT
);

INSERT INTO DEAL_ACTIVITY (activity_id, deal_id, activity_date, emails_sent, calls_made, meetings_held, stage_change, deal_amount_change, win_probability, days_in_stage)
SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10
FROM 'snow://workspace/USER$.PUBLIC."Ontology_HOL_Squadron"/versions/live/data/DEAL_ACTIVITY.csv' (FILE_FORMAT=>SALES_CSV_FORMAT);

-- ============================================================================
-- DEAL_NOTES
-- ============================================================================
CREATE OR REPLACE TABLE DEAL_NOTES (
    note_id INT,
    deal_id INT,
    note_date DATE,
    note_type VARCHAR(100),
    author VARCHAR(100),
    note_content TEXT,
    next_steps TEXT,
    competitive_intel TEXT
);

INSERT INTO DEAL_NOTES (note_id, deal_id, note_date, note_type, author, note_content, next_steps, competitive_intel)
SELECT $1,$2,$3,$4,$5,$6,$7,$8
FROM 'snow://workspace/USER$.PUBLIC."Ontology_HOL_Squadron"/versions/live/data/DEAL_NOTES.csv' (FILE_FORMAT=>SALES_CSV_FORMAT);

-- ====================================================================
-- SECTION 6: CREATE AND POPULATE ONTOLOGY TABLES
-- ====================================================================

-- ============================================================================
-- ONTOLOGY_NODES
-- ============================================================================
CREATE OR REPLACE TABLE ONTOLOGY_NODES (
    node_id INT,
    node_type VARCHAR(50),
    node_name VARCHAR(300),
    domain VARCHAR(50),
    source_table VARCHAR(100),
    source_id INT,
    properties VARIANT
);

INSERT INTO ONTOLOGY_NODES (node_id, node_type, node_name, domain, source_table, source_id, properties)
SELECT $1,$2,$3,$4,$5,$6, TRY_PARSE_JSON($7)
FROM 'snow://workspace/USER$.PUBLIC."Ontology_HOL_Squadron"/versions/live/data/ONTOLOGY_NODES.csv' (FILE_FORMAT=>SALES_CSV_FORMAT);

-- ============================================================================
-- ONTOLOGY_EDGES
-- ============================================================================
CREATE OR REPLACE TABLE ONTOLOGY_EDGES (
    edge_id INT,
    source_node_id INT,
    target_node_id INT,
    relationship_type VARCHAR(50),
    weight DECIMAL(4,2),
    properties VARIANT
);

INSERT INTO ONTOLOGY_EDGES (edge_id, source_node_id, target_node_id, relationship_type, weight, properties)
SELECT $1,$2,$3,$4,$5, TRY_PARSE_JSON($6)
FROM 'snow://workspace/USER$.PUBLIC."Ontology_HOL_Squadron"/versions/live/data/ONTOLOGY_EDGES.csv' (FILE_FORMAT=>SALES_CSV_FORMAT);

-- ============================================================================
-- ONTOLOGY_TRIPLES
-- ============================================================================
CREATE OR REPLACE TABLE ONTOLOGY_TRIPLES (
    triple_id INT,
    subject VARCHAR(300),
    predicate VARCHAR(50),
    object VARCHAR(300),
    subject_domain VARCHAR(50),
    object_domain VARCHAR(50),
    confidence DECIMAL(4,2)
);

INSERT INTO ONTOLOGY_TRIPLES (triple_id, subject, predicate, object, subject_domain, object_domain, confidence)
SELECT $1,$2,$3,$4,$5,$6,$7
FROM 'snow://workspace/USER$.PUBLIC."Ontology_HOL_Squadron"/versions/live/data/ONTOLOGY_TRIPLES.csv' (FILE_FORMAT=>SALES_CSV_FORMAT);

-- ====================================================================
-- SECTION 7: VALIDATE DATA
-- ====================================================================

SELECT 'ACCOUNTS' AS table_name, COUNT(*) AS row_count FROM ACCOUNTS
UNION ALL
SELECT 'DEALS', COUNT(*) FROM DEALS
UNION ALL
SELECT 'DEAL_ACTIVITY', COUNT(*) FROM DEAL_ACTIVITY
UNION ALL
SELECT 'DEAL_NOTES', COUNT(*) FROM DEAL_NOTES
UNION ALL
SELECT 'ONTOLOGY_NODES', COUNT(*) FROM ONTOLOGY_NODES
UNION ALL
SELECT 'ONTOLOGY_EDGES', COUNT(*) FROM ONTOLOGY_EDGES
UNION ALL
SELECT 'ONTOLOGY_TRIPLES', COUNT(*) FROM ONTOLOGY_TRIPLES;

-- ====================================================================
-- SECTION 8: CREATE SEMANTIC VIEW
-- ====================================================================

CREATE OR REPLACE SEMANTIC VIEW SALES_PIPELINE_ANALYST
  TABLES (
    accounts AS ACCOUNTS PRIMARY KEY (account_id),
    deals AS DEALS PRIMARY KEY (deal_id),
    activity AS DEAL_ACTIVITY PRIMARY KEY (activity_id)
  )
  RELATIONSHIPS (
    deals(account_id) REFERENCES accounts(account_id),
    activity(deal_id) REFERENCES deals(deal_id)
  )
  DIMENSIONS (
    -- Account dimensions
    PUBLIC accounts.account_id AS account_id,
    PUBLIC accounts.account_name AS account_name,
    PUBLIC accounts.industry AS industry,
    PUBLIC accounts.company_size AS company_size,
    PUBLIC accounts.region AS region,
    PUBLIC accounts.account_owner AS account_owner,
    PUBLIC accounts.account_tier AS account_tier,
    -- Deal dimensions
    PUBLIC deals.deal_id AS deal_id,
    PUBLIC deals.deal_name AS deal_name,
    PUBLIC deals.deal_stage AS deal_stage,
    PUBLIC deals.deal_owner AS deal_owner,
    PUBLIC deals.product_line AS product_line,
    PUBLIC deals.lead_source AS lead_source,
    PUBLIC deals.is_won AS is_won,
    PUBLIC deals.is_closed AS is_closed,
    PUBLIC deals.close_date AS close_date,
    PUBLIC deals.deal_created_date AS created_date,
    -- Activity dimensions
    PUBLIC activity.activity_date AS activity_date,
    PUBLIC activity.stage_change AS stage_change
  )
  METRICS (
    -- Deal metrics
    PUBLIC deals.total_deal_amount AS SUM(deal_amount),
    PUBLIC deals.deal_count AS COUNT(deal_id),
    PUBLIC deals.avg_deal_amount AS AVG(deal_amount),
    -- Activity metrics
    PUBLIC activity.total_emails_sent AS SUM(emails_sent),
    PUBLIC activity.total_calls_made AS SUM(calls_made),
    PUBLIC activity.total_meetings_held AS SUM(meetings_held),
    PUBLIC activity.avg_win_probability AS AVG(win_probability),
    PUBLIC activity.avg_days_in_stage AS AVG(days_in_stage),
    PUBLIC activity.total_deal_amount_change AS SUM(deal_amount_change),
    -- Account metrics
    PUBLIC accounts.total_annual_revenue AS SUM(annual_revenue),
    PUBLIC accounts.account_count AS COUNT(account_id)
  )
  COMMENT = 'Semantic view for analyzing sales pipeline performance, deal progression, and account health';

-- Verify semantic view was created
SHOW SEMANTIC VIEWS LIKE 'SALES_PIPELINE_ANALYST';

-- ====================================================================
-- SECTION 9: CREATE CORTEX SEARCH SERVICE FOR DEAL NOTES
-- ====================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE SALES_DEAL_SEARCH
  ON combined_text
  ATTRIBUTES deal_name, note_type, author, account_name, industry
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 hour'
  AS (
    SELECT
      n.note_id,
      d.deal_name,
      a.account_name,
      a.industry,
      n.note_type,
      n.author,
      CONCAT(
        'Deal: ', d.deal_name, '. ',
        'Account: ', a.account_name, ' (', a.industry, '). ',
        'Note Type: ', n.note_type, '. ',
        'Content: ', n.note_content, '. ',
        'Next Steps: ', COALESCE(n.next_steps, 'N/A'), '. ',
        'Competitive Intel: ', COALESCE(n.competitive_intel, 'N/A')
      ) AS combined_text
    FROM DEAL_NOTES n
    JOIN DEALS d ON n.deal_id = d.deal_id
    JOIN ACCOUNTS a ON d.account_id = a.account_id
  );

-- Verify search service was created
SHOW CORTEX SEARCH SERVICES LIKE 'SALES_DEAL_SEARCH';

-- ====================================================================
-- SECTION 10: TEST SALES SEMANTIC VIEW
-- ====================================================================

-- Test semantic view - Pipeline by stage
SELECT
    deal_stage,
    deal_count,
    total_deal_amount,
    avg_deal_amount
FROM SEMANTIC_VIEW(
    SALES_PIPELINE_ANALYST
    DIMENSIONS deal_stage
    METRICS deal_count, total_deal_amount, avg_deal_amount
);

-- Test semantic view - Performance by industry
SELECT
    industry,
    account_count,
    deal_count,
    total_deal_amount
FROM SEMANTIC_VIEW(
    SALES_PIPELINE_ANALYST
    DIMENSIONS industry
    METRICS account_count, deal_count, total_deal_amount
);

-- Test search service
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SALES_DEAL_SEARCH',
        '{"query": "competitive pricing concerns", "columns": ["deal_name", "account_name", "combined_text"], "limit": 3}'
    )
) AS search_results;

-- ====================================================================
-- SECTION 11: TEST ONTOLOGY QUERIES (CROSS-DOMAIN)
-- ====================================================================

-- Find all marketing campaigns that targeted a specific sales account
SELECT t.subject, t.predicate, t.object, t.confidence
FROM ONTOLOGY_TRIPLES t
WHERE t.subject = 'CloudSphere Technologies'
  AND t.predicate = 'TARGETED_BY'
ORDER BY t.confidence DESC;

-- Find all deals influenced by a specific campaign
SELECT t.subject, t.predicate, t.object, t.confidence
FROM ONTOLOGY_TRIPLES t
WHERE t.object = 'LinkedIn B2B Lead Gen'
  AND t.predicate IN ('TARGETED_BY', 'INFLUENCED_BY')
ORDER BY t.confidence DESC;

-- Cross-domain: Which campaigns influenced deals at Technology accounts?
SELECT
    t_deal.subject AS deal_name,
    t_deal.object AS campaign_name,
    t_deal.confidence AS influence_confidence,
    t_acct.object AS industry
FROM ONTOLOGY_TRIPLES t_deal
JOIN ONTOLOGY_TRIPLES t_acct
  ON SPLIT_PART(t_deal.subject, ' - ', 1) = SPLIT_PART(t_acct.subject, ' ', 1)
WHERE t_deal.predicate = 'INFLUENCED_BY'
  AND t_acct.predicate = 'BELONGS_TO'
  AND t_acct.object = 'Technology'
  AND t_deal.subject_domain = 'sales'
  AND t_deal.object_domain = 'marketing'
LIMIT 10;

-- Graph traversal: Accounts → Segment matches → Campaign targeting
SELECT
    n_acct.node_name AS account_name,
    e_match.relationship_type,
    n_seg.node_name AS segment_name,
    e_target.relationship_type AS campaign_targets,
    n_camp.node_name AS campaign_name
FROM ONTOLOGY_NODES n_acct
JOIN ONTOLOGY_EDGES e_match ON n_acct.node_id = e_match.source_node_id
JOIN ONTOLOGY_NODES n_seg ON e_match.target_node_id = n_seg.node_id
JOIN ONTOLOGY_EDGES e_target ON n_seg.node_id = e_target.target_node_id
JOIN ONTOLOGY_NODES n_camp ON e_target.source_node_id = n_camp.node_id
WHERE n_acct.node_type = 'account'
  AND e_match.relationship_type = 'MATCHES_SEGMENT'
  AND e_target.relationship_type = 'TARGETS_SEGMENT'
  AND n_camp.node_type = 'campaign'
ORDER BY n_acct.node_name, n_camp.node_name
LIMIT 20;

-- ====================================================================
-- SECTION 12: CONCLUSION
-- ====================================================================

SELECT
$$
=====================================================
SALES PIPELINE & KNOWLEDGE GRAPH ONTOLOGY - SETUP COMPLETE
=====================================================

Database created: SALES_PIPELINE_DB

Sales/CRM Tables (Bronze Layer):
   - ACCOUNTS (30 records)
   - DEALS (80 records)
   - DEAL_ACTIVITY (~1,323 records)
   - DEAL_NOTES (110 records)

Knowledge Graph Ontology Tables:
   - ONTOLOGY_NODES (90 nodes across both domains)
   - ONTOLOGY_EDGES (136 directed relationships)
   - ONTOLOGY_TRIPLES (160 SPO triples for cross-domain queries)

Silver Layer:
   - Semantic View: SALES_PIPELINE_ANALYST
   - Cortex Search: SALES_DEAL_SEARCH

Cross-Domain Relationships:
   - TARGETED_BY: Accounts targeted by marketing campaigns
   - INFLUENCED_BY: Deals influenced by campaign exposure
   - MATCHES_SEGMENT: Accounts matching campaign audience segments
   - SOURCED_FROM: Lead sources linked to campaign channels
   - BELONGS_TO: Accounts classified by industry
   - OWNS: People (sales reps / marketing managers) owning entities

Query the ontology:
   SELECT * FROM ONTOLOGY_TRIPLES WHERE subject = 'CloudSphere Technologies';
   SELECT * FROM ONTOLOGY_TRIPLES WHERE predicate = 'INFLUENCED_BY';

$$ AS setup_status;
