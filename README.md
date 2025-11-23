⭐ REVISED PRODUCT SPEC — Outbound Intent Engine
Version: v1.0
🔥 1. Overview

The Outbound Intent Engine identifies visitors arriving from cold outreach using a single short URL parameter (e.g., ?i=ab3f9).

Once identified, a lightweight JavaScript pixel captures all on-site behavior—pageviews, engagement, scroll depth, and form activity—and streams it to an edge backend (Cloudflare Worker), which forwards events into BigQuery.

This creates a behavioral profile of each outbound lead and enables intent scoring, campaign-level attribution, and future AI-powered analysis.

🎯 2. Primary Goals

Instantly identify visitors from outbound email with zero friction.

Track the full buyer journey across sessions and devices.

Store all behavior in BigQuery for scoring, modeling, and historical analysis.

Never degrade site performance, Core Web Vitals, or SEO.

Enable future customer-facing personalization using identity data.

Optional: Provide a foundation for AI-based predictive scoring and buyer journey forecasting.

🧩 3. Key Use Cases
USE CASE A — Cold Email Click → Real-Time Identification

Recipient clicks:

https://yourdomain.com/go?i=7f29d


System:

Resolves i=7f29d to a known lead.

Initializes a new browser session.

Begins tracking user activity immediately.

Stores all events in BigQuery.

Outcome: Full outbound attribution, identity resolution, and session tracking.

USE CASE B — High-Intent Behavior Detection

Visitor exhibits high-intent patterns:

Pricing page visits

Deep scroll depth

Case studies viewed

Product/feature exploration

Return visits

Video engagement

Form interactions

System captures:

IP → company inference

Browser/device

Location

HEMs (sha256, sha1, MD5) if captured via forms

Engagement level

Outcome: Behavioral fingerprints stored in BigQuery to support scoring, reporting, and AI models.

USE CASE C — Multi-Session Tracking

Visitor returns via:

Direct/organic

Bookmarks

Shared link

Forwarded email

Pixel re-identifies via cookie/localStorage.

Outcome: Cross-session continuity with accurate identity stitching.

👥 4. Personas
Primary: SDR/BDR

Identify who clicked from outbound

Know which leads are “warming up”

Follow up at the moment of intent

Prioritize leads automatically

Secondary: RevOps / Marketing Ops

Configure scoring

Validate attribution

Sync high-intent leads to CRM

Build dashboards

Tertiary: Sales Leaders

Understand intent trends

Optimize outbound strategy

Review campaign effectiveness

Improve pipeline forecasting

🏗 5. Functional Requirements
FR1 — Identity Tracking

Identify user via a single URL param (i).

Persist identity via:

localStorage

first-party cookie

Persistence should survive at least 90 days.

FR2 — Event Tracking

Pixel tracks:

Required Events

Pageview (URL, timestamp, referrer)

Scroll depth

Active time on page

Click interactions (CTA, nav, buttons)

Form start

Form submission

Video engagement

Focus loss / regain

Return visits

Optional Events

Text highlight

Rage clicks

Copy events

Cursor jitter

Reading velocity

FR3 — Session Management

A session:

Begins at first interaction.

Ends after 30 minutes inactivity.

Includes:

Entry / exit pages

Duration

Device & browser metadata

All events captured

FR4 — Data Storage

All events stored in:

events (raw events)

sessions (session aggregates)

lead_profiles (identity, scoring, campaign metadata)

FR5 — Personalization Read Model (New Requirement)

Identity + enrichment data synced from BigQuery into Cloudflare KV.

Pixel can fetch personalization profile in <10ms via a Worker.

Supports personalized on-page content (name, company, industry, etc.) for customers.

💨 6. Non-Functional Requirements
NFR1 — Performance

Pixel <12 KB

Zero blocking JavaScript

Events sent via navigator.sendBeacon or async fetch

Page load impact <5ms

NFR2 — Reliability

99.99% uptime via Cloudflare edge

<1s BigQuery insertion delay

Retry logic for failed event submissions

NFR3 — Scalability

1,000,000+ events/day

10,000,000+ outbound leads

10,000+ simultaneous visitor sessions

NFR4 — Security

Only allow POSTs from your domain

Validate identity tokens

Event signing using a server-side secret

No personally identifiable info exposed client-side

🗺 7. End-to-End Visitor Journey

Outbound email sent with link:

https://yourdomain.com/go?i=94dj2


Visitor clicks link
Pixel extracts i and persists identity.

Pixel activates
Captures behavioral events locally.

Events stream to Cloudflare Worker
Worker batches + sends to BigQuery.

BigQuery stores + stitches events
Session + identity + campaign metadata combined.

KV updated based on nightly sync

Pixel personalizes website instantly for logged-in customers

CRM sync + alerts as scoring increases.

📦 8. Dependencies
Required

Cloudflare Workers (event pipeline)

BigQuery (warehouse + scoring)

Required for personalization

Cloudflare KV (identity + personalization cache)

Optional

n8n (Smartlead webhooks → BigQuery + KV sync)

Cloudflare D1 (alternative to KV for personalization)