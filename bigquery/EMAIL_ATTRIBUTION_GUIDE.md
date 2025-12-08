# Email Attribution via UTM Parameters - Guide

## Overview

Since we don't track email opens/clicks (for deliverability), we use **probabilistic attribution** based on UTM parameters. When someone visits your site with UTM parameters matching a campaign, we attribute the visit to the last email sent to that person for that campaign.

## How It Works

### 1. UTM Parameters in Email Links

When creating email campaigns in Smartlead, include UTM parameters in all links:
```
https://yoursite.com/pricing?utm_source=email&utm_medium=email&utm_campaign=q1_2024_outreach
```

### 2. Campaign Setup

Store UTM parameters in the `email_campaigns` table:
```sql
UPDATE `outbound_sales.email_campaigns`
SET 
  utmSource = 'email',
  utmMedium = 'email',
  utmCampaign = 'q1_2024_outreach'
WHERE campaignId = 'your_campaign_id';
```

### 3. Attribution Logic

When someone visits with matching UTM parameters:
1. **Match UTM parameters** to campaign (utmCampaign is most specific)
2. **Find last email sent** to that person for that campaign (within 30 days)
3. **Attribute the visit** to that email
4. **Calculate confidence** based on UTM match quality

### 4. Attribution Confidence

- **100%**: Exact match on utmSource + utmMedium + utmCampaign
- **80%**: Match on utmCampaign only
- **70%**: Match on utmSource + utmMedium = 'email'
- **50%**: Partial match (minimum threshold)

## Views Created

### `email_attribution_utm`

Shows all website visits attributed to emails via UTM parameters:

```sql
SELECT 
  trackingId,
  visitAt,
  campaignName,
  attributedEmailId,
  hoursSinceEmailSent,
  attributionConfidence,
  attributionWindow
FROM `outbound_sales.email_attribution_utm`
ORDER BY visitAt DESC;
```

**Fields:**
- `attributedEmailId` - The email this visit is attributed to
- `hoursSinceEmailSent` - Time between email sent and visit
- `attributionConfidence` - Confidence score (50-100)
- `attributionWindow` - immediate, same_day, within_week, within_month

### `email_campaigns_ml` (Updated)

Now includes UTM-based attribution fields:

- `visitedWebsite` - Time-based attribution (visit after email sent)
- `visitedWebsiteViaUtm` - UTM-based attribution (visit with matching UTMs)
- `visitedWebsiteAny` - Either method (combined)
- `utmAttributionConfidence` - Confidence of UTM attribution
- `utmHoursToVisit` - Hours from email to UTM-attributed visit

## Example Queries

### See All Attributed Visits

```sql
SELECT 
  campaignName,
  COUNT(*) as attributedVisits,
  AVG(attributionConfidence) as avgConfidence,
  AVG(hoursSinceEmailSent) as avgHoursToVisit
FROM `outbound_sales.email_attribution_utm`
WHERE visitAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY campaignName
ORDER BY attributedVisits DESC;
```

### Attribution by Confidence Level

```sql
SELECT 
  CASE
    WHEN attributionConfidence >= 90 THEN 'High (90-100)'
    WHEN attributionConfidence >= 70 THEN 'Medium (70-89)'
    ELSE 'Low (50-69)'
  END as confidenceLevel,
  COUNT(*) as visits,
  AVG(hoursSinceEmailSent) as avgHoursToVisit
FROM `outbound_sales.email_attribution_utm`
GROUP BY confidenceLevel;
```

### Email Performance with UTM Attribution

```sql
SELECT 
  emailId,
  campaignName,
  emailSubject,
  -- Time-based attribution
  visitedWebsite as visitedTimeBased,
  -- UTM-based attribution
  visitedWebsiteViaUtm as visitedUtmBased,
  -- Combined
  visitedWebsiteAny as visitedEither,
  utmAttributionConfidence
FROM `outbound_sales.email_campaigns_ml`
WHERE sentAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
ORDER BY sentAt DESC;
```

## Setup Requirements

### 1. Campaign UTM Parameters

Make sure your campaigns have UTM parameters set:

```sql
-- Check campaigns without UTM parameters
SELECT campaignId, campaignName
FROM `outbound_sales.email_campaigns`
WHERE utmCampaign IS NULL;
```

### 2. Email Links Include UTMs

In Smartlead, when creating email templates, include UTM parameters:
- `utm_source=email`
- `utm_medium=email`
- `utm_campaign={campaign_id}` (match your campaign's utmCampaign)

### 3. Attribution Window

Default attribution window is **30 days**. If someone visits more than 30 days after email sent, it won't be attributed.

To change, modify the view:
```sql
-- Change from 30 days to 60 days
AND e_sent.sentAt >= TIMESTAMP_SUB(mv.visitAt, INTERVAL 60 DAY)
```

## Limitations

1. **Probabilistic, not deterministic** - We assume if UTM matches, they came from email
2. **Requires UTM parameters** - Visits without UTMs won't be attributed
3. **Last email only** - If multiple emails sent, attributes to most recent
4. **30-day window** - Visits after 30 days aren't attributed

## Best Practices

1. **Use consistent UTM parameters** across all email links in a campaign
2. **Set UTM parameters in campaign metadata** when creating campaigns
3. **Use unique utmCampaign values** per campaign for accurate matching
4. **Monitor attribution confidence** - low confidence may indicate UTM mismatch
5. **Combine with time-based attribution** - use `visitedWebsiteAny` for best coverage

## Testing

Test attribution with sample data:

```sql
-- 1. Create campaign with UTM parameters
INSERT INTO `outbound_sales.email_campaigns` (...)
VALUES (..., 'email', 'email', 'test_campaign', ...);

-- 2. Send email (insert email_sent event)
INSERT INTO `outbound_sales.events` (type, timestamp, visitorId, campaignId, ...)
VALUES ('email_sent', ...);

-- 3. Visit site with matching UTM parameters
INSERT INTO `outbound_sales.events` (type, timestamp, visitorId, utmSource, utmMedium, utmCampaign, ...)
VALUES ('pageview', ..., 'email', 'email', 'test_campaign', ...);

-- 4. Check attribution
SELECT * FROM `outbound_sales.email_attribution_utm`
WHERE campaignName = 'Test Campaign';
```

## Status

✅ **Implemented and tested**
- Attribution view created
- ML view updated with UTM attribution fields
- Test data verified working



