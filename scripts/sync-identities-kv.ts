#!/usr/bin/env node
/**
 * Sync campaign identities to Cloudflare KV
 * Usage: npm run sync-identities -- --file campaign-xxx-identities.json
 */

import { readFileSync } from 'fs';
import type { LeadIdentity } from '../src/utils/identity-generator';

interface Args {
  file: string;
  accountId: string;
  namespaceId: string;
  apiToken: string;
}

async function main() {
  const args = parseArgs();
  
  console.log('☁️  Syncing identities to Cloudflare KV...\n');
  
  // Read identities file
  const identitiesJson = readFileSync(args.file, 'utf-8');
  const identities: LeadIdentity[] = JSON.parse(identitiesJson);
  
  console.log(`📦 Loaded ${identities.length} identities\n`);
  
  // Batch upload to KV (max 100 per batch)
  const batchSize = 100;
  let uploaded = 0;
  
  for (let i = 0; i < identities.length; i += batchSize) {
    const batch = identities.slice(i, i + batchSize);
    await uploadBatch(batch, args);
    uploaded += batch.length;
    console.log(`✅ Uploaded ${uploaded}/${identities.length} identities`);
  }
  
  console.log('\n✨ Sync complete!');
}

async function uploadBatch(identities: LeadIdentity[], args: Args): Promise<void> {
  const url = `https://api.cloudflare.com/client/v4/accounts/${args.accountId}/storage/kv/namespaces/${args.namespaceId}/bulk`;
  
  // Format for KV bulk API
  const kvPairs = identities.map(identity => ({
    key: identity.shortId,
    value: JSON.stringify(identity),
    expiration_ttl: Math.floor((identity.expiresAt - identity.createdAt) / 1000)
  }));
  
  const response = await fetch(url, {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${args.apiToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(kvPairs)
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`KV upload failed: ${error}`);
  }
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
  const accountId = parsed.accountId || process.env.CLOUDFLARE_ACCOUNT_ID;
  const namespaceId = parsed.namespaceId || process.env.KV_IDENTITY_STORE_ID;
  const apiToken = parsed.apiToken || process.env.CLOUDFLARE_API_TOKEN;
  
  if (!parsed.file) {
    console.error('❌ Error: --file is required');
    console.log('\nUsage:');
    console.log('  npm run sync-identities -- --file campaign-xxx-identities.json');
    console.log('\nOr set environment variables:');
    console.log('  CLOUDFLARE_ACCOUNT_ID');
    console.log('  KV_IDENTITY_STORE_ID');
    console.log('  CLOUDFLARE_API_TOKEN');
    process.exit(1);
  }
  
  if (!accountId || !namespaceId || !apiToken) {
    console.error('❌ Error: Missing Cloudflare credentials');
    console.log('Set via CLI args or environment variables');
    process.exit(1);
  }
  
  return {
    file: parsed.file,
    accountId,
    namespaceId,
    apiToken
  };
}

main().catch(error => {
  console.error('❌ Error:', error.message);
  process.exit(1);
});

