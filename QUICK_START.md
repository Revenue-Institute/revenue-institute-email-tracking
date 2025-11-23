# Quick Start Guide - 10 Minutes to Your First Campaign

Get the Outbound Intent Engine running in 10 minutes.

---

## ⚡ Prerequisites

- Node.js 18+
- Cloudflare account (free tier works)
- Google Cloud account with BigQuery enabled
- 10 minutes ⏱️

---

## 🚀 Step-by-Step

### 1. Install (1 minute)

```bash
git clone <repo-url>
cd revenue-institute-email-tracking
npm install
```

### 2. Set Up Cloudflare (3 minutes)

```bash
# Login to Cloudflare
npx wrangler login

# Create KV namespaces
npx wrangler kv:namespace create "IDENTITY_STORE"
npx wrangler kv:namespace create "PERSONALIZATION"

# Copy the IDs into wrangler.toml
# (Follow the output instructions)
```

### 3. Set Up BigQuery (3 minutes)

```bash
# 1. Create GCP project at console.cloud.google.com
# 2. Enable BigQuery API
# 3. Create service account with BigQuery permissions
# 4. Download JSON key as service-account.json

# Create dataset and tables
bq mk --dataset outbound_sales
bq query --use_legacy_sql=false < bigquery/schema.sql
```

### 4. Configure Secrets (2 minutes)

```bash
npx wrangler secret put BIGQUERY_PROJECT_ID
# Enter: your-gcp-project-id

npx wrangler secret put BIGQUERY_DATASET
# Enter: outbound_sales

npx wrangler secret put BIGQUERY_CREDENTIALS
# Paste: (contents of service-account.json)

npx wrangler secret put ALLOWED_ORIGINS
# Enter: https://yourdomain.com

npx wrangler secret put EVENT_SIGNING_SECRET
# Enter: (random 32+ character string)
```

### 5. Deploy (1 minute)

```bash
# Build and deploy pixel
npm run build:pixel
npm run deploy:pixel

# Deploy worker
npm run deploy:worker
```

**Done!** 🎉 Your worker is live at: `https://your-worker.workers.dev`

---

## 📧 Create Your First Campaign

### 1. Prepare Leads CSV

```csv
email,firstName,lastName,company
john@acme.com,John,Doe,Acme Corp
jane@widget.com,Jane,Smith,Widget Co
```

### 2. Generate Tracking URLs

```bash
npm run create-campaign -- \
  --campaign "My First Campaign" \
  --file leads.csv \
  --baseUrl https://yourdomain.com \
  --landingPage /demo
```

Output: `campaign-xxx-urls.csv` with tracking links.

### 3. Sync to Storage

```bash
# Sync to KV
export CLOUDFLARE_ACCOUNT_ID="your-account-id"
export KV_IDENTITY_STORE_ID="your-kv-id"
export CLOUDFLARE_API_TOKEN="your-token"
npm run sync-identities -- --file campaign-xxx-identities.json

# Sync to BigQuery
export BIGQUERY_PROJECT_ID="your-project"
export GOOGLE_APPLICATION_CREDENTIALS="./service-account.json"
npm run sync-bigquery -- --file campaign-xxx-identities.json
```

### 4. Add Pixel to Website

Add to your website's `<head>`:

```html
<script>
  window.oieConfig = {
    endpoint: 'https://your-worker.workers.dev/track',
    debug: false
  };
</script>
<script src="https://yourdomain.com/js/pixel.js"></script>
```

### 5. Import to Email Tool

1. Open Smartlead/Instantly/Lemlist
2. Import `campaign-xxx-urls.csv`
3. Use "Tracking URL" column in your email template:

```
Hi {{firstName}},

Quick question about {{company}}...

Want to see how we can help?
→ {{trackingUrl}}
```

### 6. Launch Campaign! 🚀

Start sending emails. Track results in BigQuery:

```sql
-- See recent activity
SELECT * FROM `outbound_sales.recent_sessions` LIMIT 10;

-- See hot leads
SELECT * FROM `outbound_sales.high_intent_leads` LIMIT 10;
```

---

## 📊 View Results

### BigQuery Console

```sql
-- Campaign performance
SELECT * FROM `outbound_sales.campaign_performance`;

-- High-intent leads
SELECT 
  email, 
  company, 
  intentScore,
  pricingPageVisits,
  formSubmissions
FROM `outbound_sales.lead_profiles`
WHERE intentScore >= 70
ORDER BY intentScore DESC;
```

### Looker Studio Dashboard (Free)

1. Go to [Looker Studio](https://lookerstudio.google.com)
2. Create report → Connect to BigQuery
3. Select `outbound_sales` dataset
4. Add views: `high_intent_leads`, `campaign_performance`

---

## 🆘 Troubleshooting

### Events not showing in BigQuery?

```bash
# Check worker logs
npx wrangler tail

# Verify BigQuery credentials
npx wrangler secret list
```

### Pixel not loading?

```html
<!-- Enable debug mode -->
<script>
  window.oieConfig = {
    endpoint: 'https://your-worker.workers.dev/track',
    debug: true  // See console logs
  };
</script>
```

Check browser console for errors.

### Visitor ID not persisting?

1. Check localStorage: `localStorage.getItem('_oie_visitor')`
2. Check cookies: `document.cookie`
3. Verify `?i=xxx` in URL

---

## 🚀 Bonus: Set Up CI/CD (5 minutes)

Want automatic deployment on every push to main? Follow [CI_CD_SETUP.md](CI_CD_SETUP.md)

**Quick setup:**

```bash
# Install GitHub CLI
brew install gh

# Run setup script
./scripts/setup-github-secrets.sh

# Push to GitHub
git add .
git commit -m "Initial commit"
git push origin main

# Watch it deploy automatically! 🎉
```

After setup, every push to `main` automatically deploys to Cloudflare Workers in ~2 minutes.

---

## 📚 Next Steps

- 📖 Read [DEPLOYMENT.md](DEPLOYMENT.md) for full setup
- 🏗️ Read [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
- 🛠️ Read [DEVELOPMENT.md](DEVELOPMENT.md) for development
- 🚀 Read [CI_CD_SETUP.md](CI_CD_SETUP.md) for auto-deployment

---

## 💡 Tips

**Best Practices:**
- Start with 10-20 test leads
- Check BigQuery after 5 minutes
- Use debug mode initially
- Set up Looker Studio dashboard
- Configure CRM sync for hot leads (70+ score)

**Common Mistakes:**
- ❌ Forgetting to add pixel to website
- ❌ Not syncing identities to KV before sending emails
- ❌ Wrong ALLOWED_ORIGINS in Worker
- ❌ Using third-party cookie blocking browsers without first-party setup

---

**Questions?** Open an issue or check the docs!

