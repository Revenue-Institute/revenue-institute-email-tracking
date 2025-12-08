# Flowise Integration Setup Checklist

This guide shows exactly what needs to change in each repository.

---

## ✅ This Repo (Worker/Tracking) - NO CHANGES NEEDED

**Good news!** Everything is already set up and working:

- ✅ `/personalize` endpoint exists at: `GET /personalize?vid={visitorId}`
- ✅ Personalizer class available in `src/pixel/personalization.ts`
- ✅ Tracking pixel available
- ✅ CORS headers configured
- ✅ All personalization fields available

**You don't need to change anything in this repo!**

---

## 🔧 Your Repo (With Embedded Flowise Function) - CHANGES NEEDED

You need to add code to:
1. Load the tracking pixel
2. Get personalization data
3. Pass it to your custom Flowise function

### Step 1: Include the Tracking Pixel

Add this to your HTML page (in `<head>` or before `</body>`):

```html
<!-- Tracking Pixel -->
<script>
  window.oieConfig = {
    endpoint: 'https://your-worker.workers.dev/track',  // Replace with your worker URL
    debug: true  // Set to false in production
  };
</script>
<script src="https://your-worker.workers.dev/pixel.js"></script>
```

**Important:** 
- Replace `https://your-worker.workers.dev` with your actual worker URL
- The `/pixel.js` endpoint is already available on your worker - no need to build or host it separately
- The pixel includes the `Personalizer` class automatically, so you can use `window.Personalizer` after loading

### Step 2: Add Personalization Code

**Note:** The Personalizer class is not included in the pixel bundle, so we'll use a simple fetch approach (no extra dependencies needed).

Add this script to your page:

Add this script to your page (this is the simplest approach - no Personalizer class needed):

```html
<script>
  /**
   * Personalization Helper
   * Gets visitor data and passes it to your Flowise function
   * This uses a simple fetch - no Personalizer class needed
   */
  async function setupFlowiseWithPersonalization() {
    // Wait for tracker to initialize
    if (!window.oieTracker || !window.oieTracker.visitorId) {
      setTimeout(setupFlowiseWithPersonalization, 500);
      return;
    }

    // Get personalization data from worker
    const workerUrl = 'https://your-worker.workers.dev';  // Replace with your worker URL
    const visitorId = window.oieTracker.visitorId;
    
    try {
      const response = await fetch(`${workerUrl}/personalize?vid=${visitorId}`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' }
      });

      if (!response.ok) {
        console.warn('⚠️ No personalization data available');
        return;
      }

      const data = await response.json();

      if (!data.personalized) {
        console.log('ℹ️ Visitor not in system');
        return;
      }

      // Build variables object (only include values that exist)
      const variables = {};
      
      // Personal
      if (data.firstName) variables.firstName = data.firstName;
      if (data.lastName) variables.lastName = data.lastName;
      if (data.email) variables.email = data.email;
      if (data.phone) variables.phone = data.phone;
      
      // Company
      if (data.company) variables.company = data.company;
      if (data.companyName) variables.companyName = data.companyName;
      if (data.industry) variables.industry = data.industry;
      if (data.companySize) variables.companySize = data.companySize;
      if (data.revenue) variables.revenue = data.revenue;
      
      // Job
      if (data.jobTitle) variables.jobTitle = data.jobTitle;
      if (data.seniority) variables.seniority = data.seniority;
      if (data.department) variables.department = data.department;
      
      // Behavioral
      if (data.intentScore !== undefined) variables.intentScore = data.intentScore;
      if (data.engagementLevel) variables.engagementLevel = data.engagementLevel;
      if (data.totalVisits !== undefined) variables.totalVisits = data.totalVisits;
      if (data.viewedPricing !== undefined) variables.viewedPricing = data.viewedPricing;
      
      // Campaign
      if (data.campaignName) variables.campaignName = data.campaignName;
      
      // Visitor ID
      if (visitorId) variables.visitorId = visitorId;

      console.log('✅ Personalization data loaded:', variables);

      // ============================================
      // PASS TO YOUR CUSTOM FLOWISE FUNCTION
      // ============================================
      // Replace this with your actual custom Flowise function call
      
      YourCustomFlowiseFunction({
        // Your existing Flowise config
        containerId: 'flowise-chatbot-container',
        chatflowId: 'your-chatflow-id',
        apiHost: 'https://your-flowise-instance.com',
        
        // Add personalization variables here
        variables: variables,
        // OR if your function expects sessionVariables:
        // sessionVariables: variables,
        // OR pass individually:
        // firstName: variables.firstName,
        // company: variables.company,
        // etc.
      });

    } catch (error) {
      console.error('❌ Error loading personalization:', error);
    }
  }

  // Initialize when page loads
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupFlowiseWithPersonalization);
  } else {
    setupFlowiseWithPersonalization();
  }
</script>
```

### Step 3: Modify Your Custom Flowise Function

Update your custom Flowise embed function to accept and use the variables:

**Before:**
```javascript
function YourCustomFlowiseFunction(config) {
  // Your existing Flowise initialization code
  const chatflow = new FlowiseChatbot({
    chatflowId: config.chatflowId,
    apiHost: config.apiHost
  });
  chatflow.init(config.containerId);
}
```

**After:**
```javascript
function YourCustomFlowiseFunction(config) {
  // Your existing Flowise initialization code
  const chatflow = new FlowiseChatbot({
    chatflowId: config.chatflowId,
    apiHost: config.apiHost,
    // Pass variables to Flowise
    sessionVariables: config.variables || config.sessionVariables || {}
  });
  chatflow.init(config.containerId);
  
  // Or if your Flowise component reads from a global variable:
  window.flowiseVariables = config.variables;
}
```

**The exact implementation depends on how your custom Flowise component works.** Common patterns:

1. **Session Variables**: Pass as `sessionVariables` in initialization
2. **Global Variable**: Set `window.flowiseVariables = variables`
3. **Function Parameter**: Pass as separate parameters
4. **API Call**: Send variables in API request body

---

## 📋 Complete Example

Here's a complete example of what your page should look like:

```html
<!DOCTYPE html>
<html>
<head>
  <title>My Site with Flowise</title>
</head>
<body>
  <h1>Welcome</h1>
  
  <!-- Flowise Container -->
  <div id="flowise-chatbot-container"></div>

  <!-- 1. Tracking Pixel -->
  <script>
    window.oieConfig = {
      endpoint: 'https://your-worker.workers.dev/track',
      debug: true
    };
  </script>
  <script src="https://your-worker.workers.dev/pixel.js"></script>

  <!-- 2. Your Custom Flowise Script -->
  <script src="path/to/your/custom-flowise.js"></script>

  <!-- 3. Personalization Integration -->
  <script>
    async function setupFlowiseWithPersonalization() {
      if (!window.oieTracker || !window.oieTracker.visitorId) {
        setTimeout(setupFlowiseWithPersonalization, 500);
        return;
      }

      const workerUrl = 'https://your-worker.workers.dev';
      const visitorId = window.oieTracker.visitorId;
      
      try {
        const response = await fetch(`${workerUrl}/personalize?vid=${visitorId}`);
        const data = await response.json();

        if (!data.personalized) return;

        // Build variables
        const variables = {};
        if (data.firstName) variables.firstName = data.firstName;
        if (data.company) variables.company = data.company;
        if (data.jobTitle) variables.jobTitle = data.jobTitle;
        if (data.intentScore !== undefined) variables.intentScore = data.intentScore;
        // ... add all fields you need

        // Call your custom Flowise function
        YourCustomFlowiseFunction({
          containerId: 'flowise-chatbot-container',
          chatflowId: 'your-chatflow-id',
          apiHost: 'https://your-flowise-instance.com',
          variables: variables  // <-- Personalization data
        });

      } catch (error) {
        console.error('Error:', error);
      }
    }

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', setupFlowiseWithPersonalization);
    } else {
      setupFlowiseWithPersonalization();
    }
  </script>
</body>
</html>
```

---

## 🔍 Testing

1. **Test with a tracking ID**: Visit `https://yoursite.com?i=abc123` (where `abc123` is a valid tracking ID in your system)

2. **Check browser console**: You should see:
   - `✅ Personalization data loaded: {firstName: "...", company: "...", ...}`
   - Your Flowise function being called with the variables

3. **Verify in Flowise**: The variables should be available in your Flowise chatflow as `{{firstName}}`, `{{company}}`, etc.

---

## ❓ What If My Custom Flowise Function Works Differently?

If your custom Flowise component has a different API, you can:

1. **Store variables globally**: `window.flowiseVariables = variables;` and have your Flowise component read from there

2. **Use localStorage**: `localStorage.setItem('flowise_variables', JSON.stringify(variables));`

3. **Pass via postMessage**: If Flowise is in an iframe, use `postMessage`

4. **Custom API call**: Make an API call to your Flowise instance with the variables

The key is: **get the variables from the personalization endpoint, then pass them to Flowise however your custom component expects them.**

---

## 📝 Summary

**This Repo (Worker):**
- ✅ Nothing to change - already ready!

**Your Repo (Flowise):**
1. ✅ Add tracking pixel script
2. ✅ Add personalization fetch code
3. ✅ Modify your custom Flowise function to accept variables
4. ✅ Pass variables to Flowise in the format it expects

That's it! 🎉

