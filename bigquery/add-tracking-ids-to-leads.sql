-- ============================================
-- Add Tracking IDs to Your Existing Leads Table
-- ============================================
-- This adds a trackingId column to your leads table
-- and generates unique IDs for each lead

-- Step 1: Add trackingId column (if it doesn't exist)
ALTER TABLE `n8n-revenueinstitute.outbound_sales.leads`
ADD COLUMN IF NOT EXISTS trackingId STRING;

-- Step 2: Generate tracking IDs for all leads
-- Using email hash to create deterministic, unique IDs
UPDATE `n8n-revenueinstitute.outbound_sales.leads`
SET trackingId = SUBSTR(TO_HEX(SHA256(LOWER(TRIM(email)))), 1, 8)
WHERE trackingId IS NULL OR trackingId = '';

-- Step 3: Populate identity_map table with lead data
INSERT INTO `n8n-revenueinstitute.outbound_sales.identity_map` 
  (shortId, visitorId, email, emailHash, firstName, lastName, company, 
   campaignId, campaignName, createdAt, expiresAt, clicks, lastClickedAt)
SELECT 
  trackingId as shortId,
  NULL as visitorId,
  email,
  SUBSTR(TO_HEX(SHA256(LOWER(TRIM(email)))), 1, 16) as emailHash,
  firstName,
  lastName,
  company,
  'bulk_import' as campaignId,
  'Bulk Import' as campaignName,
  CURRENT_TIMESTAMP() as createdAt,
  TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 90 DAY) as expiresAt,
  0 as clicks,
  NULL as lastClickedAt
FROM `n8n-revenueinstitute.outbound_sales.leads`
WHERE trackingId IS NOT NULL
  AND trackingId NOT IN (
    SELECT shortId FROM `n8n-revenueinstitute.outbound_sales.identity_map`
  );

-- Step 4: Verify
SELECT 
  COUNT(*) as total_leads,
  COUNT(trackingId) as leads_with_tracking_id,
  COUNT(DISTINCT trackingId) as unique_tracking_ids
FROM `n8n-revenueinstitute.outbound_sales.leads`;

-- Step 5: Sample output
SELECT 
  email,
  firstName,
  lastName,
  company,
  trackingId,
  CONCAT('https://revenueinstitute.com/demo?i=', trackingId) as example_url
FROM `n8n-revenueinstitute.outbound_sales.leads`
WHERE trackingId IS NOT NULL
LIMIT 10;


