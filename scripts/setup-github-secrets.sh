#!/bin/bash

# Setup GitHub Secrets for CI/CD
# Requires: gh CLI (GitHub CLI) installed
# Install: brew install gh

set -e

echo "🔐 GitHub Secrets Setup for Outbound Intent Engine"
echo "=================================================="
echo ""

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo "Install with: brew install gh"
    echo "Or visit: https://cli.github.com"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "🔑 Please authenticate with GitHub first:"
    gh auth login
fi

echo "This script will help you set up all required GitHub secrets."
echo ""

# Function to set secret
set_secret() {
    local name=$1
    local description=$2
    local example=$3
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Setting: $name"
    echo "Description: $description"
    if [ -n "$example" ]; then
        echo "Example: $example"
    fi
    echo ""
    
    # Check if secret already exists
    if gh secret list | grep -q "^$name"; then
        read -p "Secret '$name' already exists. Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "⏭️  Skipped"
            echo ""
            return
        fi
    fi
    
    read -p "Enter value (or press Enter to skip): " -s value
    echo ""
    
    if [ -z "$value" ]; then
        echo "⏭️  Skipped"
    else
        echo "$value" | gh secret set "$name"
        echo "✅ Set successfully"
    fi
    echo ""
}

echo "📋 Required Secrets"
echo ""

set_secret \
    "CLOUDFLARE_API_TOKEN" \
    "Cloudflare API token with Workers edit permissions" \
    "Get from: https://dash.cloudflare.com/profile/api-tokens"

set_secret \
    "CLOUDFLARE_ACCOUNT_ID" \
    "Your Cloudflare account ID" \
    "Found in Cloudflare Dashboard → Account ID"

set_secret \
    "BIGQUERY_PROJECT_ID" \
    "Your Google Cloud project ID" \
    "e.g., my-gcp-project-123"

set_secret \
    "BIGQUERY_DATASET" \
    "BigQuery dataset name" \
    "Default: outbound_sales"

echo "For BIGQUERY_CREDENTIALS, you'll need to paste the entire JSON file."
echo "Tip: cat service-account.json | gh secret set BIGQUERY_CREDENTIALS"
echo ""
read -p "Press Enter to continue or Ctrl+C to set manually..."
echo ""

set_secret \
    "BIGQUERY_CREDENTIALS" \
    "Complete JSON service account key" \
    "Paste entire contents of service-account.json"

set_secret \
    "EVENT_SIGNING_SECRET" \
    "Random 32+ character string for event signing" \
    "Generate: openssl rand -hex 32"

set_secret \
    "ALLOWED_ORIGINS" \
    "Comma-separated list of allowed origins" \
    "https://yourdomain.com,https://www.yourdomain.com"

echo ""
echo "🎯 Optional: Staging Secrets"
echo ""
read -p "Do you want to set up staging environment secrets? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    set_secret \
        "BIGQUERY_PROJECT_ID_STAGING" \
        "Staging BigQuery project ID" \
        ""
    
    set_secret \
        "BIGQUERY_DATASET_STAGING" \
        "Staging dataset name" \
        "Default: outbound_sales_staging"
    
    set_secret \
        "BIGQUERY_CREDENTIALS_STAGING" \
        "Staging service account JSON" \
        ""
    
    set_secret \
        "ALLOWED_ORIGINS_STAGING" \
        "Staging allowed origins" \
        "https://staging.yourdomain.com"
fi

echo ""
echo "✅ All done! Your GitHub secrets are configured."
echo ""
echo "📋 Next Steps:"
echo "1. Commit and push your code: git push origin main"
echo "2. GitHub Actions will automatically deploy to Cloudflare"
echo "3. Check deployment: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions"
echo ""
echo "🔍 View all secrets:"
echo "   gh secret list"
echo ""
echo "📚 Documentation:"
echo "   See CI_CD_SETUP.md for more details"
echo ""

