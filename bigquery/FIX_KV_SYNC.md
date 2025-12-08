# Fix KV Sync - Sync All 1M Leads

## Problem

**Current:** Only 9,904 leads syncing to KV  
**Expected:** ~1 million leads should sync  

## Root Cause

The query in `automated-kv-sync.sql` has a **10-minute filter**:

```sql
WHERE l.trackingId IS NOT NULL
  AND (
    l.inserted_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)  -- Only recent leads
    OR b.visitorId IS NOT NULL  -- OR leads who have visited
  )
```

This means it ONLY syncs leads who either:
1. Were added in the last 90 days, OR
2. Have visited your website

**Since your leads are all less than 2 weeks old, the problem is likely:**
- The `inserted_at` timestamp isn't recent enough, OR
- Most leads haven't visited your website yet

The 9,904 that ARE syncing are the ones who have already visited your site (`b.visitorId IS NOT NULL`).

---

## Solution

Replace `automated-kv-sync.sql` with `kv-sync-all-leads.sql` which has **NO time filter**.

### Step 1: Update GitHub Actions Workflow

**File:** `.github/workflows/sync-kv.yml`

Find the line that references the sync query and change it to use `kv-sync-all-leads.sql`:

**Before:**
```yaml
bq query --use_legacy_sql=false < bigquery/automated-kv-sync.sql
```

**After:**
```yaml
bq query --use_legacy_sql=false < bigquery/kv-sync-all-leads.sql
```

---

### Step 2: Manually Test the New Query

Run this to see how many leads it would sync:

```sql
-- Test query (count only)
SELECT COUNT(*) as total_leads_with_tracking
FROM `n8n-revenueinstitute.outbound_sales.leads`
WHERE trackingId IS NOT NULL;
```

**Expected:** ~1 million

Then run the full sync query:

```bash
cd /Users/stephenlowisz/Documents/Github-Cursor/Revenue\ Institute/revenue-institute-email-tracking
bq query --use_legacy_sql=false < bigquery/kv-sync-all-leads.sql > /tmp/kv_data.json
```

This will take 5-10 minutes for 1M leads.

---

### Step 3: Update Your Sync Script

If you're using the TypeScript sync script, update it to use the new query:

**File:** `scripts/sync-identities-kv.ts`

Change the query import:

```typescript
// Before
import queryFile from '../bigquery/automated-kv-sync.sql';

// After
import queryFile from '../bigquery/kv-sync-all-leads.sql';
```

Or just reference the new file path.

---

### Step 4: Run Full Sync

```bash
export CLOUDFLARE_API_TOKEN="your_token"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
npm run sync-personalization
```

**Expected Output:**
```
📊 Syncing leads to Cloudflare KV...
🔍 Fetching leads from BigQuery...
✅ Fetched 950000 leads
✅ Uploaded 10000/950000 leads to KV
✅ Uploaded 20000/950000 leads to KV
...
✅ Uploaded 950000/950000 leads to KV
🎉 Sync complete!
```

**Time:** ~30-45 minutes for 1M leads (batch upload)

---

## Key Differences: Old vs New Query

### Old Query (`automated-kv-sync.sql`)
```sql
WHERE l.trackingId IS NOT NULL
  AND (
    l.inserted_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
    OR b.visitorId IS NOT NULL  -- Only those who visited
  )
```
**Result:** 9,904 leads (only website visitors)

### New Query (`kv-sync-all-leads.sql`)
```sql
WHERE l.trackingId IS NOT NULL
  -- NO TIME FILTER
```
**Result:** ~1 million leads (everyone with trackingId)

---

## Why Only 9,904 Before?

Those 9,904 leads were the ones who had **already visited your website**. The query was excluding the ~990,000 leads who:
- Have a trackingId ✅
- Were added recently ✅
- But **haven't visited your website yet** ❌

With the new query, they'll ALL sync to KV, so when they DO visit (via email link), personalization will work immediately.

---

## Verification

After running the new sync:

```bash
# Check KV count
wrangler kv key list --binding=IDENTITY_STORE --remote | jq 'length'

# Expected: ~950,000 to 1,000,000

# Test a random tracking ID
curl "https://intel.revenueinstitute.com/personalize?vid=SOME_TRACKING_ID" | jq .

# Should return lead data
```

---

## Performance Notes

**Cloudflare KV Limits:**
- Free tier: 1 GB storage (1M leads = ~100-200 MB, you're fine)
- Paid tier: 10 GB storage
- Unlimited reads
- 1000 writes/sec

**Sync Performance:**
- 1M leads = ~30-45 minutes initial sync
- Hourly updates = ~5-10 minutes (only changed leads)
- Reads = <10ms (instant personalization)

**Cost:**
- Storage: $0 (under 1 GB)
- Reads: $0 (unlimited)
- Writes: $0 (under limits)

---

## Done!

After running the new sync, all ~1 million leads will be in KV and ready for personalization when they click email links.

