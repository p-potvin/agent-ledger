const fs = require("node:fs");
const path = require("node:path");

function unauthorized(res) {
  res.statusCode = 401;
  res.setHeader("WWW-Authenticate", 'Basic realm="Work Impact"');
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Robots-Tag", "noindex, nofollow");
  res.end("Authentication required.");
}

function forbidden(res) {
  res.statusCode = 403;
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Robots-Tag", "noindex, nofollow");
  res.end("Forbidden.");
}

function misconfigured(res) {
  res.statusCode = 503;
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Robots-Tag", "noindex, nofollow");
  res.end(
    "WORK_IMPACT_USER / WORK_IMPACT_PASS are not configured on this deployment."
  );
}

function safeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

function parseBasicAuth(header) {
  if (!header) return null;
  const m = header.match(/^Basic\s+(.+)$/i);
  if (!m) return null;
  try {
    const decoded = Buffer.from(m[1], "base64").toString("utf8");
    const idx = decoded.indexOf(":");
    if (idx < 0) return null;
    return {
      user: decoded.slice(0, idx),
      pass: decoded.slice(idx + 1),
    };
  } catch {
    return null;
  }
}

module.exports = async (req, res) => {
  const expectedUser = process.env.WORK_IMPACT_USER || "";
  const expectedPass = process.env.WORK_IMPACT_PASS || "";

  if (!expectedUser || !expectedPass) {
    return misconfigured(res);
  }

  const creds = parseBasicAuth(req.headers.authorization);
  if (!creds) return unauthorized(res);
  if (!safeEqual(creds.user, expectedUser) || !safeEqual(creds.pass, expectedPass)) {
    return forbidden(res);
  }

  const htmlPath = path.join(process.cwd(), "WORK_IMPACT.html");
  let html;
  try {
    html = fs.readFileSync(htmlPath, "utf8");
  } catch {
    res.statusCode = 500;
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("X-Robots-Tag", "noindex, nofollow");
    res.end("WORK_IMPACT.html not found in the deployment bundle.");
    return;
  }

  res.statusCode = 200;
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Robots-Tag", "noindex, nofollow");
  res.end(html);
};

