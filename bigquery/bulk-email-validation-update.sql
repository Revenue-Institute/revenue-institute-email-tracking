-- ============================================
-- Bulk Email Validation Update
-- Use this to update email statuses in bulk from external validation service
-- ============================================

-- Option 1: Update from a CSV import (recommended for bulk validation)
-- First, create a temporary table with validation results:

CREATE TEMP TABLE email_validation_results AS
SELECT 
  email,
  email_status  -- 'verified', 'invalid', 'accept_all', 'unverified'
FROM UNNEST([
  STRUCT('john@example.com' AS email, 'verified' AS email_status),
  STRUCT('bad@invalid.com' AS email, 'invalid' AS email_status)
  -- Add more rows here or load from CSV
]) AS validation_data;

-- Then merge into leads table
MERGE `n8n-revenueinstitute.outbound_sales.leads` T
USING email_validation_results S
ON LOWER(TRIM(T.email)) = LOWER(TRIM(S.email))
WHEN MATCHED THEN
  UPDATE SET
    T.email_status = S.email_status,
    T.email_verified_at = CASE 
      WHEN S.email_status = 'verified' THEN CURRENT_TIMESTAMP()
      ELSE T.email_verified_at
    END;


-- ============================================
-- Option 2: Load validation results from Cloud Storage
-- ============================================

-- Step 1: Upload your validation CSV to Google Cloud Storage
-- CSV format: email,email_status
-- Example:
-- john@example.com,verified
-- jane@company.com,invalid
-- team@startup.io,accept_all

-- Step 2: Create external table pointing to CSV
CREATE OR REPLACE EXTERNAL TABLE `n8n-revenueinstitute.outbound_sales.email_validation_temp`
OPTIONS (
  format = 'CSV',
  uris = ['gs://your-bucket/email-validation-results.csv'],
  skip_leading_rows = 1
);

-- Step 3: Merge validation results
MERGE `n8n-revenueinstitute.outbound_sales.leads` T
USING `n8n-revenueinstitute.outbound_sales.email_validation_temp` S
ON LOWER(TRIM(T.email)) = LOWER(TRIM(S.email))
WHEN MATCHED THEN
  UPDATE SET
    T.email_status = S.email_status,
    T.email_verified_at = CASE 
      WHEN S.email_status = 'verified' THEN CURRENT_TIMESTAMP()
      ELSE T.email_verified_at
    END;


-- ============================================
-- Option 3: Mark all bounced emails as invalid
-- ============================================

-- If you have a list of bounced emails from your email service
UPDATE `n8n-revenueinstitute.outbound_sales.leads`
SET 
  email_status = 'invalid',
  email_verified_at = NULL
WHERE email IN (
  'bounced1@example.com',
  'bounced2@example.com'
  -- Add bounced emails here
);


-- ============================================
-- Performance Notes for 1M+ Leads:
-- ============================================
-- ✅ MERGE is more efficient than UPDATE for large datasets
-- ✅ Only updates matching rows (doesn't scan entire table)
-- ✅ BigQuery optimizes these operations automatically
-- ✅ Cost: ~$0.0005 to scan 1M rows (half a cent)
-- ✅ Time: Usually completes in seconds for 1M rows
-- ============================================


-- ============================================
-- Verification Queries
-- ============================================

-- Check validation status distribution
SELECT 
  email_status,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM `n8n-revenueinstitute.outbound_sales.leads`
GROUP BY email_status
ORDER BY count DESC;

-- Check recently verified emails
SELECT 
  email,
  email_status,
  email_verified_at,
  trackingId
FROM `n8n-revenueinstitute.outbound_sales.leads`
WHERE email_verified_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY email_verified_at DESC
LIMIT 100;

-- Count by status
SELECT 
  SUM(CASE WHEN email_status = 'verified' THEN 1 ELSE 0 END) as verified,
  SUM(CASE WHEN email_status = 'unverified' THEN 1 ELSE 0 END) as unverified,
  SUM(CASE WHEN email_status = 'invalid' THEN 1 ELSE 0 END) as invalid,
  SUM(CASE WHEN email_status = 'accept_all' THEN 1 ELSE 0 END) as accept_all,
  COUNT(*) as total
FROM `n8n-revenueinstitute.outbound_sales.leads`;



