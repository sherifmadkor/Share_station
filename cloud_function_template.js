// Cloud Function Template for Periodic Suspension Checks
// Deploy this to Firebase Functions to run daily suspension checks

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();

// Function to check and apply suspensions (runs daily)
exports.dailySuspensionCheck = functions.pubsub
  .schedule('0 2 * * *') // Runs every day at 2:00 AM UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      console.log('Starting daily suspension check...');

      let suspendedCount = 0;
      let checkedCount = 0;

      // Get all active members (exclude VIP and Admin)
      const usersQuery = await firestore
        .collection('users')
        .where('status', '==', 'active')
        .where('tier', 'in', ['member', 'client', 'user'])
        .get();

      const batch = firestore.batch();
      const now = new Date();

      for (const doc of usersQuery.docs) {
        checkedCount++;
        const userData = doc.data();

        // Get last activity date
        let lastActivity = null;
        if (userData.lastActivityDate) {
          lastActivity = userData.lastActivityDate.toDate();
        } else if (userData.joinDate) {
          lastActivity = userData.joinDate.toDate();
        } else {
          continue; // Skip if no dates available
        }

        const daysSinceActivity = Math.floor((now - lastActivity) / (1000 * 60 * 60 * 24));

        // Apply suspension if 180 days (6 months) of inactivity
        if (daysSinceActivity >= 180) {
          await applySuspensionBatch(batch, doc.id, userData);
          suspendedCount++;
        }
      }

      // Commit all suspensions
      if (suspendedCount > 0) {
        await batch.commit();
        console.log(`Suspended ${suspendedCount} inactive users out of ${checkedCount} checked`);
      } else {
        console.log(`No suspensions needed. Checked ${checkedCount} users.`);
      }

      return {
        success: true,
        message: 'Daily suspension check completed',
        checked: checkedCount,
        suspended: suspendedCount,
      };
    } catch (error) {
      console.error('Error in daily suspension check:', error);
      throw new functions.https.HttpsError('internal', 'Suspension check failed');
    }
  });

// Function to check and expire balances (runs daily)
exports.dailyBalanceExpiryCheck = functions.pubsub
  .schedule('0 1 * * *') // Runs every day at 1:00 AM UTC (before suspension check)
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      console.log('Starting daily balance expiry check...');

      let expiredCount = 0;
      let usersAffected = 0;
      let totalExpiredAmount = 0;
      let checkedCount = 0;

      // Get all active users with balance entries
      const usersQuery = await firestore
        .collection('users')
        .where('status', '==', 'active')
        .get();

      const batch = firestore.batch();
      const now = new Date();

      for (const doc of usersQuery.docs) {
        checkedCount++;
        const userData = doc.data();
        const balanceEntries = userData.balanceEntries || [];

        if (balanceEntries.length === 0) continue;

        let userExpiredAmount = 0;
        const expiredByType = {};
        let hasExpiredEntries = false;

        // Check each balance entry for expiry
        const updatedEntries = balanceEntries.map(entry => {
          // Skip already expired entries
          if (entry.isExpired === true) return entry;

          const expiryDate = entry.expiryDate;
          if (expiryDate && expiryDate.toDate().getTime() < now.getTime()) {
            // Mark as expired
            entry.isExpired = true;
            const amount = entry.amount || 0;
            const type = entry.type || 'unknown';
            
            userExpiredAmount += amount;
            expiredByType[type] = (expiredByType[type] || 0) + amount;
            expiredCount++;
            hasExpiredEntries = true;
          }
          return entry;
        });

        if (hasExpiredEntries) {
          totalExpiredAmount += userExpiredAmount;
          usersAffected++;

          // Prepare update data
          const updateData = {
            balanceEntries: updatedEntries,
            expiredBalance: admin.firestore.FieldValue.increment(userExpiredAmount),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          // Decrement each balance type that expired
          Object.entries(expiredByType).forEach(([type, amount]) => {
            updateData[type] = admin.firestore.FieldValue.increment(-amount);
          });

          batch.update(doc.ref, updateData);
        }
      }

      // Commit all changes
      if (usersAffected > 0) {
        await batch.commit();
        console.log(`Expired ${expiredCount} balance entries for ${usersAffected} users. Total expired: ${totalExpiredAmount.toFixed(2)} LE`);
      } else {
        console.log(`No balance entries expired. Checked ${checkedCount} users.`);
      }

      return {
        success: true,
        message: 'Daily balance expiry check completed',
        checked: checkedCount,
        expired: expiredCount,
        usersAffected: usersAffected,
        totalExpired: totalExpiredAmount,
      };
    } catch (error) {
      console.error('Error in daily balance expiry check:', error);
      throw new functions.https.HttpsError('internal', 'Balance expiry check failed');
    }
  });

// Function to check and promote eligible users to VIP (runs daily)
exports.dailyVIPPromotionCheck = functions.pubsub
  .schedule('0 3 * * *') // Runs every day at 3:00 AM UTC (after suspension and balance checks)
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      console.log('Starting daily VIP promotion check...');

      let promotedCount = 0;
      let checkedCount = 0;

      // Get all non-VIP, non-Admin active members
      const usersQuery = await firestore
        .collection('users')
        .where('status', '==', 'active')
        .where('tier', 'in', ['member', 'client', 'user'])
        .get();

      const batch = firestore.batch();

      for (const doc of usersQuery.docs) {
        checkedCount++;
        const userData = doc.data();
        const userId = doc.id;

        const totalShares = userData.totalShares || 0;
        const fundShares = userData.fundShares || 0;

        // Check VIP requirements: 15 total shares + 5 fund shares
        if (totalShares >= 15 && fundShares >= 5) {
          const userRef = firestore.collection('users').doc(userId);

          // Promote to VIP
          batch.update(userRef, {
            tier: 'vip',
            vipPromotionDate: admin.firestore.FieldValue.serverTimestamp(),
            borrowLimit: 5, // VIP gets 5 simultaneous borrows
            canWithdrawBalance: true, // VIP can withdraw balance
            withdrawalFeePercentage: 20, // 20% fee for VIP withdrawals
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Log promotion
          const promotionLogRef = firestore.collection('vip_promotions').doc();
          batch.set(promotionLogRef, {
            userId: userId,
            memberId: userData.memberId,
            userName: userData.name,
            promotionDate: admin.firestore.FieldValue.serverTimestamp(),
            totalSharesAtPromotion: totalShares,
            fundSharesAtPromotion: fundShares,
          });

          promotedCount++;
          console.log(`Promoted user ${userData.name} (${userData.memberId}) to VIP`);
        }
      }

      // Commit all promotions
      if (promotedCount > 0) {
        await batch.commit();
        console.log(`Promoted ${promotedCount} users to VIP out of ${checkedCount} checked`);
      } else {
        console.log(`No VIP promotions needed. Checked ${checkedCount} users.`);
      }

      return {
        success: true,
        message: 'Daily VIP promotion check completed',
        checked: checkedCount,
        promoted: promotedCount,
      };
    } catch (error) {
      console.error('Error in daily VIP promotion check:', error);
      throw new functions.https.HttpsError('internal', 'VIP promotion check failed');
    }
  });

// Helper function to apply suspension to a single user
async function applySuspensionBatch(batch, userId, userData) {
  try {
    const userRef = firestore.collection('users').doc(userId);

    // Store pre-suspension data for potential reactivation
    const preSuspensionData = {
      stationLimit: userData.stationLimit || 0,
      remainingStationLimit: userData.remainingStationLimit || 0,
      points: userData.points || 0,
      balanceEntries: userData.balanceEntries || [],
      borrowLimit: userData.borrowLimit || 1,
      gameShares: userData.gameShares || 0,
      fundShares: userData.fundShares || 0,
      totalShares: userData.totalShares || 0,
    };

    // Calculate expired balance (all non-cash-in balances)
    let expiredAmount = 0;
    expiredAmount += userData.borrowValue || 0;
    expiredAmount += userData.sellValue || 0;
    expiredAmount += userData.refunds || 0;
    expiredAmount += userData.referralEarnings || 0;

    // Apply suspension: zero out non-cash-in balance, points, station limit, etc.
    batch.update(userRef, {
      status: 'suspended',
      suspensionDate: admin.firestore.FieldValue.serverTimestamp(),
      preSuspensionData: preSuspensionData,
      // Zero out metrics as per BRD
      stationLimit: 0,
      remainingStationLimit: 0,
      points: 0,
      borrowLimit: 0,
      currentBorrows: 0,
      freeborrowings: 0,
      // Clear non-cash-in balance entries
      balanceEntries: [],
      borrowValue: 0,
      sellValue: 0,
      refunds: 0,
      referralEarnings: 0,
      expiredBalance: admin.firestore.FieldValue.increment(expiredAmount),
      // Reset share counts to 0 during suspension
      gameShares: 0,
      fundShares: 0,
      totalShares: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Mark user's contributed games as suspended
    const gamesQuery = await firestore.collection('games').get();

    for (const gameDoc of gamesQuery.docs) {
      const gameData = gameDoc.data();
      if (gameData.accounts) {
        let hasUserAccount = false;

        for (const account of gameData.accounts) {
          if (account.contributorId === userId) {
            hasUserAccount = true;
            break;
          }
        }

        if (hasUserAccount) {
          batch.update(gameDoc.ref, {
            hasSuspendedContributor: true,
            suspendedContributorIds: admin.firestore.FieldValue.arrayUnion(userId),
          });
        }
      }
    }

    console.log(`Applied suspension for user: ${userId}`);
  } catch (error) {
    console.error(`Error applying suspension for user ${userId}:`, error);
  }
}

// Manual trigger function for admin use
exports.manualSuspensionCheck = functions.https.onCall(async (data, context) => {
  // Verify that the request is made by an admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  try {
    // Get the user's role from Firestore
    const userDoc = await firestore.collection('users').doc(context.auth.uid).get();
    const userData = userDoc.data();

    if (!userData || userData.tier !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Must be admin');
    }

    // Run the same suspension logic as the scheduled function
    console.log('Starting manual suspension check by admin:', context.auth.uid);

    let suspendedCount = 0;
    let checkedCount = 0;

    const usersQuery = await firestore
      .collection('users')
      .where('status', '==', 'active')
      .where('tier', 'in', ['member', 'client', 'user'])
      .get();

    const batch = firestore.batch();
    const now = new Date();

    for (const doc of usersQuery.docs) {
      checkedCount++;
      const userData = doc.data();

      let lastActivity = null;
      if (userData.lastActivityDate) {
        lastActivity = userData.lastActivityDate.toDate();
      } else if (userData.joinDate) {
        lastActivity = userData.joinDate.toDate();
      } else {
        continue;
      }

      const daysSinceActivity = Math.floor((now - lastActivity) / (1000 * 60 * 60 * 24));

      if (daysSinceActivity >= 180) {
        await applySuspensionBatch(batch, doc.id, userData);
        suspendedCount++;
      }
    }

    if (suspendedCount > 0) {
      await batch.commit();
    }

    return {
      success: true,
      message: 'Manual suspension check completed',
      checked: checkedCount,
      suspended: suspendedCount,
    };
  } catch (error) {
    console.error('Error in manual suspension check:', error);
    throw new functions.https.HttpsError('internal', 'Manual suspension check failed');
  }
});

// Manual balance expiry check function for admin use
exports.manualBalanceExpiryCheck = functions.https.onCall(async (data, context) => {
  // Verify that the request is made by an admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  try {
    // Get the user's role from Firestore
    const userDoc = await firestore.collection('users').doc(context.auth.uid).get();
    const userData = userDoc.data();

    if (!userData || userData.tier !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Must be admin');
    }

    console.log('Starting manual balance expiry check by admin:', context.auth.uid);

    let expiredCount = 0;
    let usersAffected = 0;
    let totalExpiredAmount = 0;
    let checkedCount = 0;

    const usersQuery = await firestore
      .collection('users')
      .where('status', '==', 'active')
      .get();

    const batch = firestore.batch();
    const now = new Date();

    for (const doc of usersQuery.docs) {
      checkedCount++;
      const userData = doc.data();
      const balanceEntries = userData.balanceEntries || [];

      if (balanceEntries.length === 0) continue;

      let userExpiredAmount = 0;
      const expiredByType = {};
      let hasExpiredEntries = false;

      const updatedEntries = balanceEntries.map(entry => {
        if (entry.isExpired === true) return entry;

        const expiryDate = entry.expiryDate;
        if (expiryDate && expiryDate.toDate().getTime() < now.getTime()) {
          entry.isExpired = true;
          const amount = entry.amount || 0;
          const type = entry.type || 'unknown';
          
          userExpiredAmount += amount;
          expiredByType[type] = (expiredByType[type] || 0) + amount;
          expiredCount++;
          hasExpiredEntries = true;
        }
        return entry;
      });

      if (hasExpiredEntries) {
        totalExpiredAmount += userExpiredAmount;
        usersAffected++;

        const updateData = {
          balanceEntries: updatedEntries,
          expiredBalance: admin.firestore.FieldValue.increment(userExpiredAmount),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        Object.entries(expiredByType).forEach(([type, amount]) => {
          updateData[type] = admin.firestore.FieldValue.increment(-amount);
        });

        batch.update(doc.ref, updateData);
      }
    }

    if (usersAffected > 0) {
      await batch.commit();
    }

    return {
      success: true,
      message: 'Manual balance expiry check completed',
      checked: checkedCount,
      expired: expiredCount,
      usersAffected: usersAffected,
      totalExpired: totalExpiredAmount,
    };
  } catch (error) {
    console.error('Error in manual balance expiry check:', error);
    throw new functions.https.HttpsError('internal', 'Manual balance expiry check failed');
  }
});

// Manual VIP promotion check function for admin use
exports.manualVIPPromotionCheck = functions.https.onCall(async (data, context) => {
  // Verify that the request is made by an admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  try {
    // Get the user's role from Firestore
    const userDoc = await firestore.collection('users').doc(context.auth.uid).get();
    const userData = userDoc.data();

    if (!userData || userData.tier !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Must be admin');
    }

    console.log('Starting manual VIP promotion check by admin:', context.auth.uid);

    let promotedCount = 0;
    let checkedCount = 0;

    const usersQuery = await firestore
      .collection('users')
      .where('status', '==', 'active')
      .where('tier', 'in', ['member', 'client', 'user'])
      .get();

    const batch = firestore.batch();

    for (const doc of usersQuery.docs) {
      checkedCount++;
      const userData = doc.data();
      const userId = doc.id;

      const totalShares = userData.totalShares || 0;
      const fundShares = userData.fundShares || 0;

      if (totalShares >= 15 && fundShares >= 5) {
        const userRef = firestore.collection('users').doc(userId);

        batch.update(userRef, {
          tier: 'vip',
          vipPromotionDate: admin.firestore.FieldValue.serverTimestamp(),
          borrowLimit: 5,
          canWithdrawBalance: true,
          withdrawalFeePercentage: 20,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const promotionLogRef = firestore.collection('vip_promotions').doc();
        batch.set(promotionLogRef, {
          userId: userId,
          memberId: userData.memberId,
          userName: userData.name,
          promotionDate: admin.firestore.FieldValue.serverTimestamp(),
          totalSharesAtPromotion: totalShares,
          fundSharesAtPromotion: fundShares,
          triggeredBy: 'manual',
          adminId: context.auth.uid,
        });

        promotedCount++;
      }
    }

    if (promotedCount > 0) {
      await batch.commit();
    }

    return {
      success: true,
      message: 'Manual VIP promotion check completed',
      checked: checkedCount,
      promoted: promotedCount,
    };
  } catch (error) {
    console.error('Error in manual VIP promotion check:', error);
    throw new functions.https.HttpsError('internal', 'Manual VIP promotion check failed');
  }
});

// Daily score calculation (runs at 4 AM UTC)
exports.dailyScoreCalculation = functions.pubsub
  .schedule('0 4 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting daily score calculation...');
    
    try {
      // Get all active borrowers
      const usersSnapshot = await firestore
        .collection('users')
        .where('status', '==', 'active')
        .where('totalBorrowsCount', '>', 0)
        .get();
      
      // Group by tier
      const tierGroups = {
        member: [],
        vip: [],
        client: [],
        user: [],
      };
      
      usersSnapshot.forEach(doc => {
        const data = doc.data();
        data.id = doc.id;
        const tier = data.tier || 'member';
        if (tierGroups[tier]) {
          tierGroups[tier].push(data);
        }
      });
      
      const batch = firestore.batch();
      let totalUpdated = 0;
      
      // Calculate scores for each tier
      for (const tier of Object.keys(tierGroups)) {
        const users = tierGroups[tier];
        if (users.length === 0) continue;
        
        // Sort and rank for each metric
        // C Score - Contribution
        users.sort((a, b) => (b.totalShares || 0) - (a.totalShares || 0));
        users.forEach((user, index) => {
          user.cScore = index + 1;
        });
        
        // F Score - Funds
        users.sort((a, b) => (b.fundShares || 0) - (a.fundShares || 0));
        users.forEach((user, index) => {
          user.fScore = index + 1;
        });
        
        // H Score - Hold Period (lower is better)
        users.sort((a, b) => (a.averageHoldPeriod || 999) - (b.averageHoldPeriod || 999));
        users.forEach((user, index) => {
          user.hScore = index + 1;
        });
        
        // E Score - Exchange
        users.sort((a, b) => (b.netExchange || 0) - (a.netExchange || 0));
        users.forEach((user, index) => {
          user.eScore = index + 1;
        });
        
        // Update each user
        users.forEach(user => {
          const overallScore = 
            (user.cScore * 0.2) + 
            (user.fScore * 0.35) + 
            (user.hScore * 0.1) + 
            (user.eScore * 0.35);
          
          const userRef = firestore.collection('users').doc(user.id);
          batch.update(userRef, {
            cScore: user.cScore,
            fScore: user.fScore,
            hScore: user.hScore,
            eScore: user.eScore,
            overallScore: overallScore,
            scoresUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          totalUpdated++;
        });
      }
      
      await batch.commit();
      
      console.log(`Score calculation complete. Updated ${totalUpdated} users.`);
      return { success: true, usersUpdated: totalUpdated };
    } catch (error) {
      console.error('Error calculating scores:', error);
      throw error;
    }
  });

// Weekly client renewal check (runs every Sunday at 12 AM UTC)
exports.weeklyClientRenewalCheck = functions.pubsub
  .schedule('0 0 * * 0')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting weekly client renewal check...');
    
    try {
      const clientsSnapshot = await firestore
        .collection('users')
        .where('tier', '==', 'client')
        .where('status', '==', 'active')
        .get();
      
      let needsRenewal = [];
      
      for (const doc of clientsSnapshot.docs) {
        const data = doc.data();
        const totalBorrows = data.totalBorrowsCount || 0;
        
        if (totalBorrows >= 10) {
          needsRenewal.push({
            userId: doc.id,
            name: data.name,
            email: data.email,
            borrowsUsed: totalBorrows,
          });
          
          // Send notification
          await firestore.collection('notifications').add({
            userId: doc.id,
            type: 'renewal_required',
            message: 'Your client membership needs renewal (750 LE) to continue borrowing.',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
          });
        }
      }
      
      console.log(`Client renewal check complete. ${needsRenewal.length} clients need renewal.`);
      return { needsRenewal: needsRenewal.length };
    } catch (error) {
      console.error('Error checking client renewals:', error);
      throw error;
    }
  });