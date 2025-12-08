# N8N Campaign Assignment Workflow

## Purpose
Assign leads to BigQuery campaigns via N8N webhook or manual trigger.

---

## Workflow Overview

```
Trigger (Webhook or Manual)
    ↓
Parse Input (Campaign ID, Lead Filters)
    ↓
BigQuery: Run Assignment Query
    ↓
BigQuery: Get Member Count
    ↓
Send Confirmation (Email/Slack/Webhook)
```

---

## Setup Steps

### 1. Create N8N Workflow

**Workflow Name:** `Assign Leads to Campaign`

**Nodes:**

#### Node 1: Webhook Trigger
- **Type:** Webhook
- **Method:** POST
- **Path:** `/assign-campaign`
- **Authentication:** Basic Auth (recommended)

**Expected JSON Payload:**
```json
{
  "campaignId": "q1-outreach-2025",
  "campaignName": "Q1 Outreach Campaign 2025",
  "description": "Targeting VPs in SaaS",
  "totalSequenceSteps": 5,
  "filters": {
    "job_title": "%VP%",
    "industry": "SaaS",
    "company_size": ["51-200", "201-500", "501-1000"]
  },
  "limit": 10000
}
```

---

#### Node 2: Create Campaign (if doesn't exist)
- **Type:** Google BigQuery
- **Operation:** Execute Query
- **Project ID:** `n8n-revenueinstitute`
- **Query:**

```sql
INSERT INTO `outbound_sales.campaigns` (
  campaignId,
  campaignName,
  description,
  totalSequenceSteps,
  utmSource,
  utmMedium,
  utmCampaign,
  status,
  startedAt
)
SELECT
  '{{ $json.campaignId }}',
  '{{ $json.campaignName }}',
  '{{ $json.description }}',
  {{ $json.totalSequenceSteps }},
  'email',
  'email',
  '{{ $json.campaignId }}',
  'active',
  CURRENT_TIMESTAMP()
WHERE NOT EXISTS (
  SELECT 1 FROM `outbound_sales.campaigns` 
  WHERE campaignId = '{{ $json.campaignId }}'
);
```

---

#### Node 3: Assign Leads to Campaign
- **Type:** Google BigQuery
- **Operation:** Execute Query
- **Project ID:** `n8n-revenueinstitute`
- **Query:**

```sql
INSERT INTO `outbound_sales.campaign_members` (
  trackingId,
  campaignId,
  campaignName,
  sequenceStep,
  status,
  addedAt
)
SELECT 
  l.trackingId,
  '{{ $json.campaignId }}' as campaignId,
  '{{ $json.campaignName }}' as campaignName,
  1 as sequenceStep,
  'active' as status,
  CURRENT_TIMESTAMP() as addedAt
FROM `outbound_sales.leads` l
WHERE l.trackingId IS NOT NULL
  {% if $json.filters.job_title %}
  AND l.job_title LIKE '{{ $json.filters.job_title }}'
  {% endif %}
  {% if $json.filters.industry %}
  AND l.industry = '{{ $json.filters.industry }}'
  {% endif %}
  {% if $json.filters.company_size %}
  AND l.company_size IN ({{ $json.filters.company_size | map("'$'") | join(', ') }})
  {% endif %}
  {% if $json.filters.seniority %}
  AND l.seniority = '{{ $json.filters.seniority }}'
  {% endif %}
  {% if $json.filters.department %}
  AND l.department = '{{ $json.filters.department }}'
  {% endif %}
  AND NOT EXISTS (
    SELECT 1 FROM `outbound_sales.campaign_members` cm
    WHERE cm.trackingId = l.trackingId
      AND cm.campaignId = '{{ $json.campaignId }}'
  )
LIMIT {{ $json.limit | default(10000) }};
```

---

#### Node 4: Get Member Count
- **Type:** Google BigQuery
- **Operation:** Execute Query
- **Project ID:** `n8n-revenueinstitute`
- **Query:**

```sql
SELECT 
  COUNT(*) as totalMembers
FROM `outbound_sales.campaign_members`
WHERE campaignId = '{{ $json.campaignId }}';
```

---

#### Node 5: Send Confirmation
- **Type:** Set (or Send Email / Slack)
- **Operation:** Set values

**Output:**
```json
{
  "success": true,
  "campaignId": "{{ $json.campaignId }}",
  "campaignName": "{{ $json.campaignName }}",
  "totalMembers": {{ $node["Get Member Count"].json.totalMembers }},
  "message": "Successfully assigned leads to campaign"
}
```

---

## Usage

### Option 1: Via Webhook (Programmatic)

```bash
curl -X POST https://your-n8n-instance.com/webhook/assign-campaign \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic YOUR_AUTH_TOKEN" \
  -d '{
    "campaignId": "q1-outreach-2025",
    "campaignName": "Q1 Outreach Campaign 2025",
    "description": "Targeting VPs in SaaS",
    "totalSequenceSteps": 5,
    "filters": {
      "job_title": "%VP%",
      "industry": "SaaS",
      "company_size": ["51-200", "201-500"]
    },
    "limit": 10000
  }'
```

---

### Option 2: Manual Trigger (N8N UI)

1. Open N8N workflow
2. Click "Execute Workflow"
3. Fill in form:
   - Campaign ID: `q1-outreach-2025`
   - Campaign Name: `Q1 Outreach Campaign 2025`
   - Job Title Filter: `%VP%`
   - Industry: `SaaS`
   - Company Size: `51-200,201-500`
   - Limit: `10000`
4. Click "Execute"

---

### Option 3: From Google Sheets

**Setup:**
1. Create Google Sheet with campaign details
2. Add N8N workflow with "Google Sheets Trigger"
3. When row is added → trigger workflow

**Sheet Columns:**
| Campaign ID | Campaign Name | Job Title | Industry | Company Size | Limit |
|-------------|---------------|-----------|----------|--------------|-------|
| q1-outreach-2025 | Q1 Outreach | %VP% | SaaS | 51-200,201-500 | 10000 |

---

## Common Filters

Copy/paste these into the `filters` object:

### By Job Title
```json
"filters": {
  "job_title": "%VP%"
}
```
```json
"filters": {
  "job_title": "%Director%"
}
```
```json
"filters": {
  "job_title": "%Chief%"
}
```

### By Industry
```json
"filters": {
  "industry": "SaaS"
}
```
```json
"filters": {
  "industry": "Technology"
}
```

### By Company Size
```json
"filters": {
  "company_size": ["11-50", "51-200"]
}
```
```json
"filters": {
  "company_size": ["201-500", "501-1000", "1001-5000"]
}
```

### By Seniority
```json
"filters": {
  "seniority": "VP"
}
```
```json
"filters": {
  "seniority": "C-Level"
}
```

### Multiple Filters (AND)
```json
"filters": {
  "job_title": "%VP%",
  "industry": "SaaS",
  "company_size": ["51-200", "201-500"],
  "seniority": "VP"
}
```

---

## Advanced: Assign by Email List

If you have a CSV with specific emails to add:

**Webhook Payload:**
```json
{
  "campaignId": "q1-outreach-2025",
  "campaignName": "Q1 Outreach Campaign 2025",
  "totalSequenceSteps": 5,
  "emails": [
    "john@company.com",
    "jane@company2.com",
    "bob@company3.com"
  ]
}
```

**Modified Assignment Query:**
```sql
INSERT INTO `outbound_sales.campaign_members` (...)
SELECT 
  l.trackingId,
  '{{ $json.campaignId }}',
  '{{ $json.campaignName }}',
  1,
  'active',
  CURRENT_TIMESTAMP()
FROM `outbound_sales.leads` l
WHERE l.trackingId IS NOT NULL
  AND l.email IN (
    {% for email in $json.emails %}
      '{{ email }}'{% if not loop.last %},{% endif %}
    {% endfor %}
  )
  AND NOT EXISTS (...);
```

---

## Verification

After assignment, check results:

```sql
-- View campaign members
SELECT 
  l.email,
  l.person_name,
  l.company_name,
  l.job_title,
  cm.status,
  cm.addedAt
FROM campaign_members cm
INNER JOIN leads l ON cm.trackingId = l.trackingId
WHERE cm.campaignId = 'q1-outreach-2025'
LIMIT 100;

-- Campaign summary
SELECT 
  campaignName,
  COUNT(*) as totalMembers,
  COUNT(CASE WHEN status = 'active' THEN 1 END) as activeMembers
FROM campaign_members
WHERE campaignId = 'q1-outreach-2025'
GROUP BY campaignName;
```

---

## Export for Email Tool

After assigning, export for Smartlead/Instantly:

```sql
SELECT 
  l.email,
  l.firstName,
  l.lastName,
  l.company_name as company,
  l.job_title as jobTitle,
  CONCAT('https://yourdomain.com?v=', l.trackingId) as trackingUrl
FROM campaign_members cm
INNER JOIN leads l ON cm.trackingId = l.trackingId
WHERE cm.campaignId = 'q1-outreach-2025'
  AND cm.status = 'active';
```

---

## Done!

Now you can:
1. ✅ Create campaigns in BigQuery
2. ✅ Assign leads via N8N webhook
3. ✅ Track performance via views
4. ✅ Export for email tools

