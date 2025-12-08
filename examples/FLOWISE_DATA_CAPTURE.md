# Capturing Flowise Chatbot Data via Pixel

This guide shows how to capture user data from Flowise chatbot interactions and send it to your tracking system using the pixel.

---

## ✅ Why Use the Pixel (Recommended)

**The pixel automatically captures:**
- ✅ IP address (hashed for privacy)
- ✅ User agent
- ✅ Cookies (visitor ID, session ID)
- ✅ Geographic data (country, city, region)
- ✅ Device type (desktop, mobile, tablet)
- ✅ Network info (ISP, ASN)
- ✅ Timestamps
- ✅ URL parameters
- ✅ Email hashing (SHA-256, SHA-1)

**All you need to do:** Call `window.oieTracker.track()` with your chatbot data!

---

## 🚀 Basic Usage

### Simple Event Tracking

```javascript
// In your Flowise integration code
if (window.oieTracker) {
  window.oieTracker.track('flowise_message', {
    message: 'User asked about pricing',
    intent: 'pricing_inquiry',
    chatflowId: 'your-chatflow-id'
  });
}
```

---

## 📧 Capturing Email Addresses

The pixel automatically hashes emails. You have two options:

### Option 1: Pass Email Directly (Recommended)

The pixel will automatically hash it on the server side:

```javascript
// When user provides email in chatbot
if (window.oieTracker && userEmail) {
  window.oieTracker.track('flowise_email_captured', {
    email: userEmail,  // Will be hashed automatically
    source: 'chatbot',
    chatflowId: 'your-chatflow-id',
    conversationId: 'conv-123'
  });
}
```

### Option 2: Hash Email Client-Side (If Needed)

If you need the hash immediately, you can hash it yourself:

```javascript
async function hashEmail(email) {
  const normalized = email.toLowerCase().trim();
  const encoder = new TextEncoder();
  const data = encoder.encode(normalized);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

// Usage
const emailHash = await hashEmail(userEmail);
window.oieTracker.track('flowise_email_captured', {
  emailHash: emailHash,
  emailDomain: userEmail.split('@')[1],
  source: 'chatbot'
});
```

---

## 📝 Complete Example: Tracking Chatbot Interactions

Here's a complete example that tracks all chatbot interactions:

```javascript
/**
 * Flowise Chatbot Data Capture
 * Call this from your Flowise integration
 */

// 1. Track when user starts conversation
function trackChatbotStart(chatflowId) {
  if (window.oieTracker) {
    window.oieTracker.track('flowise_conversation_start', {
      chatflowId: chatflowId,
      timestamp: Date.now(),
      source: 'chatbot'
    });
  }
}

// 2. Track user messages
function trackUserMessage(message, conversationId) {
  if (window.oieTracker) {
    window.oieTracker.track('flowise_user_message', {
      message: message.substring(0, 500), // Limit length
      conversationId: conversationId,
      messageLength: message.length,
      timestamp: Date.now()
    });
  }
}

// 3. Track when user provides information
function trackUserDataProvided(data) {
  if (window.oieTracker) {
    const eventData = {
      source: 'chatbot',
      timestamp: Date.now()
    };
    
    // Add any fields user provided
    if (data.email) {
      eventData.email = data.email; // Will be auto-hashed
      eventData.emailDomain = data.email.split('@')[1];
    }
    if (data.name) eventData.name = data.name;
    if (data.company) eventData.company = data.company;
    if (data.phone) eventData.phone = data.phone;
    if (data.message) eventData.message = data.message.substring(0, 500);
    
    window.oieTracker.track('flowise_data_captured', eventData);
  }
}

// 4. Track chatbot responses
function trackChatbotResponse(response, conversationId) {
  if (window.oieTracker) {
    window.oieTracker.track('flowise_bot_response', {
      response: response.substring(0, 500),
      conversationId: conversationId,
      responseLength: response.length,
      timestamp: Date.now()
    });
  }
}

// 5. Track conversation completion
function trackConversationComplete(conversationId, summary) {
  if (window.oieTracker) {
    window.oieTracker.track('flowise_conversation_complete', {
      conversationId: conversationId,
      summary: summary,
      timestamp: Date.now()
    });
  }
}

// 6. Track specific intents/actions
function trackChatbotIntent(intent, confidence, data) {
  if (window.oieTracker) {
    window.oieTracker.track('flowise_intent', {
      intent: intent,
      confidence: confidence,
      data: data,
      timestamp: Date.now()
    });
  }
}
```

---

## 🔗 Integration with Flowise

### Option A: Call from Flowise Webhook/API

If Flowise calls a webhook or you have access to Flowise's API:

```javascript
// In your Flowise webhook handler or custom code
window.addEventListener('flowise-message', (event) => {
  const { type, data } = event.detail;
  
  if (type === 'user_message') {
    trackUserMessage(data.message, data.conversationId);
  } else if (type === 'bot_response') {
    trackChatbotResponse(data.response, data.conversationId);
  } else if (type === 'data_captured') {
    trackUserDataProvided(data);
  }
});
```

### Option B: Call from Flowise Custom Component

If you're using a custom Flowise component:

```javascript
// In your custom Flowise component
class MyFlowiseComponent {
  onMessage(userMessage) {
    // Your existing Flowise logic
    this.sendToFlowise(userMessage);
    
    // Track it
    trackUserMessage(userMessage, this.conversationId);
  }
  
  onResponse(botResponse) {
    // Your existing Flowise logic
    this.displayResponse(botResponse);
    
    // Track it
    trackChatbotResponse(botResponse, this.conversationId);
  }
  
  onDataCapture(userData) {
    // Your existing Flowise logic
    this.processData(userData);
    
    // Track it
    trackUserDataProvided(userData);
  }
}
```

### Option C: Intercept Flowise API Calls

If Flowise makes API calls you can intercept:

```javascript
// Intercept fetch calls to Flowise API
const originalFetch = window.fetch;
window.fetch = function(...args) {
  const url = args[0];
  
  // Check if it's a Flowise API call
  if (typeof url === 'string' && url.includes('flowise') && url.includes('api')) {
    return originalFetch.apply(this, args)
      .then(response => {
        // Clone response to read body
        const clonedResponse = response.clone();
        clonedResponse.json().then(data => {
          // Track the interaction
          if (window.oieTracker) {
            window.oieTracker.track('flowise_api_call', {
              url: url,
              method: args[1]?.method || 'GET',
              data: data
            });
          }
        }).catch(() => {}); // Ignore errors
        
        return response;
      });
  }
  
  return originalFetch.apply(this, args);
};
```

---

## 📊 What Gets Automatically Captured

Every event you track automatically includes:

### Server-Side Enrichment (Automatic)
- ✅ **IP Address** (hashed: `ipHash`)
- ✅ **User Agent** (`userAgent`)
- ✅ **Geographic Data**: country, city, region, continent, postal code
- ✅ **Network Info**: ISP, ASN, company identifier
- ✅ **Device Type**: desktop, mobile, tablet
- ✅ **Cookies**: visitor ID, session ID (from pixel)
- ✅ **Timestamps**: client timestamp + server timestamp
- ✅ **URL Parameters**: all query params, UTM parameters
- ✅ **TLS Info**: TLS version, cipher

### Client-Side Data (From Pixel)
- ✅ **Visitor ID** (`visitorId`)
- ✅ **Session ID** (`sessionId`)
- ✅ **Page URL** (`url`)
- ✅ **Referrer** (`referrer`)

---

## 🎯 Example: Complete Flowise Integration

```html
<script>
  // Wait for tracker to be ready
  function waitForTracker(callback) {
    if (window.oieTracker) {
      callback();
    } else {
      setTimeout(() => waitForTracker(callback), 500);
    }
  }

  // Initialize Flowise tracking
  waitForTracker(() => {
    console.log('✅ Tracker ready for Flowise integration');
    
    // Your Flowise initialization code here
    // ... initialize Flowise ...
    
    // Example: Track when Flowise loads
    window.oieTracker.track('flowise_loaded', {
      chatflowId: 'your-chatflow-id',
      timestamp: Date.now()
    });
  });

  // Track user interactions
  function trackFlowiseInteraction(type, data) {
    if (window.oieTracker) {
      window.oieTracker.track(`flowise_${type}`, {
        ...data,
        timestamp: Date.now(),
        visitorId: window.oieTracker.visitorId,
        sessionId: window.oieTracker.sessionId
      });
    }
  }

  // Example usage in your Flowise component
  // When user sends a message:
  trackFlowiseInteraction('user_message', {
    message: userMessage,
    conversationId: conversationId
  });

  // When user provides email:
  trackFlowiseInteraction('email_captured', {
    email: userEmail,
    source: 'chatbot',
    conversationId: conversationId
  });

  // When user provides other data:
  trackFlowiseInteraction('data_captured', {
    name: userName,
    company: userCompany,
    phone: userPhone,
    message: userMessage,
    conversationId: conversationId
  });
</script>
```

---

## 🔍 Viewing Captured Data

All events are stored in BigQuery `events` table:

```sql
-- View all Flowise events
SELECT 
  type,
  visitorId,
  timestamp,
  JSON_EXTRACT_SCALAR(data, '$.email') as email,
  JSON_EXTRACT_SCALAR(data, '$.message') as message,
  JSON_EXTRACT_SCALAR(data, '$.conversationId') as conversationId,
  ip,
  userAgent,
  country,
  city
FROM `your-project.outbound_sales.events`
WHERE type LIKE 'flowise_%'
ORDER BY timestamp DESC
LIMIT 100;
```

---

## ✅ Best Practices

1. **Always check if tracker exists:**
   ```javascript
   if (window.oieTracker) {
     window.oieTracker.track(...);
   }
   ```

2. **Limit data size:**
   ```javascript
   // Limit message length
   message: message.substring(0, 500)
   ```

3. **Use consistent event names:**
   ```javascript
   // Good: flowise_user_message
   // Bad: userMessage, chatbot_message, etc.
   ```

4. **Include conversation context:**
   ```javascript
   // Always include conversationId for linking events
   conversationId: conversationId
   ```

5. **Don't send sensitive data unhashed:**
   ```javascript
   // Email will be auto-hashed, but other PII should be hashed
   // or sent only if necessary
   ```

---

## 🚨 Important Notes

- **Email hashing**: Emails are automatically hashed on the server side
- **Data limits**: Keep event data under 1MB total
- **Rate limiting**: Events are batched automatically (100ms delay)
- **Privacy**: IP addresses are hashed automatically
- **Cookies**: Visitor ID and session ID are captured automatically

---

## 📝 Summary

**Easiest approach:** Use `window.oieTracker.track()` from your Flowise integration code.

**What you get automatically:**
- ✅ IP, user agent, cookies, geo data
- ✅ Email hashing
- ✅ Automatic enrichment
- ✅ BigQuery storage
- ✅ Visitor/session tracking

**What you need to do:**
- ✅ Call `track()` with your chatbot data
- ✅ Use consistent event names
- ✅ Include conversation context

That's it! 🎉




