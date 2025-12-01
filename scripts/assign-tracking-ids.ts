#!/usr/bin/env node
/**
 * Assign tracking IDs to all leads in BigQuery
 * This adds a trackingId column to your leads table
 * 
 * Usage: npm run assign-tracking-ids
 */

import { BigQuery } from '@google-cloud/bigquery';

interface Args {
  projectId: string;
  dataset: string;
  leadsTable: string;
  credentialsFile?: string;
  batchSize?: number;
  campaignId?: string;
  campaignName?: string;
}

async function main() {
  const args = parseArgs();
  
  console.log('🏷️  Assigning tracking IDs to all leads...\n');
  console.log(`Project: ${args.projectId}`);
  console.log(`Dataset: ${args.dataset}`);
  console.log(`Table: ${args.leadsTable}\n`);
  
  // Initialize BigQuery
  const bigquery = new BigQuery({
    projectId: args.projectId,
    keyFilename: args.credentialsFile
  });
  
  // Step 1: Check if trackingId column exists, if not create it
  console.log('📋 Checking table schema...');
  await ensureTrackingIdColumn(bigquery, args);
  
  // Step 2: Get leads without tracking IDs
  console.log('🔍 Finding leads without tracking IDs...');
  const query = `
    SELECT 
      email,
      firstName,
      lastName,
      company,
      trackingId
    FROM \`${args.dataset}.${args.leadsTable}\`
    WHERE trackingId IS NULL OR trackingId = ''
    LIMIT ${args.batchSize}
  `;
  
  const [leads] = await bigquery.query({ query });
  console.log(`📦 Found ${leads.length} leads needing tracking IDs\n`);
  
  if (leads.length === 0) {
    console.log('✅ All leads already have tracking IDs!');
    return;
  }
  
  // Step 3: Generate tracking IDs
  console.log('🔄 Generating tracking IDs...');
  const identities = await Promise.all(
    leads.map(async (lead: any) => {
      const trackingId = await generateTrackingId(lead.email, args.campaignId || 'default');
      return {
        email: lead.email,
        trackingId,
        firstName: lead.firstName,
        lastName: lead.lastName,
        company: lead.company
      };
    })
  );
  
  console.log('✅ Generated tracking IDs\n');
  
  // Step 4: Update leads table with tracking IDs
  console.log('📝 Updating leads table...');
  await updateLeadsWithTrackingIds(bigquery, args, identities);
  console.log('✅ Updated leads table\n');
  
  // Step 5: Store in identity_map table
  console.log('🗺️  Storing in identity_map...');
  await storeIdentityMap(bigquery, args, identities);
  console.log('✅ Stored in identity_map\n');
  
  console.log('🎉 Complete!');
  console.log(`\n📊 Next steps:`);
  console.log(`1. Sync to Cloudflare KV: npm run sync-kv-from-bigquery`);
  console.log(`2. Use in your emails: {{baseUrl}}/page?i={{trackingId}}`);
  console.log(`\nExample: https://revenueinstitute.com/demo?i={{trackingId}}\n`);
}

async function ensureTrackingIdColumn(bigquery: BigQuery, args: Args): Promise<void> {
  const query = `
    ALTER TABLE \`${args.dataset}.${args.leadsTable}\`
    ADD COLUMN IF NOT EXISTS trackingId STRING
  `;
  
  try {
    await bigquery.query({ query });
    console.log('✅ trackingId column ready\n');
  } catch (error: any) {
    if (error.message?.includes('Already exists')) {
      console.log('✅ trackingId column already exists\n');
    } else {
      throw error;
    }
  }
}

async function generateTrackingId(email: string, campaignId: string): Promise<string> {
  const input = `${email.toLowerCase().trim()}-${campaignId}`;
  const encoder = new TextEncoder();
  const data = encoder.encode(input);
  const hash = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hash));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  
  // Take first 8 chars for clean, short ID
  return hashHex.substring(0, 8);
}

async function updateLeadsWithTrackingIds(
  bigquery: BigQuery, 
  args: Args, 
  identities: any[]
): Promise<void> {
  // Update in batches using MERGE
  const cases = identities.map(id => 
    `WHEN email = '${id.email.replace(/'/g, "\\'")}' THEN '${id.trackingId}'`
  ).join('\n    ');
  
  const emails = identities.map(id => `'${id.email.replace(/'/g, "\\'")}'`).join(', ');
  
  const query = `
    UPDATE \`${args.dataset}.${args.leadsTable}\`
    SET trackingId = CASE
      ${cases}
    END
    WHERE email IN (${emails})
  `;
  
  await bigquery.query({ query });
}

async function storeIdentityMap(
  bigquery: BigQuery,
  args: Args,
  identities: any[]
): Promise<void> {
  const rows = identities.map(id => ({
    shortId: id.trackingId,
    visitorId: null, // Will be assigned on first visit
    email: id.email,
    emailHash: hashEmail(id.email),
    firstName: id.firstName || null,
    lastName: id.lastName || null,
    company: id.company || null,
    campaignId: args.campaignId || 'default',
    campaignName: args.campaignName || 'Default Campaign',
    sequenceStep: null,
    createdAt: new Date().toISOString(),
    expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(), // 90 days
    clicks: 0,
    lastClickedAt: null
  }));
  
  const table = bigquery.dataset(args.dataset).table('identity_map');
  
  await table.insert(rows, {
    skipInvalidRows: true,
    ignoreUnknownValues: false
  });
}

function hashEmail(email: string): string {
  const normalized = email.toLowerCase().trim();
  let hash = 0;
  for (let i = 0; i < normalized.length; i++) {
    const char = normalized.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return hash.toString(36);
}

function parseArgs(): Args {
  const args = process.argv.slice(2);
  const parsed: any = {};
  
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i].replace(/^--/, '');
    const value = args[i + 1];
    parsed[key] = value;
  }
  
  const projectId = parsed.projectId || process.env.BIGQUERY_PROJECT_ID || 'n8n-revenueinstitute';
  const dataset = parsed.dataset || process.env.BIGQUERY_DATASET || 'outbound_sales';
  const leadsTable = parsed.leadsTable || 'leads';
  const credentialsFile = parsed.credentialsFile || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const batchSize = parsed.batchSize ? parseInt(parsed.batchSize) : 10000;
  
  return {
    projectId,
    dataset,
    leadsTable,
    credentialsFile,
    batchSize,
    campaignId: parsed.campaignId,
    campaignName: parsed.campaignName
  };
}

main().catch(error => {
  console.error('❌ Error:', error.message);
  process.exit(1);
});


