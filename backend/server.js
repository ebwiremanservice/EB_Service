/**
 * EB Wireman Assistant — Express Server Entry Point
 */

require('dotenv').config();

const express     = require('express');
const helmet      = require('helmet');
const cors        = require('cors');
const compression = require('compression');
const rateLimit   = require('express-rate-limit');

const connectDB    = require('./config/db');
const seedMathavan = require('./config/seedMathavan');
const authRoutes   = require('./routes/authRoutes');
const ebRoutes     = require('./routes/ebRoutes');
const errorHandler = require('./middleware/errorHandler');

// ─── Production Security Validation ──────────────────────────────────────────
if (process.env.NODE_ENV === 'production') {
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET === 'eb_wireman_secret_key_2026') {
    console.warn('\n⚠️ [SECURITY WARNING] Default JWT_SECRET detected in production! Please set a strong random JWT_SECRET in your Render dashboard.\n');
  }
}

// ─── App Setup ───────────────────────────────────────────────────────────────
const app  = express();
const PORT = process.env.PORT || 5000;

// ─── Free-Tier Rate Limiting & Protection ────────────────────────────────────
// Prevents API exhaustion while allowing 100+ concurrent users/substations
const globalApiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes window
  max: 1200,                 // 1200 requests per 15 min (supports busy teams)
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many requests from this network. Please wait a moment and try again.',
  },
});

// ─── Security, Compression & Parsing Middleware ──────────────────────────────
app.use(helmet());          // Secure HTTP headers
app.use(compression());     // Gzip/deflate compression (saves ~75% bandwidth)
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*', // Lock down in production
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
}));
app.use(express.json({ limit: '10kb' }));       // Parse JSON bodies (max 10 KB)
app.use(express.urlencoded({ extended: false }));

// ─── Health & Privacy Endpoints ──────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Official Privacy Policy URL for Google Play Console submission
app.get('/privacy', (req, res) => {
  res.setHeader('Content-Type', 'text/html');
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Privacy Policy - Wireman Service</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #1e293b; max-width: 800px; margin: 0 auto; padding: 32px 20px; background-color: #f8fafc; }
        .card { background: white; padding: 36px; border-radius: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); border: 1px solid #e2e8f0; }
        h1 { color: #0f3a78; font-size: 26px; margin-top: 0; }
        h2 { color: #1e3a8a; font-size: 18px; margin-top: 24px; border-bottom: 2px solid #e2e8f0; padding-bottom: 6px; }
        p, li { font-size: 14px; color: #475569; }
        ul { padding-left: 20px; }
        .contact { background: #eff6ff; padding: 16px; border-radius: 10px; margin-top: 24px; border: 1px solid #bfdbfe; font-size: 13.5px; }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>Privacy Policy for Wireman Service</h1>
        <p><strong>Last Updated:</strong> November 2026</p>
        <p>Wireman Service ("we", "our", or "the app") is committed to protecting your privacy. This Privacy Policy explains our data collection and protection practices in compliance with Google Play Developer Policies.</p>
        
        <h2>1. Information We Collect</h2>
        <ul>
          <li><strong>Account Details:</strong> Your email address and display name, used strictly for user authentication, multi-device synchronization, and subscription management.</li>
          <li><strong>Location Information:</strong> Precise GPS coordinates (latitude and longitude) captured exclusively when you record or navigate to electricity consumer service meters in the field.</li>
          <li><strong>Service Records:</strong> Consumer numbers, optional contact numbers, and landmark notes entered by wiremen to perform field inspection and maintenance visits.</li>
        </ul>

        <h2>2. How We Use Information</h2>
        <ul>
          <li>To save, organize, and navigate to electricity consumer meters via mapping applications.</li>
          <li>To synchronize your meter records securely across all authorized devices in your team.</li>
          <li>We do <strong>NOT</strong> sell, rent, or trade your personal or consumer data to any third parties or advertisers.</li>
        </ul>

        <h2>3. Data Retention & Permanent Account Deletion</h2>
        <p>In accordance with Google Play's User Data Policy, you retain complete ownership of your data:</p>
        <ul>
          <li>You may permanently delete your account and all associated consumer records at any time directly within the mobile application under <em>Profile &gt; Delete Account Permanently</em>.</li>
          <li>Alternatively, you may request account deletion by emailing us at <a href="mailto:ebwiremanservice@gmail.com">ebwiremanservice@gmail.com</a>.</li>
        </ul>

        <h2>4. Security</h2>
        <p>All data transmitted between the mobile application and our servers is encrypted using industry-standard HTTPS (TLS 1.3). Database access is restricted with multi-tenant user isolation.</p>

        <div class="contact">
          <strong>Contact Us:</strong><br>
          If you have any questions or data requests, contact us at: 
          <a href="mailto:ebwiremanservice@gmail.com">ebwiremanservice@gmail.com</a>
        </div>
      </div>
    </body>
    </html>
  `);
});

// ─── API Routes ──────────────────────────────────────────────────────────────
app.use('/api', globalApiLimiter);
app.use('/api/auth', authRoutes);
app.use('/api/eb-records', ebRoutes);

// ─── 404 Handler ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found.` });
});

// ─── Global Error Handler ────────────────────────────────────────────────────
app.use(errorHandler);

// ─── Start Server ────────────────────────────────────────────────────────────
const startServer = async () => {
  await connectDB();
  await seedMathavan();
  app.listen(PORT, () => {
    console.log(`🚀  Server running on http://localhost:${PORT}`);
  });
};

startServer();

