# Suspension System Implementation Guide

## Overview
The enhanced suspension system automatically manages user suspensions and VIP promotions based on contribution activity. This system includes:

1. **Contribution Tracking**: Updates user's `lastContributionDate` on contributions
2. **Periodic Suspension Checks**: Runs daily to check for inactive contributors
3. **Automatic VIP Promotions**: Promotes eligible users to VIP automatically
4. **Automatic Suspension**: Suspends users based on contribution inactivity
5. **Reactivation**: Allows suspended users to reactivate by contributing

## Files Modified

### 1. Services (Activity Tracking Added)

#### `lib/services/contribution_service.dart`
- Added `SuspensionService` import and instance
- **Contribution Submission Methods:**
  - `submitContribution()`: Calls `updateLastContribution()` and `checkAndPromoteToVIP()`
  - `submitFundContribution()`: Calls `updateLastContribution()` and `checkAndPromoteToVIP()`
- **Contribution Approval Methods:**
  - `approveGameContribution()`: Calls `updateLastContribution()` and `checkAndPromoteToVIP()`
  - `approveFundContribution()`: Calls `updateLastContribution()` and `checkAndPromoteToVIP()`

#### `lib/services/borrow_service.dart`
- Added `SuspensionService` import and instance  
- **Borrow Activities:**
  - `submitBorrowRequest()`: Calls `checkAndApplySuspensions()` (line 104)
  - `returnBorrowedGame()`: Calls `updateLastContribution()` (line 475)

#### `lib/presentation/screens/admin/admin_dashboard.dart`
- Added `SuspensionService` import and instance
- Added `_runPeriodicSuspensionCheck()` method (line 238)
- Called suspension check in `initState()` (line 48)

### 2. Existing Files (Already Tracking Activity)

#### `lib/presentation/providers/auth_provider.dart`
- Already updates `lastActivityDate` in `_updateLastLogin()` method
- No changes needed - login activity is already tracked

## Activity Tracking Implementation

### Current Implementation
The following user activities now automatically update `lastActivityDate`:

1. **Login** - Already implemented in `auth_provider.dart`
2. **Submit Contribution** - Added to `contribution_service.dart`
3. **Submit Fund Contribution** - Added to `contribution_service.dart` 
4. **Submit Borrow Request** - Added to `borrow_service.dart`
5. **Return Borrowed Game** - Added to `borrow_service.dart`

### Code Pattern Used
```dart
// Import the suspension service
import 'suspension_service.dart';

// Add instance to service class
final SuspensionService _suspensionService = SuspensionService();

// Call after successful user action
await _suspensionService.updateLastActivity(userId);
```

## Periodic Suspension Checks

### Option 1: Admin Dashboard (Implemented)
- Runs when admin opens dashboard
- Provides immediate feedback via SnackBar
- Good for development and testing

### Option 2: Cloud Function (Recommended for Production)
- Use the provided `cloud_function_template.js`
- Deploy to Firebase Functions
- Runs daily at 2:00 AM UTC automatically
- Includes manual trigger for admin use

#### To Deploy Cloud Function:
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Navigate to functions folder
cd functions

# Install dependencies
npm install firebase-functions firebase-admin

# Copy the template code to functions/index.js

# Deploy
firebase deploy --only functions
```

## Manual Suspension Check

### From Admin Dashboard
Suspension checks run automatically when admin opens the dashboard. Results are shown in console and via SnackBar if users are suspended.

### From Cloud Function
```dart
// Call the manual trigger function
final result = await FirebaseFunctions.instance
    .httpsCallable('manualSuspensionCheck')
    .call();
```

## Usage Examples

### Daily Automatic Check (Cloud Function)
```javascript
// Runs daily at 2:00 AM UTC
exports.dailySuspensionCheck = functions.pubsub
  .schedule('0 2 * * *')
  .onRun(async (context) => {
    // Suspension logic runs automatically
  });
```

### Manual Check (Dart)
```dart
// From admin dashboard or any admin action
final suspensionService = SuspensionService();
final result = await suspensionService.checkAndApplySuspensions();

print('Checked: ${result['checked']}, Suspended: ${result['suspended']}');
```

### Activity Tracking (Dart)
```dart
// Add to any user action
final suspensionService = SuspensionService();
await suspensionService.updateLastActivity(userId);
```

## Suspension and VIP Promotion Logic

### Suspension System

#### Users Affected
- **Member** tier users
- **Client** tier users  
- **User** tier users

#### Users Exempt
- **VIP** tier users
- **Admin** tier users

#### Suspension Criteria
- 180 days (6 months) of contribution inactivity
- Based on `lastContributionDate` or `joinDate` if no contribution activity recorded

#### Suspension Actions
1. Set `status` to 'suspended'
2. Store pre-suspension data for reactivation
3. Zero out balance components (except cashIn)
4. Reset points and station limits
5. Mark contributed games as having suspended contributors

#### Reactivation
Users can reactivate by making a new contribution. The `reactivateAccount()` method restores:
- Status to 'active'
- Pre-suspension metrics
- Station limits and borrow limits
- Game availability

### VIP Promotion System

#### VIP Requirements
- Minimum 15 total shares (game + fund contributions)
- Minimum 5 fund shares
- Active status (not suspended)

#### VIP Benefits
- 5 simultaneous borrows (increased from regular member limits)
- Balance withdrawal permissions
- 20% withdrawal fee (reduced from non-VIP rates)
- Exemption from suspension system

#### Promotion Triggers
- **Automatic**: During contribution approval (`contribution_service.dart`)
- **Periodic**: Daily Cloud Function check
- **Manual**: Admin dashboard trigger

#### Promotion Actions
1. Update `tier` to 'vip'
2. Set `vipPromotionDate` timestamp
3. Increase `borrowLimit` to 5
4. Enable `canWithdrawBalance`
5. Set `withdrawalFeePercentage` to 20
6. Log promotion in `vip_promotions` collection

## Monitoring

### Logs
- Console logs show suspension check results
- Admin dashboard shows notifications
- Firebase Functions logs (if using Cloud Functions)

### Statistics
- Check admin dashboard for updated user counts
- Suspended users appear in statistics
- Games with suspended contributors are tracked

## Testing

### Test Suspension
```dart
// Manually set a user's lastContributionDate to 181 days ago
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({
  'lastContributionDate': Timestamp.fromDate(
    DateTime.now().subtract(Duration(days: 181))
  ),
});

// Run suspension check
final result = await suspensionService.checkAndApplySuspensions();
print('Suspended: ${result['suspended']} out of ${result['checked']} users');
```

### Test VIP Promotion
```dart
// Set user with VIP-eligible shares
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({
  'totalShares': 15,
  'fundShares': 5,
  'gameShares': 10,
  'tier': 'member', // Should be promoted
  'status': 'active',
});

// Run VIP promotion check
final result = await suspensionService.checkAndPromoteToVIP(userId);
print('VIP promotion result: ${result['message']}');

// Or run batch check
final batchResult = await suspensionService.batchCheckVIPPromotions();
print('Batch promoted: ${batchResult['promoted']} out of ${batchResult['checked']} users');
```

### Test Reactivation
```dart
// Reactivate a suspended user by making a contribution
final result = await suspensionService.reactivateAccount(userId);
print('Reactivation result: ${result['message']}');
```

### Integration Testing
```dart
// Complete workflow test
1. Create test user with contributions
2. Set lastContributionDate to 181 days ago
3. Run suspension check - user should be suspended
4. Submit new contribution for suspended user
5. Approve contribution - user should be reactivated
6. Set user shares to VIP levels
7. Run VIP promotion - user should become VIP
```

## Production Deployment

### Prerequisites
1. **Firebase CLI** installed and authenticated
2. **Node.js** environment for Cloud Functions
3. **Admin permissions** configured in Firestore security rules
4. **Composite indexes** created for efficient queries

### Deployment Steps

#### 1. Deploy Cloud Functions
```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install firebase-functions firebase-admin

# Copy cloud_function_template.js to functions/index.js
cp ../cloud_function_template.js index.js

# Deploy functions
firebase deploy --only functions
```

#### 2. Verify Scheduled Functions
- Check Firebase Console > Functions for successful deployment
- Verify `dailySuspensionCheck` scheduled for 2:00 AM UTC
- Verify `dailyVIPPromotionCheck` scheduled for 3:00 AM UTC

#### 3. Test Manual Functions
```dart
// Test manual suspension check
final result = await FirebaseFunctions.instance
    .httpsCallable('manualSuspensionCheck')
    .call();

// Test manual VIP promotion check  
final vipResult = await FirebaseFunctions.instance
    .httpsCallable('manualVIPPromotionCheck')
    .call();
```

#### 4. Monitor and Verify
1. **Check Firebase Functions logs** for execution results
2. **Test with staging users** by adjusting their contribution dates
3. **Verify admin dashboard** shows updated statistics
4. **Test reactivation flow** with suspended accounts
5. **Verify VIP promotions** work correctly

#### 5. Production Rollout
1. **Schedule maintenance window** for initial checks
2. **Run manual checks first** to understand current state
3. **Monitor automated daily runs** for first week
4. **Set up alerts** for function failures or unusual patterns

## Security Considerations

- Only admins can trigger manual suspension checks
- Cloud Function runs with admin privileges
- Activity updates are called from server-side services
- Suspension checks include proper error handling
- All changes are atomic using Firestore batches

## Monitoring and Maintenance

### Daily Operations
1. **Check Function Logs**: Review Cloud Function execution results
2. **Monitor Statistics**: Track suspension and VIP promotion numbers
3. **Review Edge Cases**: Handle any failed operations manually
4. **User Notifications**: Communicate with affected users if needed

### Weekly Reviews
1. **Analyze Trends**: Track suspension patterns and VIP growth
2. **Review Thresholds**: Adjust suspension period if needed
3. **Check Performance**: Monitor function execution times
4. **Update Documentation**: Keep implementation notes current

### Alerts and Notifications
```javascript
// Add to Cloud Functions for monitoring
if (suspendedCount > 50) {
  // Alert admin of unusually high suspensions
  console.warn(`High suspension count: ${suspendedCount}`);
}

if (promotedCount > 10) {
  // Alert admin of mass VIP promotions
  console.warn(`High VIP promotion count: ${promotedCount}`);
}
```

## Troubleshooting

### Common Issues

#### Function Timeout
- **Cause**: Large user base causing slow execution
- **Solution**: Implement batch processing with smaller chunks
- **Prevention**: Monitor execution time and optimize queries

#### Incorrect Suspension Dates
- **Cause**: Users with no `lastContributionDate` field
- **Solution**: Migration script to set initial dates
- **Prevention**: Always set contribution dates on user actions

#### VIP Promotion Failures
- **Cause**: Share count discrepancies
- **Solution**: Recalculate shares from contribution history
- **Prevention**: Ensure atomic updates in contribution approval

#### Batch Operation Failures
- **Cause**: Firestore batch size limits or concurrent modifications
- **Solution**: Implement retry logic and smaller batch sizes
- **Prevention**: Use transactions for critical operations

## Future Enhancements

### Planned Features
1. **Email Notifications**: Warn users before suspension (7-day warning)
2. **Grace Periods**: Different timeout periods for different tiers
3. **Activity Categories**: Track different types of contribution activities
4. **Dashboard Analytics**: Show suspension trends and VIP promotion statistics
5. **Bulk Operations**: Admin tools for managing suspended accounts in bulk

### Advanced Features
1. **Progressive Warnings**: 30-day, 7-day, 1-day suspension warnings
2. **Tier-Based Rules**: Different suspension periods for different user tiers
3. **Seasonal Adjustments**: Longer grace periods during holidays
4. **Contribution Quality Metrics**: Weight different contribution types
5. **Automated Appeals**: System for users to contest suspensions

### Integration Opportunities
1. **Push Notifications**: Mobile app notifications for warnings
2. **SMS Alerts**: Critical notifications via SMS
3. **Analytics Dashboard**: Detailed reporting and trend analysis
4. **API Endpoints**: External system integration capabilities
5. **Machine Learning**: Predictive models for user engagement