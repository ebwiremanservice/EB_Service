const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
      maxlength: 100,
    },
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    isVerified: {
      type: Boolean,
      default: false,
    },
    otp: {
      code: { type: String, default: null },
      expiresAt: { type: Date, default: null },
      attempts: { type: Number, default: 0 },
    },
    // Track total EB houses registered by this user
    registeredHousesCount: {
      type: Number,
      default: 0,
    },
    // Subscription status (10 houses free, ₹799/yr for unlimited)
    subscription: {
      status: {
        type: String,
        enum: ['free', 'active', 'expired'],
        default: 'free',
      },
      plan: {
        type: String,
        default: 'free_10',
      },
      startDate: {
        type: Date,
        default: null,
      },
      endDate: {
        type: Date,
        default: null,
      },
      paymentId: {
        type: String,
        default: null,
      },
      amountPaid: {
        type: Number,
        default: 0,
      },
    },
  },
  {
    timestamps: true,
  }
);

// Method to verify if user can add more houses under free tier or active sub
userSchema.methods.canAddHouse = function () {
  const isSubActive =
    this.subscription.status === 'active' &&
    this.subscription.endDate &&
    new Date(this.subscription.endDate) > new Date();

  if (isSubActive) return true;
  return this.registeredHousesCount < 10;
};

module.exports = mongoose.model('User', userSchema);

