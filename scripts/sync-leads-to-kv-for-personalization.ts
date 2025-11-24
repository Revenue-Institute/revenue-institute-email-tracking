#!/usr/bin/env node
/**
 * Sync leads from BigQuery to Cloudflare KV for instant personalization
 * This pre-loads all lead data so personalization works immediately
 * 
 * Usage: npm run sync-personalization
 */

import { BigQuery } from '@google-cloud/bigquery';

async function main() {
  console.log('📊 Syncing leads to Cloudflare KV for personalization...\n');
  
  const projectId = process.env.BIGQUERY_PROJECT_ID || 'n8n-revenueinstitute';
  const dataset = 'outbound_sales';
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID || 'e406ada6b728029380a6465d03932cb8';
  const namespaceId = process.env.KV_IDENTITY_STORE_ID || '84ed00a75f6f44adb62d4d7bbec149ae';
  const apiToken = process.env.CLOUDFLARE_API_TOKEN;
  
  if (!apiToken) {
    console.error('❌ CLOUDFLARE_API_TOKEN environment variable required');
    console.log('Get from: https://dash.cloudflare.com/profile/api-tokens');
    process.exit(1);
  }
  
  // Initialize BigQuery
  const bigquery = new BigQuery({ projectId });
  
  // Query all leads with tracking IDs
  console.log('🔍 Fetching leads from BigQuery...');
  const query = `
    SELECT 
      l.trackingId,
      l.email,
      l.person_name,
      l.company_name,
      l.company_website,
      l.company_description,
      l.company_size,
      l.revenue,
      l.industry,
      l.department,
      l.job_title,
      l.seniority,
      l.phone,
      l.linkedin,
      l.company_linkedin
    FROM \`${dataset}.leads\` l
    WHERE l.trackingId IS NOT NULL
    LIMIT 10000  -- Start with first 10k, can increase
  `;
  
  const [leads] = await bigquery.query({ query });
  console.log(`✅ Fetched ${leads.length} leads\n`);
  
  // Batch upload to KV (100 at a time)
  const batchSize = 100;
  let uploaded = 0;
  
  for (let i = 0; i < leads.length; i += batchSize) {
    const batch = leads.slice(i, i + batchSize);
    
    // Prepare KV entries
    const kvEntries = batch.map((lead: any) => ({
      key: lead.trackingId,
      value: JSON.stringify({
        // Personal
        firstName: (lead.person_name || '').split(' ')[0],
        lastName: (lead.person_name || '').split(' ').slice(1).join(' '),
        personName: lead.person_name,
        email: lead.email,
        phone: lead.phone,
        linkedin: lead.linkedin,
        
        // Company
        company: lead.company_name,
        companyName: lead.company_name,
        domain: lead.company_website || (lead.email ? lead.email.split('@')[1] : null),
        companyWebsite: lead.company_website,
        companyDescription: lead.company_description,
        companySize: lead.company_size,
        revenue: lead.revenue,
        industry: lead.industry,
        companyLinkedin: lead.company_linkedin,
        
        // Job
        jobTitle: lead.job_title,
        seniority: lead.seniority,
        department: lead.department,
        
        // Status
        isFirstVisit: true,
        intentScore: 0,
        engagementLevel: 'new'
      }),
      expiration_ttl: 90 * 24 * 60 * 60 // 90 days
    }));
    
    // Upload to KV using bulk API
    const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/storage/kv/namespaces/${namespaceId}/bulk`;
    
    console.log(`Uploading batch ${Math.floor(i / batchSize) + 1}...`);
    
    const response = await fetch(url, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${apiToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(kvEntries)
    });
    
    if (!response.ok) {
      const error = await response.text();
      console.error(`❌ Batch ${i / batchSize + 1} failed:`, error);
    } else {
      uploaded += batch.length;
      console.log(`✅ Uploaded ${uploaded}/${leads.length} leads to KV`);
    }
  }
  
  console.log('\n🎉 Sync complete!');
  console.log(`\n📊 Summary:`);
  console.log(`- Total leads synced: ${uploaded}`);
  console.log(`- KV namespace: ${namespaceId}`);
  console.log(`- Expiration: 90 days`);
  console.log(`\n✨ Personalization now works instantly for all synced leads!`);
}

main().catch(error => {
  console.error('❌ Error:', error.message);
  process.exit(1);
});

