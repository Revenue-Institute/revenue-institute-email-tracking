# Campaign Setup Guide

## Quick Start: 3 Steps

### Step 1: Create Tables (One-Time Setup)

Run this in BigQuery console:

```bash
bq query --use_legacy_sql=false < bigquery/schema-campaigns.sql
```

This creates:
- `campaigns` table (campaign metadata)
- `campaign_members` table (who's in which campaign)
- 3 views for reporting

---

### Step 2: Assign Leads to Campaign

**Method A: Direct SQL (Simplest)**

1. Open `bigquery/assign-leads-to-campaign.sql`
2. Edit lines 20-25 (campaign details):
   ```sql
   VALUES (
     'q1-outreach-2025',              -- YOUR CAMPAIGN ID
     'Q1 Outreach Campaign 2025',     -- YOUR CAMPAIGN NAME
     'Targeting VPs in SaaS',         -- DESCRIPTION
     5,                               -- NUMBER OF EMAILS IN SEQUENCE
   ```
3. Edit lines 53-58 (lead filters):
   ```sql
   WHERE l.trackingId IS NOT NULL
     AND l.job_title LIKE '%VP%'           -- YOUR FILTER
     AND l.industry = 'SaaS'               -- YOUR FILTER
     AND l.company_size IN ('51-200')      -- YOUR FILTER
   ```
4. Run it:
   ```bash
   bq query --use_legacy_sql=false < bigquery/assign-leads-to-campaign.sql
   ```

**Method B: Via N8N (Automated)**

See `n8n/CAMPAIGN_ASSIGNMENT_N8N.md` for full setup.

---

### Step 3: Export for Email Tool

Run this query to get CSV for Smartlead/Instantly:

```sql
SELECT 
  l.email,
  l.firstName,
  l.lastName,
  l.company_name as company,
  l.job_title as jobTitle,
  CONCAT('https://yourdomain.com?v=', l.trackingId) as trackingUrl
FROM `outbound_sales.campaign_members` cm
INNER JOIN `outbound_sales.leads` l ON cm.trackingId = l.trackingId
WHERE cm.campaignId = 'q1-outreach-2025'
  AND cm.status = 'active';
```

Import CSV to your email tool, use `trackingUrl` in email body.

---

## How It Works

```
1. Create campaign
   ↓
   INSERT INTO campaigns (campaignId, campaignName, ...)
   
2. Assign leads to campaign
   ↓
   INSERT INTO campaign_members (trackingId, campaignId, ...)
   
3. Send emails with tracking URLs
   ↓
   https://yourdomain.com?v={trackingId}
   
4. Track everything automatically
   ↓
   - Email events tracked in events table
   - Website visits tracked with visitorId = trackingId
   - Campaign performance auto-calculated
```

---

## Multiple Campaigns Per Lead (It Just Works)

Same person can be in multiple campaigns:

```sql
-- John is in 3 campaigns
SELECT * FROM campaign_members WHERE trackingId = 'abc123';

Results:
trackingId | campaignId        | campaignName          | status
-----------|-------------------|-----------------------|--------
abc123     | q1-outreach       | Q1 Outreach          | active
abc123     | webinar-followup  | Webinar Follow-up    | completed
abc123     | pricing-nurture   | Pricing Nurture      | active
```

Each campaign tracks separately:
- Emails sent/opened/clicked per campaign
- First touch per campaign
- Status per campaign

---

## Common Workflows

### Workflow 1: Industry-Specific Campaign

```sql
-- Campaign for SaaS VPs
INSERT INTO campaigns VALUES ('saas-vp-2025', 'SaaS VP Outreach', ...);

INSERT INTO campaign_members (...)
SELECT l.trackingId, 'saas-vp-2025', ...
FROM leads l
WHERE l.industry = 'SaaS' 
  AND l.seniority = 'VP';
```

### Workflow 2: Re-engagement Campaign

```sql
-- Target leads who visited but didn't convert
INSERT INTO campaign_members (...)
SELECT l.trackingId, 're-engage-2025', ...
FROM leads l
INNER JOIN lead_profiles lp ON l.trackingId = lp.visitorId
WHERE lp.totalSessions >= 2
  AND lp.formSubmissions = 0
  AND NOT EXISTS (
    SELECT 1 FROM campaign_members 
    WHERE trackingId = l.trackingId
  );
```

### Workflow 3: A/B Test (Two Campaigns, Different Messaging)

```sql
-- Campaign A: Direct pitch
INSERT INTO campaigns VALUES ('direct-pitch-a', 'Direct Pitch (Variant A)', ...);
INSERT INTO campaign_members (...) SELECT ... LIMIT 5000;

-- Campaign B: Educational approach
INSERT INTO campaigns VALUES ('edu-approach-b', 'Educational (Variant B)', ...);
INSERT INTO campaign_members (...) SELECT ... OFFSET 5000 LIMIT 5000;
```

Compare performance:
```sql
SELECT * FROM v_campaign_performance 
WHERE campaignId IN ('direct-pitch-a', 'edu-approach-b');
```

---

## Campaign Performance Dashboard

```sql
-- Overall performance
SELECT * FROM v_campaign_performance
ORDER BY websiteVisitRate DESC;

-- High intent leads per campaign
SELECT 
  campaignName,
  COUNT(*) as highIntentLeads,
  AVG(lp.intentScore) as avgScore
FROM campaign_members cm
INNER JOIN lead_profiles lp ON cm.trackingId = lp.visitorId
WHERE lp.intentScore >= 70
GROUP BY campaignName;

-- Daily campaign activity
SELECT 
  DATE(firstEmailSentAt) as date,
  COUNT(*) as emails_sent,
  COUNT(CASE WHEN firstEmailOpenedAt IS NOT NULL THEN 1 END) as opened,
  COUNT(CASE WHEN firstWebsiteVisitAt IS NOT NULL THEN 1 END) as visited
FROM campaign_members
WHERE campaignId = 'q1-outreach-2025'
  AND firstEmailSentAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY date
ORDER BY date DESC;
```

---

## Useful Queries

All queries available in `bigquery/campaign-queries.sql`:

- View all campaigns
- Campaign performance summary
- Get campaign members
- Remove lead from campaign
- Pause/resume campaign
- High intent leads in campaign
- Export for email tool
- Daily campaign report

---

## Pro Tips

1. **Use consistent campaign IDs:** lowercase-with-hyphens-2025
2. **Set totalSequenceSteps:** Helps track completion
3. **Use status field:** 'active', 'paused', 'completed', 'unsubscribed'
4. **Query views, not tables:** Views join everything for you
5. **One trackingId per person:** They can be in unlimited campaigns

---

## Summary

✅ **Created:**
- `schema-campaigns.sql` - Tables and views
- `assign-leads-to-campaign.sql` - SQL assignment
- `campaign-queries.sql` - Management queries
- `kv-sync-all-leads.sql` - Fixed KV sync (includes campaigns)
- `n8n/CAMPAIGN_ASSIGNMENT_N8N.md` - N8N workflow

✅ **Ready to:**
1. Create campaigns in BigQuery
2. Assign leads (SQL or N8N)
3. Track performance automatically
4. Same person in multiple campaigns
5. Export for email tools

**Now go assign some fucking leads to campaigns!** 🚀

