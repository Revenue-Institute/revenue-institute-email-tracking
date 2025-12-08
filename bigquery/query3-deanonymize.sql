-- Query 3: De-Anonymize Visitor Sessions

INSERT INTO `n8n-revenueinstitute.outbound_sales.session_identity_map`
  (sessionId, originalVisitorId, identifiedVisitorId, email, emailHash, 
   identifiedAt, identificationMethod, eventsCount)
WITH email_captures AS (
  SELECT DISTINCT
    sessionId,
    JSON_EXTRACT_SCALAR(data, '$.emailHash') as emailHash,
    timestamp
  FROM `n8n-revenueinstitute.outbound_sales.events`
  WHERE type IN ('email_identified', 'form_submit')
    AND JSON_EXTRACT_SCALAR(data, '$.emailHash') IS NOT NULL
    AND visitorId IS NULL
    AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
),
matched_identities AS (
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
  SELECT sessionId FROM `n8n-revenueinstitute.outbound_sales.session_identity_map`
)
GROUP BY mi.sessionId, mi.trackingId, mi.email, mi.emailHash;

