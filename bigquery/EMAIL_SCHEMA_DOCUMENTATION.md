# Email Campaign Tracking - BigQuery Schema Documentation

## Overview

This schema tracks email campaigns from Smartlead for ML model training. The design uses:
- **Existing `events` table** (extended with email columns) - all email events
- **`email_campaigns` table** - campaign metadata (one row per campaign)
- **`email_messages` table** - message templates including A/B test variants (one row per message/variant)
- **`email_campaigns_ml` view** - denormalized flat table for ML training

## Architecture

```
Smartlead Webhook
    ↓
n8n (transforms & enriches)
    ↓
INSERT into events table
    type='email_sent'
    campaignId, messageId, emailId
    ↓
Separately:
    INSERT into email_campaigns (campaign metadata)
    INSERT into email_messages (message templates)
    ↓
email_campaigns_ml view (JOINs all tables)
    ↓
ML Training Dataset
```

## Tables

### 1. `events` (Extended)

**New columns added:**
- `campaignId` STRING - References `email_campaigns.campaignId`
- `messageId` STRING - References `email_messages.messageId`
- `emailId` STRING - Unique per email sent to a person (used across all events for that email)

**New event types:**
- `email_sent` - Email sent to recipient
- `email_delivered` - Successfully delivered
- `email_bounced` - Bounced (hard or soft)
- `email_opened` - Email opened
- `email_clicked` - Link clicked in email
- `email_replied` - Reply received
- `email_unsubscribed` - Unsubscribe clicked

**Example:**
```sql
-- Email sent
INSERT INTO events (type, timestamp, visitorId, campaignId, messageId, emailId, ...)
VALUES ('email_sent', 1234567890, 'abc123', 'camp_xyz', 'msg_456', 'email_unique_789', ...);

-- Email opened (same emailId)
INSERT INTO events (type, timestamp, visitorId, emailId, ...)
VALUES ('email_opened', 1234567900, 'abc123', 'email_unique_789', ...);
```

### 2. `email_campaigns`

**Purpose:** Store campaign metadata from Smartlead

**One row per campaign** - not per recipient

**Key fields:**
- `campaignId` - Unique campaign identifier
- `campaignName` - Human-readable name
- `smartleadCampaignId` - Reference to Smartlead
- `sequenceId` - Sequence identifier
- `totalStepsInSequence` - Number of emails in sequence

**Example:**
```sql
SELECT * FROM email_campaigns WHERE campaignId = 'camp_q1_outreach_2024';
-- Returns: 1 row with campaign metadata
```

### 3. `email_messages`

**Purpose:** Store email message templates including A/B test variants

**One row per message template/variant**

**Key fields:**
- `messageId` - Unique message identifier
- `campaignId` - Which campaign this belongs to
- `sequenceStep` - Position in sequence (1, 2, 3...)
- `isAbTest` - TRUE if this is an A/B test variant
- `variantId` - 'A', 'B', 'C', etc.
- `emailSubject` - Template with {{merge_fields}}
- `emailBody` - Full HTML/text template

**A/B Test Example:**
If campaign has 3 emails, and email #2 has A/B test:
- Email 1: 1 row (sequenceStep=1, isAbTest=FALSE)
- Email 2: 2 rows (sequenceStep=2, isAbTest=TRUE, variantId='A' and 'B')
- Email 3: 1 row (sequenceStep=3, isAbTest=FALSE)
- **Total: 4 rows** for this campaign

**Example:**
```sql
-- Get all messages for a campaign
SELECT * FROM email_messages 
WHERE campaignId = 'camp_q1_outreach_2024'
ORDER BY sequenceStep, variantId;

-- Get A/B test variants for email #2
SELECT * FROM email_messages 
WHERE campaignId = 'camp_q1_outreach_2024'
  AND sequenceStep = 2
  AND isAbTest = TRUE;
```

### 4. `email_campaigns_ml` (View)

**Purpose:** Denormalized flat table for ML model training

**One row per email sent** with all features and outcomes

**Built by JOINing:**
- `events` (email_sent events)
- `email_campaigns` (campaign metadata)
- `email_messages` (message templates)
- `leads` (persona/demographic data)
- `lead_profiles` (prior behavior)
- `events` again (outcomes: opens, clicks, website visits)

**Key features:**
- Email content: `emailSubject`, `emailBody`, `emailWordCount`, etc.
- Campaign context: `campaignName`, `sequenceStep`, `variantId`, etc.
- Lead persona: `companyName`, `industry`, `jobTitle`, `seniority`, etc.
- Prior behavior: `priorWebsiteVisits`, `priorIntentScore`, etc.
- Outcomes: `wasOpened`, `wasClicked`, `visitedWebsite`, etc.

**Example:**
```sql
-- Get training data for last 90 days
SELECT * FROM email_campaigns_ml
WHERE sentAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
LIMIT 1000;

-- Export for ML training
EXPORT DATA OPTIONS(
  uri='gs://bucket/email_ml_data_*.csv',
  format='CSV'
) AS
SELECT * FROM email_campaigns_ml
WHERE sentAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY);
```

## Data Flow

### Campaign Setup (One-time)

1. Create campaign in Smartlead
2. n8n gets campaign metadata → INSERT into `email_campaigns`
3. n8n gets all message templates → INSERT into `email_messages` (one row per message/variant)

### Email Sending (Continuous)

1. Smartlead sends email to person
2. Webhook → n8n → INSERT into `events`:
   ```sql
   type='email_sent'
   visitorId='abc123' (trackingId from leads table)
   campaignId='camp_xyz'
   messageId='msg_456' (references email_messages)
   emailId='email_unique_789' (unique per person per message)
   ```

3. Person opens email → INSERT into `events`:
   ```sql
   type='email_opened'
   emailId='email_unique_789' (same as sent event)
   ```

4. Person clicks link → INSERT into `events`:
   ```sql
   type='email_clicked'
   emailId='email_unique_789'
   url='https://destination.com'
   ```

### ML Training

Query `email_campaigns_ml` view → get flat table → export to CSV/Parquet

## Key Design Decisions

### Why extend `events` table instead of separate `email_events`?

- **Unified event stream** - All user actions (website + email) in one place
- **Simple attribution** - Email click → website visit = timestamp comparison in same table
- **Existing infrastructure** - Partitioning, clustering, retention already configured

### Why separate `email_campaigns` and `email_messages`?

- **Normalized storage** - Don't duplicate message content for every recipient
- **A/B test tracking** - Each variant is a separate row with variantId
- **Template management** - Update message content without touching events

### Why `emailId` in events table?

- **Links all events for one email** - sent, opened, clicked all share same emailId
- **Easy aggregation** - "Did this email get opened?" = simple WHERE clause
- **Attribution** - Match email click to website visit via emailId + timestamp

## Example Queries

### Campaign Performance

```sql
SELECT 
  c.campaignName,
  COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END) as sent,
  COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) as opened,
  COUNT(CASE WHEN e.type = 'email_clicked' THEN 1 END) as clicked,
  COUNT(CASE WHEN e.type = 'email_replied' THEN 1 END) as replied,
  ROUND(COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END), 0), 2) as openRate
FROM events e
JOIN email_campaigns c ON e.campaignId = c.campaignId
WHERE e.type LIKE 'email_%'
GROUP BY c.campaignName;
```

### A/B Test Results

```sql
SELECT 
  m.variantName,
  COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END) as sent,
  COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) as opened,
  ROUND(COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END), 0), 2) as openRate
FROM events e
JOIN email_messages m ON e.messageId = m.messageId
WHERE e.type IN ('email_sent', 'email_opened')
  AND m.isAbTest = TRUE
  AND m.campaignId = 'camp_q1_outreach_2024'
  AND m.sequenceStep = 2
GROUP BY m.variantName
ORDER BY openRate DESC;
```

### Email → Website Attribution

```sql
SELECT 
  email_sent.visitorId,
  email_sent.timestamp as email_sent_at,
  website_visit.timestamp as visited_at,
  TIMESTAMP_DIFF(website_visit.timestamp, email_sent.timestamp, HOUR) as hours_to_visit
FROM events email_sent
JOIN events website_visit 
  ON email_sent.visitorId = website_visit.visitorId
  AND website_visit.type = 'pageview'
  AND website_visit.timestamp > email_sent.timestamp
  AND website_visit.timestamp <= TIMESTAMP_ADD(email_sent.timestamp, INTERVAL 7 DAY)
WHERE email_sent.type = 'email_sent'
  AND email_sent.campaignId = 'camp_q1_outreach_2024';
```

## Setup Steps

1. **Run ALTER statement:**
   ```sql
   -- Execute: bigquery/alter-events-add-email-columns.sql
   ```

2. **Create campaign table:**
   ```sql
   -- Execute: bigquery/schema-email-campaigns.sql
   ```

3. **Create messages table:**
   ```sql
   -- Execute: bigquery/schema-email-messages.sql
   ```

4. **Create ML view:**
   ```sql
   -- Execute: bigquery/view-email-campaigns-ml.sql
   ```

5. **Set up n8n workflow** (separate task):
   - Receive Smartlead webhooks
   - Insert into `events` table
   - Insert/update `email_campaigns` table
   - Insert/update `email_messages` table

## ML Model Use Cases

Once data is populated, you can build models to answer:

1. **Subject line optimization:** Which subject line words increase open rates for VPs in SaaS?
2. **Sequence optimization:** Should CEOs get 5 or 7 emails? With what spacing?
3. **Persona targeting:** Which industries respond best to case study emails?
4. **Send time optimization:** Best time to email CTOs in tech companies?
5. **Content optimization:** Do personalized emails work better for SMBs or enterprise?
6. **A/B test analysis:** Is variant A better for all personas or just some?

## Notes

- All email content stored as **templates** with merge fields ({{firstName}})
- Actual personalized content not stored (would be too large)
- ML models train on template + persona to predict outcomes
- Attribution window: 30 days (can be adjusted in view)
- Partitioning: `events` by `_insertedAt`, `email_campaigns_ml` by `sentAt`



