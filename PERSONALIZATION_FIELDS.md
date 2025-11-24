# Personalization Fields Available

All data available for personalizing your website content.

---

## 🎯 How Personalization Works

When someone visits with `?i=abc123`:

1. Pixel calls: `GET /personalize?vid=abc123`
2. Worker looks up in identity_map → joins with leads table
3. Returns ALL lead data + behavioral data (if return visitor)
4. Page personalizes instantly (<50ms first visit, <10ms return visit)

---

## 📋 All Available Fields

### **Personal Information**

| Field | Type | Example | Use For |
|-------|------|---------|---------|
| `firstName` | string | "John" | Greetings, CTAs |
| `lastName` | string | "Doe" | Formal address |
| `personName` | string | "John Doe" | Full name display |
| `email` | string | "john@acme.com" | Contact info |
| `phone` | string | "+1234567890" | Click-to-call buttons |
| `linkedin` | string | "linkedin.com/in/johndoe" | Social proof |

---

### **Company Information**

| Field | Type | Example | Use For |
|-------|------|---------|---------|
| `company` | string | "Acme Corp" | Personalized messaging |
| `companyName` | string | "Acme Corp" | Same as above |
| `domain` | string | "acme.com" | Email domain |
| `companyWebsite` | string | "acme.com" | Links |
| `companyDescription` | string | "Leading widget maker" | Context |
| `companySize` | string | "100-500" | Enterprise vs SMB |
| `revenue` | string | "$10M-$50M" | Budget indicator |
| `industry` | string | "Technology" | Industry-specific content |
| `companyLinkedin` | string | "linkedin.com/company/acme" | Social proof |

---

### **Job Information**

| Field | Type | Example | Use For |
|-------|------|---------|---------|
| `jobTitle` | string | "VP of Sales" | Role-based content |
| `seniority` | string | "Executive" | Decision maker flag |
| `department` | string | "Sales" | Department-specific content |

---

### **Campaign Attribution**

| Field | Type | Example | Use For |
|-------|------|---------|---------|
| `campaignId` | string | "q1_outbound" | Track source |
| `campaignName` | string | "Q1 Outbound Campaign" | Context |

---

### **Behavioral Data** (Return Visitors Only)

| Field | Type | Example | Use For |
|-------|------|---------|---------|
| `intentScore` | number | 75 | Prioritization |
| `engagementLevel` | string | "hot" | Urgency |
| `totalVisits` | number | 3 | Frequency |
| `totalPageviews` | number | 15 | Engagement |
| `isFirstVisit` | boolean | false | Welcome vs return message |
| `viewedPricing` | boolean | true | Show next step |
| `submittedForm` | boolean | false | CTA adjustment |

---

## 🎨 How to Use in HTML

### **Basic Personalization:**

```html
<!-- Welcome message -->
<h1>
  Welcome back, <span data-personalize="firstName">there</span>!
</h1>

<!-- Company-specific -->
<p>
  Great to see <span data-personalize="companyName">your company</span> 
  exploring our solutions.
</p>

<!-- Role-based -->
<p data-show-if="seniority=Executive">
  As a <span data-personalize="jobTitle">leader</span>, 
  you'll appreciate our executive dashboard.
</p>

<!-- Industry-specific -->
<div data-show-if="industry">
  <h2>Solutions for <span data-personalize="industry">your industry</span></h2>
</div>
```

---

### **Advanced Personalization:**

```html
<!-- Company size-based pricing -->
<div data-show-if="companySize">
  <p>Perfect for companies with <span data-personalize="companySize">your team size</span></p>
</div>

<!-- Revenue-based messaging -->
<div data-show-if="revenue">
  <p>Built for companies at the <span data-personalize="revenue">your revenue stage</span></p>
</div>

<!-- Department-specific content -->
<div data-show-if="department=Sales">
  <h3>Sales Team Solutions</h3>
  <p>Hi <span data-personalize="firstName">there</span>, 
     see how we help sales teams like yours...</p>
</div>

<!-- LinkedIn integration -->
<a data-personalize="linkedin" href="">
  Connect with me on LinkedIn
</a>

<!-- Phone CTA -->
<a href="tel:" data-personalize="phone">
  <button>Call Us</button>
</a>

<!-- Company website link -->
<p>Visit <a data-personalize="companyWebsite" href="">your website</a></p>
```

---

### **Behavioral Personalization (Return Visitors):**

```html
<!-- Return visitor messaging -->
<div data-show-if="isFirstVisit=false">
  <h2>Welcome back, <span data-personalize="firstName">there</span>!</h2>
  <p>This is visit #<span data-personalize="totalVisits">X</span></p>
</div>

<!-- High-intent messaging -->
<div data-show-if="intentScore>70">
  <h2>🔥 Ready to get started?</h2>
  <p>Hi <span data-personalize="firstName">there</span> from 
     <span data-personalize="companyName">your company</span>,
     let's schedule your demo!</p>
</div>

<!-- Viewed pricing -->
<div data-show-if="viewedPricing=true">
  <p>We saw you checked out pricing. 
     Let's discuss a plan for <span data-personalize="companyName">your team</span>.</p>
</div>
```

---

## 🔧 Complete List of Personalization Data Attributes

### **Use with `data-personalize="fieldName"`:**

**Personal:**
- `firstName`
- `lastName`
- `personName`
- `email`
- `phone`
- `linkedin`

**Company:**
- `company` or `companyName`
- `domain`
- `companyWebsite`
- `companyDescription`
- `companySize`
- `revenue`
- `industry`
- `companyLinkedin`

**Job:**
- `jobTitle`
- `seniority`
- `department`

**Behavioral (return visitors):**
- `intentScore`
- `engagementLevel`
- `totalVisits`
- `totalPageviews`

---

## 🎨 Example: Full Personalized Page

```html
<!-- Hero Section -->
<div class="hero">
  <h1>
    Welcome<span data-show-if="firstName">, 
    <span data-personalize="firstName">there</span></span>!
  </h1>
  
  <p data-show-if="companyName">
    Solutions built for 
    <strong data-personalize="companyName">your company</strong>
  </p>
</div>

<!-- Industry-specific -->
<section data-show-if="industry">
  <h2>Trusted by leaders in <span data-personalize="industry">your industry</span></h2>
  <p>Companies like <span data-personalize="companyName">yours</span> 
     in the <span data-personalize="industry">industry</span> space 
     use our platform to drive results.</p>
</section>

<!-- Company size-specific -->
<section data-show-if="companySize">
  <h3>Perfect for <span data-personalize="companySize">your company size</span></h3>
  <p>Our <span data-show-if="companySize=1-10">Starter</span>
     <span data-show-if="companySize=100-500">Growth</span>
     <span data-show-if="companySize=500+">Enterprise</span> 
     plan is built for teams your size.</p>
</section>

<!-- Role-based CTA -->
<div class="cta">
  <span data-show-if="seniority=Executive">
    <h3>Executive Demo</h3>
    <p>Hi <span data-personalize="firstName">there</span>, 
       as a <span data-personalize="jobTitle">leader</span>, 
       you'll want to see our executive dashboard.</p>
    <button>Book Executive Demo</button>
  </span>
  
  <span data-show-if="department=Sales">
    <h3>Sales Team Solutions</h3>
    <p>Perfect for <span data-personalize="department">your department</span></p>
    <button>See Sales Features</button>
  </span>
</div>

<!-- Return visitor -->
<div data-show-if="intentScore>50" class="priority-banner">
  <p>🔥 Welcome back, <span data-personalize="firstName">there</span>!</p>
  <p>This is your <span data-personalize="totalVisits">Xth</span> visit.</p>
  <p>Your engagement score: <strong data-personalize="intentScore">0</strong>/100</p>
  <button>Let's get you started</button>
</div>
```

---

## 🚀 Full Personalization Response

When someone visits with `?i=abc123`, they get:

```javascript
{
  personalized: true,
  
  // Personal
  firstName: "John",
  lastName: "Doe", 
  personName: "John Doe",
  email: "john@acme.com",
  phone: "+1234567890",
  linkedin: "linkedin.com/in/johndoe",
  
  // Company
  company: "Acme Corp",
  companyName: "Acme Corp",
  domain: "acme.com",
  companyWebsite: "acme.com",
  companyDescription: "Leading widget manufacturer",
  companySize: "100-500",
  revenue: "$10M-$50M",
  industry: "Manufacturing",
  companyLinkedin: "linkedin.com/company/acme",
  
  // Job
  jobTitle: "VP of Sales",
  seniority: "Executive",
  department: "Sales",
  
  // Campaign
  campaignId: "q1_outbound",
  campaignName: "Q1 Outbound Campaign",
  
  // Behavior (first visit)
  intentScore: 0,
  engagementLevel: "new",
  isFirstVisit: true,
  totalVisits: 0
}
```

**On return visit, adds:**
```javascript
  intentScore: 85,
  engagementLevel: "hot",
  isFirstVisit: false,
  totalVisits: 3,
  totalPageviews: 15,
  viewedPricing: true,
  submittedForm: false
```

---

## 📊 Performance

**First visit (with tracking ID):**
- Lookup in BigQuery: ~50ms
- Returns ALL lead data
- Personalize immediately

**Return visit:**
- Lookup in KV: <10ms  
- Returns lead data + behavior
- Ultra-fast personalization

**Site performance impact:**
- Pixel load: <5ms (async)
- Personalization: 50ms first visit, 10ms return
- **Total user-facing delay: Negligible**

---

## ✅ Summary

**Available NOW for personalization:**
- ✅ firstName, lastName, personName
- ✅ email, phone, linkedin
- ✅ company, companyName, domain
- ✅ companyWebsite, companyDescription
- ✅ companySize, revenue, industry
- ✅ jobTitle, seniority, department
- ✅ companyLinkedin
- ✅ All lead table fields (19 total!)

**Plus behavioral (after they interact):**
- ✅ intentScore, engagementLevel
- ✅ totalVisits, totalPageviews
- ✅ viewedPricing, submittedForm

**Total: 30+ personalization fields!** 🎉

