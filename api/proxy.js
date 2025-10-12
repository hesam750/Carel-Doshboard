// Simple HTTP proxy for PLC endpoints used by dashboard.html via "/proxy?url=<...>"
// Restrictable via env: ALLOWED_PROXY_HOSTS (comma-separated host:port list), e.g. "1.2.3.4:8080,plc.example.com"
// Note: This forwards only HTTP/HTTPS. If the PLC requires non-HTTP protocols (e.g., Modbus/TCP), a different backend is needed.

const { URL } = require('url');

function getAllowedHosts() {
  const raw = process.env.ALLOWED_PROXY_HOSTS || '';
  return raw
    .split(',')
    .map(s => s.trim().toLowerCase())
    .filter(Boolean);
}

function isAllowedHost(host) {
  const allowed = getAllowedHosts();
  // If not configured, allow all (useful for quick tests). Configure in Vercel for production.
  if (allowed.length === 0) return true;
  const h = String(host || '').toLowerCase();
  return allowed.some(a => a === h);
}

module.exports = async (req, res) => {
  // Basic CORS for browser access
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    return res.end();
  }

  // Extract target URL from query string
  const qs = (req.url.split('?')[1] || '');
  const params = new URLSearchParams(qs);
  const targetStr = params.get('url');
  if (!targetStr) {
    res.statusCode = 400;
    return res.end('Missing query parameter: url');
  }

  let target;
  try {
    target = new URL(targetStr);
  } catch (e) {
    res.statusCode = 400;
    return res.end('Invalid URL');
  }

  if (!/^https?:$/.test(target.protocol)) {
    res.statusCode = 400;
    return res.end('Only http/https is supported');
  }

  if (!isAllowedHost(target.host)) {
    res.statusCode = 403;
    return res.end('Target host not allowed');
  }

  // Read POST body if needed
  let body = undefined;
  if (req.method === 'POST') {
    body = await new Promise((resolve, reject) => {
      let acc = '';
      req.on('data', chunk => { acc += chunk; });
      req.on('end', () => resolve(acc));
      req.on('error', reject);
    });
  }

  try {
    // Vercel Node runtimes provide global fetch
    const upstream = await fetch(target.href, {
      method: req.method,
      headers: {
        'Content-Type': req.headers['content-type'] || (req.method === 'POST' ? 'application/x-www-form-urlencoded' : undefined)
      },
      body: req.method === 'POST' ? body : undefined,
    });

    // Pass-through status and content-type
    const ct = upstream.headers.get('content-type') || 'text/plain; charset=utf-8';
    res.statusCode = upstream.status;
    res.setHeader('Content-Type', ct);
    const buf = Buffer.from(await upstream.arrayBuffer());
    return res.end(buf);
  } catch (e) {
    res.statusCode = 502;
    return res.end('Upstream error: ' + (e && e.message ? e.message : String(e)));
  }
};