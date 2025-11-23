/**
 * Outbound Intent Engine - Cloudflare Worker
 * Edge worker for event ingestion, validation, and forwarding to BigQuery
 */

export interface Env {
  IDENTITY_STORE: KVNamespace;
  PERSONALIZATION: KVNamespace;
  BIGQUERY_PROJECT_ID: string;
  BIGQUERY_DATASET: string;
  BIGQUERY_CREDENTIALS: string;
  EVENT_SIGNING_SECRET: string;
  ALLOWED_ORIGINS: string;
  ENVIRONMENT: string;
}

interface TrackingEvent {
  type: string;
  timestamp: number;
  sessionId: string;
  visitorId: string | null;
  url: string;
  referrer: string;
  data?: Record<string, any>;
}

interface EventBatch {
  events: TrackingEvent[];
  meta: {
    sentAt: number;
  };
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return handleCORS(request, env);
    }

    const url = new URL(request.url);

    // Route handling
    if (url.pathname === '/track' && request.method === 'POST') {
      return handleTrackEvents(request, env, ctx);
    }

    if (url.pathname === '/identify' && request.method === 'GET') {
      return handleIdentityLookup(request, env);
    }

    if (url.pathname === '/personalize' && request.method === 'GET') {
      return handlePersonalization(request, env);
    }

    if (url.pathname === '/go' && request.method === 'GET') {
      return handleRedirect(request, env);
    }

    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok', timestamp: Date.now() }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    return new Response('Not Found', { status: 404 });
  }
};

/**
 * Handle incoming tracking events
 */
async function handleTrackEvents(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  try {
    // Validate origin
    if (!isOriginAllowed(request, env)) {
      return new Response('Forbidden', { status: 403 });
    }

    // Parse event batch
    const body = await request.json() as EventBatch;
    
    if (!body.events || !Array.isArray(body.events)) {
      return new Response('Invalid payload', { status: 400 });
    }

    // Enrich events with server-side data
    const enrichedEvents = body.events.map(event => enrichEvent(event, request));

    // Store events asynchronously (don't wait)
    ctx.waitUntil(storeEvents(enrichedEvents, env));

    // Return success immediately
    return new Response(JSON.stringify({ 
      success: true, 
      eventsReceived: body.events.length 
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        ...getCORSHeaders(request, env)
      }
    });
  } catch (error) {
    console.error('Error handling events:', error);
    return new Response('Internal Server Error', { status: 500 });
  }
}

/**
 * Enrich event with server-side data
 */
function enrichEvent(event: TrackingEvent, request: Request): any {
  const ip = request.headers.get('CF-Connecting-IP');
  const country = request.headers.get('CF-IPCountry');
  const userAgent = request.headers.get('User-Agent');

  return {
    ...event,
    serverTimestamp: Date.now(),
    ip,
    country,
    userAgent,
    // Cloudflare specific data
    colo: request.cf?.colo,
    asn: request.cf?.asn,
    city: request.cf?.city,
    region: request.cf?.region,
    timezone: request.cf?.timezone
  };
}

/**
 * Store events in BigQuery
 */
async function storeEvents(events: any[], env: Env): Promise<void> {
  try {
    // Get BigQuery credentials
    const credentials = JSON.parse(env.BIGQUERY_CREDENTIALS);
    const projectId = env.BIGQUERY_PROJECT_ID;
    const dataset = env.BIGQUERY_DATASET;

    // Create JWT token for BigQuery API authentication
    const token = await createBigQueryToken(credentials);

    // Insert rows into BigQuery
    const tableId = 'events';
    const url = `https://bigquery.googleapis.com/bigquery/v2/projects/${projectId}/datasets/${dataset}/tables/${tableId}/insertAll`;

    const rows = events.map((event, index) => ({
      insertId: `${event.sessionId}-${event.timestamp}-${index}`,
      json: event
    }));

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        rows,
        skipInvalidRows: false,
        ignoreUnknownValues: false
      })
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('BigQuery insertion failed:', error);
      throw new Error(`BigQuery error: ${response.status}`);
    }

    const result = await response.json();
    
    if (result.insertErrors) {
      console.error('BigQuery insert errors:', result.insertErrors);
    }

    console.log(`Successfully stored ${events.length} events in BigQuery`);
  } catch (error) {
    console.error('Failed to store events:', error);
    // In production, you might want to queue failed events for retry
  }
}

/**
 * Create JWT token for BigQuery API
 */
async function createBigQueryToken(credentials: any): Promise<string> {
  const header = {
    alg: 'RS256',
    typ: 'JWT',
    kid: credentials.private_key_id
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: credentials.client_email,
    scope: 'https://www.googleapis.com/auth/bigquery.insertdata',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now
  };

  // Base64url encode header and payload
  const encodedHeader = base64urlEncode(JSON.stringify(header));
  const encodedPayload = base64urlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  // Sign with private key
  const privateKey = await importPrivateKey(credentials.private_key);
  const signature = await signToken(unsignedToken, privateKey);
  const encodedSignature = base64urlEncode(signature);

  const jwt = `${unsignedToken}.${encodedSignature}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  // Remove PEM header/footer and decode
  const pemContents = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

  return await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256'
    },
    false,
    ['sign']
  );
}

async function signToken(data: string, key: CryptoKey): Promise<string> {
  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(data)
  );
  return String.fromCharCode(...new Uint8Array(signature));
}

function base64urlEncode(data: string): string {
  const base64 = btoa(data);
  return base64
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

/**
 * Handle identity lookup (resolve short ID to full profile)
 */
async function handleIdentityLookup(request: Request, env: Env): Promise<Response> {
  try {
    const url = new URL(request.url);
    const identityId = url.searchParams.get('i');

    if (!identityId) {
      return new Response('Missing identity parameter', { status: 400 });
    }

    // Lookup in KV store
    const identity = await env.IDENTITY_STORE.get(identityId, 'json');

    if (!identity) {
      return new Response('Identity not found', { status: 404 });
    }

    return new Response(JSON.stringify(identity), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=3600'
      }
    });
  } catch (error) {
    console.error('Identity lookup error:', error);
    return new Response('Internal Server Error', { status: 500 });
  }
}

/**
 * Handle personalization data fetch
 */
async function handlePersonalization(request: Request, env: Env): Promise<Response> {
  try {
    const url = new URL(request.url);
    const visitorId = url.searchParams.get('vid');

    if (!visitorId) {
      return new Response('Missing visitor ID', { status: 400 });
    }

    // Lookup personalization data
    const personalization = await env.PERSONALIZATION.get(visitorId, 'json');

    if (!personalization) {
      return new Response(JSON.stringify({ personalized: false }), {
        headers: { 
          'Content-Type': 'application/json',
          ...getCORSHeaders(request, env)
        }
      });
    }

    return new Response(JSON.stringify({
      personalized: true,
      ...personalization
    }), {
      headers: { 
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=300',
        ...getCORSHeaders(request, env)
      }
    });
  } catch (error) {
    console.error('Personalization error:', error);
    return new Response('Internal Server Error', { status: 500 });
  }
}

/**
 * Handle redirect from short URL
 */
async function handleRedirect(request: Request, env: Env): Promise<Response> {
  try {
    const url = new URL(request.url);
    const identityId = url.searchParams.get('i');
    const destination = url.searchParams.get('to') || '/';

    if (!identityId) {
      return Response.redirect(destination, 302);
    }

    // Track the click
    const clickEvent = {
      type: 'email_click',
      timestamp: Date.now(),
      identityId,
      destination,
      ip: request.headers.get('CF-Connecting-IP'),
      userAgent: request.headers.get('User-Agent'),
      country: request.headers.get('CF-IPCountry')
    };

    // Store click asynchronously
    await storeEvents([clickEvent], env);

    // Redirect with identity parameter
    const destinationUrl = new URL(destination, url.origin);
    destinationUrl.searchParams.set('i', identityId);

    return Response.redirect(destinationUrl.toString(), 302);
  } catch (error) {
    console.error('Redirect error:', error);
    return Response.redirect('/', 302);
  }
}

/**
 * CORS handling
 */
function handleCORS(request: Request, env: Env): Response {
  return new Response(null, {
    status: 204,
    headers: getCORSHeaders(request, env)
  });
}

function getCORSHeaders(request: Request, env: Env): Record<string, string> {
  const origin = request.headers.get('Origin') || '';
  const allowedOrigins = env.ALLOWED_ORIGINS?.split(',') || [];

  if (isOriginAllowed(request, env)) {
    return {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Max-Age': '86400'
    };
  }

  return {};
}

function isOriginAllowed(request: Request, env: Env): boolean {
  const origin = request.headers.get('Origin') || '';
  const allowedOrigins = env.ALLOWED_ORIGINS?.split(',') || [];
  
  // In development, allow all origins
  if (env.ENVIRONMENT === 'development') {
    return true;
  }

  return allowedOrigins.some(allowed => origin === allowed.trim());
}

