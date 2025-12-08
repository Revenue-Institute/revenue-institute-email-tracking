-- ============================================
-- CAMPAIGN TRACKING TABLES
-- ============================================
-- Purpose: Track which leads belong to which campaigns
-- Architecture: Many-to-many (one lead can be in multiple campaigns)
-- ============================================

-- ============================================
-- TABLE 1: campaigns (Campaign Metadata)
-- ============================================
CREATE TABLE IF NOT EXISTS `outbound_sales.campaigns` (
  -- Identity
  campaignId STRING NOT NULL,
  campaignName STRING NOT NULL,
  
  -- Attribution (for UTM tracking)
  utmSource STRING,
  utmMedium STRING DEFAULT 'email',
  utmCampaign STRING,
  utmContent STRING,
  utmTerm STRING,
  
  -- Campaign Details
  description STRING,
  totalSequenceSteps INT64,        -- How many emails in sequence (e.g., 5)
  
  -- Smartlead Integration
  smartleadCampaignId STRING,      -- Reference to Smartlead campaign
  smartleadSequenceId STRING,
  
  -- Status
  status STRING,                   -- 'draft', 'active', 'paused', 'completed'
  startedAt TIMESTAMP,
  endedAt TIMESTAMP,
  
  -- Metadata
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  _updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY campaignId, status
OPTIONS(
  description="Campaign metadata - one row per campaign"
);

-- ============================================
-- TABLE 2: campaign_members (Lead-to-Campaign Assignment)
-- ============================================
CREATE TABLE IF NOT EXISTS `outbound_sales.campaign_members` (
  -- Identifiers
  trackingId STRING NOT NULL,      -- Links to leads.trackingId
  campaignId STRING NOT NULL,      -- Links to campaigns.campaignId
  
  -- Campaign Context
  campaignName STRING,             -- Denormalized for easy querying
  sequenceStep INT64,              -- Current step in sequence (1, 2, 3...)
  
  -- Status
  status STRING,                   -- 'active', 'completed', 'bounced', 'unsubscribed', 'paused'
  addedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  removedAt TIMESTAMP,
  
  -- Email Engagement (aggregated from events)
  emailsSent INT64 DEFAULT 0,
  emailsDelivered INT64 DEFAULT 0,
  emailsOpened INT64 DEFAULT 0,
  emailsClicked INT64 DEFAULT 0,
  emailsReplied INT64 DEFAULT 0,
  emailsBounced INT64 DEFAULT 0,
  
  -- First Touch Attribution
  firstEmailSentAt TIMESTAMP,
  firstEmailOpenedAt TIMESTAMP,
  firstEmailClickedAt TIMESTAMP,
  firstWebsiteVisitAt TIMESTAMP,
  
  -- Latest Touch
  lastEmailSentAt TIMESTAMP,
  lastEmailOpenedAt TIMESTAMP,
  lastEmailClickedAt TIMESTAMP,
  lastWebsiteVisitAt TIMESTAMP,
  
  -- Metadata
  _updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY trackingId, campaignId
OPTIONS(
  description="Many-to-many junction table: which leads are in which campaigns"
);

-- ============================================
-- INDEX: Unique constraint (one person per campaign)
-- ============================================
-- Note: BigQuery doesn't support unique constraints
-- Handle this in application logic or use MERGE statements

-- ============================================
-- VIEWS: Campaign Analytics
-- ============================================

-- View: Campaign Performance Summary
CREATE OR REPLACE VIEW `outbound_sales.v_campaign_performance` AS
SELECT 
  c.campaignId,
  c.campaignName,
  c.status as campaignStatus,
  c.startedAt,
  c.endedAt,
  
  -- Member counts
  COUNT(DISTINCT cm.trackingId) as totalMembers,
  COUNT(DISTINCT CASE WHEN cm.status = 'active' THEN cm.trackingId END) as activeMembers,
  COUNT(DISTINCT CASE WHEN cm.status = 'completed' THEN cm.trackingId END) as completedMembers,
  COUNT(DISTINCT CASE WHEN cm.status = 'unsubscribed' THEN cm.trackingId END) as unsubscribedMembers,
  
  -- Email metrics
  SUM(cm.emailsSent) as totalEmailsSent,
  SUM(cm.emailsOpened) as totalEmailsOpened,
  SUM(cm.emailsClicked) as totalEmailsClicked,
  SUM(cm.emailsReplied) as totalEmailsReplied,
  
  -- Rates
  SAFE_DIVIDE(SUM(cm.emailsOpened), NULLIF(SUM(cm.emailsSent), 0)) as openRate,
  SAFE_DIVIDE(SUM(cm.emailsClicked), NULLIF(SUM(cm.emailsSent), 0)) as clickRate,
  SAFE_DIVIDE(SUM(cm.emailsReplied), NULLIF(SUM(cm.emailsSent), 0)) as replyRate,
  
  -- Website visits
  COUNT(DISTINCT CASE WHEN cm.firstWebsiteVisitAt IS NOT NULL THEN cm.trackingId END) as visitedWebsite,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN cm.firstWebsiteVisitAt IS NOT NULL THEN cm.trackingId END),
    NULLIF(COUNT(DISTINCT cm.trackingId), 0)
  ) as websiteVisitRate,
  
  -- High intent leads (joined with lead_profiles)
  COUNT(DISTINCT CASE WHEN lp.intentScore >= 70 THEN cm.trackingId END) as highIntentLeads,
  AVG(lp.intentScore) as avgIntentScore,
  
  -- Revenue metrics (if you have deal data)
  -- SUM(deals.amount) as totalRevenue,
  
  -- Metadata
  MAX(cm._updatedAt) as lastUpdated
  
FROM `outbound_sales.campaigns` c
LEFT JOIN `outbound_sales.campaign_members` cm ON c.campaignId = cm.campaignId
LEFT JOIN `outbound_sales.lead_profiles` lp ON cm.trackingId = lp.visitorId
GROUP BY 
  c.campaignId, 
  c.campaignName, 
  c.status, 
  c.startedAt, 
  c.endedAt;

-- View: Lead's Campaign History
CREATE OR REPLACE VIEW `outbound_sales.v_lead_campaigns` AS
SELECT 
  l.trackingId,
  l.email,
  l.person_name,
  l.company_name,
  
  cm.campaignId,
  cm.campaignName,
  cm.status as membershipStatus,
  cm.addedAt,
  cm.sequenceStep,
  
  -- Engagement
  cm.emailsSent,
  cm.emailsOpened,
  cm.emailsClicked,
  cm.firstEmailClickedAt,
  cm.firstWebsiteVisitAt,
  
  -- Intent score
  lp.intentScore,
  lp.engagementLevel,
  
  cm._updatedAt as lastUpdated
  
FROM `outbound_sales.leads` l
INNER JOIN `outbound_sales.campaign_members` cm ON l.trackingId = cm.trackingId
LEFT JOIN `outbound_sales.lead_profiles` lp ON l.trackingId = lp.visitorId
ORDER BY l.trackingId, cm.addedAt DESC;

-- View: Active Campaign Members (For Daily Exports)
CREATE OR REPLACE VIEW `outbound_sales.v_active_campaign_members` AS
SELECT 
  l.trackingId,
  l.email,
  l.firstName,
  l.lastName,
  l.company_name as company,
  l.job_title as jobTitle,
  
  cm.campaignId,
  cm.campaignName,
  cm.sequenceStep,
  cm.status,
  
  -- For email personalization
  cm.emailsSent,
  cm.emailsOpened,
  cm.lastEmailSentAt,
  
  -- Website behavior
  lp.totalSessions,
  lp.totalPageviews,
  lp.intentScore,
  
  cm._updatedAt
  
FROM `outbound_sales.campaign_members` cm
INNER JOIN `outbound_sales.leads` l ON cm.trackingId = l.trackingId
LEFT JOIN `outbound_sales.lead_profiles` lp ON cm.trackingId = lp.visitorId
WHERE cm.status = 'active';

-- ============================================
-- DONE: Run this file to create campaign tables
-- Next: Use assign-leads-to-campaign.sql to add members
-- ============================================

