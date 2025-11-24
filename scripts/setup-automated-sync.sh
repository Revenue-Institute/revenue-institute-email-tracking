#!/bin/bash

# Setup Automated KV Sync
# This sets up a cron job to sync BigQuery → Cloudflare KV every hour
# Keeps personalization data fresh with new leads and behavioral updates

echo "🔄 Setting up automated KV sync..."
echo ""

# Check if required env vars are set
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ CLOUDFLARE_API_TOKEN not set"
    echo "Export it first: export CLOUDFLARE_API_TOKEN='your-token'"
    exit 1
fi

if [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    echo "❌ GOOGLE_APPLICATION_CREDENTIALS not set"
    echo "Export it first: export GOOGLE_APPLICATION_CREDENTIALS='/path/to/service-account.json'"
    exit 1
fi

PROJECT_DIR="$(pwd)"

# Create wrapper script that sets env vars
cat > /tmp/kv-sync-wrapper.sh <<'EOF'
#!/bin/bash
cd "PROJECT_DIR_PLACEHOLDER"

export GOOGLE_APPLICATION_CREDENTIALS="GOOGLE_CREDS_PLACEHOLDER"
export CLOUDFLARE_API_TOKEN="CF_TOKEN_PLACEHOLDER"
export BIGQUERY_PROJECT_ID="n8n-revenueinstitute"

npm run sync-personalization >> /tmp/kv-sync.log 2>&1

echo "$(date): KV sync completed" >> /tmp/kv-sync.log
EOF

# Replace placeholders
sed -i '' "s|PROJECT_DIR_PLACEHOLDER|$PROJECT_DIR|g" /tmp/kv-sync-wrapper.sh
sed -i '' "s|GOOGLE_CREDS_PLACEHOLDER|$GOOGLE_APPLICATION_CREDENTIALS|g" /tmp/kv-sync-wrapper.sh
sed -i '' "s|CF_TOKEN_PLACEHOLDER|$CLOUDFLARE_API_TOKEN|g" /tmp/kv-sync-wrapper.sh

chmod +x /tmp/kv-sync-wrapper.sh

# Add to crontab (runs every hour)
echo ""
echo "Adding cron job to run every hour..."
echo ""

# Current crontab
crontab -l > /tmp/current_cron 2>/dev/null || touch /tmp/current_cron

# Check if already exists
if grep -q "kv-sync-wrapper.sh" /tmp/current_cron; then
    echo "⚠️  Cron job already exists. Skipping..."
else
    # Add new job - runs every hour at minute 15
    echo "0 * * * * /tmp/kv-sync-wrapper.sh" >> /tmp/current_cron
    crontab /tmp/current_cron
    echo "✅ Cron job added: Runs every hour"
fi

echo ""
echo "✅ Automated sync configured!"
echo ""
echo "📋 What happens now:"
echo "   - Every hour, at :00 minutes"
echo "   - Fetches latest leads from BigQuery"
echo "   - Updates Cloudflare KV"
echo "   - Includes new leads + behavioral updates"
echo ""
echo "📊 Sync log: /tmp/kv-sync.log"
echo ""
echo "🧪 Test it now:"
echo "   /tmp/kv-sync-wrapper.sh"
echo ""
echo "🗑️  To remove:"
echo "   crontab -e  (then delete the kv-sync line)"
echo ""

