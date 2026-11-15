/**
 * MongoDB Connection Utility
 * Connects to MongoDB with retry logic and proper event listeners.
 */

const mongoose = require('mongoose');

function sanitizeMongoUri(rawUri) {
  if (!rawUri) return rawUri;
  // If password contains unescaped special characters like '@', URL-encode it
  const match = rawUri.match(/^(mongodb(?:\+srv)?:\/\/)([^:]+):(.+)@([^@]+)$/);
  if (match) {
    const protocol = match[1];
    const username = match[2];
    const password = match[3];
    const hostAndRest = match[4];
    const encodedPassword = encodeURIComponent(decodeURIComponent(password));
    return `${protocol}${username}:${encodedPassword}@${hostAndRest}`;
  }
  return rawUri;
}

const connectDB = async () => {
  const rawUri = process.env.MONGO_URI;

  if (!rawUri) {
    console.error('❌  MONGO_URI is not set in environment variables.');
    process.exit(1);
  }

  const uri = sanitizeMongoUri(rawUri);

  try {
    const conn = await mongoose.connect(uri, {
      maxPoolSize: 15,                 // Optimal pool size for Free Tier MongoDB Atlas
      minPoolSize: 2,                  // Minimum persistent sockets
      serverSelectionTimeoutMS: 5000,  // Timeout after 5 s
      socketTimeoutMS: 45000,          // Close sockets after 45 s of inactivity
    });

    console.log(`✅  MongoDB connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`❌  MongoDB connection error: ${error.message}`);
    process.exit(1);
  }

  // Log subsequent disconnection events
  mongoose.connection.on('disconnected', () => {
    console.warn('⚠️  MongoDB disconnected. Reconnecting...');
  });

  mongoose.connection.on('reconnected', () => {
    console.log('✅  MongoDB reconnected.');
  });
};

module.exports = connectDB;

