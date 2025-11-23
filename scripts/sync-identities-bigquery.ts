#!/usr/bin/env node
/**
 * Sync campaign identities to BigQuery
 * Usage: npm run sync-bigquery -- --file campaign-xxx-identities.json
 */

import { readFileSync } from 'fs';
import { BigQuery } from '@google-cloud/bigquery';
import type { LeadIdentity } from '../src/utils/identity-generator';

interface Args {
  file: string;
  projectId: string;
  dataset: string;
  credentialsFile?: string;
}

async function main() {
  const args = parseArgs();
  
  console.log('📊 Syncing identities to BigQuery...\n');
  
  // Initialize BigQuery client
  const bigquery = new BigQuery({
    projectId: args.projectId,
    keyFilename: args.credentialsFile
  });
  
  // Read identities file
  const identitiesJson = readFileSync(args.file, 'utf-8');
  const identities: LeadIdentity[] = JSON.parse(identitiesJson);
  
  console.log(`📦 Loaded ${identities.length} identities\n`);
  
  // Transform for BigQuery
  const rows = identities.map(identity => ({
    shortId: identity.shortId,
    visitorId: identity.visitorId,
    email: identity.email,
    emailHash: hashEmail(identity.email),
    firstName: identity.firstName || null,
    lastName: identity.lastName || null,
    company: identity.company || null,
    campaignId: identity.campaignId,
    campaignName: identity.campaignName,
    sequenceStep: identity.sequenceStep || null,
    createdAt: new Date(identity.createdAt).toISOString(),
    expiresAt: new Date(identity.expiresAt).toISOString(),
    clicks: 0,
    lastClickedAt: null
  }));
  
  // Insert into BigQuery
  const table = bigquery.dataset(args.dataset).table('identity_map');
  
  console.log('🔄 Inserting rows into BigQuery...');
  
  try {
    await table.insert(rows, {
      skipInvalidRows: false,
      ignoreUnknownValues: false,
      createInsertId: true
    });
    
    console.log(`✅ Successfully inserted ${rows.length} identities`);
    console.log(`   Dataset: ${args.dataset}`);
    console.log(`   Table: identity_map\n`);
    
    // Also create initial lead profiles
    console.log('🔄 Creating initial lead profiles...');
    
    const profileRows = identities.map(identity => ({
      visitorId: identity.shortId, // Use shortId as initial visitorId
      campaignId: identity.campaignId,
      campaignName: identity.campaignName,
      email: identity.email,
      emailSHA256: null,
      firstName: identity.firstName || null,
      lastName: identity.lastName || null,
      company: identity.company || null,
      totalSessions: 0,
      totalPageviews: 0,
      totalActiveTime: 0,
      intentScore: 0,
      engagementLevel: 'cold',
      pricingPageVisits: 0,
      caseStudyViews: 0,
      productPageViews: 0,
      formSubmissions: 0,
      videoCompletions: 0,
      syncedToCRM: false
    }));
    
    const profilesTable = bigquery.dataset(args.dataset).table('lead_profiles');
    await profilesTable.insert(profileRows, {
      skipInvalidRows: true,
      ignoreUnknownValues: false
    });
    
    console.log(`✅ Created ${profileRows.length} lead profiles\n`);
    console.log('✨ Sync complete!');
    
  } catch (error: any) {
    if (error.name === 'PartialFailureError') {
      console.error('❌ Some rows failed to insert:');
      console.error(JSON.stringify(error.errors, null, 2));
    } else {
      throw error;
    }
  }
}

function hashEmail(email: string): string {
  // Simple hash for demo - in production use proper crypto
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
  
  // Read from env if not provided
  const projectId = parsed.projectId || process.env.BIGQUERY_PROJECT_ID;
  const dataset = parsed.dataset || process.env.BIGQUERY_DATASET || 'outbound_sales';
  const credentialsFile = parsed.credentialsFile || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  
  if (!parsed.file) {
    console.error('❌ Error: --file is required');
    console.log('\nUsage:');
    console.log('  npm run sync-bigquery -- --file campaign-xxx-identities.json');
    console.log('\nOr set environment variables:');
    console.log('  BIGQUERY_PROJECT_ID');
    console.log('  BIGQUERY_DATASET (default: outbound_sales)');
    console.log('  GOOGLE_APPLICATION_CREDENTIALS');
    process.exit(1);
  }
  
  if (!projectId) {
    console.error('❌ Error: Missing BIGQUERY_PROJECT_ID');
    process.exit(1);
  }
  
  return {
    file: parsed.file,
    projectId,
    dataset,
    credentialsFile
  };
}

main().catch(error => {
  console.error('❌ Error:', error.message);
  process.exit(1);
});

