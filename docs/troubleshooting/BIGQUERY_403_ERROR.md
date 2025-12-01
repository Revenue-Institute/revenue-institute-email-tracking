# Fixing BigQuery 403 Permission Error

## Problem

You're seeing this error in Cloudflare Workers logs:
```
❌ KV sync error: BigQuery query failed: 403
```

This means your service account doesn't have permission to **query** BigQuery (it can only insert data).

## Root Cause

The token was only requesting `bigquery.insertdata` scope, which allows:
- ✅ Inserting data into tables
- ❌ Querying/reading data from tables

The KV sync function needs to **query** the `leads` and `events` tables, which requires read permissions.

## Solution

### Step 1: Verify Service Account Permissions

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **IAM & Admin** → **Service Accounts**
3. Find your service account (e.g., `outbound-intent-tracker@...`)
4. Click on it to view details
5. Check the **"Permissions"** tab

**Required Roles:**
- ✅ **BigQuery Data Editor** (allows read + write to tables)
- ✅ **BigQuery Job User** (allows running queries)

If these roles are missing, add them:

1. Click **"GRANT ACCESS"** button
2. In "Add principals", enter your service account email
3. In "Select a role", add:
   - `BigQuery Data Editor`
   - `BigQuery Job User`
4. Click **"SAVE"**

### Step 2: Verify Code Update

The code has been updated to request the full BigQuery scope. Make sure you have the latest version:

**File:** `src/worker/index.ts`

The `createBigQueryToken` function should now request:
```typescript
scope: scope || 'https://www.googleapis.com/auth/bigquery'
```

Instead of the old:
```typescript
scope: 'https://www.googleapis.com/auth/bigquery.insertdata'
```

### Step 3: Redeploy Worker

After updating the code, redeploy your Cloudflare Worker:

```bash
npm run deploy
```

Or via Wrangler:
```bash
npx wrangler deploy
```

### Step 4: Test the Fix

1. Wait for the next cron run (every 5 minutes) or trigger manually:
   ```bash
   curl -X POST https://your-worker.workers.dev/sync-kv-now \
     -H "Authorization: Bearer YOUR_EVENT_SIGNING_SECRET"
   ```

2. Check Cloudflare Workers logs:
   - Go to Cloudflare Dashboard
   - Workers & Pages → Your Worker
   - Click "Logs" tab
   - Look for: `✅ Synced X leads to KV`

## Verification

### Check Service Account Permissions

Run this in Google Cloud Console to verify permissions:

```bash
# List service account permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:YOUR_SERVICE_ACCOUNT_EMAIL"
```

You should see:
- `roles/bigquery.dataEditor`
- `roles/bigquery.jobUser`

### Test BigQuery Query Manually

1. Go to [BigQuery Console](https://console.cloud.google.com/bigquery)
2. Run this query (replace with your project/dataset):
   ```sql
   SELECT 
     trackingId,
     email,
     company_name
   FROM `YOUR_PROJECT.outbound_sales.leads`
   WHERE trackingId IS NOT NULL
   LIMIT 10;
   ```

If this works, your service account should also work.

## Common Issues

### Issue: "Permission denied for table"

**Solution:** The service account needs access to the specific dataset:
1. Go to BigQuery → Your Dataset
2. Click **"SHARING"** → **"Permissions"**
3. Click **"ADD PRINCIPAL"**
4. Add your service account email
5. Grant role: **"BigQuery Data Editor"**

### Issue: "Project not found"

**Solution:** Verify `BIGQUERY_PROJECT_ID` environment variable:
1. Check Cloudflare Workers → Settings → Variables
2. Ensure `BIGQUERY_PROJECT_ID` matches your Google Cloud project ID
3. Project ID format: `outbound-intent-engine-123456` (not the project name!)

### Issue: "Dataset not found"

**Solution:** Verify `BIGQUERY_DATASET` environment variable:
1. Check it matches your dataset name (usually `outbound_sales`)
2. Case-sensitive! Must match exactly

### Issue: "Invalid credentials"

**Solution:** Regenerate service account key:
1. Go to Service Accounts → Your Account → Keys
2. Delete old key
3. Create new key (JSON)
4. Update `BIGQUERY_CREDENTIALS` in Cloudflare Workers secrets

## Required BigQuery Scopes

The service account now requests the full BigQuery scope which includes:

- ✅ `bigquery.readonly` - Read/query data
- ✅ `bigquery.insertdata` - Insert data
- ✅ `bigquery` - Full access (what we're using)

## Required IAM Roles

Your service account needs these roles at the **Project** level:

1. **BigQuery Data Editor** (`roles/bigquery.dataEditor`)
   - Read and write data in datasets
   - Create and delete tables
   - Run queries

2. **BigQuery Job User** (`roles/bigquery.jobUser`)
   - Run queries and jobs
   - Cancel jobs

## Testing After Fix

After deploying the fix, you should see in logs:

```
📊 Starting BigQuery → KV sync...
🔑 Creating BigQuery token...
✅ Token created
📦 Found X leads to sync
✅ Synced X leads to KV
```

Instead of:
```
❌ KV sync error: BigQuery query failed: 403
```

## Still Having Issues?

1. **Check the actual error message** - The code now shows detailed error messages
2. **Verify service account email** - Make sure it matches in Google Cloud and Cloudflare
3. **Check project ID** - Must be the project ID, not name
4. **Wait a few minutes** - IAM changes can take 1-2 minutes to propagate

## Related Files

- `src/worker/index.ts` - Token creation and query logic
- `docs/guides/BIGQUERY_SETUP_BEGINNERS.md` - Initial setup guide
- `bigquery/schema.sql` - Table definitions

