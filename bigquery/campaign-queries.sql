-- ============================================
-- CAMPAIGN MANAGEMENT QUERIES
-- ============================================
-- Quick reference queries for managing campaigns
-- ============================================

-- ============================================
-- VIEW ALL CAMPAIGNS
-- ============================================
SELECT 
  campaignId,
  campaignName,
  status,
  totalSequenceSteps,
  startedAt,
  endedAt,
  (SELECT COUNT(*) FROM `outbound_sales.campaign_members` WHERE campaignId = c.campaignId) as totalMembers
FROM `outbound_sales.campaigns` c
ORDER BY startedAt DESC;

-- ============================================
-- CAMPAIGN PERFORMANCE (use the view)
-- ============================================
SELECT * 
FROM `outbound_sales.v_campaign_performance`
ORDER BY totalMembers DESC;

-- ============================================
-- GET MEMBERS OF A SPECIFIC CAMPAIGN
-- ============================================
SELECT 
  l.email,
  l.person_name,
  l.company_name,
  l.job_title,
  cm.status,
  cm.addedAt,
  cm.emailsSent,
  cm.emailsOpened,
  cm.emailsClicked,
  cm.firstWebsiteVisitAt,
  lp.intentScore
FROM `outbound_sales.campaign_members` cm
INNER JOIN `outbound_sales.leads` l ON cm.trackingId = l.trackingId
LEFT JOIN `outbound_sales.lead_profiles` lp ON cm.trackingId = lp.visitorId
WHERE cm.campaignId = 'q1-outreach-2025'
ORDER BY cm.addedAt DESC
LIMIT 100;

-- ============================================
-- REMOVE LEAD FROM CAMPAIGN
-- ============================================
UPDATE `outbound_sales.campaign_members`
SET 
  status = 'removed',
  removedAt = CURRENT_TIMESTAMP()
WHERE trackingId = 'abc123ef'
  AND campaignId = 'q1-outreach-2025';

-- ============================================
-- PAUSE ENTIRE CAMPAIGN
-- ============================================
UPDATE `outbound_sales.campaigns`
SET 
  status = 'paused',
  _updatedAt = CURRENT_TIMESTAMP()
WHERE campaignId = 'q1-outreach-2025';

-- Pause all members
UPDATE `outbound_sales.campaign_members`
SET 
  status = 'paused',
  _updatedAt = CURRENT_TIMESTAMP()
WHERE campaignId = 'q1-outreach-2025'
  AND status = 'active';

-- ============================================
-- RESUME CAMPAIGN
-- ============================================
UPDATE `outbound_sales.campaigns`
SET 
  status = 'active',
  _updatedAt = CURRENT_TIMESTAMP()
WHERE campaignId = 'q1-outreach-2025';

-- Resume all paused members
UPDATE `outbound_sales.campaign_members`
SET 
  status = 'active',
  _updatedAt = CURRENT_TIMESTAMP()
WHERE campaignId = 'q1-outreach-2025'
  AND status = 'paused';

-- ============================================
-- MARK CAMPAIGN AS COMPLETED
-- ============================================
UPDATE `outbound_sales.campaigns`
SET 
  status = 'completed',
  endedAt = CURRENT_TIMESTAMP(),
  _updatedAt = CURRENT_TIMESTAMP()
WHERE campaignId = 'q1-outreach-2025';

-- ============================================
-- GET LEADS IN MULTIPLE CAMPAIGNS
-- ============================================
SELECT 
  l.trackingId,
  l.email,
  l.person_name,
  COUNT(DISTINCT cm.campaignId) as numCampaigns,
  STRING_AGG(cm.campaignName, ', ' ORDER BY cm.addedAt DESC) as campaigns
FROM `outbound_sales.leads` l
INNER JOIN `outbound_sales.campaign_members` cm ON l.trackingId = cm.trackingId
GROUP BY l.trackingId, l.email, l.person_name
HAVING COUNT(DISTINCT cm.campaignId) > 1
ORDER BY numCampaigns DESC;

-- ============================================
-- HIGH INTENT LEADS IN CAMPAIGN
-- ============================================
SELECT 
  l.email,
  l.person_name,
  l.company_name,
  cm.campaignName,
  lp.intentScore,
  lp.totalSessions,
  lp.pricingPageVisits,
  lp.lastVisitAt,
  cm.firstWebsiteVisitAt
FROM `outbound_sales.campaign_members` cm
INNER JOIN `outbound_sales.leads` l ON cm.trackingId = l.trackingId
INNER JOIN `outbound_sales.lead_profiles` lp ON cm.trackingId = lp.visitorId
WHERE cm.campaignId = 'q1-outreach-2025'
  AND lp.intentScore >= 70
ORDER BY lp.intentScore DESC, lp.lastVisitAt DESC;

-- ============================================
-- CAMPAIGN FUNNEL ANALYSIS
-- ============================================
SELECT 
  campaignName,
  COUNT(*) as totalLeads,
  COUNT(CASE WHEN emailsSent > 0 THEN 1 END) as sentEmail,
  COUNT(CASE WHEN emailsOpened > 0 THEN 1 END) as openedEmail,
  COUNT(CASE WHEN emailsClicked > 0 THEN 1 END) as clickedEmail,
  COUNT(CASE WHEN firstWebsiteVisitAt IS NOT NULL THEN 1 END) as visitedWebsite,
  
  -- Conversion rates
  ROUND(COUNT(CASE WHEN emailsOpened > 0 THEN 1 END) * 100.0 / NULLIF(COUNT(CASE WHEN emailsSent > 0 THEN 1 END), 0), 2) as openRate,
  ROUND(COUNT(CASE WHEN emailsClicked > 0 THEN 1 END) * 100.0 / NULLIF(COUNT(CASE WHEN emailsSent > 0 THEN 1 END), 0), 2) as clickRate,
  ROUND(COUNT(CASE WHEN firstWebsiteVisitAt IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 2) as websiteVisitRate
  
FROM `outbound_sales.campaign_members`
WHERE campaignId = 'q1-outreach-2025'
GROUP BY campaignName;

-- ============================================
-- EXPORT FOR EMAIL TOOL (Smartlead, Instantly, etc.)
-- ============================================
SELECT 
  l.email,
  l.firstName,
  l.lastName,
  l.company_name as company,
  l.job_title as jobTitle,
  l.phone,
  l.linkedin,
  
  -- Tracking URL
  CONCAT('https://yourdomain.com?v=', l.trackingId) as trackingUrl,
  
  -- Custom fields for personalization
  l.industry,
  l.company_size as companySize,
  cm.sequenceStep
  
FROM `outbound_sales.campaign_members` cm
INNER JOIN `outbound_sales.leads` l ON cm.trackingId = l.trackingId
WHERE cm.campaignId = 'q1-outreach-2025'
  AND cm.status = 'active'
ORDER BY cm.addedAt;

-- ============================================
-- DAILY CAMPAIGN REPORT
-- ============================================
WITH daily_stats AS (
  SELECT 
    campaignId,
    DATE(firstEmailSentAt) as date,
    COUNT(*) as emailsSentToday,
    COUNT(CASE WHEN firstEmailOpenedAt IS NOT NULL THEN 1 END) as opensToday,
    COUNT(CASE WHEN firstEmailClickedAt IS NOT NULL THEN 1 END) as clicksToday,
    COUNT(CASE WHEN firstWebsiteVisitAt IS NOT NULL THEN 1 END) as visitsToday
  FROM `outbound_sales.campaign_members`
  WHERE firstEmailSentAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  GROUP BY campaignId, date
)
SELECT 
  c.campaignName,
  ds.date,
  ds.emailsSentToday,
  ds.opensToday,
  ds.clicksToday,
  ds.visitsToday,
  ROUND(ds.opensToday * 100.0 / NULLIF(ds.emailsSentToday, 0), 2) as openRate,
  ROUND(ds.clicksToday * 100.0 / NULLIF(ds.emailsSentToday, 0), 2) as clickRate
FROM daily_stats ds
INNER JOIN `outbound_sales.campaigns` c ON ds.campaignId = c.campaignId
WHERE c.campaignId = 'q1-outreach-2025'
ORDER BY ds.date DESC;

