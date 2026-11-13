/**
 * Email Service using Nodemailer
 * Sends OTP verification emails using Gmail SMTP (App Password)
 */

const nodemailer = require('nodemailer');

function createTransporter() {
  const user = process.env.GMAIL_USER;
  const pass = process.env.GMAIL_PASS;

  if (!user || !pass) {
    console.warn('[emailService] GMAIL_USER or GMAIL_PASS not configured in .env. OTP will be printed to console for testing.');
    return null;
  }

  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user,
      pass,
    },
  });
}

/**
 * Send 6-Digit OTP Verification Email
 * @param {string} toEmail 
 * @param {string} otpCode 
 * @param {string} userName 
 */
exports.sendOtpEmail = async (toEmail, otpCode, userName = 'Wireman') => {
  const transporter = createTransporter();

  // If no email configured, log to console so development/testing never blocks
  if (!transporter) {
    console.log(`\n========================================`);
    console.log(`🔑 [DEV OTP] For ${toEmail}: ${otpCode}`);
    console.log(`========================================\n`);
    return { success: true, devMode: true };
  }

  const mailOptions = {
    from: `"EB Houses Assistant" <${process.env.GMAIL_USER}>`,
    to: toEmail,
    subject: `${otpCode} is your EB Houses Verification Code`,
    html: `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; border: 1px solid #e2e8f0; box-shadow: 0 4px 12px rgba(0,0,0,0.05);">
        <div style="background: linear-gradient(135deg, #0F3A78 0%, #1565C0 100%); padding: 28px 24px; text-align: center;">
          <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 700; letter-spacing: 0.5px;">⚡ EB Houses</h1>
          <p style="color: #93c5fd; margin: 6px 0 0; font-size: 13px;">Wireman Service Assistant</p>
        </div>
        <div style="padding: 28px 24px;">
          <h2 style="color: #1e293b; font-size: 18px; margin: 0 0 12px; font-weight: 600;">Hello ${userName},</h2>
          <p style="color: #475569; font-size: 14px; line-height: 1.6; margin: 0 0 20px;">
            Use the verification code below to securely register or log in to your <strong>EB Houses</strong> account.
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
    `,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log(`[emailService] OTP email sent to ${toEmail}: ${info.messageId}`);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('[emailService] Error sending email:', error);
    // Print fallback OTP in case of SMTP configuration failure
    console.log(`\n========================================`);
    console.log(`🔑 [FALLBACK DEV OTP] For ${toEmail}: ${otpCode}`);
    console.log(`========================================\n`);
    throw new Error('Failed to send verification email. Please check your email address or Gmail configuration.');
  }
};

