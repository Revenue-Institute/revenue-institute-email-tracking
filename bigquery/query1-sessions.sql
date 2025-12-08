-- Query 1: Aggregate Events into Sessions
-- This query runs separately

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
      
      -- High-intent pages
      ARRAY_AGG(DISTINCT CASE WHEN e.url LIKE '%/pricing%' OR e.url LIKE '%/demo%' OR e.url LIKE '%/contact%' THEN e.url END IGNORE NULLS) as highIntentPages,
      
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
      
      LEAST(100, (
        (pageviews * 5) +
        (clicks * 3) +
        (COALESCE(maxScrollDepth, 0) / 2) +
        (formsStarted * 15) +
        (formsSubmitted * 30) +
        (videosWatched * 20) +
        (CAST(activeTime AS FLOAT64) / 10) +
        (ARRAY_LENGTH(COALESCE(highIntentPages, [])) * 15)
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



