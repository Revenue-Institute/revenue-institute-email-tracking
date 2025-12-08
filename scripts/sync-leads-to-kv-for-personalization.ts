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
  
  // Query all leads with tracking IDs (NO LIMIT - sync everyone!)
  console.log('🔍 Fetching leads from BigQuery...');
  const query = `
    WITH behavioral_data AS (
      SELECT 
        visitorId,
        COUNT(DISTINCT sessionId) as totalSessions,
        COUNT(DISTINCT CASE WHEN type = 'pageview' THEN timestamp END) as totalPageviews,
        MAX(TIMESTAMP_MILLIS(timestamp)) as lastVisit,
        MIN(TIMESTAMP_MILLIS(timestamp)) as firstVisit,
        COUNTIF(url LIKE '%/pricing%') > 0 as viewedPricing,
        COUNTIF(url LIKE '%/demo%') > 0 as requestedDemo,
        COUNTIF(type = 'form_submit') > 0 as submittedForm
      FROM \`${dataset}.events\`
      WHERE visitorId IS NOT NULL
        AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
      GROUP BY visitorId
    ),
    campaign_data AS (
      SELECT 
        trackingId,
        ARRAY_AGG(STRUCT(
          campaignId,
          campaignName,
          status
        ) ORDER BY addedAt DESC LIMIT 5) as campaigns,
        COUNT(*) as totalCampaigns
      FROM \`${dataset}.campaign_members\`
      GROUP BY trackingId
    )
    SELECT 
      l.trackingId,
      l.email,
      l.firstName,
      l.lastName,
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
      l.company_linkedin,
      
      -- Behavioral data
      COALESCE(b.totalSessions, 0) as totalSessions,
      COALESCE(b.totalPageviews, 0) as totalPageviews,
      b.lastVisit,
      b.firstVisit,
      COALESCE(b.viewedPricing, FALSE) as viewedPricing,
      COALESCE(b.requestedDemo, FALSE) as requestedDemo,
      COALESCE(b.submittedForm, FALSE) as submittedForm,
      b.visitorId IS NOT NULL as hasVisited,
      
      -- Campaign data
      COALESCE(c.totalCampaigns, 0) as totalCampaigns,
      TO_JSON_STRING(c.campaigns) as campaigns
      
    FROM \`${dataset}.leads\` l
    LEFT JOIN behavioral_data b ON l.trackingId = b.visitorId
    LEFT JOIN campaign_data c ON l.trackingId = c.trackingId
    WHERE l.trackingId IS NOT NULL
    LIMIT 1000000  -- Sync ALL leads (up to 1M)
  `;
  
  const [leads] = await bigquery.query({ query });
  console.log(`✅ Fetched ${leads.length} leads\n`);
  
  // Batch upload to KV (100 at a time)
  const batchSize = 100;
  let uploaded = 0;
  let failed = 0;
  const maxRetries = 3;
  const retryDelay = 2000; // 2 seconds
  
  for (let i = 0; i < leads.length; i += batchSize) {
    const batch = leads.slice(i, i + batchSize);
    const batchNum = Math.floor(i / batchSize) + 1;
    
    // Prepare KV entries
    const kvEntries = batch.map((lead: any) => {
      let campaigns = [];
      try {
        campaigns = lead.campaigns ? JSON.parse(lead.campaigns) : [];
      } catch (e) {
        campaigns = [];
      }
      
      return {
        key: lead.trackingId,
        value: JSON.stringify({
          // Personal
          firstName: lead.firstName || (lead.person_name || '').split(' ')[0],
          lastName: lead.lastName || (lead.person_name || '').split(' ').slice(1).join(' '),
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
          
          // Tracking
          trackingId: lead.trackingId,
          
          // Behavioral
          totalSessions: lead.totalSessions || 0,
          totalPageviews: lead.totalPageviews || 0,
          lastVisit: lead.lastVisit,
          firstVisit: lead.firstVisit,
          viewedPricing: lead.viewedPricing || false,
          requestedDemo: lead.requestedDemo || false,
          submittedForm: lead.submittedForm || false,
          hasVisited: lead.hasVisited || false,
          
          // Campaign
          totalCampaigns: lead.totalCampaigns || 0,
          campaigns: campaigns,
          isInCampaign: (lead.totalCampaigns || 0) > 0,
          
          // Status
          isFirstVisit: !lead.hasVisited,
          engagementLevel: lead.totalSessions >= 3 && lead.viewedPricing ? 'hot' :
                          lead.totalSessions >= 2 || lead.viewedPricing ? 'warm' :
                          lead.hasVisited ? 'cold' : 'new',
          
          // Metadata
          syncedAt: new Date().toISOString()
        }),
        expiration_ttl: 90 * 24 * 60 * 60 // 90 days
      };
    });
    
    // Upload to KV with retry logic
    const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/storage/kv/namespaces/${namespaceId}/bulk`;
    
    let success = false;
    let lastError = null;
    
    for (let retry = 0; retry < maxRetries; retry++) {
      try {
        if (retry > 0) {
          console.log(`  Retry ${retry}/${maxRetries - 1} for batch ${batchNum}...`);
          await new Promise(resolve => setTimeout(resolve, retryDelay * retry));
        }
        
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
          lastError = error;
          
          // Duplicate key errors are OK (just updating existing data)
          if (error.includes('duplicate key')) {
            success = true;
            uploaded += batch.length;
            console.log(`✅ Uploaded ${uploaded}/${leads.length} leads (batch ${batchNum})`);
            break;
          }
          
          // Rate limit - wait longer
          if (response.status === 429) {
            console.log(`  ⏳ Rate limited, waiting ${retryDelay * 2}ms...`);
            await new Promise(resolve => setTimeout(resolve, retryDelay * 2));
            continue;
          }
          
          // Other errors - retry
          console.warn(`  ⚠️  Batch ${batchNum} attempt ${retry + 1} failed: ${error.substring(0, 100)}`);
        } else {
          success = true;
          uploaded += batch.length;
          console.log(`✅ Uploaded ${uploaded}/${leads.length} leads (batch ${batchNum})`);
          break;
        }
      } catch (error: any) {
        lastError = error.message;
        console.warn(`  ⚠️  Batch ${batchNum} attempt ${retry + 1} error: ${error.message}`);
        
        // Network error - wait and retry
        if (error.message.includes('fetch failed') || error.message.includes('ECONNRESET')) {
          await new Promise(resolve => setTimeout(resolve, retryDelay * 2));
          continue;
        }
      }
    }
    
    if (!success) {
      failed += batch.length;
      console.error(`❌ Batch ${batchNum} failed after ${maxRetries} retries: ${lastError}`);
      console.error(`   Skipping batch and continuing...`);
    }
    
    // Progress checkpoint every 1000 leads
    if (uploaded % 1000 === 0 && uploaded > 0) {
      console.log(`\n📊 Progress: ${uploaded}/${leads.length} (${Math.round(uploaded/leads.length*100)}%) | Failed: ${failed}\n`);
    }
  }
  
  console.log('\n🎉 Sync complete!');
  console.log(`\n📊 Final Summary:`);
  console.log(`- Total leads fetched: ${leads.length}`);
  console.log(`- Successfully synced: ${uploaded}`);
  console.log(`- Failed: ${failed}`);
  console.log(`- Success rate: ${Math.round(uploaded/leads.length*100)}%`);
  console.log(`- KV namespace: ${namespaceId}`);
  console.log(`- Expiration: 90 days`);
  
  if (failed > 0) {
    console.log(`\n⚠️  Warning: ${failed} leads failed to sync after ${maxRetries} retries`);
    console.log(`   Run this script again to retry failed batches`);
  }
  
  console.log(`\n✨ Personalization now works instantly for all ${uploaded} synced leads!`);
}

main().catch(error => {
  console.error('❌ Error:', error.message);
  process.exit(1);
});

