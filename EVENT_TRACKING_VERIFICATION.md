# Event Tracking Verification Guide

## ✅ What Events Are Now Being Tracked

### 1. **All Mouse Clicks** (Enhanced)
- **Previously**: Only tracked clicks on links (`<a>`) and buttons (`<button>`)
- **Now**: Tracks **ALL mouse clicks** anywhere on the page
- **Data Captured**:
  - Click coordinates (x, y)
  - Element information (tag, id, class, text)
  - Whether it's a link/button or other element
  - Mouse button used (left, middle, right)

### 2. **Keyboard Events** (NEW)
- **Previously**: Not tracked at all
- **Now**: Tracks **all key presses** (keydown events)
- **Data Captured**:
  - Key pressed (e.g., "Enter", "a", "Space")
  - Key code and which
  - Modifier keys (Shift, Ctrl, Alt, Meta)
  - Context (input field, textarea, etc.)
  - Target element information

### 3. **Video Events** (Enhanced)
- **Previously**: Only tracked videos present at page load
- **Now**: Tracks videos added dynamically via JavaScript
- **Events Tracked**:
  - `video_play` - When video starts playing
  - `video_pause` - When video is paused (with current time)
  - `video_progress` - At 25%, 50%, 75% completion
  - `video_complete` - When video reaches 100% or ends
- **Data Captured**:
  - Video source URL
  - Video duration
  - Current time (for pause events)
  - Progress percentage
  - Video ID and class (if available)

### 4. **Existing Events** (Still Working)
- Pageviews
- Scroll depth
- Form submissions
- Form field focus
- Email capture
- Copy/paste events
- Rage clicks
- Focus gained/lost

## 🔍 How to Verify Events Are Being Sent

### Step 1: Check Browser Console

1. Open your test page with the tracking pixel loaded
2. Open browser DevTools (F12 or Cmd+Option+I)
3. Go to the Console tab
4. Look for messages like:
   ```
   [OutboundIntentTracker] Event tracked: click
   [OutboundIntentTracker] Event tracked: key_press
   [OutboundIntentTracker] Sending events: click, key_press
   [OutboundIntentTracker] Fetch response: 200 2 events
   ```

### Step 2: Test Events Manually

1. **Test Clicks**:
   - Click anywhere on the page (not just buttons)
   - Click on text, images, divs, etc.
   - You should see `click` events in the console

2. **Test Keyboard**:
   - Click in an input field and type
   - Press keys anywhere on the page
   - You should see `key_press` events in the console
   - Note: Modifier keys alone (Shift, Ctrl, Alt) are not tracked to reduce noise

3. **Test Video Events**:
   - Add a `<video>` element to your page (or use existing one)
   - Click play → should see `video_play` event
   - Pause video → should see `video_pause` event
   - Watch video → should see `video_progress` at 25%, 50%, 75%
   - Complete video → should see `video_complete` event
   - **Dynamic videos**: Videos added via JavaScript are also tracked automatically

### Step 3: Verify in BigQuery

Run this query in BigQuery to see all tracked events:

```sql
SELECT 
  type,
  timestamp,
  visitorId,
  sessionId,
  url,
  JSON_EXTRACT_SCALAR(data, '$.key') as key_pressed,
  JSON_EXTRACT_SCALAR(data, '$.elementType') as element_clicked,
  JSON_EXTRACT_SCALAR(data, '$.x') as click_x,
  JSON_EXTRACT_SCALAR(data, '$.y') as click_y,
  _insertedAt
FROM `your-project.outbound_sales.events`
WHERE type IN ('click', 'key_press')
  AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
ORDER BY timestamp DESC
LIMIT 100;
```

### Step 4: Count Events by Type

```sql
SELECT 
  type,
  COUNT(*) as event_count,
  COUNT(DISTINCT visitorId) as unique_visitors,
  COUNT(DISTINCT sessionId) as unique_sessions
FROM `your-project.outbound_sales.events`
WHERE _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY type
ORDER BY event_count DESC;
```

## 📊 Event Data Structure

### Click Event Data
```json
{
  "type": "click",
  "elementType": "div",
  "elementId": "my-div",
  "elementClass": "container",
  "elementText": "Click me",
  "href": null,
  "x": 150,
  "y": 200,
  "button": 0,
  "isLinkOrButton": false,
  "targetTag": "div",
  "targetId": "my-div",
  "targetClass": "container"
}
```

### Key Press Event Data
```json
{
  "type": "key_press",
  "key": "Enter",
  "code": "Enter",
  "keyCode": 13,
  "which": 13,
  "shiftKey": false,
  "ctrlKey": false,
  "altKey": false,
  "metaKey": false,
  "isInputField": true,
  "targetTag": "input",
  "targetType": "text",
  "targetId": "email-input",
  "targetName": "email",
  "defaultPrevented": false
}
```

### Video Event Data Examples

**Video Play:**
```json
{
  "type": "video_play",
  "src": "https://example.com/video.mp4",
  "duration": 120.5,
  "videoId": "intro-video",
  "videoClass": "hero-video"
}
```

**Video Progress:**
```json
{
  "type": "video_progress",
  "src": "https://example.com/video.mp4",
  "progress": 50,
  "currentTime": 60.25,
  "duration": 120.5,
  "videoId": "intro-video"
}
```

**Video Complete:**
```json
{
  "type": "video_complete",
  "src": "https://example.com/video.mp4",
  "duration": 120.5,
  "videoId": "intro-video"
}
```

## 🚀 Event Flow

1. **Client Side** (`src/pixel/index.ts`):
   - Event listeners capture clicks and key presses
   - Events are queued via `trackEvent()`
   - Events are flushed to server every 100ms

2. **Server Side** (`src/worker/index.ts`):
   - Events received at `/track` endpoint
   - Events enriched with server-side data (IP, geo, etc.)
   - Events stored in BigQuery `events` table

3. **BigQuery**:
   - All events stored in `events` table
   - Event data stored in `data` JSON field
   - Queryable via SQL

## ⚠️ Important Notes

1. **Keyboard Event Filtering**: 
   - Modifier keys alone (Shift, Ctrl, Alt, Meta, Tab, CapsLock) are NOT tracked
   - This prevents noise from accidental modifier key presses
   - Only actual character/action keys are tracked

2. **Event Batching**:
   - Events are batched and sent every 100ms
   - This prevents overwhelming the server with rapid events
   - All events are still captured and sent

3. **Privacy**:
   - Keyboard events in input fields track the key but NOT the value
   - This respects user privacy while tracking engagement

## 🧪 Testing Checklist

- [ ] Click events appear in console for all clicks (not just buttons)
- [ ] Keyboard events appear in console when typing
- [ ] Video play event fires when video starts
- [ ] Video progress events fire at 25%, 50%, 75%
- [ ] Video complete event fires when video ends
- [ ] Dynamically added videos are tracked (test by adding video via JavaScript)
- [ ] Events show "Sending events" message in console
- [ ] Events show "Fetch response: 200" in console
- [ ] Events appear in BigQuery within 1-2 minutes
- [ ] Click events have x, y coordinates
- [ ] Key press events have key, code, and context
- [ ] Video events have src, duration, and progress data
- [ ] All event types are queryable in BigQuery

## 📝 Example BigQuery Queries

### Find all clicks in the last hour
```sql
SELECT 
  timestamp,
  visitorId,
  JSON_EXTRACT_SCALAR(data, '$.elementType') as element,
  JSON_EXTRACT_SCALAR(data, '$.x') as x,
  JSON_EXTRACT_SCALAR(data, '$.y') as y
FROM `your-project.outbound_sales.events`
WHERE type = 'click'
  AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
ORDER BY timestamp DESC;
```

### Find all keyboard events in input fields
```sql
SELECT 
  timestamp,
  visitorId,
  JSON_EXTRACT_SCALAR(data, '$.key') as key_pressed,
  JSON_EXTRACT_SCALAR(data, '$.targetType') as input_type,
  JSON_EXTRACT_SCALAR(data, '$.targetName') as field_name
FROM `your-project.outbound_sales.events`
WHERE type = 'key_press'
  AND JSON_EXTRACT_SCALAR(data, '$.isInputField') = 'true'
  AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
ORDER BY timestamp DESC;
```

### Find all video events
```sql
SELECT 
  type,
  timestamp,
  visitorId,
  JSON_EXTRACT_SCALAR(data, '$.src') as video_src,
  JSON_EXTRACT_SCALAR(data, '$.progress') as progress_percent,
  JSON_EXTRACT_SCALAR(data, '$.currentTime') as current_time,
  JSON_EXTRACT_SCALAR(data, '$.duration') as duration
FROM `your-project.outbound_sales.events`
WHERE type IN ('video_play', 'video_pause', 'video_progress', 'video_complete')
  AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY timestamp DESC;
```

### Count video completions by video
```sql
SELECT 
  JSON_EXTRACT_SCALAR(data, '$.src') as video_src,
  COUNT(*) as completion_count,
  COUNT(DISTINCT visitorId) as unique_viewers
FROM `your-project.outbound_sales.events`
WHERE type = 'video_complete'
  AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY video_src
ORDER BY completion_count DESC;
```

### Count events by type for a specific visitor
```sql
SELECT 
  type,
  COUNT(*) as count,
  MIN(TIMESTAMP_MILLIS(timestamp)) as first_event,
  MAX(TIMESTAMP_MILLIS(timestamp)) as last_event
FROM `your-project.outbound_sales.events`
WHERE visitorId = 'your-visitor-id'
  AND _insertedAt >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY type
ORDER BY count DESC;
```

