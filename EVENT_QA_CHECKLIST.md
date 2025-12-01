# Event Tracking QA Checklist

Complete list of all events tracked by the Outbound Intent Engine pixel.

---

## ✅ Automatic Events (No User Action Required)

### 1. **`pageview`** 
**When:** Every page load  
**Data captured:**
- Page title, path, URL
- Referrer & domain
- UTM parameters (utm_source, utm_medium, utm_campaign, etc.)
- Device info (screen size, browser, OS, language)
- Network info (connection type, speed)
- Geo data (timezone, local time, business hours)
- Visit number (1st visit vs return)
- Device fingerprint

**How to test:**
```
1. Visit any page on your site
2. Check BigQuery for type = 'pageview'
3. Verify data.title, data.path, data.deviceFingerprint exist
```

---

## 📊 Engagement Events

### 2. **`scroll_depth`**
**When:** User scrolls to 25%, 50%, 75%, 90%, 100% of page  
**Data captured:**
- `depth`: scroll percentage (25, 50, 75, 90, 100)
- `pixelsScrolled`: actual scroll distance

**How to test:**
```
1. Visit a long page
2. Scroll to bottom slowly
3. Should see 5 events (one for each milestone)
4. Check: JSON_VALUE(data, '$.depth')
```

### 3. **`click`**
**When:** Click on links (`<a>`) or buttons (`<button>`)  
**Data captured:**
- `elementType`: 'a' or 'button'
- `elementId`: element ID
- `elementClass`: CSS classes
- `elementText`: button/link text (first 100 chars)
- `href`: link destination
- `x`, `y`: click coordinates

**How to test:**
```
1. Click any button or link on your site
2. Check BigQuery for type = 'click'
3. Verify data.elementText shows button text
4. Verify data.href shows link destination
```

**IMPORTANT:** Only tracks `<a>` and `<button>` elements, NOT:
- Generic `<div>` with onClick
- `<span>` buttons
- Custom React/Vue components (unless they render as `<button>`)

---

## 📝 Form Events

### 4. **`form_start`**
**When:** User focuses on any form field (input, textarea, select)  
**Data captured:**
- `formId`: form element ID
- `fieldName`: field name or ID

**How to test:**
```
1. Click into any form field (email, name, etc.)
2. Check BigQuery for type = 'form_start'
3. Verify data.formId and data.fieldName
```

### 5. **`form_submit`**
**When:** Form is submitted  
**Data captured:**
- `formId`: form ID
- `formAction`: form action URL
- `formMethod`: GET/POST
- `fields`: array of field names
- `hasEmail`: boolean if email field detected

**How to test:**
```
1. Fill out and submit a form
2. Check BigQuery for type = 'form_submit'
3. Verify data.hasEmail = true if email was entered
```

### 6. **`email_captured`**
**When:** Form with email field is submitted  
**Data captured:**
- `formId`: which form
- `previouslyAnonymous`: was visitor unknown before?

**How to test:**
```
1. Submit form with email field
2. Check for type = 'email_captured'
3. Should fire AFTER form_submit
```

### 7. **`email_identified`**
**When:** User types email and blurs the field (without submitting)  
**Data captured:**
- `emailHash`: SHA256 hash of email
- `emailDomain`: domain part of email
- `wasAnonymous`: was visitor unknown?
- `sessionId`: current session

**How to test:**
```
1. Type email in field
2. Click outside field (blur)
3. Check for type = 'email_identified'
4. Verify data.emailDomain = 'gmail.com' (or actual domain)
```

---

## 🎥 Video Events

### 8. **`video_play`**
**When:** HTML5 `<video>` element starts playing  
**Data captured:**
- `src`: video source URL

**How to test:**
```
1. Add <video> element to page
2. Click play
3. Check for type = 'video_play'
```

### 9. **`video_pause`**
**When:** Video is paused  
**Data captured:**
- `src`: video URL
- `currentTime`: timestamp when paused

**How to test:**
```
1. Play video, then pause
2. Check for type = 'video_pause'
3. Verify data.currentTime
```

### 10. **`video_progress`**
**When:** Video reaches 25%, 50%, 75% completion  
**Data captured:**
- `src`: video URL
- `progress`: 25, 50, or 75

**How to test:**
```
1. Play video at least 75% through
2. Should see 3 events (25%, 50%, 75%)
3. Check data.progress values
```

### 11. **`video_complete`**
**When:** Video reaches 100% completion  
**Data captured:**
- `src`: video URL

**How to test:**
```
1. Watch video to end
2. Check for type = 'video_complete'
```

**NOTE:** Only tracks native `<video>` elements, NOT:
- YouTube embeds
- Vimeo embeds
- Custom video players (unless they use `<video>` tag)

---

## 📋 Copy/Paste Events

### 12. **`text_copied`**
**When:** User copies text (Cmd/Ctrl+C)  
**Data captured:**
- `textLength`: number of characters
- `textPreview`: first 100 characters
- `page`: current pathname

**How to test:**
```
1. Select and copy any text on page
2. Check for type = 'text_copied'
3. Verify data.textPreview shows copied text
```

### 13. **`text_pasted`**
**When:** User pastes into form field  
**Data captured:**
- `fieldName`: which field
- `page`: current pathname

**How to test:**
```
1. Paste text into any input/textarea
2. Check for type = 'text_pasted'
```

---

## 😤 Rage Events

### 14. **`rage_click`**
**When:** User clicks 5+ times within 2 seconds (frustrated user)  
**Data captured:** None (just the event itself)

**How to test:**
```
1. Rapidly click anywhere 5+ times in 2 seconds
2. Check for type = 'rage_click'
3. Should only fire once, then reset
```

---

## 👁️ Visibility Events

### 15. **`focus_gained`**
**When:** User returns to tab (tab becomes visible)  
**Data captured:** None

**How to test:**
```
1. Switch to different tab
2. Switch back to your site's tab
3. Check for type = 'focus_gained'
```

### 16. **`focus_lost`**
**When:** User switches away from tab  
**Data captured:** None

**How to test:**
```
1. Switch to different tab
2. Check for type = 'focus_lost'
```

---

## 🚪 Exit Events

### 17. **`page_exit`**
**When:** User leaves page (close tab, navigate away, refresh)  
**Data captured:**
- `activeTime`: seconds user was active
- `totalTime`: total seconds on page
- `maxScrollDepth`: deepest scroll percentage
- `readingTime`: time spent reading (slow scroll)
- `scanningTime`: time spent fast scrolling
- `readingRatio`: readingTime / totalTime
- `engagementQuality`: 'high' or 'low'
- `pagesThisSession`: number of pages visited
- `timePerPage`: average time per page
- `deviceFingerprint`: device ID
- `browserId`: persistent browser ID

**How to test:**
```
1. Visit page, scroll, read for 30+ seconds
2. Close tab or navigate away
3. Check for type = 'page_exit'
4. Verify data.totalTime, data.maxScrollDepth, data.readingTime
```

---

## 📱 Device Switching

### 18. **`device_switched`**
**When:** Same visitor (with tracking ID) visits from a new device  
**Data captured:**
- `previousDeviceCount`: how many devices before
- `newDevice`: device fingerprint
- `allDevices`: array of all device fingerprints

**How to test:**
```
1. Visit with ?i=testid123 on desktop
2. Visit with ?i=testid123 on mobile (or different browser)
3. Check for type = 'device_switched'
4. Verify data.allDevices shows both devices
```

---

## 🎯 Manual Events

### 19. **`identify`**
**When:** Manual call to `window.oieTracker.identify(visitorId)`  
**Data captured:**
- `visitorId`: the ID provided

**How to test:**
```
1. Open browser console
2. Run: window.oieTracker.identify('manual-test-123')
3. Check for type = 'identify'
4. Verify visitorId = 'manual-test-123'
```

### 20. **Custom Events**
**When:** Manual call to `window.oieTracker.track(eventName, data)`  
**Data captured:** Whatever you pass in

**How to test:**
```javascript
// In browser console:
window.oieTracker.track('custom_event', { 
  action: 'clicked_pricing', 
  plan: 'enterprise' 
})

// Check BigQuery:
// type = 'custom_event'
// data.action = 'clicked_pricing'
// data.plan = 'enterprise'
```

---

## 🔍 BigQuery Queries for QA

### See all event types:
```sql
SELECT 
  type,
  COUNT(*) as count,
  MAX(_insertedAt) as last_seen
FROM `n8n-revenueinstitute.outbound_sales.events`
WHERE _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
GROUP BY type
ORDER BY count DESC;
```

### See specific event details:
```sql
SELECT 
  type,
  data,
  visitorId,
  url,
  city,
  country,
  _insertedAt
FROM `n8n-revenueinstitute.outbound_sales.events`
WHERE type = 'click'  -- Change to any event type
ORDER BY _insertedAt DESC
LIMIT 10;
```

### See scroll depths:
```sql
SELECT 
  JSON_VALUE(data, '$.depth') AS scroll_percent,
  COUNT(*) as count
FROM `n8n-revenueinstitute.outbound_sales.events`
WHERE type = 'scroll_depth'
  AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
GROUP BY scroll_percent
ORDER BY CAST(scroll_percent AS INT64);
```

### See button clicks:
```sql
SELECT 
  JSON_VALUE(data, '$.elementText') AS button_text,
  JSON_VALUE(data, '$.href') AS link_url,
  COUNT(*) as clicks
FROM `n8n-revenueinstitute.outbound_sales.events`
WHERE type = 'click'
  AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
GROUP BY button_text, link_url
ORDER BY clicks DESC;
```

---

## ⚠️ Common Issues

### Clicks Not Being Tracked?

**Check if your buttons/links are actual HTML elements:**
```html
✅ WILL TRACK:
<button>Click Me</button>
<a href="/page">Link</a>

❌ WON'T TRACK:
<div onClick="...">Click Me</div>
<span class="button">Click Me</span>
```

**Solution:** Use semantic HTML (`<button>`, `<a>`) or add manual tracking:
```javascript
document.querySelector('.custom-button').addEventListener('click', () => {
  window.oieTracker.track('custom_click', { button: 'hero-cta' });
});
```

### Videos Not Being Tracked?

Only tracks HTML5 `<video>` elements, not YouTube/Vimeo embeds.

**For YouTube/Vimeo:** Use their APIs and manual tracking:
```javascript
// YouTube iframe API example
player.addEventListener('onStateChange', (event) => {
  if (event.data === YT.PlayerState.PLAYING) {
    window.oieTracker.track('youtube_play', { videoId: 'abc123' });
  }
});
```

### Form Events Not Firing?

Make sure you're using actual `<form>` elements with `<input>`, `<textarea>`, or `<select>` tags.

---

## 📊 Expected Event Volume

For a typical user session (5 min on site, visits 3 pages):
- **`pageview`**: 3 events
- **`scroll_depth`**: 10-15 events (5 per page on average)
- **`click`**: 5-10 events
- **`focus_gained/lost`**: 2-4 events
- **`page_exit`**: 3 events
- **`form_start`**: 0-2 events (if forms present)
- **`form_submit`**: 0-1 events

**Total: 23-38 events per typical session**

If you're seeing much less, check:
1. Is pixel loaded? (Check Network tab)
2. Are events being sent? (Check Network tab for `/track` POST requests)
3. Are events being saved? (Check Cloudflare logs)
4. Is schema correct? (Check BigQuery table structure)

---

## ✅ Quick QA Test Plan

**5-Minute Test (cover most events):**
1. Visit homepage → `pageview`
2. Scroll to bottom → 5x `scroll_depth` (25%, 50%, 75%, 90%, 100%)
3. Click a button → `click`
4. Click into form field → `form_start`
5. Type email and blur → `email_identified`
6. Submit form → `form_submit`, `email_captured`
7. Copy some text → `text_copied`
8. Switch tabs and back → `focus_lost`, `focus_gained`
9. Click 5+ times fast → `rage_click`
10. Close tab → `page_exit`

**Expected: ~15-20 events in BigQuery within 1-2 minutes**

---

**Happy QA Testing! 🎯**

