#!/bin/bash
# Monitor KV sync progress

LOG_FILE="/Users/stephenlowisz/Documents/Github-Cursor/Revenue Institute/revenue-institute-email-tracking/sync.log"

echo "🔍 Checking sync progress..."
echo ""

# Check if process is running
if ps aux | grep "sync-personalization" | grep -v grep > /dev/null; then
  echo "✅ Sync process is RUNNING"
else
  echo "⚠️  Sync process is NOT running"
fi

echo ""
echo "📊 Latest output:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
tail -30 "$LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Extract progress if available
UPLOADED=$(grep "Uploaded" "$LOG_FILE" | tail -1 | grep -oE "[0-9]+/[0-9]+")
if [ ! -z "$UPLOADED" ]; then
  echo "📈 Current progress: $UPLOADED leads"
fi

FETCHED=$(grep "Fetched" "$LOG_FILE" | tail -1 | grep -oE "[0-9]+ leads")
if [ ! -z "$FETCHED" ]; then
  echo "📥 Total to sync: $FETCHED"
fi

echo ""
echo "💡 To watch live: tail -f \"$LOG_FILE\""
echo "💡 To see full log: cat \"$LOG_FILE\""

