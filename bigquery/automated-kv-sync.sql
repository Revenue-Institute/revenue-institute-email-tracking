-- ============================================
-- Automated KV Sync for Personalization
-- Schedule: Every 1 hour
-- Purpose: Keep KV updated with new leads and behavioral data
-- ============================================

-- Export query that creates JSON for KV sync
-- This will be exported to Cloud Storage, then synced to KV via Cloud Function

WITH 
-- Step 1: Get all leads with tracking IDs
leads_data AS (
  SELECT 
    trackingId,
    email,
    person_name,
    company_name,
    company_website,
    company_description,
    company_size,
    revenue,
    industry,
    department,
    job_title,
    seniority,
    phone,
    linkedin,
    company_linkedin,
    inserted_at
  FROM `n8n-revenueinstitute.outbound_sales.leads`
  WHERE trackingId IS NOT NULL
),

-- Step 2: Get behavioral data for return visitors
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

-- Step 3: Combine lead data + behavioral data for KV
SELECT 
  l.trackingId as kv_key,
  TO_JSON_STRING(STRUCT(
    -- Personal
    SPLIT(l.person_name, ' ')[SAFE_OFFSET(0)] as firstName,
    ARRAY_TO_STRING(ARRAY_SLICE(SPLIT(l.person_name, ' '), 1, 10), ' ') as lastName,
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
  
FROM leads_data l
LEFT JOIN behavioral_data b ON l.trackingId = b.visitorId
WHERE l.inserted_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)  -- Only recent leads
   OR b.visitorId IS NOT NULL  -- OR leads who have visited
ORDER BY b.lastVisit DESC NULLS LAST
LIMIT 50000;  -- Adjust based on how many leads you want in KV

-- ============================================
-- Note: This query exports to Cloud Storage
-- Then a Cloud Function syncs to Cloudflare KV
-- See: scripts/setup-automated-kv-sync.sh
-- ============================================


