-- ============================================
-- Batched Email Validation Update
-- Update 1M emails in safe batches
-- ============================================

-- PREREQUISITE: Load your validation CSV into temp table
-- CREATE EXTERNAL TABLE `email_validation_temp` ...

-- ============================================
-- Strategy: Update in alphabetical batches
-- Each batch processes ~100-150K rows
-- ============================================

-- Batch 1: Emails starting with a-d (approx 150K)
MERGE `n8n-revenueinstitute.outbound_sales.leads` T
USING (
  SELECT email, email_status 
  FROM `n8n-revenueinstitute.outbound_sales.email_validation_temp`
  WHERE SUBSTR(LOWER(email), 1, 1) BETWEEN 'a' AND 'd'
) S
ON LOWER(TRIM(T.email)) = LOWER(TRIM(S.email))
WHEN MATCHED THEN UPDATE SET T.email_status = S.email_status;

-- Check progress after Batch 1
SELECT 
  email_status,
  COUNT(*) as count
FROM `n8n-revenueinstitute.outbound_sales.leads`
WHERE SUBSTR(LOWER(email), 1, 1) BETWEEN 'a' AND 'd'
GROUP BY email_status;


-- Batch 2: Emails starting with e-h (approx 150K)
MERGE `n8n-revenueinstitute.outbound_sales.leads` T
USING (
  SELECT email, email_status 
  FROM `n8n-revenueinstitute.outbound_sales.email_validation_temp`
  WHERE SUBSTR(LOWER(email), 1, 1) BETWEEN 'e' AND 'h'
) S
ON LOWER(TRIM(T.email)) = LOWER(TRIM(S.email))
WHEN MATCHED THEN UPDATE SET T.email_status = S.email_status;


-- Batch 3: Emails starting with i-l (approx 150K)
MERGE `n8n-revenueinstitute.outbound_sales.leads` T
USING (
  SELECT email, email_status 
  FROM `n8n-revenueinstitute.outbound_sales.email_validation_temp`
  WHERE SUBSTR(LOWER(email), 1, 1) BETWEEN 'i' AND 'l'
) S
ON LOWER(TRIM(T.email)) = LOWER(TRIM(S.email))
WHEN MATCHED THEN UPDATE SET T.email_status = S.email_status;


-- Batch 4: Emails starting with m-p (approx 150K)
MERGE `n8n-revenueinstitute.outbound_sales.leads` T
USING (
  SELECT email, email_status 
  FROM `n8n-revenueinstitute.outbound_sales.email_validation_temp`
  WHERE SUBSTR(LOWER(email), 1, 1) BETWEEN 'm' AND 'p'
) S
ON LOWER(TRIM(T.email)) = LOWER(TRIM(S.email))
WHEN MATCHED THEN UPDATE SET T.email_status = S.email_status;


-- Batch 5: Emails starting with q-t (approx 150K)
MERGE `n8n-revenueinstitute.outbound_sales.leads` T
USING (
  SELECT email, email_status 
  FROM `n8n-revenueinstitute.outbound_sales.email_validation_temp`
  WHERE SUBSTR(LOWER(email), 1, 1) BETWEEN 'q' AND 't'
) S
ON LOWER(TRIM(T.email)) = LOWER(TRIM(S.email))
WHEN MATCHED THEN UPDATE SET T.email_status = S.email_status;


-- Batch 6: Emails starting with u-z (approx 150K)
MERGE `n8n-revenueinstitute.outbound_sales.leads` T
USING (
  SELECT email, email_status 
  FROM `n8n-revenueinstitute.outbound_sales.email_validation_temp`
  WHERE SUBSTR(LOWER(email), 1, 1) BETWEEN 'u' AND 'z'
) S
ON LOWER(TRIM(T.email)) = LOWER(TRIM(S.email))
WHEN MATCHED THEN UPDATE SET T.email_status = S.email_status;


-- Batch 7: Emails starting with numbers/special chars
MERGE `n8n-revenueinstitute.outbound_sales.leads` T
USING (
  SELECT email, email_status 
  FROM `n8n-revenueinstitute.outbound_sales.email_validation_temp`
  WHERE SUBSTR(LOWER(email), 1, 1) NOT BETWEEN 'a' AND 'z'
) S
ON LOWER(TRIM(T.email)) = LOWER(TRIM(S.email))
WHEN MATCHED THEN UPDATE SET T.email_status = S.email_status;


-- ============================================
-- Final Verification
-- ============================================

SELECT 
  email_status,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM `n8n-revenueinstitute.outbound_sales.leads`
GROUP BY email_status
ORDER BY count DESC;

-- ============================================
-- Performance Notes:
-- - Total time: 5-10 minutes (all batches)
-- - Cost: Same as single MERGE (~$0.002-0.005)
-- - Advantage: Can monitor progress between batches
-- - Each batch: ~10-15 seconds
-- ============================================



