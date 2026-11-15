/**
 * EB Records Controller
 * Handles business logic for creating, updating, searching, scheduling, and listing EB records.
 * Scoped per authenticated user for multi-tenant isolation.
 */

const mongoose = require('mongoose');
const EbRecord = require('../models/EbRecord');
const { validationResult } = require('express-validator');

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/eb-records/check-eb?ebNumber=...
// Checks if an EB number is already registered for this user
// ─────────────────────────────────────────────────────────────────────────────
exports.checkEbNumber = async (req, res) => {
  try {
    const ebNumber = (req.query.ebNumber || '').trim();
    if (!ebNumber) {
      return res.status(400).json({ success: false, message: 'EB number is required.' });
    }

    const existing = await EbRecord.findOne({
      userId: req.user._id,
      ebNumber,
    });

    return res.status(200).json({
      success: true,
      exists: !!existing,
      message: existing ? 'EB Number already registered in your account!' : 'EB Number is available.',
      data: existing || null,
    });
  } catch (error) {
    console.error('[checkEbNumber]', error);
    return res.status(500).json({ success: false, message: 'Server error while checking EB number.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/eb-records
// Creates a new EB record with 10-house free tier quota check & unique check
// ─────────────────────────────────────────────────────────────────────────────
exports.createRecord = async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({ success: false, errors: errors.array() });
  }

  try {
    // ── Free Tier 10-House Quota Check ───────────────────────────────────────
    if (!req.user.canAddHouse()) {
      return res.status(402).json({
        success: false,
        paymentRequired: true,
        limitReached: true,
        count: req.user.registeredHousesCount,
        message: 'Free tier limit of 10 houses reached. Upgrade to yearly unlimited plan (₹799/yr) to add more houses.',
      });
    }

    const {
      zone,
      ebNumber,
      consumerName,
      mobileNumber,
      landmarkNotes,
      longitude,
      latitude,
      address,
      scheduledDate,
    } = req.body;
    const cleanEb = ebNumber.trim();
    const cleanZone = (zone && zone.trim()) ? zone.trim() : 'General';

    // Check if EB number already exists for this user account
    const existing = await EbRecord.findOne({
      userId: req.user._id,
      ebNumber: cleanEb,
    });
    if (existing) {
      return res.status(409).json({
        success: false,
        message: `EB Number "${cleanEb}" is already registered in your account. Duplicates are not allowed.`,
      });
    }

    // GeoJSON stores as [longitude, latitude]
    const coordinates = [parseFloat(longitude), parseFloat(latitude)];

    const newRecord = new EbRecord({
      userId: req.user._id,
      userEmail: req.user.email,
      zone: cleanZone,
      ebNumber: cleanEb,
      consumerName: consumerName ? consumerName.trim() : '',
      mobileNumber: mobileNumber ? mobileNumber.trim() : '',
      landmarkNotes: landmarkNotes ? landmarkNotes.trim() : '',
      address: address ? address.trim() : '',
      scheduledDate: scheduledDate ? new Date(scheduledDate) : null,
      visitStatus: 'Pending',
      location: {
        type: 'Point',
        coordinates,
      },
    });

    await newRecord.save();

    // Sync accurate registered houses count for the user
    req.user.registeredHousesCount = await EbRecord.countDocuments({ userId: req.user._id });
    await req.user.save();

    return res.status(201).json({
      success: true,
      message: 'EB Record registered successfully.',
      data: newRecord,
      registeredHousesCount: req.user.registeredHousesCount,
    });
  } catch (error) {
    console.error('[createRecord]', error);
    return res.status(500).json({ success: false, message: 'Server error while creating record.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/eb-records/:id/schedule
// Updates or sets a scheduled visit date and status for an EB house
// ─────────────────────────────────────────────────────────────────────────────
exports.updateSchedule = async (req, res) => {
  try {
    const { id } = req.params;
    const { scheduledDate, visitStatus } = req.body;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid record ID format.' });
    }

    const updateFields = {};
    if (scheduledDate !== undefined) {
      updateFields.scheduledDate = scheduledDate ? new Date(scheduledDate) : null;
    }
    if (visitStatus !== undefined) {
      updateFields.visitStatus = visitStatus;
    }

    const record = await EbRecord.findOneAndUpdate(
      { _id: id, userId: req.user._id },
      { $set: updateFields },
      { new: true, runValidators: true }
    );

    if (!record) {
      return res.status(404).json({ success: false, message: 'Record not found in your account.' });
    }

    return res.status(200).json({
      success: true,
      message: 'Schedule updated successfully.',
      data: record,
    });
  } catch (error) {
    console.error('[updateSchedule]', error);
    return res.status(500).json({ success: false, message: 'Server error while updating schedule.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/eb-records/:id
// Updates an existing EB record for the current user
// ─────────────────────────────────────────────────────────────────────────────
exports.updateRecord = async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({ success: false, errors: errors.array() });
  }

  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid record ID format.' });
    }

    const {
      zone,
      ebNumber,
      consumerName,
      mobileNumber,
      landmarkNotes,
      longitude,
      latitude,
      address,
      scheduledDate,
      visitStatus,
    } = req.body;

    const record = await EbRecord.findOne({ _id: id, userId: req.user._id });
    if (!record) {
      return res.status(404).json({ success: false, message: 'Record not found in your account.' });
    }

    if (zone !== undefined) {
      record.zone = (zone && zone.trim()) ? zone.trim() : 'General';
    }

    // If ebNumber is being modified, verify it does not conflict with another consumer's record in this account
    if (ebNumber) {
      const cleanEb = ebNumber.trim();
      const duplicate = await EbRecord.findOne({
        userId: req.user._id,
        ebNumber: cleanEb,
        _id: { $ne: id },
      });
      if (duplicate) {
        return res.status(409).json({
          success: false,
          message: `EB Number "${cleanEb}" is already registered to another consumer in your account. Duplicates are not allowed.`,
        });
      }
      record.ebNumber = cleanEb;
    }

    if (consumerName !== undefined) record.consumerName = consumerName.trim();
    if (mobileNumber !== undefined) record.mobileNumber = mobileNumber.trim();
    if (landmarkNotes !== undefined) record.landmarkNotes = landmarkNotes.trim();
    if (address !== undefined) record.address = address.trim();

    if (scheduledDate !== undefined) {
      record.scheduledDate = scheduledDate ? new Date(scheduledDate) : null;
    }
    if (visitStatus !== undefined) record.visitStatus = visitStatus;

    if (
      longitude !== undefined &&
      latitude !== undefined &&
      longitude !== null &&
      latitude !== null &&
      !isNaN(parseFloat(longitude)) &&
      !isNaN(parseFloat(latitude))
    ) {
      record.location = {
        type: 'Point',
        coordinates: [parseFloat(longitude), parseFloat(latitude)],
      };
    }

    await record.save();

    return res.status(200).json({
      success: true,
      message: 'EB Record updated successfully.',
      data: record,
    });
  } catch (error) {
    console.error('[updateRecord]', error);
    return res.status(500).json({ success: false, message: 'Server error while updating record.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/eb-records/scheduled?date=YYYY-MM-DD
// Returns house records scheduled for a particular date for this user
// ─────────────────────────────────────────────────────────────────────────────
exports.getScheduledRecords = async (req, res) => {
  try {
    const { date } = req.query;
    const filter = { userId: req.user._id };

    if (date) {
      const targetDate = new Date(date);
      const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 0, 0, 0, 0);
      const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 23, 59, 59, 999);

      filter.scheduledDate = {
        $gte: startOfDay,
        $lte: endOfDay,
      };
    } else {
      filter.scheduledDate = { $ne: null };
    }

    const records = await EbRecord.find(filter)
      .sort({ scheduledDate: 1, updatedAt: -1 })
      .lean();

    return res.status(200).json({
      success: true,
      count: records.length,
      data: records,
    });
  } catch (error) {
    console.error('[getScheduledRecords]', error);
    return res.status(500).json({ success: false, message: 'Server error while fetching scheduled records.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/eb-records/search?query=<partial_eb_number_or_address>
// Searches records belonging to the current user
// ─────────────────────────────────────────────────────────────────────────────
exports.searchRecords = async (req, res) => {
  try {
    const query = (req.query.query || '').trim();

    if (!query) {
      return res.status(400).json({ success: false, message: 'Search query is required.' });
    }

    const regex = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');

    const records = await EbRecord.find({
      userId: req.user._id,
      $or: [
        { ebNumber: { $regex: regex } },
        { consumerName: { $regex: regex } },
        { mobileNumber: { $regex: regex } },
        { landmarkNotes: { $regex: regex } },
        { address: { $regex: regex } },
        { zone: { $regex: regex } },
      ],
    })
      .sort({ updatedAt: -1 })
      .limit(100)
      .lean();

    return res.status(200).json({ success: true, count: records.length, data: records });
  } catch (error) {
    console.error('[searchRecords]', error);
    return res.status(500).json({ success: false, message: 'Server error during search.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/eb-records/zones
// Returns list of unique zone names registered by this user
// ─────────────────────────────────────────────────────────────────────────────
exports.getZones = async (req, res) => {
  try {
    const rawZones = await EbRecord.distinct('zone', { userId: req.user._id });
    const zones = rawZones
      .filter((z) => z && typeof z === 'string' && z.trim().length > 0)
      .map((z) => z.trim())
      .sort((a, b) => a.localeCompare(b));

    return res.status(200).json({
      success: true,
      count: zones.length,
      data: zones,
    });
  } catch (error) {
    console.error('[getZones]', error);
    return res.status(500).json({ success: false, message: 'Server error while fetching zones.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/eb-records/zones-summary
// Returns list of unique zones with their house counts: [{ name, count }]
// ─────────────────────────────────────────────────────────────────────────────
exports.getZonesSummary = async (req, res) => {
  try {
    const summary = await EbRecord.aggregate([
      { $match: { userId: req.user._id } },
      {
        $group: {
          _id: { $ifNull: ['$zone', 'General'] },
          count: { $sum: 1 },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    const data = summary.map((item) => ({
      name: item._id || 'General',
      count: item.count,
    }));

    return res.status(200).json({
      success: true,
      count: data.length,
      data,
    });
  } catch (error) {
    console.error('[getZonesSummary]', error);
    return res.status(500).json({ success: false, message: 'Server error while fetching zones summary.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/eb-records/zones/rename
// Renames a zone across all houses for this user
// ─────────────────────────────────────────────────────────────────────────────
exports.renameZone = async (req, res) => {
  try {
    const { oldZone, newZone } = req.body;
    if (!oldZone || !oldZone.trim() || !newZone || !newZone.trim()) {
      return res.status(400).json({ success: false, message: 'Both oldZone and newZone are required.' });
    }

    const cleanOld = oldZone.trim();
    const cleanNew = newZone.trim();

    const result = await EbRecord.updateMany(
      { userId: req.user._id, zone: cleanOld },
      { $set: { zone: cleanNew } }
    );

    return res.status(200).json({
      success: true,
      message: `Zone renamed from "${cleanOld}" to "${cleanNew}" for ${result.modifiedCount} house(s).`,
      modifiedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error('[renameZone]', error);
    return res.status(500).json({ success: false, message: 'Server error while renaming zone.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/eb-records/zones
// Deletes a zone: either reassigns houses to 'General' (deleteHouses: false) or deletes all houses (deleteHouses: true)
// ─────────────────────────────────────────────────────────────────────────────
exports.deleteZone = async (req, res) => {
  try {
    const { zone, deleteHouses } = req.body;
    if (!zone || !zone.trim()) {
      return res.status(400).json({ success: false, message: 'Zone name is required.' });
    }

    const cleanZone = zone.trim();

    if (deleteHouses === true || deleteHouses === 'true') {
      const delResult = await EbRecord.deleteMany({ userId: req.user._id, zone: cleanZone });
      const newCount = await EbRecord.countDocuments({ userId: req.user._id });
      await User.findByIdAndUpdate(req.user._id, { registeredHousesCount: newCount });

      return res.status(200).json({
        success: true,
        message: `Zone "${cleanZone}" and ${delResult.deletedCount} house(s) permanently deleted.`,
        deletedCount: delResult.deletedCount,
        remainingHousesCount: newCount,
      });
    } else {
      const updResult = await EbRecord.updateMany(
        { userId: req.user._id, zone: cleanZone },
        { $set: { zone: 'General' } }
      );

      return res.status(200).json({
        success: true,
        message: `Zone "${cleanZone}" removed. ${updResult.modifiedCount} house(s) moved to "General".`,
        modifiedCount: updResult.modifiedCount,
      });
    }
  } catch (error) {
    console.error('[deleteZone]', error);
    return res.status(500).json({ success: false, message: 'Server error while deleting zone.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/eb-records
// Returns the records for this user (supports optional ?zone= filter)
// ─────────────────────────────────────────────────────────────────────────────
exports.getLatestRecords = async (req, res) => {
  try {
    const filter = { userId: req.user._id };
    if (req.query.zone && req.query.zone.trim()) {
      filter.zone = req.query.zone.trim();
    }

    const records = await EbRecord.find(filter)
      .sort({ updatedAt: -1 })
      .limit(100)
      .lean();

    return res.status(200).json({ success: true, count: records.length, data: records });
  } catch (error) {
    console.error('[getLatestRecords]', error);
    return res.status(500).json({ success: false, message: 'Server error while fetching records.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/eb-records/:id
// Deletes a single record by its MongoDB _id for this user
// ─────────────────────────────────────────────────────────────────────────────
exports.deleteRecord = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid record ID format.' });
    }

    const record = await EbRecord.findOneAndDelete({ _id: id, userId: req.user._id });
    if (!record) {
      return res.status(404).json({ success: false, message: 'Record not found in your account.' });
    }

    // Sync accurate registered houses count for the user
    req.user.registeredHousesCount = await EbRecord.countDocuments({ userId: req.user._id });
    await req.user.save();

    return res.status(200).json({
      success: true,
      message: 'Record deleted successfully.',
      registeredHousesCount: req.user.registeredHousesCount,
    });
  } catch (error) {
    console.error('[deleteRecord]', error);
    return res.status(500).json({ success: false, message: 'Server error during deletion.' });
  }
};
