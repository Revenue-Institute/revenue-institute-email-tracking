#!/usr/bin/env node
/**
 * CLI Script to create a new campaign and generate tracking URLs
 * Usage: npm run create-campaign -- --campaign "Q1 Campaign" --file leads.csv
 */

import { readFileSync, writeFileSync } from 'fs';
import { parse } from 'csv-parse/sync';
import { 
  createIdentitiesBatch, 
  generateCampaignCSV,
  type CampaignLead 
} from '../src/utils/identity-generator';

interface Args {
  campaign: string;
  campaignId?: string;
  file: string;
  output?: string;
  baseUrl: string;
  landingPage?: string;
  expirationDays?: number;
}

async function main() {
  const args = parseArgs();
  
  console.log('📧 Creating campaign tracking URLs...\n');
  console.log(`Campaign: ${args.campaign}`);
  console.log(`Input file: ${args.file}`);
  console.log(`Base URL: ${args.baseUrl}\n`);
  
  // Read leads from CSV
  const csvContent = readFileSync(args.file, 'utf-8');
  const records = parse(csvContent, {
    columns: true,
    skip_empty_lines: true
  });
  
  // Map to CampaignLead format
  const leads: CampaignLead[] = records.map((record: any) => ({
    email: record.email || record.Email,
    firstName: record.firstName || record['First Name'] || record.first_name,
    lastName: record.lastName || record['Last Name'] || record.last_name,
    company: record.company || record.Company
  }));
  
  console.log(`✅ Loaded ${leads.length} leads\n`);
  
  // Generate campaign ID if not provided
  const campaignId = args.campaignId || generateCampaignId(args.campaign);
  
  // Create identities
  console.log('🔄 Generating tracking IDs...');
  const identities = await createIdentitiesBatch({
    campaignId,
    campaignName: args.campaign,
    leads,
    expirationDays: args.expirationDays || 90
  });
  
  console.log('✅ Generated tracking IDs\n');
  
  // Generate output CSV
  const csv = generateCampaignCSV(
    identities, 
    args.baseUrl, 
    args.landingPage || '/'
  );
  
  const outputFile = args.output || `campaign-${campaignId}-urls.csv`;
  writeFileSync(outputFile, csv);
  
  console.log(`✅ Saved tracking URLs to: ${outputFile}\n`);
  
  // Display sample URLs
  console.log('📊 Sample tracking URLs:');
  identities.slice(0, 3).forEach(identity => {
    console.log(`  ${identity.email}: ${identity.shortId}`);
  });
  
  console.log('\n📝 Next steps:');
  console.log('1. Upload identities to Cloudflare KV (run: npm run sync-identities)');
  console.log('2. Upload identities to BigQuery (run: npm run sync-bigquery)');
  console.log(`3. Import ${outputFile} to your email tool (Smartlead, Instantly, etc.)`);
  console.log('4. Use the "Tracking URL" column as your email link\n');
  
  // Save identities JSON for syncing
  const identitiesFile = `campaign-${campaignId}-identities.json`;
  writeFileSync(identitiesFile, JSON.stringify(identities, null, 2));
  console.log(`💾 Saved identity data to: ${identitiesFile}`);
}

function parseArgs(): Args {
  const args = process.argv.slice(2);
  const parsed: any = {};
  
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i].replace(/^--/, '');
    const value = args[i + 1];
    parsed[key] = value;
  }
  
  // Validate required args
  if (!parsed.campaign) {
    console.error('❌ Error: --campaign is required');
    console.log('\nUsage:');
    console.log('  npm run create-campaign -- \\');
    console.log('    --campaign "Q1 Outbound" \\');
    console.log('    --file leads.csv \\');
    console.log('    --baseUrl https://yourdomain.com \\');
    console.log('    --landingPage /demo (optional) \\');
    console.log('    --output campaign-urls.csv (optional)');
    process.exit(1);
  }
  
  if (!parsed.file) {
    console.error('❌ Error: --file is required');
    process.exit(1);
  }
  
  if (!parsed.baseUrl) {
    console.error('❌ Error: --baseUrl is required');
    process.exit(1);
  }
  
  return {
    campaign: parsed.campaign,
    campaignId: parsed.campaignId,
    file: parsed.file,
    output: parsed.output,
    baseUrl: parsed.baseUrl,
    landingPage: parsed.landingPage,
    expirationDays: parsed.expirationDays ? parseInt(parsed.expirationDays) : 90
  };
}

function generateCampaignId(name: string): string {
  const slug = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .substring(0, 30);
  const timestamp = Date.now().toString(36);
  return `${slug}-${timestamp}`;
}

main().catch(error => {
  console.error('❌ Error:', error.message);
  process.exit(1);
});


