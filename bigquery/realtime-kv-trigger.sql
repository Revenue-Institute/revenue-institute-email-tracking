-- ============================================
-- Real-Time KV Sync Trigger
-- Schedule: Every 5 minutes (288 times per day!)
-- Detects new leads and triggers instant KV sync
-- ============================================

-- Check for new leads added in last 10 minutes
-- If found, trigger Cloudflare webhook for instant sync

DECLARE new_lead_count INT64;
DECLARE webhook_url STRING DEFAULT 'https://intel.revenueinstitute.com/sync-kv-now';
DECLARE auth_token STRING DEFAULT 'YOUR_EVENT_SIGNING_SECRET_HERE';

-- Count new leads
SET new_lead_count = (
  SELECT COUNT(*)
  FROM `n8n-revenueinstitute.outbound_sales.leads`
  WHERE trackingId IS NOT NULL
    AND inserted_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
);

-- If new leads exist, trigger webhook
IF new_lead_count > 0 THEN
  -- Call webhook using BigQuery's HTTP function (requires setup)
  -- Or use this query to log, then external tool monitors and triggers
  SELECT 
    new_lead_count as leads_to_sync,
    'trigger_webhook' as action,
    CURRENT_TIMESTAMP() as trigger_time;
    
  -- Note: BigQuery can't directly call HTTP endpoints
  -- Use Cloud Scheduler to run this query, then trigger webhook based on result
  -- Or use external monitoring tool
END IF;

-- ============================================
-- Alternative: Export to Pub/Sub (requires setup)
-- ============================================
-- EXPORT DATA OPTIONS(
--   uri='pubsub://projects/n8n-revenueinstitute/topics/lead-updates',
--   format='JSON'
-- ) AS
-- SELECT trackingId, person_name, email, company_name
-- FROM `n8n-revenueinstitute.outbound_sales.leads`
-- WHERE inserted_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE);







