-- ============================================
-- Sync ALL Leads to identity_map Table
-- Run this once to populate identity_map with all your leads
-- ============================================

-- Insert all leads that aren't already in identity_map
INSERT INTO `n8n-revenueinstitute.outbound_sales.identity_map` 
  (shortId, visitorId, email, emailHash, firstName, lastName, company, 
   campaignId, campaignName, createdAt, expiresAt, clicks, lastClickedAt)
SELECT 
  l.trackingId as shortId,
  CAST(NULL AS STRING) as visitorId,
  l.email,
  SUBSTR(TO_HEX(SHA256(LOWER(TRIM(l.email)))), 1, 16) as emailHash,
  l.person_name as firstName,
  CAST(NULL AS STRING) as lastName,
  l.company_name as company,
  'bulk_import' as campaignId,
  'Bulk Import' as campaignName,
  CURRENT_TIMESTAMP() as createdAt,
  TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 90 DAY) as expiresAt,
  0 as clicks,
  CAST(NULL AS TIMESTAMP) as lastClickedAt
FROM `n8n-revenueinstitute.outbound_sales.leads` l
WHERE l.trackingId IS NOT NULL
  AND l.trackingId NOT IN (
    SELECT shortId FROM `n8n-revenueinstitute.outbound_sales.identity_map`
  );

-- Verify count
SELECT 
  (SELECT COUNT(*) FROM `n8n-revenueinstitute.outbound_sales.leads`) as total_leads,
  (SELECT COUNT(*) FROM `n8n-revenueinstitute.outbound_sales.identity_map`) as mapped_leads;


