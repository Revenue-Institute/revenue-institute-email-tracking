-- ============================================
-- ALL SCHEDULED QUERIES - READY TO DEPLOY
-- ============================================
-- Copy each query separately into BigQuery Scheduled Queries
-- ============================================

-- ============================================
-- QUERY 1: Aggregate Events into Sessions
-- Schedule: Every 5 minutes (*/5 * * * *)
-- Name: "Aggregate Events to Sessions"
-- ============================================

MERGE `n8n-revenueinstitute.outbound_sales.sessions` T
USING (
  WITH session_events AS (
    SELECT 
      e.sessionId,
      COALESCE(e.visitorId, sim.identifiedVisitorId) as visitorId,
      MIN(e.timestamp) as firstEvent,
      MAX(e.timestamp) as lastEvent,
      COUNT(*) as eventCount,
      
      -- Pageview metrics
      COUNTIF(e.type = 'pageview') as pageviews,
      COUNTIF(e.type = 'click') as clicks,
      
      -- Scroll metrics
      MAX(CAST(JSON_EXTRACT_SCALAR(e.data, '$.depth') AS INT64)) as maxScrollDepth,
      
      -- Form metrics
      COUNTIF(e.type = 'form_start') as formsStarted,
      COUNTIF(e.type = 'form_submit') as formsSubmitted,
      
      -- Video metrics
      COUNTIF(e.type = 'video_complete') as videosWatched,
      
      -- Active time
      MAX(CAST(JSON_EXTRACT_SCALAR(e.data, '$.activeTime') AS INT64)) as activeTime,
      
      -- Entry/Exit
      ARRAY_AGG(e.url ORDER BY e.timestamp LIMIT 1)[OFFSET(0)] as entryUrl,
      ARRAY_AGG(e.referrer ORDER BY e.timestamp LIMIT 1)[OFFSET(0)] as entryReferrer,
      ARRAY_AGG(e.url ORDER BY e.timestamp DESC LIMIT 1)[OFFSET(0)] as exitUrl,
      
      -- Device info
      ARRAY_AGG(e.userAgent ORDER BY e.timestamp LIMIT 1)[OFFSET(0)] as userAgent,
      ARRAY_AGG(e.country ORDER BY e.timestamp LIMIT 1)[OFFSET(0)] as country,
      ARRAY_AGG(e.city ORDER BY e.timestamp LIMIT 1)[OFFSET(0)] as city,
      ARRAY_AGG(e.region ORDER BY e.timestamp LIMIT 1)[OFFSET(0)] as region
      
    FROM `n8n-revenueinstitute.outbound_sales.events` e
    LEFT JOIN `n8n-revenueinstitute.outbound_sales.session_identity_map` sim ON e.sessionId = sim.sessionId
    WHERE e.timestamp >= UNIX_MILLIS(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR))
    GROUP BY e.sessionId, COALESCE(e.visitorId, sim.identifiedVisitorId)
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
      
      -- Calculate engagement score (0-100)
      LEAST(100, (
        (pageviews * 5) +
        (clicks * 3) +
        (COALESCE(maxScrollDepth, 0) / 2) +
        (formsStarted * 15) +
        (formsSubmitted * 30) +
        (videosWatched * 20) +
        (CAST(activeTime AS FLOAT64) / 10)
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
    _updatedAt = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (
    sessionId, visitorId, startTime, endTime, duration, activeTime,
    entryUrl, entryReferrer, exitUrl, pageviews, clicks, maxScrollDepth,
    formsStarted, formsSubmitted, videosWatched, device, browser, os,
    country, city, region, engagementScore, _updatedAt
  )
  VALUES (
    S.sessionId, S.visitorId, S.startTime, S.endTime, S.duration, S.activeTime,
    S.entryUrl, S.entryReferrer, S.exitUrl, S.pageviews, S.clicks, S.maxScrollDepth,
    S.formsStarted, S.formsSubmitted, S.videosWatched, S.device, S.browser, S.os,
    S.country, S.city, S.region, S.engagementScore, CURRENT_TIMESTAMP()
  );


-- ============================================
-- QUERY 2: Update Lead Profiles
-- Schedule: Every 15 minutes (*/15 * * * *)
-- Name: "Update Lead Profiles"
-- ============================================

MERGE `n8n-revenueinstitute.outbound_sales.lead_profiles` T
USING (
  WITH 
  -- Include de-anonymized sessions
  all_visitor_ids AS (
    SELECT DISTINCT
      COALESCE(s.visitorId, sim.identifiedVisitorId) as visitorId
    FROM `n8n-revenueinstitute.outbound_sales.sessions` s
    LEFT JOIN `n8n-revenueinstitute.outbound_sales.session_identity_map` sim ON s.sessionId = sim.sessionId
    WHERE COALESCE(s.visitorId, sim.identifiedVisitorId) IS NOT NULL
      AND s.startTime >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
  ),
  visitor_aggregates AS (
    SELECT 
      COALESCE(s.visitorId, sim.identifiedVisitorId) as visitorId,
      COUNT(DISTINCT s.sessionId) as totalSessions,
      SUM(s.pageviews) as totalPageviews,
      SUM(s.activeTime) as totalActiveTime,
      MIN(s.startTime) as firstVisitAt,
      MAX(s.endTime) as lastVisitAt,
      
      -- Intent signals
      SUM(s.formsSubmitted) as formSubmissions,
      SUM(s.videosWatched) as videoCompletions,
      
      -- Return visits
      COUNT(DISTINCT DATE(s.startTime)) - 1 as returnVisits
      
    FROM `n8n-revenueinstitute.outbound_sales.sessions` s
    LEFT JOIN `n8n-revenueinstitute.outbound_sales.session_identity_map` sim ON s.sessionId = sim.sessionId
    WHERE COALESCE(s.visitorId, sim.identifiedVisitorId) IS NOT NULL
      AND s.startTime >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
    GROUP BY COALESCE(s.visitorId, sim.identifiedVisitorId)
  ),
  email_data AS (
    SELECT DISTINCT
      COALESCE(e.visitorId, sim.identifiedVisitorId) as visitorId,
      ARRAY_AGG(JSON_EXTRACT_SCALAR(e.data, '$.email_sha256') IGNORE NULLS ORDER BY e.timestamp DESC LIMIT 1)[OFFSET(0)] as emailSHA256,
      ARRAY_AGG(JSON_EXTRACT_SCALAR(e.data, '$.email_sha1') IGNORE NULLS ORDER BY e.timestamp DESC LIMIT 1)[OFFSET(0)] as emailSHA1
    FROM `n8n-revenueinstitute.outbound_sales.events` e
    LEFT JOIN `n8n-revenueinstitute.outbound_sales.session_identity_map` sim ON e.sessionId = sim.sessionId
    WHERE e.type = 'form_submit'
      AND JSON_EXTRACT_SCALAR(e.data, '$.email_sha256') IS NOT NULL
    GROUP BY COALESCE(e.visitorId, sim.identifiedVisitorId)
  ),
  identity_data AS (
    SELECT 
      l.trackingId as visitorId,
      CAST(NULL AS STRING) as campaignId,
      CAST(NULL AS STRING) as campaignName,
      l.email,
      l.firstName,
      l.lastName,
      l.company_name as company
    FROM `n8n-revenueinstitute.outbound_sales.leads` l
    WHERE l.trackingId IS NOT NULL
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
      
      -- Engagement (0-50 points)
      LEAST(50, va.totalPageviews * 2 + (va.totalActiveTime / 60)) +
      
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
    formSubmissions, videoCompletions, intentScore, engagementLevel, _createdAt, _updatedAt
  )
  VALUES (
    S.visitorId, S.campaignId, S.campaignName, S.email, S.emailSHA256, S.emailSHA1,
    S.firstName, S.lastName, S.company, S.totalSessions, S.totalPageviews,
    S.totalActiveTime, S.firstVisitAt, S.lastVisitAt, S.returnVisits,
    S.formSubmissions, S.videoCompletions, S.intentScore,
    CASE
      WHEN S.intentScore >= 80 THEN 'burning'
      WHEN S.intentScore >= 60 THEN 'hot'
      WHEN S.intentScore >= 40 THEN 'warm'
      ELSE 'cold'
    END,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
  );


-- ============================================
-- QUERY 3: De-Anonymize Visitor Sessions
-- Schedule: Every 15 minutes (*/15 * * * *)
-- Name: "De-Anonymize Visitor Sessions"
-- ============================================

WITH email_captures AS (
  -- Find email_identified or form_submit events with email hashes
  SELECT DISTINCT
    sessionId,
    JSON_EXTRACT_SCALAR(data, '$.emailHash') as emailHash,
    timestamp
  FROM `n8n-revenueinstitute.outbound_sales.events`
  WHERE type IN ('email_identified', 'form_submit')
    AND JSON_EXTRACT_SCALAR(data, '$.emailHash') IS NOT NULL
    AND visitorId IS NULL  -- Was anonymous
    AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
),

matched_identities AS (
  -- Match email hashes to known leads
  SELECT 
    ec.sessionId,
    ec.emailHash,
    l.trackingId,
    l.email,
    l.person_name,
    l.company_name
  FROM email_captures ec
  JOIN `n8n-revenueinstitute.outbound_sales.leads` l
    ON SUBSTR(TO_HEX(SHA256(LOWER(TRIM(l.email)))), 1, 64) = ec.emailHash
  WHERE l.trackingId IS NOT NULL
)

-- Insert de-anonymized mappings
INSERT INTO `n8n-revenueinstitute.outbound_sales.session_identity_map`
  (sessionId, originalVisitorId, identifiedVisitorId, email, emailHash, 
   identifiedAt, identificationMethod, eventsCount)
SELECT 
  mi.sessionId,
  CAST(NULL AS STRING) as originalVisitorId,
  mi.trackingId as identifiedVisitorId,
  mi.email,
  mi.emailHash,
  CURRENT_TIMESTAMP() as identifiedAt,
  'form_email_capture' as identificationMethod,
  COUNT(e.type) as eventsCount
FROM matched_identities mi
JOIN `n8n-revenueinstitute.outbound_sales.events` e ON mi.sessionId = e.sessionId
WHERE mi.sessionId NOT IN (
  -- Don't duplicate existing mappings
  SELECT sessionId FROM `n8n-revenueinstitute.outbound_sales.session_identity_map`
)
GROUP BY mi.sessionId, mi.trackingId, mi.email, mi.emailHash;

