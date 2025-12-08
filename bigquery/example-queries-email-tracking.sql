-- ============================================
-- EXAMPLE QUERIES - Email Campaign Tracking
-- ============================================
-- Useful queries for analyzing email campaign performance
-- ============================================

-- ============================================
-- 1. Campaign Performance Overview
-- ============================================

SELECT 
  c.campaignName,
  c.sequenceName,
  COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END) as emailsSent,
  COUNT(CASE WHEN e.type = 'email_delivered' THEN 1 END) as emailsDelivered,
  COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) as emailsOpened,
  COUNT(CASE WHEN e.type = 'email_clicked' THEN 1 END) as emailsClicked,
  COUNT(CASE WHEN e.type = 'email_replied' THEN 1 END) as emailsReplied,
  COUNT(CASE WHEN e.type = 'email_bounced' THEN 1 END) as emailsBounced,
  ROUND(COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END), 0), 2) as openRate,
  ROUND(COUNT(CASE WHEN e.type = 'email_clicked' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END), 0), 2) as clickRate,
  ROUND(COUNT(CASE WHEN e.type = 'email_replied' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END), 0), 2) as replyRate
FROM `outbound_sales.events` e
JOIN `outbound_sales.email_campaigns` c ON e.campaignId = c.campaignId
WHERE e.type IN ('email_sent', 'email_delivered', 'email_opened', 'email_clicked', 'email_replied', 'email_bounced')
  AND e._insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY c.campaignName, c.sequenceName
ORDER BY emailsSent DESC;

-- ============================================
-- 2. A/B Test Performance Comparison
-- ============================================

SELECT 
  m.campaignId,
  m.sequenceStep,
  m.variantId,
  m.variantName,
  m.controlVariant,
  COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END) as sent,
  COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) as opened,
  COUNT(CASE WHEN e.type = 'email_clicked' THEN 1 END) as clicked,
  ROUND(COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END), 0), 2) as openRate,
  ROUND(COUNT(CASE WHEN e.type = 'email_clicked' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END), 0), 2) as clickRate
FROM `outbound_sales.events` e
JOIN `outbound_sales.email_messages` m ON e.messageId = m.messageId
WHERE e.type IN ('email_sent', 'email_opened', 'email_clicked')
  AND m.isAbTest = TRUE
  AND e._insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY m.campaignId, m.sequenceStep, m.variantId, m.variantName, m.controlVariant
ORDER BY m.campaignId, m.sequenceStep, m.variantId;

-- ============================================
-- 3. Email → Website Attribution
-- ============================================

SELECT 
  email_sent.visitorId,
  c.campaignName,
  m.emailSubject,
  TIMESTAMP_MILLIS(email_sent.timestamp) as emailSentAt,
  TIMESTAMP_MILLIS(website_visit.timestamp) as websiteVisitedAt,
  TIMESTAMP_DIFF(
    TIMESTAMP_MILLIS(website_visit.timestamp), 
    TIMESTAMP_MILLIS(email_sent.timestamp), 
    HOUR
  ) as hoursToVisit,
  website_visit.url as firstPageVisited
FROM `outbound_sales.events` email_sent
JOIN `outbound_sales.email_campaigns` c ON email_sent.campaignId = c.campaignId
JOIN `outbound_sales.email_messages` m ON email_sent.messageId = m.messageId
JOIN `outbound_sales.events` website_visit 
  ON email_sent.visitorId = website_visit.visitorId
  AND website_visit.type = 'pageview'
  AND website_visit.timestamp > email_sent.timestamp
  AND website_visit.timestamp <= email_sent.timestamp + (30 * 24 * 60 * 60 * 1000) -- 30 days in milliseconds
WHERE email_sent.type = 'email_sent'
  AND email_sent._insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY email_sent.emailId 
  ORDER BY website_visit.timestamp
) = 1
ORDER BY email_sent.timestamp DESC
LIMIT 100;

-- ============================================
-- 4. Sequence Step Performance
-- ============================================

SELECT 
  c.campaignName,
  m.sequenceStep,
  COUNT(DISTINCT e.emailId) as emailsSent,
  COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) as opened,
  COUNT(CASE WHEN e.type = 'email_clicked' THEN 1 END) as clicked,
  ROUND(COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT e.emailId), 0), 2) as openRate,
  ROUND(COUNT(CASE WHEN e.type = 'email_clicked' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT e.emailId), 0), 2) as clickRate
FROM `outbound_sales.events` e
JOIN `outbound_sales.email_campaigns` c ON e.campaignId = c.campaignId
JOIN `outbound_sales.email_messages` m ON e.messageId = m.messageId
WHERE e.type = 'email_sent'
  AND e._insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY c.campaignName, m.sequenceStep
ORDER BY c.campaignName, m.sequenceStep;

-- ============================================
-- 5. Performance by Lead Persona
-- ============================================

SELECT 
  l.industry,
  l.seniority,
  l.company_size,
  COUNT(DISTINCT e.emailId) as emailsSent,
  COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) as opened,
  COUNT(CASE WHEN e.type = 'email_clicked' THEN 1 END) as clicked,
  ROUND(COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT e.emailId), 0), 2) as openRate,
  ROUND(COUNT(CASE WHEN e.type = 'email_clicked' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT e.emailId), 0), 2) as clickRate
FROM `outbound_sales.events` e
JOIN `outbound_sales.leads` l ON e.visitorId = l.trackingId
WHERE e.type IN ('email_sent', 'email_opened', 'email_clicked')
  AND e._insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY l.industry, l.seniority, l.company_size
HAVING COUNT(DISTINCT e.emailId) >= 10 -- Only show personas with at least 10 emails
ORDER BY openRate DESC;

-- ============================================
-- 6. Best Performing Subject Lines
-- ============================================

SELECT 
  m.emailSubject,
  m.campaignId,
  COUNT(DISTINCT e.emailId) as emailsSent,
  COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) as opened,
  ROUND(COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT e.emailId), 0), 2) as openRate
FROM `outbound_sales.events` e
JOIN `outbound_sales.email_messages` m ON e.messageId = m.messageId
WHERE e.type IN ('email_sent', 'email_opened')
  AND e._insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY m.emailSubject, m.campaignId
HAVING COUNT(DISTINCT e.emailId) >= 5 -- Only show subject lines with at least 5 sends
ORDER BY openRate DESC
LIMIT 20;

-- ============================================
-- 7. Email Engagement Timeline
-- ============================================

SELECT 
  DATE(TIMESTAMP_MILLIS(e.timestamp)) as date,
  COUNT(CASE WHEN e.type = 'email_sent' THEN 1 END) as sent,
  COUNT(CASE WHEN e.type = 'email_opened' THEN 1 END) as opened,
  COUNT(CASE WHEN e.type = 'email_clicked' THEN 1 END) as clicked,
  COUNT(CASE WHEN e.type = 'email_replied' THEN 1 END) as replied
FROM `outbound_sales.events` e
WHERE e.type IN ('email_sent', 'email_opened', 'email_clicked', 'email_replied')
  AND e._insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY DATE(TIMESTAMP_MILLIS(e.timestamp))
ORDER BY date DESC;

-- ============================================
-- 8. Unengaged Leads (Sent but Never Opened)
-- ============================================

SELECT 
  e_sent.visitorId,
  l.email,
  l.company_name,
  l.industry,
  c.campaignName,
  COUNT(DISTINCT e_sent.emailId) as emailsSent,
  MAX(TIMESTAMP_MILLIS(e_sent.timestamp)) as lastEmailSent
FROM `outbound_sales.events` e_sent
JOIN `outbound_sales.email_campaigns` c ON e_sent.campaignId = c.campaignId
JOIN `outbound_sales.leads` l ON e_sent.visitorId = l.trackingId
LEFT JOIN `outbound_sales.events` e_opened 
  ON e_sent.emailId = e_opened.emailId 
  AND e_opened.type = 'email_opened'
WHERE e_sent.type = 'email_sent'
  AND e_opened.emailId IS NULL -- Never opened
  AND e_sent._insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY e_sent.visitorId, l.email, l.company_name, l.industry, c.campaignName
HAVING COUNT(DISTINCT e_sent.emailId) >= 3 -- Sent at least 3 emails
ORDER BY emailsSent DESC
LIMIT 100;

-- ============================================
-- 9. ML View Sample Query
-- ============================================

-- Get training data for last 90 days
SELECT 
  emailId,
  sentAt,
  campaignName,
  emailSubject,
  industry,
  seniority,
  wasOpened,
  wasClicked,
  visitedWebsite,
  hoursToFirstVisit
FROM `outbound_sales.email_campaigns_ml`
WHERE sentAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
  AND wasOpened = TRUE -- Only opened emails
ORDER BY sentAt DESC
LIMIT 1000;

-- ============================================
-- 10. Campaign ROI (Email → Website → Conversion)
-- ============================================

SELECT 
  c.campaignName,
  COUNT(DISTINCT e_sent.emailId) as emailsSent,
  COUNT(DISTINCT CASE WHEN e_opened.emailId IS NOT NULL THEN e_sent.emailId END) as opened,
  COUNT(DISTINCT CASE WHEN e_clicked.emailId IS NOT NULL THEN e_sent.emailId END) as clicked,
  COUNT(DISTINCT CASE WHEN e_web.visitorId IS NOT NULL THEN e_sent.visitorId END) as visitedWebsite,
  COUNT(DISTINCT CASE WHEN e_form.visitorId IS NOT NULL THEN e_sent.visitorId END) as submittedForm
FROM `outbound_sales.events` e_sent
JOIN `outbound_sales.email_campaigns` c ON e_sent.campaignId = c.campaignId
LEFT JOIN `outbound_sales.events` e_opened 
  ON e_sent.emailId = e_opened.emailId 
  AND e_opened.type = 'email_opened'
LEFT JOIN `outbound_sales.events` e_clicked 
  ON e_sent.emailId = e_clicked.emailId 
  AND e_clicked.type = 'email_clicked'
LEFT JOIN `outbound_sales.events` e_web 
  ON e_sent.visitorId = e_web.visitorId 
  AND e_web.type = 'pageview'
  AND e_web.timestamp > e_sent.timestamp
  AND e_web.timestamp <= e_sent.timestamp + (30 * 24 * 60 * 60 * 1000)
LEFT JOIN `outbound_sales.events` e_form 
  ON e_sent.visitorId = e_form.visitorId 
  AND e_form.type = 'form_submit'
  AND e_form.timestamp > e_sent.timestamp
  AND e_form.timestamp <= e_sent.timestamp + (30 * 24 * 60 * 60 * 1000)
WHERE e_sent.type = 'email_sent'
  AND e_sent._insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY c.campaignName
ORDER BY emailsSent DESC;



