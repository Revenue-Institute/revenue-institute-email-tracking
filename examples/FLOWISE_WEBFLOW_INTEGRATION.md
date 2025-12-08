# Flowise Integration for Webflow (Pixel Already in GTM)

This guide is for when:
- ✅ Pixel is already loaded via Google Tag Manager (in page `<head>` or site settings)
- ✅ Using a custom Flowise component (not native Flowise widget, not an iframe)
- ✅ Embedding in Webflow using a code embed

---

## Important: GTM is Separate

**GTM doesn't need to be in the embed code.** GTM loads the pixel globally (usually in Webflow's site settings or page custom code). The embed code below is standalone - it just uses the tracker that GTM already loaded.

---

## What You Need to Do

Since the pixel is already loaded via GTM, you just need to:
1. **Get personalization data** (using the tracker that's already loaded)
2. **Pass it to your custom Flowise component**

**No GTM code needed in the embed!**

---

## Step 1: Add Code Embed in Webflow

In your Webflow page, add a **Code Embed** element where you want your Flowise chatbot to appear.

**Note:** This embed code is standalone. It doesn't include GTM - it just uses the tracker that GTM already loaded on the page.

### Option A: Simple Fetch Approach (Recommended)

Add this code to your Webflow Code Embed:

```html
<div id="flowise-chatbot-container"></div>

<script>
  /**
   * Get personalization data and pass to custom Flowise component
   * Pixel is already loaded via GTM, so we just need to fetch data
   */
  async function setupFlowiseWithPersonalization() {
    // Wait for tracker to initialize (from GTM)
    if (!window.oieTracker || !window.oieTracker.visitorId) {
      // Retry after a short delay
      setTimeout(setupFlowiseWithPersonalization, 500);
      return;
    }

    // Your worker URL (replace with your actual worker URL)
    const workerUrl = 'https://your-worker.workers.dev';
    const visitorId = window.oieTracker.visitorId;
    
    try {
      // Fetch personalization data
      const response = await fetch(`${workerUrl}/personalize?vid=${visitorId}`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' }
      });

      if (!response.ok) {
        console.warn('⚠️ No personalization data available');
        // Initialize Flowise without personalization
        initializeCustomFlowise({});
        return;
      }

      const data = await response.json();

      if (!data.personalized) {
        console.log('ℹ️ Visitor not in system');
        // Initialize Flowise without personalization
        initializeCustomFlowise({});
        return;
      }

      // Build variables object (only include values that exist)
      const variables = {};
      
      // Personal Information
      if (data.firstName) variables.firstName = data.firstName;
      if (data.lastName) variables.lastName = data.lastName;
      if (data.email) variables.email = data.email;
      if (data.phone) variables.phone = data.phone;
      if (data.linkedin) variables.linkedin = data.linkedin;
      
      // Company Information
      if (data.company) variables.company = data.company;
      if (data.companyName) variables.companyName = data.companyName;
      if (data.industry) variables.industry = data.industry;
      if (data.companySize) variables.companySize = data.companySize;
      if (data.revenue) variables.revenue = data.revenue;
      if (data.companyWebsite) variables.companyWebsite = data.companyWebsite;
      
      // Job Information
      if (data.jobTitle) variables.jobTitle = data.jobTitle;
      if (data.seniority) variables.seniority = data.seniority;
      if (data.department) variables.department = data.department;
      
      // Behavioral Data
      if (data.intentScore !== undefined) variables.intentScore = data.intentScore;
      if (data.engagementLevel) variables.engagementLevel = data.engagementLevel;
      if (data.totalVisits !== undefined) variables.totalVisits = data.totalVisits;
      if (data.totalPageviews !== undefined) variables.totalPageviews = data.totalPageviews;
      if (data.viewedPricing !== undefined) variables.viewedPricing = data.viewedPricing;
      if (data.submittedForm !== undefined) variables.submittedForm = data.submittedForm;
      if (data.isFirstVisit !== undefined) variables.isFirstVisit = data.isFirstVisit;
      
      // Campaign Attribution
      if (data.campaignId) variables.campaignId = data.campaignId;
      if (data.campaignName) variables.campaignName = data.campaignName;
      
      // Visitor ID
      if (visitorId) variables.visitorId = visitorId;

      console.log('✅ Personalization data loaded:', variables);

      // Initialize your custom Flowise component with variables
      initializeCustomFlowise(variables);

    } catch (error) {
      console.error('❌ Error loading personalization:', error);
      // Initialize Flowise without personalization on error
      initializeCustomFlowise({});
    }
  }

  /**
   * Initialize your custom Flowise component
   * Replace this function with your actual custom Flowise initialization code
   */
  function initializeCustomFlowise(variables) {
    // ============================================
    // REPLACE THIS WITH YOUR ACTUAL FLOWISE CODE
    // ============================================
    
    // Example 1: If your custom component accepts variables as a parameter
    if (window.YourCustomFlowiseComponent) {
      window.YourCustomFlowiseComponent({
        container: document.getElementById('flowise-chatbot-container'),
        chatflowId: 'your-chatflow-id',
        apiHost: 'https://your-flowise-instance.com',
        variables: variables  // <-- Personalization data passed here
      });
    }

    // Example 2: If your component reads from a global variable
    window.flowiseVariables = variables;
    // Then your component can access: window.flowiseVariables.firstName, etc.

    // Example 3: If your component uses sessionVariables
    if (window.FlowiseChatbot) {
      window.FlowiseChatbot.init({
        chatflowid: 'your-chatflow-id',
        apiHost: 'https://your-flowise-instance.com',
        sessionVariables: variables
      });
    }

    // Example 4: If you're making a direct API call
    // fetch('https://your-flowise-instance.com/api/v1/chatflow/your-chatflow-id', {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify({
    //     question: 'Hello',
    //     sessionVariables: variables
    //   })
    // });

    console.log('✅ Custom Flowise initialized with variables:', variables);
  }

  // Initialize when page loads
  // Wait a bit for GTM to load the pixel
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      // Give GTM a moment to load the pixel
      setTimeout(setupFlowiseWithPersonalization, 1000);
    });
  } else {
    // Page already loaded, wait for GTM
    setTimeout(setupFlowiseWithPersonalization, 1000);
  }

  // Also listen for personalization event (if pixel dispatches it)
  window.addEventListener('personalized', (e) => {
    console.log('📨 Personalization event received:', e.detail);
    if (e.detail && e.detail.personalized) {
      const variables = {};
      if (e.detail.firstName) variables.firstName = e.detail.firstName;
      if (e.detail.company) variables.company = e.detail.company;
      // ... add all fields you need
      initializeCustomFlowise(variables);
    }
  });
</script>
```

---

## Step 2: Replace `initializeCustomFlowise()` Function

**This is the key part** - replace the `initializeCustomFlowise()` function with your actual custom Flowise component initialization code.

### How to Find Your Custom Flowise Code

Your custom Flowise component code should look something like:

```javascript
// Your existing custom Flowise code (example)
function initMyCustomFlowise() {
  const chatflow = new MyCustomChatbot({
    chatflowId: 'abc123',
    apiHost: 'https://flowise.example.com',
    container: document.getElementById('chatbot-container')
  });
  chatflow.init();
}
```

### Modify It to Accept Variables

```javascript
function initMyCustomFlowise(variables) {
  const chatflow = new MyCustomChatbot({
    chatflowId: 'abc123',
    apiHost: 'https://flowise.example.com',
    container: document.getElementById('chatbot-container'),
    // Add variables here - format depends on your component
    sessionVariables: variables,
    // OR
    // variables: variables,
    // OR
    // initialVariables: variables
  });
  chatflow.init();
}
```

**The exact parameter name depends on how your custom component works.** Common names:
- `variables`
- `sessionVariables`
- `initialVariables`
- `userData`
- `context`

---

## Step 3: Update Your Worker URL

Replace `https://your-worker.workers.dev` with your actual worker URL.

You can find this in:
- Your Cloudflare Workers dashboard
- Your `wrangler.toml` file
- Or check where your GTM pixel is pointing to

---

## Complete Minimal Example

If you just want the bare minimum:

```html
<div id="flowise-chatbot-container"></div>

<script>
  async function setupFlowise() {
    if (!window.oieTracker?.visitorId) {
      setTimeout(setupFlowise, 500);
      return;
    }

    try {
      const response = await fetch(`https://your-worker.workers.dev/personalize?vid=${window.oieTracker.visitorId}`);
      const data = await response.json();
      
      if (data.personalized) {
        const vars = {};
        if (data.firstName) vars.firstName = data.firstName;
        if (data.company) vars.company = data.company;
        if (data.intentScore !== undefined) vars.intentScore = data.intentScore;
        // Add more fields as needed
        
        // Call your custom Flowise function
        YourCustomFlowiseFunction({ variables: vars });
      }
    } catch (error) {
      console.error('Error:', error);
    }
  }

  setTimeout(setupFlowise, 1000); // Wait for GTM to load pixel
</script>
```

---

## Testing

1. **Visit your Webflow site** with a tracking ID: `https://yoursite.com?i=abc123`
2. **Open browser console** (F12)
3. **Look for**:
   - `✅ Personalization data loaded: {...}`
   - `✅ Custom Flowise initialized with variables: {...}`
4. **Check your Flowise chatbot** - it should have access to the variables

---

## Troubleshooting

### "oieTracker is not defined"
- The pixel hasn't loaded yet from GTM
- Increase the timeout: `setTimeout(setupFlowiseWithPersonalization, 2000);`
- Check that GTM is actually loading the pixel

### "No personalization data available"
- Visitor might not be in your leads database
- Check that the tracking ID (`?i=abc123`) matches a lead in your system
- Verify your worker URL is correct

### Variables not appearing in Flowise
- Check how your custom component expects variables
- Try different parameter names: `variables`, `sessionVariables`, etc.
- Check browser console for errors
- Verify your Flowise instance can receive session variables

---

## Summary

**What you need to do:**
1. ✅ Pixel is already loaded via GTM (no changes needed)
2. ✅ Add Code Embed in Webflow with the script above
3. ✅ Replace `initializeCustomFlowise()` with your actual Flowise code
4. ✅ Update the worker URL
5. ✅ Test with a tracking ID

That's it! 🎉

