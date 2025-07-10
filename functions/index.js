const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Send notification when a new rating is submitted
exports.onRatingSubmitted = functions.firestore
    .document('ratings/{ratingId}')
    .onCreate(async (snap, context) => {
        const rating = snap.data();
        
        // Get venue information
        const venueDoc = await admin.firestore().collection('venues').doc(rating.venueId).get();
        if (!venueDoc.exists) {
            console.log('Venue not found:', rating.venueId);
            return;
        }
        const venue = venueDoc.data();
        
        // Find users who have this venue as a favorite
        const usersSnapshot = await admin.firestore().collection('users')
            .where('favoriteVenueIDs', 'array-contains', rating.venueId)
            .get();
        
        if (usersSnapshot.empty) {
            console.log('No users have this venue as favorite');
            return;
        }
        
        // Send notification to each user
        const tokens = [];
        usersSnapshot.forEach(doc => {
            if (doc.data().fcmToken) {
                tokens.push(doc.data().fcmToken);
            }
        });
        
        if (tokens.length > 0) {
            const message = {
                notification: {
                    title: 'New Rating at ' + venue.name,
                    body: 'Someone just rated ' + venue.name
                },
                data: {
                    type: 'venue_rating',
                    venue_id: rating.venueId,
                },
                topic: 'venue_' + rating.venueId
            };
            
            try {
                await admin.messaging().sendToTopic('venue_' + rating.venueId, message);
                console.log('Notification sent to', tokens.length, 'users');
            } catch (error) {
                console.error('Error sending notification:', error);
            }
        }
    });

// Send notification when a new venue suggestion is submitted
exports.onVenueSuggestionSubmitted = functions.firestore
    .document('venueSuggestions/{suggestionId}')
    .onCreate(async (snap, context) => {
        const suggestion = snap.data();
        
        // Find admin users
        const adminUsersSnapshot = await admin.firestore().collection('users')
            .where('isAdmin', '==', true)
            .get();
        
        if (adminUsersSnapshot.empty) {
            console.log('No admin users found');
            return;
        }
        
        // Send notification to each admin
        const tokens = [];
        adminUsersSnapshot.forEach(doc => {
            if (doc.data().fcmToken) {
                tokens.push(doc.data().fcmToken);
            }
        });
        
        if (tokens.length > 0) {
            const message = {
                notification: {
                    title: 'New Venue Suggestion',
                    body: 'A new venue suggestion has been submitted'
                },
                data: {
                    type: 'venue_suggestion',
                    suggestion_id: suggestion.id,
                }
            };
            
            try {
                await admin.messaging().sendMulticast({
                    tokens: tokens,
                    ...message
                });
                console.log('Notification sent to', tokens.length, 'admins');
            } catch (error) {
                console.error('Error sending notification:', error);
            }
        }
    });

// Send notification when a venue suggestion is approved
exports.onVenueSuggestionApproved = functions.firestore
    .document('venue_suggestions/{suggestionId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        
        // Check if status changed from pending to approved
        if (before.status === 'pending' && after.status === 'approved') {
            try {
                // Get user who submitted the suggestion
                const userDoc = await admin.firestore().collection('users').doc(after.submittedBy).get();
                if (!userDoc.exists) {
                    console.log('User not found:', after.submittedBy);
                    return;
                }
                
                // Prepare notification message
                const message = {
                    notification: {
                        title: 'Venue Suggestion Approved!',
                        body: 'Your suggestion for ' + after.name + ' has been approved and added to the app.'
                    },
                    data: {
                        type: 'suggestion_approved',
                        venue_name: after.name
                    },
                    token: userDoc.data().fcmToken // You'd need to store FCM tokens in user documents
                };
                
                // Send notification to user
                const response = await admin.messaging().send(message);
                console.log('Successfully sent approval notification:', response);
                
            } catch (error) {
                console.error('Error sending approval notification:', error);
            }
        }
    }); 