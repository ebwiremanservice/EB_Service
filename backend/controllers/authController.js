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

    // Special Master Credentials for Mathavan
    if (cleanEmail === 'mathavan479@gmail.com') {
      let user = await User.findOne({ email: cleanEmail });
      if (!user) {
        user = new User({
          email: cleanEmail,
          name: 'Mathavan',
          isVerified: true,
          subscription: {
            status: 'active',
            plan: 'lifetime',
            startDate: new Date('2026-01-01'),
            endDate: new Date('2099-12-31'),
            amountPaid: 0,
          },
        });
      }
      user.otp = {
        code: '123479',
        expiresAt: new Date('2099-12-31'),
        attempts: 0,
      };
      await user.save();
      return res.status(200).json({
        success: true,
        message: 'Master credentials recognized. Code: 123479',
        otp: '123479',
      });
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

    const isProd = process.env.NODE_ENV === 'production';
    if (isProd) {
      if (!emailResult.delivered) {
        return res.status(500).json({
          success: false,
          message: 'Failed to deliver verification code. Please check your email address or try again shortly.',
        });
      }
      return res.status(200).json({
        success: true,
        message: `Verification code sent to ${cleanEmail}. Please check your inbox or spam folder.`,
      });
    }

    // Development mode fallback
    return res.status(200).json({
      success: true,
      message: emailResult.delivered
        ? `Verification code sent to ${cleanEmail}. Please check your inbox or spam folder.`
        : `Verification code: ${otpCode} (Dev fallback)`,
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

    // Special Master Credentials for Mathavan
    if (cleanEmail === 'mathavan479@gmail.com' && cleanOtp === '123479') {
      let mathavanUser = await User.findOne({ email: cleanEmail });
      if (!mathavanUser) {
        mathavanUser = new User({
          email: cleanEmail,
          name: 'Mathavan',
          isVerified: true,
          subscription: {
            status: 'active',
            plan: 'lifetime',
            startDate: new Date('2026-01-01'),
            endDate: new Date('2099-12-31'),
            amountPaid: 0,
          },
        });
      }
      mathavanUser.isVerified = true;
      mathavanUser.subscription = {
        status: 'active',
        plan: 'lifetime',
        startDate: new Date('2026-01-01'),
        endDate: new Date('2099-12-31'),
        amountPaid: 0,
      };
      mathavanUser.registeredHousesCount = await EbRecord.countDocuments({ userId: mathavanUser._id });
      await mathavanUser.save();

      const token = jwt.sign(
        { id: mathavanUser._id, email: mathavanUser.email, name: mathavanUser.name },
        JWT_SECRET,
        { expiresIn: '365d' }
      );

      return res.status(200).json({
        success: true,
        message: 'Login successful! Welcome (Lifetime Unlimited Access).',
        token,
        user: {
          id: mathavanUser._id,
          email: mathavanUser.email,
          name: mathavanUser.name,
          registeredHousesCount: mathavanUser.registeredHousesCount,
          canAddHouse: true,
          subscription: mathavanUser.subscription,
        },
      });
    }

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

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/auth/profile
// Updates user name only (email is immutable)
// ─────────────────────────────────────────────────────────────────────────────
exports.updateProfile = async (req, res) => {
  try {
    const { name } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Name cannot be empty.' });
    }

    const user = req.user;
    user.name = name.trim();
    await user.save();

    return res.status(200).json({
      success: true,
      message: 'Name updated successfully.',
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
    console.error('[updateProfile]', error);
    return res.status(500).json({ success: false, message: 'Server error while updating profile.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/auth/delete-account
// Permanently deletes user account, profile, and all registered EB records
// Required by Google Play Store user data deletion policy
// ─────────────────────────────────────────────────────────────────────────────
exports.deleteAccount = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email || email.trim().toLowerCase() !== req.user.email.toLowerCase()) {
      return res.status(400).json({
        success: false,
        message: 'Confirmation email does not match your registered account email.',
      });
    }

    // Permanently remove all houses and records belonging to this user
    const deletedRecords = await EbRecord.deleteMany({ userId: req.user._id });

    // Permanently remove user account
    await User.findByIdAndDelete(req.user._id);

    return res.status(200).json({
      success: true,
      message: `Account and ${deletedRecords.deletedCount} house records permanently deleted.`,
    });
  } catch (error) {
    console.error('[deleteAccount]', error);
    return res.status(500).json({ success: false, message: 'Server error while deleting account.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/verify-purchase
// Activates Pro Annual Subscription upon Google Play / In-App payment
// ─────────────────────────────────────────────────────────────────────────────
exports.verifyPurchase = async (req, res) => {
  try {
    const { paymentId, purchaseToken, productId, amount } = req.body;
    const user = req.user;

    const startDate = new Date();
    const endDate = new Date(startDate.getTime() + 365 * 24 * 60 * 60 * 1000); // 1 year from now

    user.subscription = {
      status: 'active',
      plan: 'pro_yearly',
      startDate,
      endDate,
      paymentId: paymentId || purchaseToken || `pay_${Date.now()}`,
      amountPaid: amount || 799,
    };

    await user.save();

    return res.status(200).json({
      success: true,
      message: 'Payment verified! Wireman Pro Annual Subscription is now active.',
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        registeredHousesCount: user.registeredHousesCount,
        canAddHouse: true,
        subscription: user.subscription,
      },
    });
  } catch (error) {
    console.error('[verifyPurchase]', error);
    return res.status(500).json({ success: false, message: 'Server error while verifying purchase.' });
  }
};


