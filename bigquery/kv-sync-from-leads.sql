-- ============================================
-- KV Sync: Read directly from leads table
-- Schedule: Every 1 hour via GitHub Actions
-- Purpose: Sync leads data to Cloudflare KV for personalization
-- ============================================

-- This query exports leads for KV sync
-- Syncs: 
-- 1. ALL leads added in last 10 minutes (real-time)
-- 2. ALL leads who visited in last 10 minutes (behavioral updates)

WITH 
-- Step 1: Get behavioral data for visitors
behavioral_data AS (
  SELECT 
    visitorId,
    COUNT(DISTINCT sessionId) as totalSessions,
    COUNT(DISTINCT CASE WHEN type = 'pageview' THEN timestamp END) as totalPageviews,
    MAX(TIMESTAMP_MILLIS(timestamp)) as lastVisit,
    MIN(TIMESTAMP_MILLIS(timestamp)) as firstVisit,
    
    -- Device tracking
    ARRAY_AGG(DISTINCT JSON_EXTRACT_SCALAR(data, '$.deviceFingerprint') IGNORE NULLS) as devices,
    COUNT(DISTINCT JSON_EXTRACT_SCALAR(data, '$.deviceFingerprint')) as deviceCount,
    
    -- High-intent signals  
    COUNTIF(url LIKE '%/pricing%') > 0 as viewedPricing,
    COUNTIF(url LIKE '%/demo%') > 0 as requestedDemo,
    COUNTIF(type = 'form_submit') > 0 as submittedForm,
    
    -- Engagement
    SUM(CAST(JSON_EXTRACT_SCALAR(data, '$.readingTime') AS INT64)) as totalReadingTime,
    SUM(CAST(JSON_EXTRACT_SCALAR(data, '$.pagesThisSession') AS INT64)) as totalPagesViewed
    
  FROM `n8n-revenueinstitute.outbound_sales.events`
  WHERE visitorId IS NOT NULL
    AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
  GROUP BY visitorId
)

-- Step 2: Combine lead data + behavioral data for KV
SELECT 
  l.trackingId as kv_key,
  TO_JSON_STRING(STRUCT(
    -- Personal
    l.firstName,
    l.lastName,
    l.person_name as personName,
    l.email,
    l.phone,
    l.linkedin,
    
    -- Company
    l.company_name as company,
    l.company_name as companyName,
    COALESCE(l.company_website, SPLIT(l.email, '@')[SAFE_OFFSET(1)]) as domain,
    l.company_website as companyWebsite,
    l.company_description as companyDescription,
    l.company_size as companySize,
    l.revenue,
    l.industry,
    l.company_linkedin as companyLinkedin,
    
    -- Job
    l.job_title as jobTitle,
    l.seniority,
    l.department,
    
    -- Address (if you have these fields)
    -- l.address,
    -- l.city,
    -- l.state,
    -- l.country,
    -- l.zip_code,
    
    -- Tracking
    l.trackingId,
    
    -- Behavioral (if exists)
    COALESCE(b.totalSessions, 0) as totalSessions,
    COALESCE(b.totalPageviews, 0) as totalPageviews,
    b.lastVisit,
    b.firstVisit,
    COALESCE(b.deviceCount, 1) as deviceCount,
    b.devices,
    COALESCE(b.viewedPricing, FALSE) as viewedPricing,
    COALESCE(b.requestedDemo, FALSE) as requestedDemo,
    COALESCE(b.submittedForm, FALSE) as submittedForm,
    COALESCE(b.totalReadingTime, 0) as totalReadingTime,
    
    -- Status flags
    b.visitorId IS NOT NULL as hasVisited,
    COALESCE(b.totalSessions, 0) = 0 as isFirstVisit,
    CASE
      WHEN b.totalSessions IS NULL THEN 'new'
      WHEN b.totalSessions >= 3 AND b.viewedPricing THEN 'hot'
      WHEN b.totalSessions >= 2 OR b.viewedPricing THEN 'warm'
      ELSE 'cold'
    END as engagementLevel,
    
    -- Metadata
    CURRENT_TIMESTAMP() as syncedAt,
    TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 90 DAY) as expiresAt
  )) as kv_value
  
FROM `n8n-revenueinstitute.outbound_sales.leads` l
LEFT JOIN behavioral_data b ON l.trackingId = b.visitorId
WHERE l.trackingId IS NOT NULL
  AND (
    l.inserted_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)  -- New leads
    OR b.visitorId IS NOT NULL  -- OR leads who have visited
  )
ORDER BY b.lastVisit DESC NULLS LAST
LIMIT 50000;  -- Adjust based on how many leads you want in KV

-- ============================================
-- Expected output format:
-- kv_key: "abc123def"
-- kv_value: {
--   "firstName": "John",
--   "lastName": "Smith", 
--   "email": "john@example.com",
--   "company": "Acme Corp",
--   "trackingId": "abc123def",
--   ...
-- }
-- ============================================



