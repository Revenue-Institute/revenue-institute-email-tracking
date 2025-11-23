-- BigQuery Schema for Outbound Intent Engine
-- Dataset: outbound_sales

-- ============================================
-- TABLE 1: events (Raw Event Stream)
-- ============================================
CREATE TABLE IF NOT EXISTS `outbound_sales.events` (
  -- Event Identification
  type STRING NOT NULL,
  timestamp INT64 NOT NULL,
  serverTimestamp INT64,
  
  -- Session & Identity
  sessionId STRING NOT NULL,
  visitorId STRING,
  
  -- Page Context
  url STRING,
  referrer STRING,
  
  -- Event Data (flexible JSON)
  data JSON,
  
  -- Server-side Enrichment
  ip STRING,
  country STRING,
  userAgent STRING,
  colo STRING,
  asn INT64,
  city STRING,
  region STRING,
  timezone STRING,
  
  -- Metadata
  _insertedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(_insertedAt)
CLUSTER BY visitorId, sessionId, type
OPTIONS(
  description="Raw event stream from tracking pixel",
  partition_expiration_days=730  -- 2 years retention
);

-- ============================================
-- TABLE 2: sessions (Aggregated Session Data)
-- ============================================
CREATE TABLE IF NOT EXISTS `outbound_sales.sessions` (
  -- Session Identification
  sessionId STRING NOT NULL,
  visitorId STRING,
  
  -- Session Timing
  startTime TIMESTAMP NOT NULL,
  endTime TIMESTAMP,
  duration INT64,  -- seconds
  activeTime INT64,  -- seconds of actual engagement
  
  -- Entry/Exit
  entryUrl STRING,
  entryReferrer STRING,
  exitUrl STRING,
  
  -- Session Metrics
  pageviews INT64 DEFAULT 0,
  clicks INT64 DEFAULT 0,
  maxScrollDepth INT64,
  formsStarted INT64 DEFAULT 0,
  formsSubmitted INT64 DEFAULT 0,
  videosWatched INT64 DEFAULT 0,
  
  -- Device & Location
  device STRING,
  browser STRING,
  os STRING,
  country STRING,
  city STRING,
  region STRING,
  
  -- Engagement Score (0-100)
  engagementScore FLOAT64,
  
  -- Intent Signals
  viewedPricing BOOL DEFAULT FALSE,
  viewedCaseStudies BOOL DEFAULT FALSE,
  viewedProduct BOOL DEFAULT FALSE,
  highIntentPages ARRAY<STRING>,
  
  -- Metadata
  _updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(startTime)
CLUSTER BY visitorId, sessionId
OPTIONS(
  description="Aggregated session-level analytics"
);

-- ============================================
-- TABLE 3: lead_profiles (Visitor Identity & Scoring)
-- ============================================
CREATE TABLE IF NOT EXISTS `outbound_sales.lead_profiles` (
  -- Identity
  visitorId STRING NOT NULL,
  
  -- Campaign Attribution
  campaignId STRING,
  campaignName STRING,
  emailSentAt TIMESTAMP,
  firstClickAt TIMESTAMP,
  
  -- Enrichment Data
  email STRING,
  emailSHA256 STRING,
  emailSHA1 STRING,
  emailMD5 STRING,
  firstName STRING,
  lastName STRING,
  company STRING,
  companyDomain STRING,
  jobTitle STRING,
  industry STRING,
  
  -- Aggregated Behavior
  totalSessions INT64 DEFAULT 0,
  totalPageviews INT64 DEFAULT 0,
  totalActiveTime INT64 DEFAULT 0,  -- seconds
  lastVisitAt TIMESTAMP,
  firstVisitAt TIMESTAMP,
  returnVisits INT64 DEFAULT 0,
  
  -- Intent Scoring
  intentScore FLOAT64,  -- 0-100 composite score
  engagementLevel STRING,  -- 'cold', 'warm', 'hot', 'burning'
  
  -- High-Intent Signals
  pricingPageVisits INT64 DEFAULT 0,
  caseStudyViews INT64 DEFAULT 0,
  productPageViews INT64 DEFAULT 0,
  formSubmissions INT64 DEFAULT 0,
  videoCompletions INT64 DEFAULT 0,
  
  -- CRM Sync
  syncedToCRM BOOL DEFAULT FALSE,
  crmContactId STRING,
  lastSyncedAt TIMESTAMP,
  
  -- Metadata
  _createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  _updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY visitorId, engagementLevel
OPTIONS(
  description="Lead profiles with identity, attribution, and intent scoring"
);

-- ============================================
-- TABLE 4: email_clicks (Click Tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS `outbound_sales.email_clicks` (
  clickId STRING NOT NULL,
  identityId STRING NOT NULL,
  visitorId STRING,
  
  clickedAt TIMESTAMP NOT NULL,
  destination STRING,
  
  -- Attribution
  campaignId STRING,
  emailId STRING,
  
  -- Context
  ip STRING,
  country STRING,
  city STRING,
  userAgent STRING,
  device STRING,
  
  -- Metadata
  _insertedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(clickedAt)
CLUSTER BY identityId, visitorId
OPTIONS(
  description="Email click tracking for outbound campaigns"
);

-- ============================================
-- TABLE 5: identity_map (Identity Resolution)
-- ============================================
CREATE TABLE IF NOT EXISTS `outbound_sales.identity_map` (
  shortId STRING NOT NULL,  -- e.g., 'ab3f9'
  visitorId STRING,
  
  -- Lead Data
  email STRING,
  emailHash STRING,
  firstName STRING,
  lastName STRING,
  company STRING,
  
  -- Campaign Context
  campaignId STRING,
  campaignName STRING,
  sequenceStep INT64,
  
  -- Metadata
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  expiresAt TIMESTAMP,
  clicks INT64 DEFAULT 0,
  lastClickedAt TIMESTAMP
)
CLUSTER BY shortId, visitorId
OPTIONS(
  description="Maps short tracking IDs to visitor identities"
);

-- ============================================
-- VIEWS: Analytics & Reporting
-- ============================================

-- High-Intent Leads (Hot prospects)
CREATE OR REPLACE VIEW `outbound_sales.high_intent_leads` AS
SELECT 
  lp.visitorId,
  lp.email,
  lp.firstName,
  lp.lastName,
  lp.company,
  lp.intentScore,
  lp.engagementLevel,
  lp.lastVisitAt,
  lp.totalSessions,
  lp.pricingPageVisits,
  lp.formSubmissions,
  lp.campaignName,
  lp.syncedToCRM
FROM `outbound_sales.lead_profiles` lp
WHERE lp.intentScore >= 70
  AND lp.lastVisitAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
ORDER BY lp.intentScore DESC, lp.lastVisitAt DESC;

-- Campaign Performance
CREATE OR REPLACE VIEW `outbound_sales.campaign_performance` AS
SELECT 
  campaignId,
  campaignName,
  COUNT(DISTINCT visitorId) as totalRecipients,
  COUNT(DISTINCT CASE WHEN firstClickAt IS NOT NULL THEN visitorId END) as clicks,
  COUNT(DISTINCT CASE WHEN totalSessions > 0 THEN visitorId END) as visitors,
  COUNT(DISTINCT CASE WHEN intentScore >= 50 THEN visitorId END) as qualifiedLeads,
  COUNT(DISTINCT CASE WHEN intentScore >= 70 THEN visitorId END) as highIntentLeads,
  AVG(intentScore) as avgIntentScore,
  SUM(totalPageviews) as totalPageviews,
  SUM(formSubmissions) as totalFormSubmissions
FROM `outbound_sales.lead_profiles`
WHERE campaignId IS NOT NULL
GROUP BY campaignId, campaignName
ORDER BY highIntentLeads DESC;

-- Session Activity Feed (Recent)
CREATE OR REPLACE VIEW `outbound_sales.recent_sessions` AS
SELECT 
  s.sessionId,
  s.visitorId,
  lp.email,
  lp.company,
  s.startTime,
  s.duration,
  s.pageviews,
  s.clicks,
  s.engagementScore,
  s.viewedPricing,
  s.formsSubmitted,
  s.entryUrl,
  s.country,
  s.city
FROM `outbound_sales.sessions` s
LEFT JOIN `outbound_sales.lead_profiles` lp ON s.visitorId = lp.visitorId
WHERE s.startTime >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY s.startTime DESC
LIMIT 1000;

-- Intent Score Distribution
CREATE OR REPLACE VIEW `outbound_sales.intent_distribution` AS
SELECT 
  CASE 
    WHEN intentScore >= 90 THEN '90-100: Burning Hot'
    WHEN intentScore >= 70 THEN '70-89: Hot'
    WHEN intentScore >= 50 THEN '50-69: Warm'
    WHEN intentScore >= 30 THEN '30-49: Cool'
    ELSE '0-29: Cold'
  END as scoreRange,
  COUNT(*) as leadCount,
  AVG(totalSessions) as avgSessions,
  AVG(totalPageviews) as avgPageviews,
  AVG(pricingPageVisits) as avgPricingViews
FROM `outbound_sales.lead_profiles`
WHERE lastVisitAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY scoreRange
ORDER BY scoreRange DESC;

-- ============================================
-- SCHEDULED QUERIES (Run these via BigQuery Scheduled Queries)
-- ============================================

-- Query 1: Aggregate events into sessions (run every 5 minutes)
-- Query 2: Update lead profiles with latest behavior (run every 15 minutes)
-- Query 3: Calculate intent scores (run every hour)
-- Query 4: Sync high-intent leads to CRM (run every hour)

