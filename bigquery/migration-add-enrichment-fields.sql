-- Migration: Add enrichment fields to events table
-- Run this in BigQuery console to add missing columns
-- Date: 2025-12-01

-- Add missing columns to events table
ALTER TABLE `n8n-revenueinstitute.outbound_sales.events`
ADD COLUMN IF NOT EXISTS ipHash STRING,
ADD COLUMN IF NOT EXISTS companyIdentifier STRING,
ADD COLUMN IF NOT EXISTS continent STRING,
ADD COLUMN IF NOT EXISTS postalCode STRING,
ADD COLUMN IF NOT EXISTS metroCode STRING,
ADD COLUMN IF NOT EXISTS latitude STRING,
ADD COLUMN IF NOT EXISTS longitude STRING,
ADD COLUMN IF NOT EXISTS asOrganization STRING,
ADD COLUMN IF NOT EXISTS acceptLanguage STRING,
ADD COLUMN IF NOT EXISTS refererHeader STRING,
ADD COLUMN IF NOT EXISTS urlParams JSON,
ADD COLUMN IF NOT EXISTS utmSource STRING,
ADD COLUMN IF NOT EXISTS utmMedium STRING,
ADD COLUMN IF NOT EXISTS utmCampaign STRING,
ADD COLUMN IF NOT EXISTS utmTerm STRING,
ADD COLUMN IF NOT EXISTS utmContent STRING,
ADD COLUMN IF NOT EXISTS gclid STRING,
ADD COLUMN IF NOT EXISTS fbclid STRING,
ADD COLUMN IF NOT EXISTS deviceType STRING,
ADD COLUMN IF NOT EXISTS isEUCountry STRING,
ADD COLUMN IF NOT EXISTS tlsVersion STRING,
ADD COLUMN IF NOT EXISTS tlsCipher STRING,
ADD COLUMN IF NOT EXISTS httpProtocol STRING;

-- Verify columns were added
SELECT 
  column_name,
  data_type
FROM `n8n-revenueinstitute.outbound_sales.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'events'
ORDER BY ordinal_position;

