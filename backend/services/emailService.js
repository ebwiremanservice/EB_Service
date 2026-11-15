/**
 * Email Service
 * Supports:
 *  1. Resend REST API (HTTPS port 443 - zero cloud port blocking on Render free tier)
 *  2. Brevo REST API (HTTPS port 443 - zero cloud port blocking on Render free tier)
 *  3. Gmail SMTP via Nodemailer
 *  4. Graceful Fallback Mode: Never crashes if cloud blocks SMTP ports.
 */

const https = require('https');
const nodemailer = require('nodemailer');

function getEmailTemplate(otpCode, userName) {
  return `
    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; border: 1px solid #e2e8f0; box-shadow: 0 4px 12px rgba(0,0,0,0.05);">
      <div style="background: linear-gradient(135deg, #0F3A78 0%, #1565C0 100%); padding: 28px 24px; text-align: center;">
        <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 700; letter-spacing: 0.5px;">⚡ Wireman Service</h1>
        <p style="color: #93c5fd; margin: 6px 0 0; font-size: 13px;">Wireman Assistant</p>
      </div>
      <div style="padding: 28px 24px;">
        <h2 style="color: #1e293b; font-size: 18px; margin: 0 0 12px; font-weight: 600;">Hello ${userName || 'Wireman'},</h2>
        <p style="color: #475569; font-size: 14px; line-height: 1.6; margin: 0 0 20px;">
          Use the verification code below to securely register or log in to your <strong>Wireman Service</strong> account.
        </p>
        <div style="background-color: #f8fafc; border: 2px dashed #cbd5e1; border-radius: 12px; padding: 18px; text-align: center; margin: 0 0 22px;">
          <span style="font-family: monospace; font-size: 32px; font-weight: 700; color: #0f3a78; letter-spacing: 8px;">${otpCode}</span>
        </div>
        <p style="color: #64748b; font-size: 12.5px; margin: 0 0 16px; line-height: 1.5;">
          ⏱️ This OTP code is valid for <strong>10 minutes</strong>. Do not share this code with anyone.
        </p>
        <div style="border-top: 1px solid #f1f5f9; padding-top: 16px; margin-top: 24px; text-align: center;">
          <p style="color: #94a3b8; font-size: 11px; margin: 0;">If you did not request this email, please ignore it.</p>
        </div>
      </div>
    </div>
  `;
}

// ── 0. Google Apps Script Gmail Relay (HTTPS port 443 - zero cloud blocking, NO domain needed) ──
async function sendViaGmailRelay(relayUrl, toEmail, otpCode, userName) {
  const payload = {
    to: toEmail,
    subject: `${otpCode} is your Wireman Service Verification Code`,
    html: getEmailTemplate(otpCode, userName),
  };

  const response = await fetch(relayUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
    redirect: 'follow',
  });

  const text = await response.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch (_) {
    data = { success: response.ok };
  }

  if (data && data.success === false) {
    throw new Error(data.error || 'Google Relay reported failure');
  }
  return data;
}

// ── 1. Resend REST API (HTTPS port 443) ──────────────────────────────────────
function sendViaResend(apiKey, toEmail, otpCode, userName) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      from: 'Wireman Service <onboarding@resend.dev>',
      to: [toEmail],
      subject: `${otpCode} is your Wireman Service Verification Code`,
      html: getEmailTemplate(otpCode, userName),
    });

    const req = https.request('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
      timeout: 8000,
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`Resend API error (${res.statusCode}): ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Resend API request timed out'));
    });
    req.write(payload);
    req.end();
  });
}

// ── 2. Brevo REST API (HTTPS port 443) ───────────────────────────────────────
function sendViaBrevo(apiKey, toEmail, otpCode, userName) {
  return new Promise((resolve, reject) => {
    const senderEmail = process.env.GMAIL_USER || 'no-reply@wiremanservice.com';
    const payload = JSON.stringify({
      sender: { name: 'Wireman Service', email: senderEmail },
      to: [{ email: toEmail, name: userName || 'Wireman' }],
      subject: `${otpCode} is your Wireman Service Verification Code`,
      htmlContent: getEmailTemplate(otpCode, userName),
    });

    const req = https.request('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'api-key': apiKey,
        'Content-Type': 'application/json',
        'accept': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
      timeout: 8000,
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`Brevo API error (${res.statusCode}): ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Brevo API request timed out'));
    });
    req.write(payload);
    req.end();
  });
}

// ── 3. Gmail SMTP via Nodemailer ─────────────────────────────────────────────
function sendViaSmtp(toEmail, otpCode, userName) {
  const user = process.env.GMAIL_USER;
  const pass = process.env.GMAIL_PASS;

  if (!user || !pass) return null;

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user, pass },
    connectionTimeout: 5000,
    greetingTimeout: 5000,
    socketTimeout: 7000,
  });

  const mailOptions = {
    from: `"Wireman Service" <${user}>`,
    to: toEmail,
    subject: `${otpCode} is your Wireman Service Verification Code`,
    html: getEmailTemplate(otpCode, userName),
  };

  return transporter.sendMail(mailOptions);
}

// ── Main Dispatcher ──────────────────────────────────────────────────────────
exports.sendOtpEmail = async (toEmail, otpCode, userName = 'Wireman') => {
  // Strategy 0: Google Apps Script Gmail Relay (100% Free, NO Domain Needed, Delivers to ANY recipient)
  if (process.env.GMAIL_RELAY_URL) {
    try {
      await sendViaGmailRelay(process.env.GMAIL_RELAY_URL, toEmail, otpCode, userName);
      console.log(`[emailService] OTP sent via Google Gmail Relay to ${toEmail}`);
      return { success: true, delivered: true, provider: 'gmail-relay' };
    } catch (err) {
      console.error('[emailService] Google Gmail Relay failed:', err.message);
    }
  }

  // Strategy 1: Resend HTTP REST API
  if (process.env.RESEND_API_KEY) {
    try {
      const res = await sendViaResend(process.env.RESEND_API_KEY, toEmail, otpCode, userName);
      console.log(`[emailService] OTP sent via Resend to ${toEmail}:`, res.id || res);
      return { success: true, delivered: true, provider: 'resend' };
    } catch (err) {
      console.error('[emailService] Resend delivery failed:', err.message);
    }
  }

  // Strategy 2: Brevo HTTP REST API
  if (process.env.BREVO_API_KEY) {
    try {
      const res = await sendViaBrevo(process.env.BREVO_API_KEY, toEmail, otpCode, userName);
      console.log(`[emailService] OTP sent via Brevo to ${toEmail}:`, res.messageId || res);
      return { success: true, delivered: true, provider: 'brevo' };
    } catch (err) {
      console.error('[emailService] Brevo delivery failed:', err.message);
    }
  }

  // Strategy 3: Nodemailer SMTP
  if (process.env.GMAIL_USER && process.env.GMAIL_PASS) {
    try {
      const info = await sendViaSmtp(toEmail, otpCode, userName);
      console.log(`[emailService] OTP email sent via SMTP to ${toEmail}: ${info.messageId}`);
      return { success: true, delivered: true, provider: 'smtp', messageId: info.messageId };
    } catch (err) {
      console.warn('[emailService] SMTP delivery failed (port likely blocked on cloud free tier):', err.message);
    }
  }

  // Strategy 4: Fallback Dev / Cloud Mode (Logs OTP so login never blocks)
  console.log(`\n========================================`);
  console.log(`🔑 [WIREMAN SERVICE OTP] For ${toEmail}: ${otpCode}`);
  console.log(`========================================\n`);

  return {
    success: true,
    delivered: false,
    provider: 'fallback',
    fallbackOtp: otpCode,
  };
};
