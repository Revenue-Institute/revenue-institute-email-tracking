-- ============================================
-- Intent Scoring Queries for BigQuery Scheduled Queries
-- ============================================

-- ============================================
-- QUERY 1: Aggregate Events into Sessions
-- Schedule: Every 5 minutes
-- ============================================
MERGE `outbound_sales.sessions` T
USING (
  WITH session_events AS (
    SELECT 
      sessionId,
      visitorId,
      MIN(timestamp) as firstEvent,
      MAX(timestamp) as lastEvent,
      COUNT(*) as eventCount,
      
      -- Pageview metrics
      COUNTIF(type = 'pageview') as pageviews,
      COUNTIF(type = 'click') as clicks,
      
      -- Scroll metrics
      MAX(CAST(JSON_EXTRACT_SCALAR(data, '$.depth') AS INT64)) as maxScrollDepth,
      
      -- Form metrics
      COUNTIF(type = 'form_start') as formsStarted,
      COUNTIF(type = 'form_submit') as formsSubmitted,
      
      -- Video metrics
      COUNTIF(type = 'video_complete') as videosWatched,
      
      -- Active time
      MAX(CAST(JSON_EXTRACT_SCALAR(data, '$.activeTime') AS INT64)) as activeTime,
      
      -- High-intent pages (array of URLs containing key paths)
      ARRAY_AGG(DISTINCT CASE WHEN url LIKE '%/pricing%' OR url LIKE '%/demo%' OR url LIKE '%/contact%' THEN url END IGNORE NULLS) as highIntentPages,
      
      -- Entry/Exit
      ARRAY_AGG(url ORDER BY timestamp LIMIT 1)[OFFSET(0)] as entryUrl,
      ARRAY_AGG(referrer ORDER BY timestamp LIMIT 1)[OFFSET(0)] as entryReferrer,
      ARRAY_AGG(url ORDER BY timestamp DESC LIMIT 1)[OFFSET(0)] as exitUrl,
      
      -- Device info
      ARRAY_AGG(userAgent ORDER BY timestamp LIMIT 1)[OFFSET(0)] as userAgent,
      ARRAY_AGG(country ORDER BY timestamp LIMIT 1)[OFFSET(0)] as country,
      ARRAY_AGG(city ORDER BY timestamp LIMIT 1)[OFFSET(0)] as city,
      ARRAY_AGG(region ORDER BY timestamp LIMIT 1)[OFFSET(0)] as region
      
    FROM `outbound_sales.events`
    WHERE timestamp >= UNIX_MILLIS(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR))
    GROUP BY sessionId, visitorId
  ),
  parsed_sessions AS (
    SELECT
      sessionId,
      visitorId,
      TIMESTAMP_MILLIS(firstEvent) as startTime,
      TIMESTAMP_MILLIS(lastEvent) as endTime,
      CAST((lastEvent - firstEvent) / 1000 AS INT64) as duration,
      COALESCE(activeTime, 0) as activeTime,
      entryUrl,
      entryReferrer,
      exitUrl,
      pageviews,
      clicks,
      maxScrollDepth,
      formsStarted,
      formsSubmitted,
      videosWatched,
      
      -- Parse device info from user agent
      CASE 
        WHEN userAgent LIKE '%Mobile%' THEN 'Mobile'
        WHEN userAgent LIKE '%Tablet%' THEN 'Tablet'
        ELSE 'Desktop'
      END as device,
      
      CASE
        WHEN userAgent LIKE '%Chrome%' THEN 'Chrome'
        WHEN userAgent LIKE '%Safari%' THEN 'Safari'
        WHEN userAgent LIKE '%Firefox%' THEN 'Firefox'
        WHEN userAgent LIKE '%Edge%' THEN 'Edge'
        ELSE 'Other'
      END as browser,
      
      CASE
        WHEN userAgent LIKE '%Windows%' THEN 'Windows'
        WHEN userAgent LIKE '%Mac%' THEN 'macOS'
        WHEN userAgent LIKE '%Linux%' THEN 'Linux'
        WHEN userAgent LIKE '%Android%' THEN 'Android'
        WHEN userAgent LIKE '%iOS%' THEN 'iOS'
        ELSE 'Other'
      END as os,
      
      country,
      city,
      region,
      highIntentPages,
      
      -- Calculate engagement score (0-100)
      LEAST(100, (
        (pageviews * 5) +
        (clicks * 3) +
        (COALESCE(maxScrollDepth, 0) / 2) +
        (formsStarted * 15) +
        (formsSubmitted * 30) +
        (videosWatched * 20) +
        (CAST(activeTime AS FLOAT64) / 10) +
        (ARRAY_LENGTH(COALESCE(highIntentPages, [])) * 15)  -- +15 points per high-intent page visited
      )) as engagementScore
      
    FROM session_events
  )
  SELECT * FROM parsed_sessions
) S
ON T.sessionId = S.sessionId
WHEN MATCHED THEN
  UPDATE SET
    endTime = S.endTime,
    duration = S.duration,
    activeTime = S.activeTime,
    exitUrl = S.exitUrl,
    pageviews = S.pageviews,
    clicks = S.clicks,
    maxScrollDepth = S.maxScrollDepth,
    formsStarted = S.formsStarted,
    formsSubmitted = S.formsSubmitted,
    videosWatched = S.videosWatched,
    engagementScore = S.engagementScore,
    highIntentPages = S.highIntentPages,
    _updatedAt = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (
    sessionId, visitorId, startTime, endTime, duration, activeTime,
    entryUrl, entryReferrer, exitUrl, pageviews, clicks, maxScrollDepth,
    formsStarted, formsSubmitted, videosWatched, device, browser, os,
    country, city, region, engagementScore, highIntentPages, _updatedAt
  )
  VALUES (
    S.sessionId, S.visitorId, S.startTime, S.endTime, S.duration, S.activeTime,
    S.entryUrl, S.entryReferrer, S.exitUrl, S.pageviews, S.clicks, S.maxScrollDepth,
    S.formsStarted, S.formsSubmitted, S.videosWatched, S.device, S.browser, S.os,
    S.country, S.city, S.region, S.engagementScore, S.highIntentPages, CURRENT_TIMESTAMP()
  );


-- ============================================
-- QUERY 2: Update Lead Profiles
-- Schedule: Every 15 minutes
-- ============================================
MERGE `outbound_sales.lead_profiles` T
USING (
  WITH visitor_aggregates AS (
    SELECT 
      visitorId,
      COUNT(DISTINCT sessionId) as totalSessions,
      SUM(pageviews) as totalPageviews,
      SUM(activeTime) as totalActiveTime,
      MIN(startTime) as firstVisitAt,
      MAX(endTime) as lastVisitAt,
      
      -- Intent signals
      SUM(CAST(viewedPricing AS INT64)) as pricingPageVisits,
      SUM(CAST(viewedCaseStudies AS INT64)) as caseStudyViews,
      SUM(CAST(viewedProduct AS INT64)) as productPageViews,
      SUM(formsSubmitted) as formSubmissions,
      SUM(videosWatched) as videoCompletions,
      
      -- Return visits
      COUNT(DISTINCT DATE(startTime)) - 1 as returnVisits
      
    FROM `outbound_sales.sessions`
    WHERE visitorId IS NOT NULL
      AND startTime >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
    GROUP BY visitorId
  ),
  email_data AS (
    SELECT DISTINCT
      visitorId,
      ARRAY_AGG(JSON_EXTRACT_SCALAR(data, '$.email_sha256') IGNORE NULLS ORDER BY timestamp DESC LIMIT 1)[OFFSET(0)] as emailSHA256,
      ARRAY_AGG(JSON_EXTRACT_SCALAR(data, '$.email_sha1') IGNORE NULLS ORDER BY timestamp DESC LIMIT 1)[OFFSET(0)] as emailSHA1
    FROM `outbound_sales.events`
    WHERE type = 'form_submit'
      AND JSON_EXTRACT_SCALAR(data, '$.email_sha256') IS NOT NULL
    GROUP BY visitorId
  ),
  identity_data AS (
    SELECT 
      visitorId,
      campaignId,
      campaignName,
      email,
      firstName,
      lastName,
      company
    FROM `outbound_sales.identity_map`
    WHERE visitorId IS NOT NULL
  )
  SELECT 
    va.visitorId,
    id.campaignId,
    id.campaignName,
    id.email,
    ed.emailSHA256,
    ed.emailSHA1,
    id.firstName,
    id.lastName,
    id.company,
    va.totalSessions,
    va.totalPageviews,
    va.totalActiveTime,
    va.firstVisitAt,
    va.lastVisitAt,
    va.returnVisits,
    va.pricingPageVisits,
    va.caseStudyViews,
    va.productPageViews,
    va.formSubmissions,
    va.videoCompletions,
    
    -- Calculate composite intent score (0-100)
    LEAST(100, (
      -- Recency (0-30 points)
      (CASE 
        WHEN va.lastVisitAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) THEN 30
        WHEN va.lastVisitAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 DAY) THEN 25
        WHEN va.lastVisitAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY) THEN 20
        WHEN va.lastVisitAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 14 DAY) THEN 15
        WHEN va.lastVisitAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY) THEN 10
        ELSE 5
      END) +
      
      -- Frequency (0-20 points)
      LEAST(20, va.totalSessions * 4) +
      
      -- Engagement (0-25 points)
      LEAST(25, va.totalPageviews * 1.5 + (va.totalActiveTime / 60)) +
      
      -- High-intent pages (0-25 points)
      LEAST(25, (va.pricingPageVisits * 8) + (va.caseStudyViews * 5) + (va.productPageViews * 4)) +
      
      -- Conversions (0-20 points)
      LEAST(20, (va.formSubmissions * 15) + (va.videoCompletions * 5))
    )) as intentScore
    
  FROM visitor_aggregates va
  LEFT JOIN email_data ed ON va.visitorId = ed.visitorId
  LEFT JOIN identity_data id ON va.visitorId = id.visitorId
) S
ON T.visitorId = S.visitorId
WHEN MATCHED THEN
  UPDATE SET
    totalSessions = S.totalSessions,
    totalPageviews = S.totalPageviews,
    totalActiveTime = S.totalActiveTime,
    lastVisitAt = S.lastVisitAt,
    returnVisits = S.returnVisits,
    pricingPageVisits = S.pricingPageVisits,
    caseStudyViews = S.caseStudyViews,
    productPageViews = S.productPageViews,
    formSubmissions = S.formSubmissions,
    videoCompletions = S.videoCompletions,
    intentScore = S.intentScore,
    engagementLevel = CASE
      WHEN S.intentScore >= 80 THEN 'burning'
      WHEN S.intentScore >= 60 THEN 'hot'
      WHEN S.intentScore >= 40 THEN 'warm'
      ELSE 'cold'
    END,
    emailSHA256 = COALESCE(S.emailSHA256, T.emailSHA256),
    emailSHA1 = COALESCE(S.emailSHA1, T.emailSHA1),
    _updatedAt = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (
    visitorId, campaignId, campaignName, email, emailSHA256, emailSHA1,
    firstName, lastName, company, totalSessions, totalPageviews,
    totalActiveTime, firstVisitAt, lastVisitAt, returnVisits,
    pricingPageVisits, caseStudyViews, productPageViews, formSubmissions,
    videoCompletions, intentScore, engagementLevel, _createdAt, _updatedAt
  )
  VALUES (
    S.visitorId, S.campaignId, S.campaignName, S.email, S.emailSHA256, S.emailSHA1,
    S.firstName, S.lastName, S.company, S.totalSessions, S.totalPageviews,
    S.totalActiveTime, S.firstVisitAt, S.lastVisitAt, S.returnVisits,
    S.pricingPageVisits, S.caseStudyViews, S.productPageViews, S.formSubmissions,
    S.videoCompletions, S.intentScore,
    CASE
      WHEN S.intentScore >= 80 THEN 'burning'
      WHEN S.intentScore >= 60 THEN 'hot'
      WHEN S.intentScore >= 40 THEN 'warm'
      ELSE 'cold'
    END,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
  );


-- ============================================
-- QUERY 3: Sync High-Intent Leads to KV (for personalization)
-- Schedule: Every hour
-- ============================================
-- This query exports high-intent leads for syncing to Cloudflare KV
-- Export results to Cloud Storage, then use a Cloud Function to sync to KV

SELECT 
  visitorId,
  email,
  firstName,
  lastName,
  company,
  intentScore,
  engagementLevel,
  totalSessions,
  lastVisitAt,
  pricingPageVisits,
  formSubmissions,
  
  -- Personalization data
  STRUCT(
    firstName,
    company,
    intentScore,
    engagementLevel,
    CAST(pricingPageVisits > 0 AS BOOL) as viewedPricing,
    CAST(formSubmissions > 0 AS BOOL) as submittedForm
  ) as personalizationData
  
FROM `outbound_sales.lead_profiles`
WHERE intentScore >= 50  -- Only sync warm+ leads
  AND lastVisitAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
ORDER BY intentScore DESC;


-- ============================================
-- QUERY 4: Alert on Hot Leads (for CRM sync)
-- Schedule: Every 15 minutes
-- ============================================
-- Export leads that just became "hot" for immediate follow-up

SELECT 
  lp.visitorId,
  lp.email,
  lp.firstName,
  lp.lastName,
  lp.company,
  lp.intentScore,
  lp.engagementLevel,
  lp.lastVisitAt,
  lp.campaignName,
  
  -- Latest session details
  s.entryUrl as lastPageVisited,
  s.pageviews as lastSessionPageviews,
  s.viewedPricing as lastSessionViewedPricing,
  s.formsSubmitted as lastSessionFormSubmits,
  
  -- Alert metadata
  CURRENT_TIMESTAMP() as alertedAt,
  'hot_lead_alert' as alertType
  
FROM `outbound_sales.lead_profiles` lp
LEFT JOIN `outbound_sales.sessions` s 
  ON lp.visitorId = s.visitorId 
  AND s.startTime = (
    SELECT MAX(startTime) 
    FROM `outbound_sales.sessions` 
    WHERE visitorId = lp.visitorId
  )
WHERE lp.intentScore >= 70
  AND lp.lastVisitAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 MINUTE)
  AND (lp.syncedToCRM = FALSE OR lp.lastSyncedAt < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY))
ORDER BY lp.intentScore DESC, lp.lastVisitAt DESC;

