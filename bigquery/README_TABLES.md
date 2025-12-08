# BigQuery Tables Overview

## Tables with Active Data Writes ✅

### 1. `events` - Raw Event Stream
- **Written by:** Cloudflare Worker (real-time)
- **Frequency:** Every event from website visitors
- **Source:** Tracking pixel
- **Size:** Growing continuously
- **Storage:** Partitioned by date, clustered by visitorId, sessionId, type

### 2. `sessions` - Aggregated Sessions
- **Written by:** BigQuery Scheduled Query (MERGE)
- **Frequency:** Every 5 minutes
- **Source:** Aggregated from `events` table
- **Purpose:** Roll up events into session-level metrics
- **Storage:** Partitioned by startTime date

### 3. `lead_profiles` - Visitor Behavior Profiles
- **Written by:** BigQuery Scheduled Query (MERGE)
- **Frequency:** Every 15 minutes
- **Source:** Aggregated from `sessions` + `events` + behavioral data
- **Purpose:** Intent scoring and engagement tracking
- **Storage:** Clustered by visitorId

### 4. `session_identity_map` - De-anonymization
- **Written by:** BigQuery Scheduled Query (INSERT)
- **Frequency:** Every 15 minutes
- **Source:** Matches anonymous sessions to known leads via email
- **Purpose:** Link pre-identification activity to known visitors
- **Storage:** Clustered by sessionId

### 5. `leads` - Your Lead Database
- **Written by:** External sources (n8n, CSV imports, etc.)
- **Modified by:** This repo adds `trackingId` column
- **Size:** 1,093,184 rows
- **Purpose:** Master lead database with enrichment data
- **Fields:**
  - `trackingId` - 8-char unique ID for tracking
  - `firstName`, `lastName` - Split from person_name
  - `person_name` - Full name
  - `email`, `phone`, `linkedin`
  - `company_name`, `company_website`, `company_linkedin`
  - `company_size`, `revenue`, `industry`, `company_description`
  - `job_title`, `seniority`, `department`

## Tables to Remove 🗑️

### `identity_map` - REDUNDANT
- **Status:** Duplicates data from `leads` table
- **Problem:** Contains incorrect data (firstName = full name)
- **Solution:** Use `leads` table directly via `trackingId`
- **Action:** Can be dropped after migration

### `email_clicks` - UNUSED
- **Status:** Schema exists but no writes
- **Problem:** Email clicks are tracked in `events` table as `type='email_click'`
- **Solution:** Use `events` table instead
- **Action:** Can be dropped (optional)

## Views (Read-Only) 📊

All views query existing tables for analytics:

1. **`high_intent_leads`** - Filters lead_profiles for hot leads
2. **`campaign_performance`** - Campaign metrics from lead_profiles
3. **`recent_sessions`** - Last 24h activity
4. **`intent_distribution`** - Score distribution
5. **`company_activity`** - Multi-visitor company detection
6. **`visitor_return_patterns`** - Return visit analysis
7. **`content_depth`** - Engagement quality metrics
8. **`multi_device_visitors`** - Device switching tracking
9. **`backtracking_visitors`** - Navigation pattern analysis

## Data Flow

```
Website Visitor
    ↓
Tracking Pixel (events)
    ↓
events table (real-time writes)
    ↓
sessions table (every 5 min) ← aggregation
    ↓
lead_profiles table (every 15 min) ← scoring
    ↓
Views (real-time reads) → Analytics/Dashboards

Parallel Flow:
leads table → KV Sync (hourly) → Cloudflare KV → Personalization
```

## Recommended Actions

### Immediate
1. ✅ Run `migration-split-person-name.sql` to fix firstName/lastName
2. ✅ Update KV sync to use `kv-sync-from-leads.sql`
3. ✅ Deploy updated Worker code (already fixed)

### Optional Cleanup
4. Drop `identity_map` table (after verifying KV sync works)
5. Drop `email_clicks` table (not being used)

### Verification
```sql
-- Check name split worked
SELECT firstName, lastName, person_name
FROM `n8n-revenueinstitute.outbound_sales.leads`
LIMIT 10;

-- Check KV sync output
SELECT trackingId, firstName, lastName, email, company_name
FROM `n8n-revenueinstitute.outbound_sales.leads`
WHERE trackingId IS NOT NULL
LIMIT 10;
```



