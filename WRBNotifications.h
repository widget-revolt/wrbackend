//
//  WRBNotifications.h
//
//	Copyright (c) 2014 Widget Revolt LLC.  All rights reserved
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.



#import <Foundation/Foundation.h>

// Quiet period is 10pm - 10am under defaults
#define kNotif_startQuietPeriod     22
#define kNotif_endQuietPeriod       10

#define kSegment_monetizer		@"monetizer"
#define kSegment_nonmonentizer	@"nonmonetizer"

// Analytics
// track push notification actions
#define kAnalEvent_pushNotificationResponse		@"notif.push_notification_response"	// pass tracker id == "t"
#define kAnalEvent_localNotificationResponse	@"notif.local_notification_response"

@interface WRBNotifications : NSObject

//--local notifications
- (void) startLocalNotifications:(NSDictionary*)launchOptions;
- (void) createLocalNotifications;
- (void) cancelAllLocalNotifications;
- (void) handleDidOpenFromLocalNotification:(UILocalNotification*)notification;

//--push notification management
- (void) startPushNotificationSDK:(NSDictionary*)launchOptions settings:(NSDictionary*)configSettings;
- (void) stopPushNotificationSDK;
- (void) clearPushNotifications;	// cleanup badges, etc.
- (void) registerPushNotificationsWithBackend;	// this can be called after starting whenver convenient

- (void) handleDidRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken;
- (void) handleDidFailToRegisterForRemoteNotificationsWithError:(NSError*)error;
- (void) handleDidReceiveRemoteNotification:(NSDictionary*)userInfo;

@end
