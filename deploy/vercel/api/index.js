// =============================================================
//  NikVPN XHTTP Relay for Vercel
//  Copyright (C) 2026 nikvpn-iran
//  Repository: https://github.com/nikvpn-iran/NikVPN-XHTTP-Installer
//  Licensed under the GNU General Public License v3.0 (GPL-3.0).
//  See LICENSE file for full terms.
//  Based on the original work by avacocloud (XHTTP-Installer).
// =============================================================
//  NikVPN build ID: nkv-2026-010-nikvpn

export const config = {
  runtime: "edge",
  regions: ["all"],
};

const __NIKVPN_BUILD_ID__ = "nkv-2026-010-nikvpn";   // NikVPN build identifier
void __NIKVPN_BUILD_ID__;                            // prevent tree-shaking

const TARGET_DOMAIN = process.env.TARGET_DOMAIN;
const RELAY_PATH = process.env.RELAY_PATH || "/api";
const PUBLIC_RELAY_PATH = process.env.PUBLIC_RELAY_PATH || "/api";
const MAX_INFLIGHT = parseInt(process.env.MAX_INFLIGHT || "128", 10);
const MAX_UP_BPS = parseInt(process.env.MAX_UP_BPS || "2621440", 10);
const MAX_DOWN_BPS = parseInt(process.env.MAX_DOWN_BPS || "2621440", 10);
const UPSTREAM_TIMEOUT_MS = parseInt(process.env.UPSTREAM_TIMEOUT_MS || "50000", 10);
const SUCCESS_LOG_SAMPLE_RATE = parseFloat(process.env.SUCCESS_LOG_SAMPLE_RATE || "0");
const SUCCESS_LOG_MIN_DURATION_MS = parseInt(process.env.SUCCESS_LOG_MIN_DURATION_MS || "3000", 10);
const ERROR_LOG_MIN_INTERVAL_MS = parseInt(process.env.ERROR_LOG_MIN_INTERVAL_MS || "5000", 10);

// Simple rate limiter: max concurrent requests
let inflight = 0;
let lastErrorLogTime = 0;
let errorCount = 0;

const STRIP_HEADERS = new Set([
  "host",
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
  "x-forwarded-host",
  "x-forwarded-proto",
  "x-forwarded-port",
  "x-vercel-id",
  "x-vercel-ip",
  "x-vercel-ip-country",
  "x-vercel-ip-region",
]);

export default async function handler(request) {
  if (!TARGET_DOMAIN) {
    return new Response("Misconfigured: TARGET_DOMAIN env var not set", { status: 500 });
  }

  // Basic rate limiting
  if (inflight >= MAX_INFLIGHT) {
    return new Response("Too Many Requests", { status: 429 });
  }

  inflight++;
  const startTime = Date.now();

  try {
    const url = new URL(request.url);
    // Check if the request matches the public path
    if (url.pathname !== PUBLIC_RELAY_PATH && !url.pathname.startsWith(PUBLIC_RELAY_PATH)) {
      return new Response("Not Found", { status: 404 });
    }

    // Map public path to internal relay path if different
    let upstreamPath = url.pathname;
    if (PUBLIC_RELAY_PATH !== RELAY_PATH) {
      upstreamPath = RELAY_PATH + url.pathname.slice(PUBLIC_RELAY_PATH.length);
    }

    const targetUrl = TARGET_DOMAIN.replace(/\/$/, "") + upstreamPath + url.search;

    const headers = new Headers();
    let clientIp = request.headers.get("x-real-ip") || request.headers.get("x-forwarded-for");

    for (const [key, value] of request.headers) {
      const k = key.toLowerCase();
      if (STRIP_HEADERS.has(k)) continue;
      if (k.startsWith("x-vercel-")) continue;
      if (k === "x-forwarded-for" && clientIp) {
        // Already captured
        continue;
      }
      headers.set(k, value);
    }

    if (clientIp) {
      headers.set("x-forwarded-for", clientIp);
    }

    const method = request.method;
    const hasBody = method !== "GET" && method !== "HEAD";

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

    const fetchOptions = {
      method,
      headers,
      redirect: "manual",
      signal: controller.signal,
    };

    if (hasBody) {
      fetchOptions.body = request.body;
    }

    const upstream = await fetch(targetUrl, fetchOptions);
    clearTimeout(timeoutId);

    const duration = Date.now() - startTime;

    // Success logging (sampled)
    if (
      SUCCESS_LOG_SAMPLE_RATE > 0 &&
      Math.random() < SUCCESS_LOG_SAMPLE_RATE &&
      duration >= SUCCESS_LOG_MIN_DURATION_MS
    ) {
      console.log(`[NikVPN] ${method} ${url.pathname} → ${upstream.status} (${duration}ms)`);
    }

    const responseHeaders = new Headers();
    for (const [key, value] of upstream.headers) {
      if (key.toLowerCase() === "transfer-encoding") continue;
      responseHeaders.set(key, value);
    }

    return new Response(upstream.body, {
      status: upstream.status,
      headers: responseHeaders,
    });
  } catch (error) {
    const now = Date.now();
    errorCount++;
    if (now - lastErrorLogTime > ERROR_LOG_MIN_INTERVAL_MS || errorCount <= 1) {
      console.error("[NikVPN] Relay error:", error.message);
      lastErrorLogTime = now;
    }
    return new Response("Bad Gateway: Relay Failed", { status: 502 });
  } finally {
    inflight--;
  }
}
