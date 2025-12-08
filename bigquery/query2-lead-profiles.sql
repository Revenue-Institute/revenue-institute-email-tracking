-- Query 2: Update Lead Profiles

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



