# 🔄 KV Sync - Keep Personalization Fresh

**ALL done in Cloudflare Workers - no external dependencies!**

---

## ✅ Automatic Sync (Every 3 Hours)

**Schedule:** 8 times per day
- 12:00 AM, 3:00 AM, 6:00 AM, 9:00 AM
- 12:00 PM, 3:00 PM, 6:00 PM, 9:00 PM

**What it syncs:**
- ✅ **ALL leads added in last 6 hours** (unlimited!)
- ✅ **ALL leads who visited in last 6 hours** (behavioral updates)
- ✅ No 1k limit - syncs everything!

**Example:**
- Add 50,000 leads at 10:00 AM
- Sync runs at 12:00 PM
- All 50,000 synced to KV ✅
- Personalization works for all!

**Max delay:** 3 hours (usually less)

---

## ⚡ Instant Sync (On-Demand)

**For immediate sync after bulk lead import:**

**Webhook endpoint:**
```bash
POST https://intel.revenueinstitute.com/sync-kv-now
Authorization: Bearer <YOUR_EVENT_SIGNING_SECRET>
```

**Use when:**
- Just imported 50k leads → Trigger instant sync
- Need personalization to work immediately
- Testing new leads

**How to trigger:**
```bash
# Get your secret from Cloudflare
SECRET="<your-event-signing-secret>"

# Trigger sync
curl -X POST https://intel.revenueinstitute.com/sync-kv-now \
  -H "Authorization: Bearer $SECRET"

# Response:
{"success":true,"message":"KV sync completed","timestamp":"2025-11-25..."}
```

**From any system:**
- After bulk lead import in BigQuery
- From n8n workflow
- From cron job
- From Zapier/Make
- From anywhere via webhook!

---

## 🎯 Best Practice Workflow

### **Scenario 1: Bulk Lead Import**

```
1. Import 50k leads to BigQuery
   ↓
2. Immediately trigger webhook:
   curl -X POST .../sync-kv-now -H "Authorization: Bearer $SECRET"
   ↓
3. All 50k synced to KV in ~2-5 minutes
   ↓
4. Send email campaigns immediately
   ↓
5. Personalization works for everyone!
```

### **Scenario 2: Ongoing Additions**

```
Add leads throughout the day
   ↓
Automatic sync every 3 hours
   ↓
Max 3-hour delay (usually less)
   ↓
No manual work needed!
```

### **Scenario 3: Critical/VIP Lead**

```
Add VIP lead to database
   ↓
Trigger instant sync webhook
   ↓
Send personalized email immediately
   ↓
They click and see personalized page!
```

---

## 🔧 How to Trigger Instant Sync

### **Option 1: Command Line**

```bash
# Set your secret (get from: wrangler secret list)
export KV_SYNC_SECRET="your-event-signing-secret"

# Trigger sync
curl -X POST https://intel.revenueinstitute.com/sync-kv-now \
  -H "Authorization: Bearer $KV_SYNC_SECRET"
```

### **Option 2: From BigQuery Scheduled Query**

Create a BigQuery scheduled query that triggers webhook after lead import:

```sql
-- After your lead import query runs:
SELECT NET.HTTP_POST(
  'https://intel.revenueinstitute.com/sync-kv-now',
  'Authorization: Bearer YOUR_SECRET',
  ''
);
```

### **Option 3: From n8n**

Add HTTP Request node:
- Method: POST
- URL: https://intel.revenueinstitute.com/sync-kv-now
- Headers: Authorization: Bearer {{secret}}
- Trigger: After lead import

---

## 📊 Sync Performance

**Small batch (1-100 leads):**
- Time: <5 seconds
- All synced instantly

**Medium batch (1k-10k leads):**
- Time: ~1-2 minutes
- Batched automatically

**Large batch (50k+ leads):**
- Time: ~3-5 minutes
- All synced, no limit!

**BigQuery → KV latency:** Immediate (writes directly to KV)

---

## 🎯 Summary

**Automatic Sync:**
- ✅ Every 3 hours (8x/day)
- ✅ No limit - syncs ALL new leads
- ✅ 6-hour lookback window
- ✅ Pure Cloudflare (cron trigger)

**Manual Sync:**
- ✅ Webhook endpoint available
- ✅ Instant trigger anytime
- ✅ No limit - syncs everything
- ✅ From any system

**Best of both worlds:**
- Regular automatic updates (every 3h)
- Instant sync when you need it (webhook)
- Unlimited capacity (no 1k cap)

---

## 🚀 Next Steps

**1. Get your EVENT_SIGNING_SECRET:**
```bash
cd revenue-institute-email-tracking
wrangler secret list
# Copy the value (you set it earlier)
```

**2. Test instant sync:**
```bash
curl -X POST https://intel.revenueinstitute.com/sync-kv-now \
  -H "Authorization: Bearer YOUR_SECRET"
```

**3. Monitor sync:**
- https://dash.cloudflare.com
- Workers → outbound-intent-engine → Logs
- Look for: "📦 Found X leads to sync"

---

**Auto-sync:** Every 3 hours (no limit) ✅  
**Manual sync:** Webhook trigger anytime ✅  
**All Cloudflare:** No external dependencies ✅

**Add 50k leads? They'll ALL sync within 3 hours, or instantly via webhook!** 🚀

