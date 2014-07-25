//
//  WRBNotifications.m
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



#import "WRBNotifications.h"
#import "WRBackendConst.h"
#import "WRBackend.h"
#import "AnalyticsHelper.h"
#import "WRLib.h"
#import "NSDate+WRAdditions.h"

#ifndef ANDROID
#define USE_URBAN_AIRSHIP	1
#endif

#if USE_URBAN_AIRSHIP
#import "UAirship.h"
#import "UAPush.h"
#import "UATagUtils.h"
#import "UAConfig.h"
#endif



#ifndef ANDROID
#endif

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#define kToken_userFirstName	@"__USER__"

@implementation WRBNotifications

#pragma mark - object lifecycle

//===========================================================
- (id) init
{
	self = [super init];
	if(self)
	{
	
	}
	
	return self;
}
//===========================================================
- (void) dealloc
{

}

#pragma mark - Push notification

//===========================================================
- (void) startPushNotificationSDK:(NSDictionary*)launchOptions  settings:(NSDictionary*)configSettings;
{
#if USE_URBAN_AIRSHIP
	//Init Airship launch options
	UAConfig* config = [UAConfig config];//[UAConfig defaultConfig];
	
	NSString* devAppKey = configSettings[kWRBConfKey_devAppKey];
	NSString* devAppSecret = configSettings[kWRBConfKey_devAppSecret];
	NSString* prodAppKey = configSettings[kWRBConfKey_prodAppKey];
	NSString* prodAppSecret = configSettings[kWRBConfKey_prodAppSecret];
	
	NSAssert(devAppKey != NULL, @"Invalid config settings for WRBNotifications.  Add app keys/secrets");
	NSAssert(devAppSecret != NULL, @"Invalid config settings for WRBNotifications.  Add app keys/secrets");
	NSAssert(prodAppKey != NULL, @"Invalid config settings for WRBNotifications.  Add app keys/secrets");
	NSAssert(prodAppSecret != NULL, @"Invalid config settings for WRBNotifications.  Add app keys/secrets");
	
	config.detectProvisioningMode = YES;
	config.developmentAppKey = devAppKey;
	config.developmentAppSecret = devAppSecret;
	config.productionAppKey = prodAppKey;
	config.productionAppSecret = prodAppSecret;
	
	config.automaticSetupEnabled = NO;
	
	WRInfoLog(@"Urban Airship Config, production=%@", config.inProduction ? @"yes" : @"no");
	
	
    // Create Airship singleton that's used to talk to Urban Airhship servers.
    // Please populate AirshipConfig.plist with your info from http://go.urbanairship.com
    // this prints, eg "Reachability Flag Status: -R -----l- networkStatusForFlags"
    [UAirship takeOff:config];
#endif
}
//===========================================================
- (void) stopPushNotificationSDK
{
#if USE_URBAN_AIRSHIP
	//[UAirship land];
#endif
}

//===========================================================
// call this to register device.  It may prompt the user
- (void) registerPushNotificationsWithBackend
{
	WRInfoLog(@"Registering push notifications with backend");
	
#if USE_URBAN_AIRSHIP
	// Register for notifications
	[[UAPush shared] registerForRemoteNotificationTypes:(UIRemoteNotificationType)(UIRemoteNotificationTypeBadge |
																				   UIRemoteNotificationTypeSound |
																				   UIRemoteNotificationTypeAlert)];
	
	// now update urban airship stuff
	[self updateUrbanAirshipTags];
#else
	[[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
#endif

	// register our own tags
	// locale, country, device type, monetizer, alias
}
//===========================================================
- (void) clearPushNotifications
{
#if USE_URBAN_AIRSHIP
	[[UAPush shared] resetBadge];

#endif
}
//===========================================================
- (void) updateUrbanAirshipTags
{
#if USE_URBAN_AIRSHIP
	NSArray* tags = [UATagUtils createTags:(UATagType)
                     (UATagTypeTimeZoneAbbreviation
                      | UATagTypeLanguage
                      | UATagTypeCountry
                      | UATagTypeDeviceType)];
    
    NSMutableArray* tagArray = [NSMutableArray arrayWithArray:tags];
	
	// monetizer?
	if([WRBackend sharedManager].mUser.isMonetizer) {
		[tagArray addObject:kSegment_monetizer];
	}
	else {
		[tagArray addObject:kSegment_nonmonentizer];
	}

    
    
    [UAPush shared].tags = tagArray;
    [[UAPush shared] addTagsToCurrentDevice:tagArray];
    
    // For urban airship, make the alias our user identifier
    NSString* userId = [WRBackend sharedManager].mUUID;
    if(![NSString isEmptyString:userId])
    {
        WRInfoLog(@"UA alias: %@", userId);
        [UAPush shared].alias = userId;
    }
    
	// quiet time
	NSDate* startQuiet = [NSDate dateWithHours:22 minutes:0 seconds:0];
	NSDate* endQuiet = [NSDate dateWithHours:8 minutes:0 seconds:0];
	
	[UAPush shared].quietTimeEnabled = TRUE;
    [[UAPush shared] setQuietTimeFrom:startQuiet to:endQuiet withTimeZone:[NSTimeZone localTimeZone]];
    
    // Update the urban airship settings
    [[UAPush shared] updateRegistration];
#endif
}

//===========================================================
- (void) handleDidRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
	WRInfoLog(@"Registered device token: %@", deviceToken);
	
#if USE_URBAN_AIRSHIP
	// Updates the device token and registers the token with UA
    //NOTE: the docs say to use the UAirship shared manager but this will overwrite any other info you set with UAPush.
	[[UAPush shared] registerDeviceToken:deviceToken];
	
#endif

	
}
//===========================================================
- (void) handleDidFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
	WRErrorLog(@"ERROR.  Failed to register for push notifications: %@", error);
}

//===========================================================
- (void) handleDidReceiveRemoteNotification:(NSDictionary*)userInfo
{
	
#if USE_URBAN_AIRSHIP
	// send info to urban airship to it can track conversions
	UIApplication* application = [UIApplication sharedApplication];
    [[UAPush shared] handleNotification:userInfo applicationState:application.applicationState];
#endif

	// save any analytics tracking info
	[self saveTrackingCode:userInfo];

	// open related apps
	[self openRelatedApp:userInfo];
	

}

//===========================================================
- (void) saveTrackingCode:(NSDictionary*)userInfo
{
	// don't track if already running
	UIApplication* application = [UIApplication sharedApplication];
	if(application.applicationState == UIApplicationStateActive) {
		WRDebugLog(@"got notification while running...Ignore tracking");
		return;
	}
	
	// handle it at the app level (e.g. track analytics)
	NSString* analyticsCode = @"";
	id idAnalyticsCode = [userInfo objectForKey:@"t"];
	if(!idAnalyticsCode) {
		WRErrorLog(@"Push error.  No analytics code");
		return;
	}
	
	// protect against bad tracking codes/user input errors
	if([idAnalyticsCode isKindOfClass:[NSString class]])
	{
		analyticsCode = (NSString*) idAnalyticsCode;
	}
	else if([idAnalyticsCode isKindOfClass:[NSNumber class]])
	{
		NSNumber* nItc = (NSNumber*) idAnalyticsCode;
		analyticsCode = [nItc stringValue];
	}
	else
	{
		WRErrorLog(@"Unrecognized analytics code type");
		return;
	}
	
	if([NSString isEmptyString:analyticsCode])
    {
		WRInfoLog(@"Empty tracking code");
		return;//EXIT
	}
	
#if USE_ANALYTICS
	// analytics
	[[AnalyticsHelper sharedManager] trackEventEx:kAnalEvent_pushNotificationResponse param1Name:@"trackcode" param1:analyticsCode];
#endif
	
	WRInfoLog(@"Got tracking code (%@) on push notification response", analyticsCode);
}

//===========================================================
- (void) openRelatedApp:(NSDictionary*)userInfo
{
	// don't if already running
	UIApplication* application = [UIApplication sharedApplication];
	if(application.applicationState == UIApplicationStateActive) {
		WRDebugLog(@"got notification while running...Ignore open app");
		return;
	}
	
	
	id appId = [userInfo objectForKey:@"a"];
	if(!appId) {
		WRErrorLog(@"No app code key in push");
		return;
	}
	
	// protect against bad app codes/user input errors
	NSString* appIdStr = @"";
	if([appId isKindOfClass:[NSNumber class]])
	{
		NSNumber* nAppIdStr = (NSNumber*) appId;
		appIdStr = [nAppIdStr stringValue];
	}
	else if([appId isKindOfClass:[NSString class]]) {
		appIdStr = (NSString*) appId;
	}
	else
	{
		WRErrorLog(@"Unrecognized data type for app id");
		return;
	}
	
	// open it
	WRDebugLog(@"Open app store id: %@", appIdStr);
	
	id del = [WRBackend sharedManager].delegate;
	if([del respondsToSelector:@selector(openAppStoreForId:)])
	{
		NSNumber* appIdNumber = @([appIdStr intValue]);	// yay boxing!
		[del openAppStoreForId:appIdNumber];
	}
}


#pragma mark - Local Notifications

//===========================================================
- (void) startLocalNotifications:(NSDictionary*)launchOptions
{
	// did we cold start from local notification?  If so track it
	// track local notifications and cleanup
    UILocalNotification* localNotif =  [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
	
	[self handleDidOpenFromLocalNotification:localNotif];
    
}
//===========================================================
#define TEST_PERIOD 0

- (void) createLocalNotifications
{
	NSDictionary* dataSource = [[WRBackend sharedManager].mAppConfig dictForKey:@"notifications"];
	
	// Create one of each definition/period
    NSArray* notifList = [dataSource objectForKey:@"definitions"];
    for(NSDictionary* elem in notifList)
    {
        NSNumber* nPeriod = [elem objectForKey:@"period"];
        float per = [nPeriod floatValue];
        per = per * (60 * 60);
		
#if DEBUG
	per = per / 3600; //1hr = 1sec
#endif
        
        NSArray* messageList = [elem objectForKey:@"items"];
        int count = (int) [messageList count];
        int index = RANDOM_INT(0,count-1);
        
        
        NSDictionary* notificationDef = [messageList objectAtIndex:index];
        
        NSString* message = [notificationDef objectForKey:@"message"];
        NSString* action = [notificationDef objectForKey:@"action"];
        NSString* trackingCode = [notificationDef objectForKey:@"tracking"];
		
		
        
		// and finally - make a local notification
        [self createLocalNotificationWithTime:per
									  message:message
                                         action:action
                                   trackingCode:trackingCode
                                     badgeCount:1];
    }
}
//===========================================================
- (void) cancelAllLocalNotifications
{
	[[UIApplication sharedApplication] cancelAllLocalNotifications];
}
//===========================================================
- (void) handleDidOpenFromLocalNotification:(UILocalNotification*)notification
{
	if(notification)
	{
		// get the tracking code from user info
		NSString* trackingCode = [notification.userInfo objectForKey:@"tracking"];
		
		if(trackingCode)
		{
			// track the action
#if USE_ANALYTICS
			// analytics
			[[AnalyticsHelper sharedManager] trackEventEx:kAnalEvent_localNotificationResponse param1Name:@"trackcode" param1:trackingCode];
#endif

		}
        
    }
	
	id del = [WRBackend sharedManager].delegate;
	id<WRBackendDelegate> theDelegate = (id<WRBackendDelegate>) [WRBackend sharedManager].delegate;

	
	// cancel notifications?
	BOOL shouldCancel = TRUE;
	
	if([del respondsToSelector:@selector(shouldCancelAllLocalNotifications)]) {
		shouldCancel = [theDelegate shouldCancelAllLocalNotifications];
	}
	
	// now cancel all local notifications
	if(shouldCancel) {
		[self cancelAllLocalNotifications];
	}
}

//===========================================================
- (void) createLocalNotificationWithTime:(NSTimeInterval)period
                                      message:(NSString*)message
                                    action:(NSString*)action
                              trackingCode:(NSString*)trackingCode
                                badgeCount:(int)badgeCount
{
    // get the best target date allowing for a quiet period
    NSTimeInterval reminderInterval = [self getReminderIntervalWithQuietPeriod:period];
    NSDate* targetDate = [NSDate dateWithTimeIntervalSinceNow:reminderInterval];
    
    // create the local notification
    UILocalNotification* localNotif = [[UILocalNotification alloc] init];
    NSAssert(localNotif != NULL, @"null local notification??");
	
	// format the body if the body has a name element
    //STRING - this is wholly un-il8ned
    if([message containsString:kToken_userFirstName])
    {
        NSString* firstName = [WRBackend sharedManager].mUser.firstName;
        if(![NSString isEmptyString:firstName])
        {
            message = [message stringByReplacingOccurrencesOfString:kToken_userFirstName withString:firstName];
        }
        else
        {
            // strip out __NAME__ and punctuation.
			//NOTE that the order of ops is important (w.r.t. spaces trailing leading)
            message = [message stringByReplacingOccurrencesOfString:@"__USER__, " withString:@""];	// no trail space
            message = [message stringByReplacingOccurrencesOfString:@"__USER__," withString:@""];    // with trailing space
			message = [message stringByReplacingOccurrencesOfString:@"__USER__! " withString:@""];	// no trail space
            message = [message stringByReplacingOccurrencesOfString:@"__USER__!" withString:@""];    // with trailing space
			message = [message stringByReplacingOccurrencesOfString:@"__USER__. " withString:@""];	// no trail space
            message = [message stringByReplacingOccurrencesOfString:@"__USER__." withString:@""];    // with trailing space
			
            message = [message stringByReplacingOccurrencesOfString:@", __USER__" withString:@""]; // with leading space
            message = [message stringByReplacingOccurrencesOfString:@",__USER__" withString:@""];	// no leading space
            
            // capitalize the first letter if still lower case
            if([[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:[message characterAtIndex:0]])
            {
                message = [message stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[message substringToIndex:1] capitalizedString]];
            }
            
        }
    }
	
	WRDebugLog(@"Creating Local Notification (%@): %@", targetDate,message);

	// now build the uilocalnotification
    localNotif.fireDate = targetDate;
#ifndef ANDROID
    localNotif.timeZone = [NSTimeZone defaultTimeZone];
#endif
    localNotif.alertBody = message;
    localNotif.alertAction = action;
    localNotif.soundName = NULL;
    localNotif.applicationIconBadgeNumber = badgeCount;
    
    NSDictionary* infoDict = [NSDictionary dictionaryWithObject:trackingCode forKey:@"tracking"];
    localNotif.userInfo = infoDict;
    
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotif];
	

}
//===========================================================
- (NSTimeInterval) getReminderIntervalWithQuietPeriod:(NSTimeInterval)curInterval
{
    NSTimeInterval retInterval = curInterval;
    
    NSDate* targetDate = [NSDate dateWithTimeIntervalSinceNow:curInterval];
    
    // get date/time components
    NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents* timeComponents = [cal components:(NSHourCalendarUnit) fromDate:targetDate];
    
    NSInteger hour = [timeComponents hour];
    NSTimeInterval deltaInterval = 0;
	
    if(hour >= kNotif_startQuietPeriod) {
        deltaInterval = (24 - hour) + kNotif_startQuietPeriod;
    }
    if(hour <= kNotif_endQuietPeriod)  {
        deltaInterval = (kNotif_endQuietPeriod - hour);
    }
    
    
    deltaInterval = deltaInterval * 60 * 60;
	
    retInterval += deltaInterval;
    
    return retInterval;
}


@end
