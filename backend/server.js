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

// ─── App Setup ───────────────────────────────────────────────────────────────
const app  = express();
const PORT = process.env.PORT || 5000;

// ─── Free-Tier Rate Limiting & Protection ────────────────────────────────────
// Prevents API exhaustion and protects MongoDB Atlas Free Tier from overuse
const globalApiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes window
  max: 300,                  // 300 requests per 15 min per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many requests from this device. Please wait a moment and try again.',
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

// ─── Health Check ────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
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

