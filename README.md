# Cortex Agent Evaluations — Extended

A multi-domain dataset and knowledge graph ontology for building, testing, and evaluating Snowflake Cortex Agents. Extends the [original Snowflake quickstart](https://github.com/Snowflake-Labs/sfguide-getting-started-with-cortex-agent-evaluations) with a Sales/CRM domain and cross-domain ontology layer.

## Overview

This repo provides two complete analytical domains connected by a knowledge graph, designed for hands-on work with Cortex Agents, Cortex Analyst (semantic views), Cortex Search, and Cortex Agent Evaluations.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        KNOWLEDGE GRAPH                              │
│              ONTOLOGY_NODES  ·  ONTOLOGY_EDGES  ·  ONTOLOGY_TRIPLES │
│         (90 nodes)       (136 edges)         (160 triples)          │
│                                                                     │
│    Links campaigns ↔ accounts ↔ deals ↔ people ↔ segments          │
│    via TARGETED_BY, INFLUENCED_BY, MATCHES_SEGMENT, OWNS, ...      │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
┌───────────▼───────────┐   ┌─────────────▼─────────────┐
│  MARKETING CAMPAIGNS  │   │      SALES / CRM          │
│  (SETUP.sql)          │   │   (SALES_SETUP.sql)       │
│                       │   │                           │
│  Bronze:              │   │  Bronze:                  │
│   · CAMPAIGNS (25)    │   │   · ACCOUNTS (30)         │
│   · CAMPAIGN_PERF     │   │   · DEALS (80)            │
│   · CAMPAIGN_CONTENT  │   │   · DEAL_ACTIVITY (1,323) │
│   · CAMPAIGN_FEEDBACK │   │   · DEAL_NOTES (110)      │
│                       │   │                           │
│  Silver:              │   │  Silver:                  │
│   · MARKETING_        │   │   · SALES_PIPELINE_       │
│     PERFORMANCE_      │   │     ANALYST               │
│     ANALYST           │   │     (semantic view)       │
│     (semantic view)   │   │                           │
│   · MARKETING_        │   │   · SALES_DEAL_SEARCH     │
│     CAMPAIGNS_SEARCH  │   │     (Cortex Search)       │
│     (Cortex Search)   │   │                           │
└───────────────────────┘   └───────────────────────────┘
```

### What You Can Build

- **Single-domain agents** — A Cortex Agent backed by one semantic view + one search service for either marketing or sales analytics
- **Multi-domain agents** — An agent with tools spanning both domains, using the ontology for cross-domain reasoning
- **Evaluation pipelines** — Eval datasets and configs for measuring agent accuracy with TruLens-based metrics
- **Knowledge graph queries** — SPO triple queries like "Which campaigns influenced deals at Technology companies?"

## Repository Structure

```
├── SETUP.sql                       # Marketing domain setup (run first)
├── SALES_SETUP.sql                 # Sales domain + ontology setup (run second)
├── agent_evalset_generator.py      # Evaluation dataset generator
├── marketing_campaign_eval_config.yaml  # Eval config for marketing agent
├── requirements.txt                # Python dependencies
├── data/
│   ├── CAMPAIGNS.csv               # 25 marketing campaigns
│   ├── CAMPAIGN_PERFORMANCE.csv    # Campaign metrics
│   ├── CAMPAIGN_CONTENT.csv        # Campaign content/creative
│   ├── CAMPAIGN_FEEDBACK.csv       # Customer feedback on campaigns
│   ├── EVALS_TABLE.csv             # Pre-built evaluation dataset
│   ├── ACCOUNTS.csv                # 30 company accounts (6 industries)
│   ├── DEALS.csv                   # 80 sales deals (55 won, 13 lost, 12 open)
│   ├── DEAL_ACTIVITY.csv           # 1,323 weekly activity records per deal
│   ├── DEAL_NOTES.csv              # 110 rep notes with competitive intel
│   ├── ONTOLOGY_NODES.csv          # 90 entity nodes across both domains
│   ├── ONTOLOGY_EDGES.csv          # 136 directed relationship edges
│   └── ONTOLOGY_TRIPLES.csv        # 160 subject-predicate-object triples
└── data_gen.ipynb                  # Notebook used to generate sales data
```

## Prerequisites

- **Snowflake account** with Cortex Agent Evaluations enabled
- **ACCOUNTADMIN** role access (for initial setup — creates roles, databases, integrations)
- **Warehouse**: `COMPUTE_WH` (SMALL size is sufficient)
- Access to agent observability events

## Installation

### Step 0: Import this repo as a Snowflake Workspace

The setup scripts load CSV data from a Snowflake Workspace rather than via a Git API integration. This avoids needing `CREATE API INTEGRATION` privileges (which many HOL/trial accounts restrict) and requires no credentials since the repo is public.

In Snowsight:

1. Go to **Projects → Workspaces**
2. Click **From Git Repository**
3. Repository URL: `https://github.com/SquadronData/cortex-agent-eval-extended.git`
4. Workspace name: **`Ontology_HOL_Squadron`** (the name must match — the SQL scripts reference this path)
5. Click **Create**

The setup scripts reference files at `snow://workspace/USER$.PUBLIC."Ontology_HOL_Squadron"/versions/live/...`. If you use a different workspace name, find-and-replace that path in `SETUP.sql` and `SALES_SETUP.sql` before running.

### Step 1: Run the Marketing Domain Setup

Open a Snowflake worksheet and execute `SETUP.sql`. This creates:

- `MARKETING_CAMPAIGNS_DB.AGENTS` schema
- `AGENT_EVAL_ROLE` with all necessary grants
- Marketing campaign tables loaded from CSV (via the Workspace from Step 0)
- `MARKETING_PERFORMANCE_ANALYST` semantic view
- `MARKETING_CAMPAIGNS_SEARCH` Cortex Search service
- A Cortex Agent and evaluation dataset

```sql
-- Open SETUP.sql in a Snowflake worksheet and run all sections in order.
-- Estimated runtime: 3-5 minutes.
```

### Step 2: Run the Sales Domain + Ontology Setup

After SETUP.sql completes, execute `SALES_SETUP.sql`. This creates:

- `SALES_PIPELINE_DB.AGENTS` schema
- Sales/CRM tables (accounts, deals, activity, notes)
- Knowledge graph ontology tables (nodes, edges, triples)
- `SALES_PIPELINE_ANALYST` semantic view
- `SALES_DEAL_SEARCH` Cortex Search service

```sql
-- Open SALES_SETUP.sql in a Snowflake worksheet and run all sections in order.
-- Requires SETUP.sql to have been run first (reuses the AGENT_EVAL_ROLE and Workspace).
-- Estimated runtime: 3-5 minutes.
```

### Step 3: Verify

After both scripts complete, the validation query in Section 7 of `SALES_SETUP.sql` should return:

| TABLE_NAME | ROW_COUNT |
|---|---|
| ACCOUNTS | 30 |
| DEALS | 80 |
| DEAL_ACTIVITY | 1,323 |
| DEAL_NOTES | 110 |
| ONTOLOGY_NODES | 90 |
| ONTOLOGY_EDGES | 136 |
| ONTOLOGY_TRIPLES | 160 |

## Usage

### Querying the Semantic Views

The semantic views are designed for use with Cortex Analyst (text-to-SQL). You can also query them directly:

```sql
-- Sales pipeline by stage
SELECT deal_stage, deal_count, total_deal_amount, avg_deal_amount
FROM SEMANTIC_VIEW(
    SALES_PIPELINE_DB.AGENTS.SALES_PIPELINE_ANALYST
    DIMENSIONS deal_stage
    METRICS deal_count, total_deal_amount, avg_deal_amount
);

-- Marketing performance by channel
SELECT channel, total_revenue, avg_engagement_rate
FROM SEMANTIC_VIEW(
    MARKETING_CAMPAIGNS_DB.AGENTS.MARKETING_PERFORMANCE_ANALYST
    DIMENSIONS channel
    METRICS total_revenue, avg_engagement_rate
);
```

### Querying the Knowledge Graph

The ontology triples table is the simplest way to explore cross-domain relationships:

```sql
-- Which marketing campaigns targeted a specific sales account?
SELECT subject, predicate, object, confidence
FROM SALES_PIPELINE_DB.AGENTS.ONTOLOGY_TRIPLES
WHERE subject = 'CloudSphere Technologies'
  AND predicate = 'TARGETED_BY';

-- Which deals were influenced by a specific campaign?
SELECT subject, predicate, object, confidence
FROM SALES_PIPELINE_DB.AGENTS.ONTOLOGY_TRIPLES
WHERE object = 'LinkedIn B2B Lead Gen'
  AND predicate = 'INFLUENCED_BY';

-- Full graph traversal: Account → Segment → Campaign
SELECT
    n_acct.node_name AS account,
    n_seg.node_name AS segment,
    n_camp.node_name AS campaign
FROM SALES_PIPELINE_DB.AGENTS.ONTOLOGY_NODES n_acct
JOIN SALES_PIPELINE_DB.AGENTS.ONTOLOGY_EDGES e1 ON n_acct.node_id = e1.source_node_id
JOIN SALES_PIPELINE_DB.AGENTS.ONTOLOGY_NODES n_seg ON e1.target_node_id = n_seg.node_id
JOIN SALES_PIPELINE_DB.AGENTS.ONTOLOGY_EDGES e2 ON n_seg.node_id = e2.target_node_id
JOIN SALES_PIPELINE_DB.AGENTS.ONTOLOGY_NODES n_camp ON e2.source_node_id = n_camp.node_id
WHERE n_acct.node_type = 'account'
  AND e1.relationship_type = 'MATCHES_SEGMENT'
  AND e2.relationship_type = 'TARGETS_SEGMENT';
```

### Searching Deal Notes

```sql
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SALES_PIPELINE_DB.AGENTS.SALES_DEAL_SEARCH',
        '{"query": "competitive pricing concerns", "columns": ["deal_name", "account_name", "combined_text"], "limit": 3}'
    )
) AS results;
```

### Knowledge Graph Relationship Types

| Relationship | From | To | Count | Description |
|---|---|---|---|---|
| TARGETED_BY | Account | Campaign | 30 | Campaign audience matched to account profile |
| INFLUENCED_BY | Deal | Campaign | 24 | Deal potentially sourced from campaign exposure |
| BELONGS_TO | Account | Industry | 30 | Industry classification |
| MATCHES_SEGMENT | Account | Audience Segment | 22 | Account fits campaign audience criteria |
| OWNS | Person | Account/Campaign | 17 | Sales rep or marketing manager ownership |
| USES_CHANNEL | Campaign | Channel | 25 | Marketing channel used |
| TARGETS_SEGMENT | Campaign | Audience Segment | 7 | Campaign audience targeting |
| SOURCED_FROM | Lead Source | Campaign | 5 | Lead generation channel linkage |

## Data Model

### Sales/CRM Domain

- **ACCOUNTS** — 30 companies across Technology, Healthcare, Financial Services, Manufacturing, Retail, and Education. Three tiers (Strategic, Growth, Develop) and five regions.
- **DEALS** — 80 opportunities with realistic stage progression (Prospecting → Discovery → Proposal → Negotiation → Closed Won/Lost). Four product lines: Platform, Analytics, Integration, AI Services.
- **DEAL_ACTIVITY** — Weekly time-series data per deal: emails sent, calls made, meetings held, stage changes, win probability curves, and days in stage.
- **DEAL_NOTES** — Rep call notes with discovery summaries, competitive intelligence (industry-specific competitors), and next steps. Designed for Cortex Search.

### Marketing Domain

- **CAMPAIGNS** — 25 campaigns across Email, Social Media, Content Marketing, and Paid Advertising channels.
- **CAMPAIGN_PERFORMANCE** — Impressions, clicks, conversions, revenue, and engagement metrics.
- **CAMPAIGN_CONTENT** — Creative assets and messaging.
- **CAMPAIGN_FEEDBACK** — Customer responses and sentiment.

### Ontology Layer

- **ONTOLOGY_NODES** — Unified entity catalog with 8 node types spanning both domains. Each node carries a VARIANT `properties` column with type-specific metadata.
- **ONTOLOGY_EDGES** — Directed, weighted relationships between nodes. The `weight` column (0.0-1.0) indicates relationship strength.
- **ONTOLOGY_TRIPLES** — Denormalized subject-predicate-object format for simple cross-domain queries without joins. Includes `subject_domain` and `object_domain` columns to identify which domain each entity belongs to.

## Dependencies

### Snowflake Features Used

- Cortex Agents
- Cortex Analyst (Semantic Views)
- Cortex Search Services
- Cortex Agent Evaluations
- Snowflake Workspaces (for loading CSVs from this repo)
- VARIANT columns (for ontology node/edge properties)

### Python (optional, for eval dataset generation)

```
streamlit>=1.28.0
pandas>=1.5.0
snowflake-connector-python>=3.0.0
snowflake-snowpark-python>=1.31.0
python-dotenv>=0.19.0
```

Install with:
```bash
pip install -r requirements.txt
```

## Contributing

1. Create a branch from `main`
2. Make your changes
3. Submit a pull request for review
4. PRs must be reviewed before merging into `main`

See the [Squadron GitHub guidelines](https://github.com/SquadronData/.github-private) for full contribution policies.

## Credits

Based on the [Snowflake Cortex Agent Evaluations Quickstart](https://github.com/Snowflake-Labs/sfguide-getting-started-with-cortex-agent-evaluations) by Snowflake. Extended with Sales/CRM domain, knowledge graph ontology, and cross-domain agent context by Squadron Data.

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
