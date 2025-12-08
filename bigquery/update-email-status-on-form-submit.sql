-- ============================================
-- Scheduled Query: Mark Emails as Verified on Form Submit
-- Schedule: Every 15 minutes (*/15 * * * *)
-- Purpose: Update email_status when users submit forms
-- ============================================

-- When someone fills out a form, mark their email as verified
MERGE `n8n-revenueinstitute.outbound_sales.leads` T
USING (
  -- Find form submissions with email hashes from last hour
  WITH form_submissions AS (
    SELECT DISTINCT
      JSON_EXTRACT_SCALAR(data, '$.emailHash') as emailHash,
      MAX(TIMESTAMP_MILLIS(timestamp)) as last_submitted
    FROM `n8n-revenueinstitute.outbound_sales.events`
    WHERE type IN ('form_submit', 'email_identified')
      AND JSON_EXTRACT_SCALAR(data, '$.emailHash') IS NOT NULL
      AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
    GROUP BY emailHash
  )
  
  -- Match to leads table
  SELECT 
    l.trackingId,
    l.email,
    fs.last_submitted as verified_at
  FROM `n8n-revenueinstitute.outbound_sales.leads` l
  JOIN form_submissions fs
    ON SUBSTR(TO_HEX(SHA256(LOWER(TRIM(l.email)))), 1, 64) = fs.emailHash
  WHERE l.email_status != 'verified'  -- Only update if not already verified
) S
ON T.trackingId = S.trackingId
WHEN MATCHED THEN
  UPDATE SET
    email_status = 'verified',
    email_verified_at = S.verified_at;

-- ============================================
-- Performance Notes:
-- - Only scans events from last hour (very fast)
-- - Only updates leads that aren't already verified (minimal writes)
-- - Uses email hash matching (same as de-anonymization)
-- ============================================



