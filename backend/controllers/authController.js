/**
 * Authentication Controller
 * Handles Email + OTP registration, login, verification, and profile
 */

const jwt = require('jsonwebtoken');
const User = require('../models/User');
const EbRecord = require('../models/EbRecord');
const emailService = require('../services/emailService');

const JWT_SECRET = process.env.JWT_SECRET || 'eb_wireman_secret_key_2026';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/send-otp
// Sends 6-digit OTP to user's email for registration or login
// ─────────────────────────────────────────────────────────────────────────────
exports.sendOtp = async (req, res) => {
  try {
    const { email, name } = req.body;

    if (!email || !email.trim()) {
      return res.status(400).json({ success: false, message: 'Email address is required.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(cleanEmail)) {
      return res.status(400).json({ success: false, message: 'Please enter a valid email address.' });
    }

    // Generate random 6-digit numeric OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes from now

    let user = await User.findOne({ email: cleanEmail });

    if (!user) {
      user = new User({
        email: cleanEmail,
        name: name ? name.trim() : 'Wireman',
        otp: {
          code: otpCode,
          expiresAt,
          attempts: 0,
        },
      });
    } else {
      if (name && name.trim()) {
        user.name = name.trim();
      }
      user.otp = {
        code: otpCode,
        expiresAt,
        attempts: 0,
      };
    }

    await user.save();

    // Send email via emailService (HTTP API or SMTP, with graceful fallback)
    const emailResult = await emailService.sendOtpEmail(cleanEmail, otpCode, user.name);

    return res.status(200).json({
      success: true,
      message: emailResult.delivered
        ? `Verification code sent to ${cleanEmail}. Please check your inbox or spam folder.`
        : `Verification code: ${otpCode} (Notice: Cloud free tier blocked outbound SMTP; code logged in console)`,
      otp: emailResult.delivered ? undefined : otpCode,
    });
  } catch (error) {
    console.error('[sendOtp]', error);
    return res.status(500).json({
      success: false,
      message: error.message || 'Server error while sending verification code.',
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/verify-otp
// Verifies OTP and returns JWT token
// ─────────────────────────────────────────────────────────────────────────────
exports.verifyOtp = async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({ success: false, message: 'Email and OTP code are required.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanOtp = otp.trim();

    const user = await User.findOne({ email: cleanEmail });
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found. Please request a new code.' });
    }

    if (!user.otp || !user.otp.code) {
      return res.status(400).json({ success: false, message: 'No active OTP found. Please request a new code.' });
    }

    // Check expiry
    if (new Date() > new Date(user.otp.expiresAt)) {
      return res.status(400).json({ success: false, message: 'OTP has expired. Please request a new code.' });
    }

    // Check attempts limit (max 5)
    if (user.otp.attempts >= 5) {
      return res.status(429).json({ success: false, message: 'Too many incorrect attempts. Please request a new code.' });
    }

    // Validate code
    if (user.otp.code !== cleanOtp) {
      user.otp.attempts += 1;
      await user.save();
      return res.status(400).json({
        success: false,
        message: `Incorrect OTP. ${5 - user.otp.attempts} attempt(s) remaining.`,
      });
    }

    // OTP is valid! Mark verified and clear OTP
    user.isVerified = true;
    user.otp = { code: null, expiresAt: null, attempts: 0 };

    // Calculate accurate count of houses owned by this user
    user.registeredHousesCount = await EbRecord.countDocuments({ userId: user._id });
    await user.save();

    // Sign JWT token valid for 90 days
    const token = jwt.sign(
      { id: user._id, email: user.email, name: user.name },
      JWT_SECRET,
      { expiresIn: '90d' }
    );

    return res.status(200).json({
      success: true,
      message: 'Login successful!',
      token,
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        registeredHousesCount: user.registeredHousesCount,
        canAddHouse: user.canAddHouse(),
        subscription: user.subscription,
      },
    });
  } catch (error) {
    console.error('[verifyOtp]', error);
    return res.status(500).json({ success: false, message: 'Server error while verifying OTP.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/auth/me
// Returns current authenticated user profile and subscription status
// ─────────────────────────────────────────────────────────────────────────────
exports.getProfile = async (req, res) => {
  try {
    const user = req.user;
    const actualCount = await EbRecord.countDocuments({ userId: user._id });

    if (user.registeredHousesCount !== actualCount) {
      user.registeredHousesCount = actualCount;
      await user.save();
    }

    return res.status(200).json({
      success: true,
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        registeredHousesCount: user.registeredHousesCount,
        canAddHouse: user.canAddHouse(),
        subscription: user.subscription,
      },
    });
  } catch (error) {
    console.error('[getProfile]', error);
    return res.status(500).json({ success: false, message: 'Server error while fetching profile.' });
  }
};

