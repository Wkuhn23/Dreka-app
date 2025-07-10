# Push Notifications Setup Guide

This guide will help you set up push notifications for the Dreka app using Firebase Cloud Messaging (FCM).

## Overview

The app sends push notifications in the following scenarios:
1. When someone rates a venue that you have favorited
2. When a new venue suggestion is submitted (admin users only)

## Prerequisites

1. Firebase project with Cloud Functions enabled
2. Apple Developer account (for iOS push certificates)
3. Firebase CLI installed and configured

## Setup Steps

### 1. Firebase Project Configuration

1. Go to your Firebase Console
2. Navigate to Project Settings > Cloud Messaging
3. Upload your APNs authentication key or certificate
4. Note down your Server Key (you'll need this for testing)

### 2. iOS App Configuration

1. Add the following to your `Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

2. Ensure you have the required capabilities in your Xcode project:
   - Push Notifications
   - Background Modes > Remote notifications

### 3. Cloud Functions Deployment

1. Navigate to the `functions` directory in your project
2. Install dependencies:
```bash
npm install
```

3. Deploy the functions:
```bash
firebase deploy --only functions
```

### 4. Testing Notifications

To test the notification system:

1. Run the app on a physical device (notifications don't work in simulator)
2. Sign in with a user account
3. Add a venue to your favorites
4. Submit a rating for that venue
5. You should receive a notification about the new rating

## Notification Types

### Rating Notifications
- **Trigger**: When a user submits a rating for a venue
- **Recipients**: Users who have favorited that venue
- **Content**: "New Rating at [Venue Name] - Someone just rated [Venue Name]"

### Admin Notifications
- **Trigger**: When a new venue suggestion is submitted
- **Recipients**: Users with admin privileges
- **Content**: "New Venue Suggestion - A new venue suggestion has been submitted"

## Analytics Events

The app tracks the following events for analytics:
- `rating_submitted`: When user submits a rating
- `favorite_toggled`: When user adds/removes a venue from favorites

## Troubleshooting

### Common Issues

1. **Notifications not appearing**
   - Check that you're testing on a physical device
   - Verify push notification permissions are granted
   - Check Firebase Console for delivery status

2. **Cloud Functions errors**
   - Check Firebase Console > Functions for error logs
   - Verify the functions are deployed successfully

3. **Permission denied**
   - Ensure the user has granted notification permissions
   - Check that the app is requesting permissions correctly

### Debug Steps

1. Check Firebase Console > Analytics for event tracking
2. Verify Cloud Functions are running in Firebase Console
3. Test with Firebase Console's "Send test message" feature

## Security Considerations

- Notifications are only sent to users who have explicitly favorited venues
- Admin notifications are only sent to users with admin privileges
- All notification data is validated before sending

## Future Enhancements

Potential improvements to consider:
- Custom notification sounds
- Rich notifications with venue images
- Notification preferences per user
- Batch notifications for multiple events 