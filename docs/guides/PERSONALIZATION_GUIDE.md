# 🎨 Personalization Guide

**Complete guide to using dynamic personalization on your website**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Setup](#setup)
3. [Available Fields](#available-fields)
4. [Usage Examples](#usage-examples)
5. [Conditional Display](#conditional-display)
6. [Fallback Content](#fallback-content)
7. [CSS Styling](#css-styling)
8. [JavaScript API](#javascript-api)
9. [Complete Examples](#complete-examples)
10. [Best Practices](#best-practices)

---

## Overview

The personalization system lets you dynamically customize your website content based on visitor identity and behavior. It works by:

1. **Identifying visitors** via tracking parameter (`?i={{trackingId}}`)
2. **Fetching their data** from Cloudflare KV (<10ms lookup)
3. **Applying personalization** to HTML elements with special attributes
4. **Falling back gracefully** for anonymous visitors

**Key Benefits:**
- ⚡ Lightning fast (<10ms lookups)
- 🎯 Behavior-based targeting
- 🔄 Automatic fallbacks
- 🎨 No server-side rendering needed
- 📊 Full integration with tracking data

---

## Setup

### Step 1: Install Tracking Pixel

Add to all pages where you want personalization:

```html
<!DOCTYPE html>
<html>
<head>
  <title>Your Page</title>
</head>
<body>
  <!-- Your content here -->

  <!-- Tracking Pixel -->
  <script>
    window.oieConfig = {
      endpoint: 'https://intel.revenueinstitute.com/track',
      debug: false  // Set to true for development
    };
  </script>
  <script src="/dist/pixel.js"></script>

  <!-- Personalization Script -->
  <script>
    window.addEventListener('DOMContentLoaded', async () => {
      // Check if visitor is identified
      if (window.oieTracker && window.oieTracker.visitorId) {
        // Initialize personalizer
        const personalizer = new window.Personalizer(
          'https://intel.revenueinstitute.com/personalize',
          window.oieTracker.visitorId
        );
        
        // Apply personalization to page
        await personalizer.personalize();
        
        // Optional: Listen for personalization event
        window.addEventListener('personalized', (e) => {
          console.log('Page personalized with data:', e.detail);
        });
      } else {
        console.log('Visitor not identified - showing default content');
      }
    });
  </script>
</body>
</html>
```

### Step 2: Hide Elements Until Personalized (Optional)

Add this CSS to prevent flash of default content:

```html
<style>
  /* Hide personalized content until loaded */
  [data-show-if] {
    display: none;
  }
  
  /* Optional: Add fade-in animation */
  [data-show-if].personalized {
    animation: fadeIn 0.3s ease-in;
  }
  
  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }
</style>
```

---

## Available Fields

### Core Identity Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `personalized` | boolean | Whether visitor is identified | `true` |
| `firstName` | string | Visitor's first name | "John" |
| `lastName` | string | Visitor's last name | "Smith" |
| `company` | string | Company name | "Acme Corp" |

### Behavioral Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `intentScore` | number | Behavioral intent score (0-100) | `75` |
| `engagementLevel` | string | Engagement level | "hot" |
| `viewedPricing` | boolean | Has viewed pricing page | `true` |
| `submittedForm` | boolean | Has submitted a form | `true` |

### Engagement Levels

- **`cold`** - Low engagement, minimal activity
- **`warm`** - Moderate engagement, some interest
- **`hot`** - High engagement, strong interest signals
- **`burning`** - Extremely high intent, ready to buy

---

## Usage Examples

### Basic Text Replacement

Use `data-personalize` to replace text with visitor data:

```html
<!-- Simple name personalization -->
<h1>Welcome, <span data-personalize="firstName">there</span>!</h1>

<!-- Company personalization -->
<p>Solutions built for <span data-personalize="company">companies like yours</span></p>

<!-- Multiple personalizations -->
<div>
  <p>Hi <span data-personalize="firstName">Friend</span>,</p>
  <p>We help <span data-personalize="company">businesses</span> grow revenue.</p>
</div>
```

**How it works:**
- **Identified visitor**: Shows personalized data (e.g., "Welcome, John!")
- **Anonymous visitor**: Shows fallback text (e.g., "Welcome, there!")

### Inline Personalization

You can use personalizations inline without breaking text flow:

```html
<h1>
  Welcome<span data-personalize="firstName" style="display: none;">, <span></span></span>!
</h1>
<!-- Result for John: "Welcome, John!" -->
<!-- Result for anonymous: "Welcome!" -->

<p>
  Perfect for 
  <span data-personalize="industry">your industry</span> 
  companies of 
  <span data-personalize="companySize">all sizes</span>.
</p>
```

---

## Conditional Display

Use `data-show-if` to show/hide entire sections based on conditions.

### Show for Identified Visitors Only

```html
<!-- Show only if visitor is identified -->
<div data-show-if="personalized">
  <h2>Welcome back!</h2>
  <p>We remember you, <span data-personalize="firstName">friend</span>!</p>
</div>
```

### Show Based on Behavior

```html
<!-- Show if they viewed pricing -->
<div data-show-if="viewedPricing">
  <h2>🔥 Ready to get started?</h2>
  <p>We saw you checked out our pricing. Let's talk!</p>
  <a href="/demo" class="btn">Book a Demo</a>
</div>

<!-- Show if they submitted a form -->
<div data-show-if="submittedForm">
  <div class="alert">
    <p>✅ Thanks for reaching out! We'll be in touch within 24 hours.</p>
  </div>
</div>
```

### Show Based on Intent Score

```html
<!-- Show for high-intent visitors (score > 50) -->
<div data-show-if="intentScore>50">
  <h2>You're highly engaged! 🎯</h2>
  <p>Your engagement score: <strong data-personalize="intentScore">0</strong>/100</p>
  <p>Level: <strong data-personalize="engagementLevel">warm</strong></p>
</div>

<!-- Show for very high-intent visitors -->
<div data-show-if="intentScore>80">
  <div class="urgent-cta">
    <h3>🚀 Let's talk now!</h3>
    <p>Based on your activity, we think you're ready. Schedule a call?</p>
    <a href="/schedule" class="btn-primary">Schedule Call →</a>
  </div>
</div>
```

### Show Based on Engagement Level

```html
<!-- Show for "hot" leads -->
<div data-show-if="engagementLevel=hot">
  <div class="hot-lead-banner">
    <p>🔥 You're on fire! Special offer just for you...</p>
  </div>
</div>

<!-- Show for "burning" leads -->
<div data-show-if="engagementLevel=burning">
  <div class="emergency-cta">
    <p>⚡ Book a demo in the next hour and get 20% off!</p>
  </div>
</div>
```

---

## Fallback Content

The key to great personalization is **graceful fallbacks** for anonymous visitors.

### Strategy 1: Default Text in Element

Put fallback text directly in the element:

```html
<!-- Shows "there" for anonymous, "John" for identified -->
<h1>Welcome, <span data-personalize="firstName">there</span>!</h1>

<!-- Shows "your company" for anonymous, "Acme Corp" for identified -->
<p>Built for <span data-personalize="company">your company</span></p>
```

### Strategy 2: Generic + Personalized Sections

Show generic content to everyone, plus extra for identified visitors:

```html
<!-- Generic content (always visible) -->
<div>
  <h1>Transform Your Sales Process</h1>
  <p>Powerful tools for modern sales teams.</p>
</div>

<!-- Personalized overlay (only for identified visitors) -->
<div data-show-if="personalized">
  <div class="personalized-banner">
    <p>👋 Welcome back, <span data-personalize="firstName">there</span> from 
       <span data-personalize="company">your team</span>!</p>
  </div>
</div>
```

### Strategy 3: Separate Anonymous vs Identified Sections

Show completely different content based on identification:

```html
<!-- Anonymous visitor content -->
<div id="anonymous-content">
  <h2>See How We Can Help</h2>
  <p>Join thousands of companies using our platform.</p>
  <a href="/signup" class="btn">Get Started</a>
</div>

<!-- Identified visitor content (replaces anonymous) -->
<div data-show-if="personalized">
  <h2>Welcome back, <span data-personalize="firstName">friend</span>!</h2>
  <p>Pick up where you left off with <span data-personalize="company">your team</span>.</p>
  <a href="/dashboard" class="btn">Go to Dashboard</a>
</div>

<script>
  // Hide anonymous content if personalized
  window.addEventListener('personalized', () => {
    document.getElementById('anonymous-content').style.display = 'none';
  });
</script>
```

### Strategy 4: Progressive Enhancement

Start generic, enhance with personalization:

```html
<div class="hero">
  <!-- Base content (always shown) -->
  <h1 id="hero-title">Grow Your Revenue</h1>
  <p id="hero-subtitle">The platform built for results.</p>
  
  <script>
    // Enhance with personalization if available
    window.addEventListener('personalized', (e) => {
      if (e.detail.firstName) {
        document.getElementById('hero-title').innerHTML = 
          `Welcome back, ${e.detail.firstName}!`;
      }
      if (e.detail.company) {
        document.getElementById('hero-subtitle').innerHTML = 
          `Solutions built for ${e.detail.company}`;
      }
    });
  </script>
</div>
```

### Strategy 5: Conditional Logic for Fallbacks

```html
<p>
  Perfect for 
  <span data-personalize="industry">growing businesses</span>
  with 
  <span data-personalize="companySize">ambitious goals</span>.
</p>
<!-- Anonymous: "Perfect for growing businesses with ambitious goals" -->
<!-- Identified: "Perfect for SaaS companies with 50-200 employees" -->
```

---

## CSS Styling

### Automatic Body Classes

The system automatically adds engagement classes to `<body>`:

```css
/* Default state */
body {
  background: white;
}

/* Hot leads */
body.engagement-hot {
  background: #fff5f5;
}

body.engagement-hot .cta-button {
  animation: pulse 2s infinite;
  background: #ff6b6b;
}

/* Burning hot leads */
body.engagement-burning {
  background: #fff0f0;
}

body.engagement-burning .personalized-section {
  border-left: 5px solid #ff0000;
  box-shadow: 0 0 20px rgba(255, 0, 0, 0.3);
}

@keyframes pulse {
  0%, 100% { box-shadow: 0 0 10px rgba(255, 0, 0, 0.3); }
  50% { box-shadow: 0 0 20px rgba(255, 0, 0, 0.6); }
}
```

### Custom Styling Based on Personalization

```css
/* Style personalized elements */
[data-personalize] {
  color: #667eea;
  font-weight: 600;
}

/* Style conditional sections when shown */
[data-show-if] {
  display: none; /* Hidden by default */
}

/* Add entrance animation */
[data-show-if].visible {
  display: block;
  animation: slideIn 0.5s ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
```

---

## JavaScript API

### Access Personalization Data

```javascript
window.addEventListener('personalized', (e) => {
  const data = e.detail;
  
  console.log('Personalization data:', data);
  console.log('First Name:', data.firstName);
  console.log('Company:', data.company);
  console.log('Intent Score:', data.intentScore);
  console.log('Engagement Level:', data.engagementLevel);
  console.log('Viewed Pricing:', data.viewedPricing);
  console.log('Submitted Form:', data.submittedForm);
});
```

### Manual Personalization

```javascript
// Wait for tracker to initialize
if (window.oieTracker?.visitorId) {
  const personalizer = new window.Personalizer(
    'https://intel.revenueinstitute.com/personalize',
    window.oieTracker.visitorId
  );
  
  // Fetch data
  const data = await personalizer.fetch();
  
  if (data.personalized) {
    console.log('Visitor is identified:', data);
    
    // Apply personalization
    await personalizer.personalize();
    
    // Get data again later
    const currentData = personalizer.getData();
  } else {
    console.log('Anonymous visitor');
  }
}
```

### Custom Logic Based on Personalization

```javascript
window.addEventListener('personalized', (e) => {
  const { intentScore, engagementLevel, viewedPricing, company } = e.detail;
  
  // High-intent visitor actions
  if (intentScore > 80) {
    console.log('🔥 High-intent visitor detected!');
    
    // Trigger live chat
    if (window.Intercom) {
      window.Intercom('show');
    }
    
    // Show urgent CTAs
    document.querySelectorAll('.urgent-cta').forEach(el => {
      el.style.display = 'block';
    });
    
    // Alert sales team (webhook, etc.)
    fetch('/api/alert-sales', {
      method: 'POST',
      body: JSON.stringify({
        company,
        intentScore,
        timestamp: Date.now()
      })
    });
  }
  
  // Viewed pricing but didn't convert
  if (viewedPricing && !e.detail.submittedForm) {
    // Show special offer
    document.getElementById('pricing-offer').style.display = 'block';
  }
  
  // Engagement-based actions
  switch (engagementLevel) {
    case 'hot':
      // Show demo CTA
      break;
    case 'burning':
      // Show urgent offers
      break;
    case 'cold':
      // Show educational content
      break;
  }
});
```

### Check If Visitor Is Identified

```javascript
// Simple check
if (window.oieTracker?.visitorId) {
  console.log('Visitor is identified');
} else {
  console.log('Anonymous visitor');
}

// Wait for initialization
window.addEventListener('DOMContentLoaded', () => {
  if (window.oieTracker?.visitorId) {
    // Personalization code here
  } else {
    // Anonymous visitor code here
  }
});
```

---

## Complete Examples

### Example 1: Simple Landing Page

```html
<!DOCTYPE html>
<html>
<head>
  <title>Welcome</title>
  <style>
    [data-show-if] { display: none; }
    body.engagement-hot { background: #fff5f5; }
  </style>
</head>
<body>
  <!-- Hero -->
  <section class="hero">
    <h1>Welcome<span data-personalize="firstName">, <span></span></span>!</h1>
    <p>Powerful sales tools for modern teams.</p>
  </section>

  <!-- Personalized message for identified visitors -->
  <section data-show-if="personalized">
    <div class="welcome-back">
      <p>👋 Great to see you again, <span data-personalize="firstName">there</span>!</p>
      <p>We've prepared some updates for <span data-personalize="company">your team</span>.</p>
    </div>
  </section>

  <!-- High-intent CTA -->
  <section data-show-if="intentScore>70">
    <div class="urgent-cta">
      <h2>You're highly engaged! 🔥</h2>
      <p>Score: <span data-personalize="intentScore">0</span>/100</p>
      <a href="/demo" class="btn">Book Demo Now →</a>
    </div>
  </section>

  <!-- Tracking Pixel -->
  <script>
    window.oieConfig = {
      endpoint: 'https://intel.revenueinstitute.com/track'
    };
  </script>
  <script src="/dist/pixel.js"></script>

  <!-- Personalization -->
  <script>
    window.addEventListener('DOMContentLoaded', async () => {
      if (window.oieTracker?.visitorId) {
        const personalizer = new window.Personalizer(
          'https://intel.revenueinstitute.com/personalize',
          window.oieTracker.visitorId
        );
        await personalizer.personalize();
      }
    });
  </script>
</body>
</html>
```

### Example 2: Pricing Page with Dynamic CTAs

```html
<!DOCTYPE html>
<html>
<head>
  <title>Pricing</title>
</head>
<body>
  <!-- Standard pricing (always visible) -->
  <section class="pricing">
    <h1>Simple, Transparent Pricing</h1>
    <div class="plans">
      <!-- Pricing cards -->
    </div>
  </section>

  <!-- First-time visitor CTA -->
  <section id="generic-cta">
    <h2>Ready to Get Started?</h2>
    <a href="/signup" class="btn">Start Free Trial</a>
  </section>

  <!-- Return visitor personalized CTA -->
  <section data-show-if="personalized">
    <h2>Welcome back, <span data-personalize="firstName">there</span>!</h2>
    <p>Ready to upgrade <span data-personalize="company">your team</span>?</p>
    <a href="/contact-sales" class="btn">Talk to Sales</a>
  </section>

  <!-- High-intent visitor urgent CTA -->
  <section data-show-if="intentScore>80">
    <div class="urgent-offer">
      <h2>⚡ Special Offer Just For You</h2>
      <p>Book a demo today and get 20% off your first year!</p>
      <a href="/demo" class="btn-urgent">Book Demo Now →</a>
    </div>
  </section>

  <script>
    window.oieConfig = {
      endpoint: 'https://intel.revenueinstitute.com/track'
    };
  </script>
  <script src="/dist/pixel.js"></script>
  <script>
    window.addEventListener('DOMContentLoaded', async () => {
      if (window.oieTracker?.visitorId) {
        const personalizer = new window.Personalizer(
          'https://intel.revenueinstitute.com/personalize',
          window.oieTracker.visitorId
        );
        await personalizer.personalize();
        
        // Hide generic CTA if personalized
        window.addEventListener('personalized', () => {
          document.getElementById('generic-cta').style.display = 'none';
        });
      }
    });
  </script>
</body>
</html>
```

### Example 3: Blog Post with Smart CTAs

```html
<!DOCTYPE html>
<html>
<head>
  <title>Blog Post</title>
</head>
<body>
  <!-- Blog content -->
  <article>
    <h1>How to Scale Your Sales Team</h1>
    <p>Content here...</p>
  </article>

  <!-- Anonymous visitor CTA -->
  <aside id="anonymous-cta">
    <div class="cta-box">
      <h3>Want More Content Like This?</h3>
      <p>Subscribe to our newsletter for weekly insights.</p>
      <form action="/subscribe">
        <input type="email" placeholder="Your email">
        <button>Subscribe</button>
      </form>
    </div>
  </aside>

  <!-- Known visitor CTA -->
  <aside data-show-if="personalized">
    <div class="cta-box">
      <h3>Hi <span data-personalize="firstName">there</span>!</h3>
      <p>Based on this article, we think you'd love our sales automation platform.</p>
      <a href="/product" class="btn">Learn More →</a>
    </div>
  </aside>

  <!-- High-engagement visitor -->
  <aside data-show-if="intentScore>60">
    <div class="cta-box highlight">
      <h3>🎯 You've been highly engaged!</h3>
      <p>Let's discuss how we can help <span data-personalize="company">your company</span> grow.</p>
      <a href="/demo" class="btn">Schedule a Call →</a>
    </div>
  </aside>

  <script>
    window.oieConfig = {
      endpoint: 'https://intel.revenueinstitute.com/track'
    };
  </script>
  <script src="/dist/pixel.js"></script>
  <script>
    window.addEventListener('DOMContentLoaded', async () => {
      if (window.oieTracker?.visitorId) {
        const personalizer = new window.Personalizer(
          'https://intel.revenueinstitute.com/personalize',
          window.oieTracker.visitorId
        );
        await personalizer.personalize();
        
        // Replace anonymous CTA
        window.addEventListener('personalized', () => {
          document.getElementById('anonymous-cta').style.display = 'none';
        });
      }
    });
  </script>
</body>
</html>
```

---

## Best Practices

### ✅ DO

1. **Always provide fallback text**
   ```html
   <!-- Good: Has fallback -->
   <span data-personalize="firstName">there</span>
   
   <!-- Bad: Empty if no data -->
   <span data-personalize="firstName"></span>
   ```

2. **Make fallbacks natural and inclusive**
   ```html
   <!-- Good: Natural fallbacks -->
   <h1>Welcome, <span data-personalize="firstName">friend</span>!</h1>
   <p>Built for <span data-personalize="company">companies like yours</span></p>
   
   <!-- Bad: Awkward fallbacks -->
   <h1>Welcome, <span data-personalize="firstName">[Name]</span>!</h1>
   ```

3. **Test with and without personalization**
   - View page as anonymous visitor (no `?i=` parameter)
   - View page as identified visitor (with `?i=` parameter)
   - Check both look good

4. **Use progressive enhancement**
   - Show good default content
   - Enhance with personalization
   - Never break for anonymous visitors

5. **Leverage engagement levels for targeting**
   ```html
   <!-- Show different CTAs by engagement -->
   <div data-show-if="engagementLevel=cold">Educational content</div>
   <div data-show-if="engagementLevel=hot">Book a demo</div>
   <div data-show-if="engagementLevel=burning">Limited-time offer!</div>
   ```

### ❌ DON'T

1. **Don't show empty elements**
   ```html
   <!-- Bad: Could be empty -->
   <h1>Welcome, <span data-personalize="firstName"></span></h1>
   
   <!-- Good: Has fallback -->
   <h1>Welcome<span data-personalize="firstName">, <span></span></span>!</h1>
   ```

2. **Don't make anonymous experience worse**
   ```html
   <!-- Bad: Looks broken for anonymous -->
   <h1>Welcome, [NAME]</h1>
   
   <!-- Good: Works for everyone -->
   <h1>Welcome!</h1>
   <p data-show-if="personalized">
     Great to see you, <span data-personalize="firstName">friend</span>!
   </p>
   ```

3. **Don't overdo personalization**
   - Use sparingly for impact
   - Don't personalize every word
   - Focus on key conversion points

4. **Don't forget about privacy**
   - Only personalize with data visitor provided
   - Be transparent about tracking
   - Respect do-not-track preferences

5. **Don't rely solely on personalization**
   - Your core content should work without it
   - Personalization enhances, not replaces

---

## Troubleshooting

### Personalization Not Working?

1. **Check visitor is identified**
   ```javascript
   console.log('Visitor ID:', window.oieTracker?.visitorId);
   // Should show an ID, not null
   ```

2. **Check personalization endpoint**
   ```javascript
   // Enable debug mode
   window.oieConfig = {
     endpoint: 'https://intel.revenueinstitute.com/track',
     debug: true  // See console logs
   };
   ```

3. **Check data is in KV store**
   - Visitor must be in Cloudflare KV
   - Run sync script: `npm run sync-leads-to-kv`
   - Or wait for hourly auto-sync

4. **Check browser console for errors**
   ```javascript
   // Should see these logs:
   // "Visitor ID: abc123..."
   // "Page personalized: {firstName: 'John', ...}"
   ```

### Common Issues

**Issue:** Personalization flashes default then changes

**Solution:** Add CSS to hide until loaded
```css
[data-show-if] { display: none; }
```

**Issue:** Fallback text shows even for identified visitors

**Solution:** Check data attribute spelling matches exactly:
```html
<!-- Correct -->
<span data-personalize="firstName">there</span>

<!-- Wrong (camelCase) -->
<span data-personalize="firstname">there</span>
```

**Issue:** Conditional sections not showing

**Solution:** Check condition syntax:
```html
<!-- Correct -->
<div data-show-if="intentScore>50">High intent</div>
<div data-show-if="engagementLevel=hot">Hot lead</div>

<!-- Wrong (spaces, quotes) -->
<div data-show-if="intentScore > 50">High intent</div>
<div data-show-if="engagementLevel='hot'">Hot lead</div>
```

---

## Support

- **Example pages**: See `/examples/example-page.html`
- **Source code**: `src/pixel/personalization.ts`
- **Worker endpoint**: `https://intel.revenueinstitute.com/personalize`
- **GitHub**: https://github.com/smlowisz/revenue-institute-email-tracking

---

**Last Updated:** December 15, 2024
