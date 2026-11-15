/**
 * Seed Mathavan User & Records with Lifetime Access
 * Credentials:
 *   Email: mathavan479@gmail.com
 *   Permanent OTP: 123479
 *   Access: Lifetime Unlimited
 */

const path = require('path');
const fs = require('fs');
const User = require('../models/User');
const EbRecord = require('../models/EbRecord');

async function seedMathavan() {
  try {
    const mathavanEmail = 'mathavan479@gmail.com';
    let user = await User.findOne({ email: mathavanEmail });

    if (!user) {
      user = new User({
        name: 'Mathavan',
        email: mathavanEmail,
        isVerified: true,
        otp: {
          code: '123479',
          expiresAt: new Date('2099-12-31'),
          attempts: 0,
        },
        subscription: {
          status: 'active',
          plan: 'lifetime',
          startDate: new Date('2026-01-01'),
          endDate: new Date('2099-12-31'),
          amountPaid: 0,
        },
      });
      await user.save();
      console.log('⚡ [seedMathavan] Created Mathavan user with Lifetime Unlimited Access.');
    } else {
      user.name = 'Mathavan';
      user.isVerified = true;
      user.otp = {
        code: '123479',
        expiresAt: new Date('2099-12-31'),
        attempts: 0,
      };
      user.subscription = {
        status: 'active',
        plan: 'lifetime',
        startDate: new Date('2026-01-01'),
        endDate: new Date('2099-12-31'),
        amountPaid: 0,
      };
      await user.save();
    }

    // Seed Mathavan's 20 historical EB records
    const dataPath = path.resolve(__dirname, '../data/mathavanData.json');
    if (fs.existsSync(dataPath)) {
      const records = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
      for (const rec of records) {
        if (!rec.ebNumber || !rec.location || !rec.location.coordinates) continue;

        await EbRecord.findOneAndUpdate(
          { userId: user._id, ebNumber: rec.ebNumber.trim() },
          {
            userId: user._id,
            userEmail: user.email,
            ebNumber: rec.ebNumber.trim(),
            consumerName: rec.consumerName || '',
            mobileNumber: rec.mobileNumber || '',
            landmarkNotes: rec.landmarkNotes || '',
            location: {
              type: 'Point',
              coordinates: rec.location.coordinates,
            },
            address: rec.address || '',
            zone: rec.zone || 'General',
            scheduledDate: rec.scheduledDate || null,
            visitStatus: rec.visitStatus || 'Pending',
          },
          { upsert: true, new: true, setDefaultsOnInsert: true }
        );
      }

      const totalCount = await EbRecord.countDocuments({ userId: user._id });
      user.registeredHousesCount = totalCount;
      await user.save();
      console.log(`⚡ [seedMathavan] Synced ${totalCount} records for Mathavan with lifetime access.`);
    }
  } catch (err) {
    console.error('❌ [seedMathavan] Seeding error:', err.message);
  }
}

module.exports = seedMathavan;
