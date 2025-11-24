# What's Actually Being Tracked

Simple, clear list of what data exists in your BigQuery tables.

---

## 📊 events Table - What's Stored

### **Direct Columns** (Always Available)

```sql
SELECT 
  type,              -- Event type (pageview, click, scroll_depth, etc.)
  timestamp,         -- When it happened (client time)
  serverTimestamp,   -- When worker received it
  sessionId,         -- Session identifier
  visitorId,         -- Tracking ID (or NULL if anonymous)
  url,               -- Full page URL
  referrer,          -- Where they came from
  
  -- Server enrichment
  ip,                -- IP address
  country,           -- US, UK, CA
  city,              -- New York, London
  region,            -- NY, California
  timezone,          -- America/New_York
  userAgent,         -- Browser string
  colo,              -- Cloudflare datacenter
  asn,               -- ISP number
  
  -- Metadata
  _insertedAt        -- When inserted into BigQuery
  
FROM outbound_sales.events;
```

### **data Field** (JSON - Query with JSON_EXTRACT)

**For pageview events:**
```sql
JSON_EXTRACT_SCALAR(data, '$.title')         -- Page title
JSON_EXTRACT_SCALAR(data, '$.path')          -- /pricing, /demo
JSON_EXTRACT_SCALAR(data, '$.search')        -- ?utm_source=email
JSON_EXTRACT_SCALAR(data, '$.referrer')      -- Full referrer URL
JSON_EXTRACT_SCALAR(data, '$.screenWidth')   -- 1920
JSON_EXTRACT_SCALAR(data, '$.viewportWidth') -- 1440
JSON_EXTRACT_SCALAR(data, '$.language')      -- en-US
JSON_EXTRACT_SCALAR(data, '$.timezone')      -- America/Detroit

-- UTM parameters (if present in URL)
JSON_EXTRACT_SCALAR(data, '$.utm_source')    -- email, social, google
JSON_EXTRACT_SCALAR(data, '$.utm_medium')    -- email, cpc, organic
JSON_EXTRACT_SCALAR(data, '$.utm_campaign')  -- q1_outbound
JSON_EXTRACT_SCALAR(data, '$.utm_term')      -- keywords
JSON_EXTRACT_SCALAR(data, '$.utm_content')   -- variant_a
JSON_EXTRACT_SCALAR(data, '$.gclid')         -- Google Ads click ID
JSON_EXTRACT_SCALAR(data, '$.fbclid')        -- Facebook click ID
```

**For click events:**
```sql
JSON_EXTRACT_SCALAR(data, '$.elementId')     -- button-cta-demo
JSON_EXTRACT_SCALAR(data, '$.elementClass')  -- btn btn-primary
JSON_EXTRACT_SCALAR(data, '$.elementText')   -- "Get Your AI Agent"
JSON_EXTRACT_SCALAR(data, '$.href')          -- https://...
JSON_EXTRACT_SCALAR(data, '$.x')             -- Click X coordinate
JSON_EXTRACT_SCALAR(data, '$.y')             -- Click Y coordinate
```

**For form_submit events:**
```sql
JSON_EXTRACT_SCALAR(data, '$.formId')        -- contact-form
JSON_EXTRACT_SCALAR(data, '$.email_sha256')  -- Hashed email
JSON_EXTRACT_SCALAR(data, '$.hasEmail')      -- true/false
```

---

## 🎯 Useful Queries

### **See All Button Clicks:**
```sql
SELECT 
  JSON_EXTRACT_SCALAR(data, '$.elementText') as button_clicked,
  JSON_EXTRACT_SCALAR(data, '$.elementId') as button_id,
  COUNT(*) as clicks
FROM `n8n-revenueinstitute.outbound_sales.events`
WHERE type = 'click'
GROUP BY button_clicked, button_id
ORDER BY clicks DESC;
```

### **See All Pages Visited:**
```sql
SELECT 
  url,
  JSON_EXTRACT_SCALAR(data, '$.title') as page_title,
  COUNT(*) as pageviews
FROM `n8n-revenueinstitute.outbound_sales.events`
WHERE type = 'pageview'
GROUP BY url, page_title
ORDER BY pageviews DESC;
```

### **See UTM Performance:**
```sql
SELECT 
  JSON_EXTRACT_SCALAR(data, '$.utm_source') as source,
  JSON_EXTRACT_SCALAR(data, '$.utm_campaign') as campaign,
  COUNT(DISTINCT visitorId) as visitors,
  COUNT(*) as events
FROM `n8n-revenueinstitute.outbound_sales.events`
WHERE type = 'pageview'
  AND JSON_EXTRACT_SCALAR(data, '$.utm_source') IS NOT NULL
GROUP BY source, campaign
ORDER BY visitors DESC;
```

### **See What Anonymous Visitors Do (No tracking ID):**
```sql
SELECT 
  sessionId,
  COUNT(*) as events,
  COUNT(DISTINCT JSON_EXTRACT_SCALAR(data, '$.path')) as unique_pages,
  ARRAY_AGG(DISTINCT JSON_EXTRACT_SCALAR(data, '$.path') IGNORE NULLS) as pages_visited
FROM `n8n-revenueinstitute.outbound_sales.events`
WHERE visitorId IS NULL
  AND type = 'pageview'
GROUP BY sessionId
HAVING events > 3  -- Active sessions only
ORDER BY events DESC
LIMIT 100;
```

---

## 📋 Actual Data Summary

**What EXISTS in your events table:**
- ✅ Every page URL
- ✅ Every button clicked (ID, class, text)
- ✅ IP, country, city, ISP
- ✅ User agent (device/browser)
- ✅ UTM parameters (in data JSON)
- ✅ Timestamps (client + server)
- ✅ Session + Visitor IDs

**What DOESN'T exist yet** (until you hard reload site with new pixel):
- ⏳ Enhanced UTM extraction
- ⏳ Additional device fingerprinting
- ⏳ Email de-anonymization events
- ⏳ Iframe tracking

These will appear once you hard reload to get the new pixel!

---

## ✅ Bottom Line

**You're tracking:**
- ✅ Button names/IDs/text - YES! (in click events)
- ✅ Every page URL - YES!
- ✅ UTM parameters - YES! (in data field)
- ✅ IP, geo, ISP - YES!
- ✅ Email hashes - YES! (on form submit)

**Just query the `data` JSON field to access it all!**

---

**Want me to create some specific queries for your use cases?** 📊
