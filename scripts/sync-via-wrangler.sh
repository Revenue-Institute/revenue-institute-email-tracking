#!/bin/bash
# Sync leads to KV using Wrangler (no API token needed!)

echo "📊 Syncing leads to Cloudflare KV for personalization..."
echo ""

# Export 10k leads to JSON
echo "🔍 Fetching leads from BigQuery..."
bq query --project_id=n8n-revenueinstitute --use_legacy_sql=false --format=json --max_rows=10000 '
SELECT 
  trackingId,
  email,
  person_name,
  company_name,
  company_website,
  company_size,
  revenue,
  industry,
  job_title,
  seniority,
  department,
  phone,
  linkedin,
  company_linkedin,
  company_description
FROM `outbound_sales.leads`
WHERE trackingId IS NOT NULL
LIMIT 10000
' > /tmp/leads_for_kv.json

echo "✅ Exported leads"
echo ""

# Process and upload to KV using wrangler
echo "📤 Uploading to Cloudflare KV..."

node -e "
const fs = require('fs');
const leads = JSON.parse(fs.readFileSync('/tmp/leads_for_kv.json', 'utf8'));

let count = 0;
leads.forEach(lead => {
  const personalization = {
    firstName: (lead.person_name || '').split(' ')[0],
    lastName: (lead.person_name || '').split(' ').slice(1).join(' '),
    personName: lead.person_name,
    email: lead.email,
    phone: lead.phone,
    linkedin: lead.linkedin,
    company: lead.company_name,
    companyName: lead.company_name,
    domain: lead.company_website || (lead.email ? lead.email.split('@')[1] : null),
    companyWebsite: lead.company_website,
    companyDescription: lead.company_description,
    companySize: lead.company_size,
    revenue: lead.revenue,
    industry: lead.industry,
    companyLinkedin: lead.company_linkedin,
    jobTitle: lead.job_title,
    seniority: lead.seniority,
    department: lead.department,
    isFirstVisit: true,
    intentScore: 0,
    engagementLevel: 'new'
  };
  
  fs.writeFileSync(\`/tmp/kv_\${count}.json\`, JSON.stringify(personalization));
  console.log(\`wrangler kv:key put \${lead.trackingId} '\${JSON.stringify(personalization)}' --binding=IDENTITY_STORE --preview=false\`);
  count++;
});
console.log('Total leads:', count);
" > /tmp/upload_commands.sh

# Show sample
echo "Sample entries to upload:"
head -3 /tmp/upload_commands.sh
echo "..."
echo ""
echo "Total leads ready: $(wc -l < /tmp/upload_commands.sh)"
echo ""
echo "⚠️  This will take a while to upload one by one."
echo "To upload faster, run the generated script:"
echo "bash /tmp/upload_commands.sh"


