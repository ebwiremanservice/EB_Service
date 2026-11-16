/**
 * Auth Routes
 * Endpoints for email verification OTP, login, and profile
 */

const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const { sendOtp, verifyOtp, getProfile, updateProfile, deleteAccount, verifyPurchase } = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');

// Rate limiter for sending OTP (max 5 OTP requests per 10 minutes per IP)
const otpLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 5,
  message: {
    success: false,
    message: 'Too many verification code requests. Please wait 10 minutes before trying again.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Rate limiter for verifying OTP (max 10 verify attempts per 10 minutes)
const verifyLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 10,
  message: {
    success: false,
    message: 'Too many verification attempts. Please wait 10 minutes.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// POST /api/auth/send-otp
router.post('/send-otp', otpLimiter, sendOtp);

// POST /api/auth/verify-otp
router.post('/verify-otp', verifyLimiter, verifyOtp);

// GET /api/auth/me
router.get('/me', authMiddleware, getProfile);

// PUT /api/auth/profile
router.put('/profile', authMiddleware, updateProfile);

// DELETE /api/auth/delete-account
router.delete('/delete-account', authMiddleware, deleteAccount);

// POST /api/auth/verify-purchase
router.post('/verify-purchase', authMiddleware, verifyPurchase);

module.exports = router;

