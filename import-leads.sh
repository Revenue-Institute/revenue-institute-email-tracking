#!/bin/bash

# Import Leads to BigQuery + Instant KV Sync
# Usage: ./import-leads.sh leads.csv

if [ -z "$1" ]; then
    echo "❌ Usage: ./import-leads.sh <csv-file>"
    exit 1
fi

CSV_FILE=$1

echo "📊 Importing leads to BigQuery..."
echo ""

# Import to BigQuery
bq load \
  --project_id=n8n-revenueinstitute \
  --source_format=CSV \
  --autodetect \
  outbound_sales.leads \
  "$CSV_FILE"

if [ $? -ne 0 ]; then
    echo "❌ BigQuery import failed"
    exit 1
fi

echo "✅ BigQuery import complete"
echo ""

# Assign tracking IDs to new leads (if they don't have them)
echo "🔄 Assigning tracking IDs to new leads..."
bq query --project_id=n8n-revenueinstitute --use_legacy_sql=false \
  "UPDATE \`outbound_sales.leads\` 
   SET trackingId = SUBSTR(TO_HEX(SHA256(LOWER(TRIM(email)))), 1, 8) 
   WHERE trackingId IS NULL OR trackingId = ''"

echo "✅ Tracking IDs assigned"
echo ""

# Get your secret (set as environment variable)
if [ -z "$EVENT_SIGNING_SECRET" ]; then
    echo "⚠️  EVENT_SIGNING_SECRET not set"
    echo "Set it with: export EVENT_SIGNING_SECRET='your-secret'"
    echo ""
    read -p "Enter your EVENT_SIGNING_SECRET: " SECRET
else
    SECRET=$EVENT_SIGNING_SECRET
fi

# Trigger instant KV sync
echo "⚡ Triggering instant KV sync..."
RESPONSE=$(curl -s -X POST https://intel.revenueinstitute.com/sync-kv-now \
  -H "Authorization: Bearer $SECRET")

echo "$RESPONSE" | jq .

if echo "$RESPONSE" | jq -e '.success == true' > /dev/null; then
    echo ""
    echo "✅ KV sync completed!"
    echo "🎉 All leads are now available for personalization!"
else
    echo ""
    echo "❌ KV sync failed. Check the response above."
fi

