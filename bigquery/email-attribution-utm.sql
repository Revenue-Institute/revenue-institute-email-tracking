-- ============================================
-- Probabilistic Email Attribution via UTM Parameters
-- ============================================
-- When someone visits the site with UTM parameters matching a campaign,
-- attribute the visit to the last email sent to that person for that campaign
-- ============================================

-- ============================================
-- VIEW: email_attribution_utm
-- ============================================
-- Attributes website visits to emails based on UTM parameters
-- ============================================

CREATE OR REPLACE VIEW `outbound_sales.email_attribution_utm` AS
WITH email_sent_events AS (
  SELECT 
    emailId,
    visitorId as trackingId,
    TIMESTAMP_MILLIS(timestamp) as sentAt,
    campaignId,
    messageId,
    ROW_NUMBER() OVER (
      PARTITION BY visitorId, campaignId, TIMESTAMP_MILLIS(timestamp)
      ORDER BY TIMESTAMP_MILLIS(timestamp) DESC
    ) as rn
  FROM `outbound_sales.events`
  WHERE type = 'email_sent'
    AND campaignId IS NOT NULL
),
utm_visits AS (
  SELECT 
    e.visitorId as trackingId,
    TIMESTAMP_MILLIS(e.timestamp) as visitAt,
    e.url,
    e.utmSource,
    e.utmMedium,
    e.utmCampaign,
    e.utmContent,
    e.utmTerm,
    e.sessionId
  FROM `outbound_sales.events` e
  WHERE e.type = 'pageview'
    AND e.visitorId IS NOT NULL
    AND (
      -- Match UTM parameters to email campaigns
      (e.utmSource IS NOT NULL AND e.utmMedium = 'email')
      OR e.utmCampaign IS NOT NULL
    )
),
campaign_utm_match AS (
  SELECT 
    c.campaignId,
    c.campaignName,
    c.utmSource,
    c.utmMedium,
    c.utmCampaign,
    c.utmContent,
    c.utmTerm
  FROM `outbound_sales.email_campaigns` c
  WHERE c.utmSource IS NOT NULL OR c.utmCampaign IS NOT NULL
),
matched_visits AS (
  SELECT 
    uv.trackingId,
    uv.visitAt,
    uv.url,
    uv.sessionId,
    c.campaignId,
    c.campaignName,
    -- Attribution confidence (higher = more confident)
    CASE
      -- Exact UTM match
      WHEN (uv.utmSource = c.utmSource OR c.utmSource IS NULL)
        AND (uv.utmMedium = c.utmMedium OR c.utmMedium IS NULL)
        AND (uv.utmCampaign = c.utmCampaign OR c.utmCampaign IS NULL)
        THEN 100
      -- Partial match
      WHEN uv.utmCampaign = c.utmCampaign THEN 80
      WHEN uv.utmSource = c.utmSource AND uv.utmMedium = 'email' THEN 70
      ELSE 50
    END as attributionConfidence
  FROM utm_visits uv
  JOIN campaign_utm_match c ON
    -- Match by utmCampaign (most specific)
    (uv.utmCampaign = c.utmCampaign OR (uv.utmCampaign IS NULL AND c.utmCampaign IS NULL))
    -- Or match by utmSource + utmMedium
    OR (uv.utmSource = c.utmSource AND uv.utmMedium = c.utmMedium AND uv.utmMedium = 'email')
  WHERE uv.visitAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
),
attributed_visits AS (
  SELECT 
    mv.trackingId,
    mv.visitAt,
    mv.url,
    mv.sessionId,
    mv.campaignId,
    mv.campaignName,
    mv.attributionConfidence,
    -- Find the last email sent to this person for this campaign before the visit
    e_sent.emailId as attributedEmailId,
    e_sent.sentAt as attributedEmailSentAt,
    TIMESTAMP_DIFF(mv.visitAt, e_sent.sentAt, HOUR) as hoursSinceEmailSent
  FROM matched_visits mv
  LEFT JOIN email_sent_events e_sent
    ON mv.trackingId = e_sent.trackingId
    AND mv.campaignId = e_sent.campaignId
    AND e_sent.sentAt <= mv.visitAt
    AND e_sent.sentAt >= TIMESTAMP_SUB(mv.visitAt, INTERVAL 30 DAY)
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY mv.trackingId, mv.visitAt, mv.campaignId
    ORDER BY e_sent.sentAt DESC
  ) = 1
)
SELECT 
  trackingId,
  visitAt,
  url,
  sessionId,
  campaignId,
  campaignName,
  attributedEmailId,
  attributedEmailSentAt,
  hoursSinceEmailSent,
  attributionConfidence,
  -- Attribution window
  CASE
    WHEN hoursSinceEmailSent <= 1 THEN 'immediate'
    WHEN hoursSinceEmailSent <= 24 THEN 'same_day'
    WHEN hoursSinceEmailSent <= 168 THEN 'within_week'
    ELSE 'within_month'
  END as attributionWindow
FROM attributed_visits
WHERE attributedEmailId IS NOT NULL -- Only include visits where we found a matching email
  AND attributionConfidence >= 50; -- Minimum confidence threshold

-- ============================================
-- Usage Examples:
-- ============================================

-- See all attributed visits
-- SELECT * FROM `outbound_sales.email_attribution_utm`
-- ORDER BY visitAt DESC
-- LIMIT 100;

-- Attribution by campaign
-- SELECT 
--   campaignName,
--   COUNT(*) as attributedVisits,
--   AVG(attributionConfidence) as avgConfidence,
--   AVG(hoursSinceEmailSent) as avgHoursToVisit
-- FROM `outbound_sales.email_attribution_utm`
-- GROUP BY campaignName
-- ORDER BY attributedVisits DESC;

-- Attribution by confidence level
-- SELECT 
--   CASE
--     WHEN attributionConfidence >= 90 THEN 'High (90-100)'
--     WHEN attributionConfidence >= 70 THEN 'Medium (70-89)'
--     ELSE 'Low (50-69)'
--   END as confidenceLevel,
--   COUNT(*) as visits,
--   AVG(hoursSinceEmailSent) as avgHoursToVisit
-- FROM `outbound_sales.email_attribution_utm`
-- GROUP BY confidenceLevel;
