-- ====================================================================
-- CROSS-DOMAIN AGENT — Marketing + Sales + Ontology
-- ====================================================================
-- Builds:
--   1. ONTOLOGY_ANALYST semantic view over ONTOLOGY_TRIPLES (text-to-SQL
--      access to cross-domain relationships).
--   2. CROSS_DOMAIN_REVOPS_AGENT with 5 tools:
--        - sales_metrics      (SALES_PIPELINE_ANALYST)
--        - marketing_metrics  (MARKETING_PERFORMANCE_ANALYST)
--        - ontology_lookup    (ONTOLOGY_ANALYST — the bridge)
--        - search_deal_notes  (SALES_DEAL_SEARCH)
--        - search_campaigns   (MARKETING_CAMPAIGNS_SEARCH)
--
-- Prereqs: SETUP.sql and SALES_SETUP.sql must have run successfully.
-- ====================================================================

USE ROLE ACCOUNTADMIN;
GRANT CREATE AGENT ON SCHEMA SALES_PIPELINE_DB.AGENTS TO ROLE AGENT_EVAL_ROLE;

USE ROLE AGENT_EVAL_ROLE;
USE SCHEMA SALES_PIPELINE_DB.AGENTS;

-- ====================================================================
-- 1. ONTOLOGY semantic view
-- ====================================================================
CREATE OR REPLACE SEMANTIC VIEW ONTOLOGY_ANALYST
  TABLES (
    triples AS ONTOLOGY_TRIPLES PRIMARY KEY (triple_id)
  )
  DIMENSIONS (
    PUBLIC triples.subject AS subject,
    PUBLIC triples.predicate AS predicate,
    PUBLIC triples.object AS object,
    PUBLIC triples.subject_domain AS subject_domain,
    PUBLIC triples.object_domain AS object_domain
  )
  METRICS (
    PUBLIC triples.triple_count AS COUNT(triple_id),
    PUBLIC triples.avg_confidence AS AVG(confidence)
  )
  COMMENT = 'Knowledge-graph ontology: subject-predicate-object triples linking marketing campaigns and sales accounts/deals. Predicates: TARGETED_BY, INFLUENCED_BY, BELONGS_TO, MATCHES_SEGMENT, OWNS, USES_CHANNEL, TARGETS_SEGMENT, SOURCED_FROM. Use this to answer cross-domain questions like "which campaigns influenced deals at Technology accounts" or "which accounts were targeted by the LinkedIn B2B campaign".';

SHOW SEMANTIC VIEWS LIKE 'ONTOLOGY_ANALYST';

-- Quick check
SELECT predicate, triple_count
FROM SEMANTIC_VIEW(ONTOLOGY_ANALYST DIMENSIONS predicate METRICS triple_count);

-- ====================================================================
-- 2. CROSS_DOMAIN_REVOPS_AGENT
-- ====================================================================
CREATE OR REPLACE AGENT MARKETING_CAMPAIGNS_DB.AGENTS.CROSS_DOMAIN_REVOPS_AGENT
WITH PROFILE='{ "display_name": "Cross-Domain RevOps Agent" }'
    COMMENT=$$ Cross-domain agent connecting marketing campaigns and sales pipeline via knowledge-graph ontology. $$
FROM SPECIFICATION $$
{
  "models": {"orchestration": "auto"},
  "instructions": {
    "orchestration": "You are a RevOps analytics agent with visibility across MARKETING (campaigns, content, performance, feedback) and SALES (accounts, deals, activity, notes), connected by an ONTOLOGY layer of subject-predicate-object triples.\n\n## Tool routing\n\n1. Pure marketing metrics (revenue, ROI, CTR, conversions by campaign/channel) -> marketing_metrics.\n2. Pure sales metrics (deal counts, pipeline by stage, win rate, account size) -> sales_metrics.\n3. Cross-domain questions that need to JOIN marketing to sales (e.g. 'which campaigns influenced won deals?', 'which accounts were targeted by Campaign X?', 'industries reached by social campaigns') -> ontology_lookup FIRST to get the entity names, then call sales_metrics or marketing_metrics with those names as filters to get numbers.\n4. Qualitative deal context (call notes, competitive intel, next steps) -> search_deal_notes.\n5. Qualitative campaign context (copy, A/B test learnings, customer feedback) -> search_campaigns.\n\n## Cross-domain pattern\nWhen the user asks a question that spans both domains, use this pattern:\n  a) Use ontology_lookup with predicate filters (TARGETED_BY, INFLUENCED_BY, BELONGS_TO, MATCHES_SEGMENT, etc.) to identify the linked entities.\n  b) Use the entity names returned by ontology_lookup as filters in sales_metrics or marketing_metrics to compute numbers.\n  c) Optionally enrich with search_deal_notes or search_campaigns for qualitative color.\n\n## Predicate cheat-sheet\n- TARGETED_BY: account is in a campaign's audience.\n- INFLUENCED_BY: deal was influenced by campaign exposure.\n- BELONGS_TO: account belongs to industry.\n- MATCHES_SEGMENT: account matches an audience segment.\n- TARGETS_SEGMENT: campaign targets an audience segment.\n- USES_CHANNEL: campaign uses a marketing channel.\n- SOURCED_FROM: lead source linked to a campaign.\n- OWNS: person owns an account or campaign.\n\nNever hallucinate links. If the ontology has no triple connecting two entities, say so.",
    "response": "Lead with the answer. Show numbers with units. When you used the ontology to bridge domains, briefly say which predicate(s) you traversed so the user can audit the path. Cite specific campaign and account names.",
    "sample_questions": [
      {"question": "Which marketing campaigns influenced our largest closed-won deals?"},
      {"question": "What is the total pipeline value at accounts targeted by the LinkedIn B2B Lead Gen campaign?"},
      {"question": "Which industries are most represented in our open pipeline, and which campaigns reached them?"},
      {"question": "For deals at Technology accounts, what feedback themes appear in the campaigns that influenced them?"}
    ]
  },
  "tools": [
    {"tool_spec": {
      "type": "cortex_analyst_text_to_sql",
      "name": "sales_metrics",
      "description": "Quantitative sales data: accounts (industry, region, tier, annual_revenue), deals (stage, amount, owner, product_line, lead_source, won/lost), and weekly deal activity (emails, calls, meetings, win_probability, days_in_stage). Use for any sales numbers, pipeline analysis, win rates, deal-stage progression."
    }},
    {"tool_spec": {
      "type": "cortex_analyst_text_to_sql",
      "name": "marketing_metrics",
      "description": "Quantitative marketing data: campaigns (type, channel, budget, dates), daily performance (impressions, clicks, conversions, revenue, ROI, engagement). Use for campaign performance, channel comparison, ROI ranking, time-series marketing trends."
    }},
    {"tool_spec": {
      "type": "cortex_analyst_text_to_sql",
      "name": "ontology_lookup",
      "description": "Knowledge-graph triples connecting marketing and sales. Each row is (subject, predicate, object, subject_domain, object_domain, confidence). Filter by predicate to traverse a relationship: TARGETED_BY (account-campaign), INFLUENCED_BY (deal-campaign), BELONGS_TO (account-industry), MATCHES_SEGMENT (account-segment), TARGETS_SEGMENT (campaign-segment), USES_CHANNEL (campaign-channel), SOURCED_FROM (lead_source-campaign), OWNS (person-entity). Use this FIRST for any question that spans marketing and sales, then use the returned entity names as filters in sales_metrics or marketing_metrics."
    }},
    {"tool_spec": {
      "type": "cortex_search",
      "name": "search_deal_notes",
      "description": "Unstructured deal notes: call summaries, discovery notes, competitive intelligence, next steps. Use for qualitative deal context."
    }},
    {"tool_spec": {
      "type": "cortex_search",
      "name": "search_campaigns",
      "description": "Unstructured campaign content: descriptions, marketing copy, A/B test results, customer feedback. Use for qualitative campaign context."
    }}
  ],
  "tool_resources": {
    "sales_metrics": {
      "execution_environment": {"type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 299},
      "semantic_view": "SALES_PIPELINE_DB.AGENTS.SALES_PIPELINE_ANALYST"
    },
    "marketing_metrics": {
      "execution_environment": {"type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 299},
      "semantic_view": "MARKETING_CAMPAIGNS_DB.AGENTS.MARKETING_PERFORMANCE_ANALYST"
    },
    "ontology_lookup": {
      "execution_environment": {"type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 299},
      "semantic_view": "SALES_PIPELINE_DB.AGENTS.ONTOLOGY_ANALYST"
    },
    "search_deal_notes": {
      "execution_environment": {"type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 299},
      "search_service": "SALES_PIPELINE_DB.AGENTS.SALES_DEAL_SEARCH"
    },
    "search_campaigns": {
      "execution_environment": {"type": "warehouse", "warehouse": "COMPUTE_WH", "query_timeout": 299},
      "search_service": "MARKETING_CAMPAIGNS_DB.AGENTS.MARKETING_CAMPAIGNS_SEARCH"
    }
  }
}
$$;

DESCRIBE AGENT MARKETING_CAMPAIGNS_DB.AGENTS.CROSS_DOMAIN_REVOPS_AGENT;
