# n8n Real-Time KV Sync Setup

**Add this to your n8n workflow to get instant KV sync**

---

## 🎯 Your n8n Workflow

**Current flow (example):**
```
1. Schedule/Webhook/Trigger
2. Get leads (CSV, API, Smartlead, etc.)
3. Transform data
4. Insert into BigQuery (outbound_sales.leads)
5. Done
```

**Add one more node:**
```
1. Schedule/Webhook/Trigger
2. Get leads
3. Transform data
4. Insert into BigQuery
5. HTTP Request → Trigger KV Sync  ← ADD THIS!
6. Done
```

---

## 📝 Node Configuration

### **Node 5: HTTP Request - Trigger KV Sync**

**Settings:**
- **Name:** `Trigger KV Sync`
- **Method:** `POST`
- **URL:** `https://intel.revenueinstitute.com/sync-kv-now`

**Authentication:**
- **Type:** Generic Credential Type → Header Auth
- **Create credential:**
  - **Name:** `Cloudflare KV Sync Auth`
  - **Header Name:** `Authorization`
  - **Header Value:** `Bearer <YOUR_EVENT_SIGNING_SECRET>`

**When to execute:**
- **Execute Once:** Yes (not for each item)
- **Run after:** BigQuery insert node

**Response:**
- Returns: `{"success": true, "message": "KV sync completed"}`
- Takes: 30 seconds - 5 minutes depending on lead count

---

## 🔑 Get Your Secret

**If you don't have it saved:**

```bash
cd "/Users/stephenlowisz/Documents/Github-Cursor/Revenue Institute/revenue-institute-email-tracking"
wrangler secret list
```

**Look for:** `EVENT_SIGNING_SECRET`

**Or it might be in your notes from earlier setup.**

---

## 🧪 Test Your Workflow

**1. Add test lead via n8n**
- Should insert to BigQuery ✅
- Should trigger KV sync ✅
- Check n8n execution logs for HTTP Request node

**2. Verify in KV** (30 seconds later)
```bash
# Check if lead is in KV
curl https://intel.revenueinstitute.com/personalize?vid=<trackingId> | jq .
```

**3. Expected result:**
```json
{
  "personalized": true,
  "firstName": "...",
  "company": "...",
  "email": "..."
}
```

---

## 📊 What This Achieves

**Before:**
- Add leads via n8n → Wait up to 3 hours for sync
- Can't send emails immediately

**After:**
- Add leads via n8n → KV synced in <1 minute ⚡
- Send emails immediately!
- Personalization works right away!

---

## 🎯 Example n8n Workflow

```
┌─────────────────┐
│  Smartlead      │  New leads from campaign
│  Webhook        │
└────────┬────────┘
         ↓
┌─────────────────┐
│  Transform      │  Clean/format data
│  Data           │
└────────┬────────┘
         ↓
┌─────────────────┐
│  BigQuery       │  Insert into outbound_sales.leads
│  Insert         │
└────────┬────────┘
         ↓
┌─────────────────┐
│  HTTP Request   │  POST /sync-kv-now
│  (KV Sync)      │  Authorization: Bearer <secret>
└────────┬────────┘
         ↓
┌─────────────────┐
│  Slack/Email    │  Optional: Notify sync complete
│  Notification   │
└─────────────────┘
```

---

## ✅ Benefits

**Real-time availability:**
- Lead added → Available in <1 minute
- No waiting for cron
- Send campaigns immediately

**Automatic:**
- Part of your n8n workflow
- No manual steps
- Just works!

**Reliable:**
- Fallback cron every 3 hours
- If webhook fails, cron catches it
- Never miss a lead

---

**Add the HTTP Request node to your n8n workflow and you're done!** 🎉

**Need help finding your EVENT_SIGNING_SECRET?** Let me know!

