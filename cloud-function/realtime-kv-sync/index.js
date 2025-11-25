/**
 * Cloud Function for Real-Time KV Sync
 * Triggered by Pub/Sub when new leads are added
 * Immediately syncs to Cloudflare KV
 */

const CLOUDFLARE_ACCOUNT_ID = 'e406ada6b728029380a6465d03932cb8';
const KV_NAMESPACE_ID = '84ed00a75f6f44adb62d4d7bbec149ae';
const CLOUDFLARE_API_TOKEN = 'b2eUcOm0HJSnK2G-DQQbSzUmjQLL34J20ZQxo1o_';
const WORKER_WEBHOOK = 'https://intel.revenueinstitute.com/sync-kv-now';
const EVENT_SIGNING_SECRET = process.env.EVENT_SIGNING_SECRET;

exports.syncLeadToKV = async (message, context) => {
  console.log('📥 Pub/Sub message received');
  
  try {
    // Simply trigger the Cloudflare webhook
    // The webhook already has the logic to sync leads
    const response = await fetch(WORKER_WEBHOOK, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${EVENT_SIGNING_SECRET}`
      }
    });
    
    if (!response.ok) {
      throw new Error(`Webhook failed: ${response.status}`);
    }
    
    const result = await response.json();
    console.log('✅ KV sync triggered:', result);
    
  } catch (error) {
    console.error('❌ Error triggering KV sync:', error);
    throw error;
  }
};

