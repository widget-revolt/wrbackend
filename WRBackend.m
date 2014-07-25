//
//  WRBackend.m
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



#import "WRBackend.h"
#import "WRBackendConst.h"
#import "WRBHttpClient.h"
#import "WRBLeaderboard.h"
#import "WRBPromoBanners.h"


#import "AnalyticsHelper.h"
#import "WRLib.h"
#import "WRUUID.h"

#if WRB_USE_AFNETWORKING20
	//void
#else
	#import "AFJSONRequestOperation.h"
#endif

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif



#define kPrefBackend_lastSessionEnd		@"com.wrbackend.last_session_end"
#define kPrefBackend_launchCount		@"com.wrbackend.launch_count"
#define kPrefBackend_activationCount	@"com.wrbackend.activation_count"
#define kPrefBackend_sessionCount		@"com.wrbackend.session_count"
#define kPrefBackend_installDate		@"com.wrbackend.install_date"

const NSTimeInterval kWRBackend_defaultSessionTimeout = (30.0f * 60.0f);	//thirty minutes session timeout
const int kWRBackend_defaultSessionsUntilPush = 2;

//////////////////////////////////////////////////////////////////
@interface WRBackend ()

@property (nonatomic, strong, readwrite) NSString* mUUID;
@property (nonatomic, strong, readwrite) NSString* mUUIDHash;
@property (nonatomic, strong, readwrite) NSString* mODIN;
@property (nonatomic, strong, readwrite) NSString* mAppId;

@property (nonatomic, strong) NSString* mServerAddress;
@property (nonatomic, strong) NSString* mProtocol;	//http, https
@property (nonatomic, strong) NSString* mAppUrlPrefix; /// used to construct urls e.g. if appname=foo, then url will be /foo/register_user

@property (nonatomic, retain, readwrite) WRBUser* mUser;
@property (nonatomic, retain, readwrite) WRBAppConfig* mAppConfig;
@property (nonatomic, retain, readwrite) WRBNotifications* mNotifications;
@property (nonatomic, retain, readwrite) WRBWallet* mWallet;
@property (nonatomic, retain, readwrite) WRBLeaderboard* mLeaderboard;
@property (nonatomic, retain, readwrite) WRBPromoBanners* mPromoBanners;
@property (nonatomic, strong, readwrite) NSMutableDictionary* mUserAuxInfo;

// config props
@property (nonatomic, assign) NSTimeInterval	mSessionTimeout;
@property (nonatomic, assign) int mSessionsToPush;

// state props
@property (nonatomic, strong, readwrite) NSDate* mInstallDate;
@property (nonatomic, assign, readwrite) BOOL mRegistered;
@property (nonatomic, assign, readwrite) int	mLaunchCount;
@property (nonatomic, assign, readwrite) int mActivationCount;	// # of times user has activated app
@property (nonatomic, assign, readwrite) int mSessionCount;
@end

//////////////////////////////////////////////////////////////////
@implementation WRBackend

//===========================================================
+ (WRBackend*) sharedManager
{
	static WRBackend* _sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[WRBackend alloc] init];
    });
    
    return _sharedClient;
}

//===========================================================
- (id) init
{
	self = [super init];
	if(self)
	{
		_mRegistered = FALSE;
	
		self.mProtocol = @"http://";
		self.mServerAddress = @"localhost:8080";
		self.mAppUrlPrefix = @"SET THE APP URL";
		self.mAppId = @"";
		
		self.mUUID = @"";
		self.mUUIDHash = @"";
		self.mODIN = @"";
		self.mInstallDate = [NSDate date];
		
		// props
		self.mSessionTimeout = kWRBackend_defaultSessionTimeout;
		self.mSessionsToPush = kWRBackend_defaultSessionsUntilPush;
		
		// default obj alloc
		self.mUser = [[WRBUser alloc] init];	// uninitialized user
		self.mAppConfig = [[WRBAppConfig alloc] init];
		self.mNotifications = [[WRBNotifications alloc] init];
		self.mUserAuxInfo = [NSMutableDictionary dictionary];
		self.mLeaderboard = [[WRBLeaderboard alloc] init];
		self.mPromoBanners = [[WRBPromoBanners alloc] init];
	
		// create a uuid right now
		[WRUUID createUUIDWithSalt:kUUIDSalt];
		
		self.mUUID = [WRUUID getAppUUID];
		self.mUUIDHash = [WRUUID getAppUUIDHash];
		self.mODIN = [WRSystemInfo getODIN];
		
		// initialize our launch and activation counts
		NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		self.mLaunchCount = (int) [defaults integerForKey:kPrefBackend_launchCount];
		self.mActivationCount = (int) [defaults integerForKey:kPrefBackend_activationCount];
		self.mSessionCount = (int) [defaults integerForKey:kPrefBackend_sessionCount];
	}
	
	return self;
}
//===========================================================
- (void) debugReset
{
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kPrefBackend_launchCount];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kPrefBackend_activationCount];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kPrefBackend_sessionCount];
	
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kPref_userIsMonetized];
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	_mLaunchCount = 0;
	_mActivationCount = 0;
	self.mSessionCount = 0;
}

#pragma mark - App lifecycle
//===========================================================
- (void) registerBackend:(NSString*)protocol
				  server:(NSString*)server
			appUrlPrefix:(NSString*)appUrlPrefix
				   appId:(NSString*)appId
				delegate:(id<WRBackendDelegate>)delegate
				settings:(NSDictionary*)settings
		   launchOptions:(NSDictionary*)launchOptions
{
	self.delegate = delegate;
	
	// tell our app config to reload
	[_mAppConfig onRegisterBackend:launchOptions];

	// save our install date if missing
	NSDate* installDate = [[NSUserDefaults standardUserDefaults] objectForKey:kPrefBackend_installDate];
	if(!installDate)
	{
		installDate = [NSDate date];
	
		[[NSUserDefaults standardUserDefaults] setObject:installDate forKey:kPrefBackend_installDate];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	self.mInstallDate = installDate;

	// set our esrver location
	self.mProtocol = protocol;
	self.mServerAddress = server;
	self.mAppUrlPrefix = appUrlPrefix;
	self.mAppId = appId;
	
	[WRBHttpClient setProtocol:protocol address:server];
	
	// modify any custom settings
	// @"session_timeout" (value in minutes)
	[self initUserSettings:settings];
	
	// initialize an http client
	[WRBHttpClient sharedManager];
	
	// initialize notifications
	[_mNotifications startLocalNotifications:launchOptions];
	[_mNotifications startPushNotificationSDK:launchOptions settings:settings];
	
	// initialize the wallet
	NSDictionary* defaultBalances = [delegate getWalletDefaultBalances];
	NSAssert(defaultBalances, @"You must implement WRBackendDelegate#getWalletDefaultBalances");
	
	
	
	NSString* walletSalt = settings[kWRBConfKey_walletSalt];
	if(!walletSalt) {
		WRDebugLog(@"Using default salt.  Consider making your own");
		walletSalt = @"a%dbcdef%dg%@hi";
	}
	self.mWallet = [[WRBWallet alloc] initWithDefaultBalances:defaultBalances salt:walletSalt];
	
	// call any "plugins"
	[_mLeaderboard backendDidRegister:settings];
	[_mPromoBanners backendDidRegister:settings];
	
	
	// and see if we have any tasks to perform
	[self handleAppDidLaunch];

}
//===========================================================
- (void) initUserSettings:(NSDictionary*)settings
{
	NSNumber* nSessionTimeout = settings[kWRBConfKey_sessionTimeout];
	if(nSessionTimeout)
	{
		float sessionTimeout = [nSessionTimeout floatValue];
		sessionTimeout *= 60.0f;
		self.mSessionTimeout = sessionTimeout;
	}
	
	NSNumber* nSessionToPush = settings[kWRBConfKey_sessionsToPush];
	if(nSessionToPush)
	{
		float sessionsToPush = [nSessionToPush floatValue];
		self.mSessionsToPush = sessionsToPush;
	}
	
}
//===========================================================
- (BOOL) isNewSession
{
	NSDate* now = [NSDate date];
	NSDate* lastSessionEnd = [[NSUserDefaults standardUserDefaults] objectForKey:kPrefBackend_lastSessionEnd];
	if(!lastSessionEnd)
	{
		[[NSUserDefaults standardUserDefaults] setObject:now forKey:kPrefBackend_lastSessionEnd];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
		return TRUE;
	}
	
	NSTimeInterval deltaTime = [now timeIntervalSinceDate:lastSessionEnd];
	if(deltaTime >= _mSessionTimeout) {
		return TRUE;
	}
	
	return FALSE;
}
//===========================================================
- (void) handleAppDidLaunch
{
	// update our launch count
	_mLaunchCount++;
	[[NSUserDefaults standardUserDefaults] setInteger:_mLaunchCount forKey:kPrefBackend_launchCount];
	[[NSUserDefaults standardUserDefaults] synchronize];

//	if([self isNewSession])
//	{
//		[self handleNewSession];
//	}

	
}
//===========================================================
- (void) handleAppDidBecomeActive
{
	// update our activation count
	_mActivationCount++;
	[[NSUserDefaults standardUserDefaults] setInteger:_mLaunchCount forKey:kPrefBackend_activationCount];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	// notifications
	[_mNotifications cancelAllLocalNotifications];
	[_mNotifications clearPushNotifications];
	
	// session?
	if([self isNewSession]) {
		[self handleNewSession];
	}
	
	// call any "plugins"
	[_mLeaderboard appDidBecomeActive];
	[_mPromoBanners appDidBecomeActive];
	
}

//===========================================================
- (void) handleNewSession
{
	// save the session count
	_mSessionCount++;
	[[NSUserDefaults standardUserDefaults] setInteger:_mSessionCount forKey:kPrefBackend_sessionCount];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	// delegate
	id del = _delegate;
	if([del respondsToSelector:@selector(didStartNewSession:)])
	{
		[_delegate didStartNewSession:_mSessionCount];
	}


	// push notification register
	//NOTE: this is hard coded to 2 activatinos for now
	if(_mSessionCount >= _mSessionsToPush)
	{
		[_mNotifications registerPushNotificationsWithBackend];
		
	}

}
//===========================================================
- (void) handleAppWillResignActive
{
	NSDate* now = [NSDate date];
	[[NSUserDefaults standardUserDefaults] setObject:now forKey:kPrefBackend_lastSessionEnd];
	[[NSUserDefaults standardUserDefaults] synchronize];

	// call any "plugins"
	[_mLeaderboard appWillResignActive];
	[_mPromoBanners appWillResignActive];

	// make our local notifications now
	[_mNotifications createLocalNotifications];
	
	
}

//===========================================================
- (void) handleAppWillTerminate
{
	[_mNotifications stopPushNotificationSDK];
}
//===========================================================
- (void) handleDidReceiveLocalNotification:(UILocalNotification*)notif
{
	[_mNotifications handleDidOpenFromLocalNotification:notif];
}
//===========================================================
- (void) handleDidRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
	[_mNotifications handleDidRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
	
	// register the device on success or failure here
	[self registerDevice:deviceToken];
}
//===========================================================
- (void) handleDidFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
	[_mNotifications handleDidFailToRegisterForRemoteNotificationsWithError:error];
	
	// register the device on success or failure here
	[self registerDevice:NULL];
}
//===========================================================
- (void) handleDidReceiveRemoteNotification:(NSDictionary*)userInfo
{
	[_mNotifications handleDidReceiveRemoteNotification:userInfo];
}

#pragma mark - User Aux Info

//===========================================================
- (void) setUserAuxInfo:(NSDictionary*)infoDict
{
	self.mUserAuxInfo = [NSMutableDictionary dictionaryWithDictionary:infoDict];
	
	//?? send out a notification?
}
//===========================================================
- (id) getAppUserInfoObjectForKey:(NSString*)key
{
	id obj = [_mUserAuxInfo objectForKey:key];
	return obj;
}
//===========================================================
- (int) getAppUserInfoIntForKey:(NSString*)key default:(int)defaultInt
{
	int retValue = defaultInt;
	
	id obj = _mUserAuxInfo[key];
	if(obj) {
		retValue = [(NSNumber*)obj intValue];
	}
	return retValue;
}
//===========================================================
- (double) getAppUserInfoDoubleForKey:(NSString*)key default:(double)defaultVal
{
	double retValue = defaultVal;
	
	id obj = _mUserAuxInfo[key];
	if(obj) {
		retValue = [(NSNumber*)obj doubleValue];
	}
	return retValue;
}
//===========================================================
- (void) setAppUserInfoObject:(id)object forKey:(NSString*)key
{
	_mUserAuxInfo[key] = object;
}

#pragma mark - Utils
//===========================================================
- (NSString*) getProtocol
{
	return _mProtocol;
}
//===========================================================
- (NSString*) getServer
{
	return _mServerAddress;	
}
//===========================================================
- (NSString*) getAppUrlPrefix
{
	return _mAppUrlPrefix;
}
//===========================================================
- (NSString*) createApiUrl:(NSString*)basePath
{
	NSString* retStr = [NSString stringWithFormat:@"/%@%@", _mAppUrlPrefix, basePath];
	return retStr;
}
//===========================================================
- (NSString*) safeStringParam:(NSString*)s
{
	NSString* retVal = s;
	if([NSString isEmptyString:s]) {
		retVal = @"";
	}
	
	return retVal;
}

#pragma mark - API calls

//===========================================================
- (void) registerUser
{
	WRDebugLog(@"WRBackend /register_user");
	
	
	NSString* asid = @"";
	NSString* platform;
	NSString* osVersion = @"";
	NSString* deviceName = @"";
	NSString* idfvString = @"";
	NSDictionary* carrierInfo = @{
								  @"carrier": @"",
								  @"mcc":@"",
								  @"mnc":@""
								  };
	
	
	asid = [WRSystemInfo getAdvertiserId];
	platform = @"ios";
	osVersion = [UIDevice currentDevice].systemVersion;
	deviceName = [UIDevice currentDevice].model;
	
	carrierInfo = [WRSystemInfo getCarrierInfo];
	NSUUID* identifierForVendor = [UIDevice currentDevice].identifierForVendor;
	idfvString = [identifierForVendor UUIDString];
	
	
	NSDictionary* paramDict = @{
								@"uuid": _mUUID,
								@"auth": _mUUIDHash,
								@"odin": _mODIN,
								@"asid": asid,
								@"idfv": idfvString,
								
								@"platform": platform,
								@"osvers": osVersion,
								@"device": deviceName,
								
								@"fbid": _mUser.facebookId,
								@"fname": _mUser.firstName,
								@"lname": _mUser.lastName,
								@"email": _mUser.emailAddress,
								@"age_range": _mUser.ageRange,
								@"gender": _mUser.gender,
								@"locale": _mUser.locale,
								@"birthday": _mUser.birthday,
								
								@"carrier": carrierInfo[@"carrier"],
								@"mcc": carrierInfo[@"mcc"],
								@"mnc": carrierInfo[@"mnc"],
								
								@"gc_id": _mUser.gamecenterId,
								@"gc_alias": _mUser.gamecenterAlias,
								};
	
	BOOL alreadyRegistered = self.mRegistered;	// save this for delegate.  We might just be updating user info
	
	__weak __typeof__(self) bself = self;
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlStr = [self createApiUrl:kBackendAPI_registerUser];
#if WRB_USE_AFNETWORKING20
	[httpClient POST:urlStr parameters:paramDict
			 success:^(AFHTTPRequestOperation *operation, id responseObject)
	
#else
	 [httpClient postPath:urlStr parameters:paramDict
				  success:^(AFHTTPRequestOperation *operation, id responseObject)
#endif
	
	 {
		 NSDictionary* jsonDict = (NSDictionary*) responseObject;
		 
		 // check for error
		 NSString* result = jsonDict[@"result"];
		 if(![result isEqualToString:@"ok"])
		 {
			 WRDebugLog(@"Error in register_user: %@", result);
			 if(_delegate) {
				 [_delegate didCompleteRegistration:TRUE alreadyRegistered:alreadyRegistered];
			 }
			 
			 // nsnotification
			 NSDictionary* userInfo = @{ @"already_registered": @(alreadyRegistered) };
			 [[NSNotificationCenter defaultCenter] postNotificationName:kNotification_wrBackendDidRegister
																 object:NULL
															   userInfo:userInfo];
			 
			 return;//exit
		 }
		 
		 
		 WRDebugLog(@"User registered: %@", jsonDict);
		 
		 //-- config data
		 NSDictionary* configData = jsonDict[@"data"];
		 if(configData)  {
			 // save the data to the app config
			 [_mAppConfig updateVolatileAppConfigWithDict:configData];
		 }
		 
		 //-- user aux info
		 NSDictionary* userAuxInfo = configData[@"_client_user"];
		 if(userAuxInfo) {
			 [bself setUserAuxInfo:userAuxInfo];
		 }
		 
		 //--other plugins...this is optional so if we turn this into plugin, then we need to check plugin support for method
		 [_mPromoBanners backendUserDidRegister:configData];

		 
		 
		 _mRegistered = TRUE;
		 
		 if(_delegate)
		 {
			 [_delegate didCompleteRegistration:TRUE alreadyRegistered:alreadyRegistered];
			 
			 // nsnotification
			 NSDictionary* userInfo = @{ @"already_registered": @(alreadyRegistered) };
			 [[NSNotificationCenter defaultCenter] postNotificationName:kNotification_wrBackendDidRegister
																 object:NULL
															   userInfo:userInfo];
		 }
		 
	 }
				 failure:^(AFHTTPRequestOperation *operation, NSError *error)
	 {
		 WRErrorLog(@"Error registering user: %@", error);
		 
		 // analytics
		 NSString* exceptionStr = [NSString stringWithFormat:@"WRBackend registration error: %@", error];
		 [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
		 
		 if(_delegate) {
			 [_delegate didCompleteRegistration:FALSE alreadyRegistered:alreadyRegistered];
		 }
		 
		 
		 
		 // operation self releases
	 }
	 ];
}

//===========================================================
- (void) addInstallTrackerInfo:(NSString*)trackerId trackerName:(NSString*)trackerName referrer:(NSString*)referrer ip:(NSString*)ip callback:(WRBackendAppHttpResultBlock)callback
{
	WRDebugLog(@"WRBackend /add_user_install_info");
	

	
	NSDictionary* paramDict = @{
								@"uuid": _mUUID,
								@"auth": _mUUIDHash,
								@"odin":@"",
								@"asid": @"",
								@"install_tracker_id": trackerId,
								@"install_tracker_name": trackerName,
								@"install_referrer": referrer,
								@"install_referrer_ip": ip,
								};
	
	
	///__weak __typeof__(self) bself = self;
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlPath = [[WRBackend sharedManager] createApiUrl:kBackendAPI_addUserInstallInfo];
#if WRB_USE_AFNETWORKING20
	[httpClient POST:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#else
	[httpClient postPath:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#endif
	 {
		 NSDictionary* jsonDict = (NSDictionary*) responseObject;
		 
		 // check for error
		 NSString* result = jsonDict[@"result"];
		 if(![result isEqualToString:@"ok"])
		 {
			 WRDebugLog(@"Error addInstallTrackerInfo: %@", result);
			 
			 callback(FALSE, NULL);
			 
			 return;
		 }
		 
		 // success callback
		 callback(TRUE, NULL);
		 
		 
	 }
	 failure:^(AFHTTPRequestOperation *operation, NSError *error)
	 {
		 WRErrorLog(@"Error addInstallTrackerInfo: %@", error);
		 
		 callback(FALSE, error);
		 
		 // analytics
		 NSString* exceptionStr = [NSString stringWithFormat:@"WRBackend addInstallTrackerInfo error: %@", error];
		 [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
		 
		 
		 // operation self releases
	 }];
}
//===========================================================
//params["uuid"],
//params["device_id"],
//params["apns_token"],
//params["language"],
//params["country"],
//
//params["time_zone"],
//params["platform"],
//params["osvers"],
//params["device"],
//params["carrier"],
//
//params["mcc"],
//params["mnc"],
//params["imei"]
- (void) registerDevice:(NSData*)deviceToken
{
	
	WRDebugLog(@"WRBackend /register_device");
	
	
	NSString* platform;
	NSString* osVersion = @"";
	NSString* deviceName = @"";
	NSString* idfvString = @"";
	NSDictionary* carrierInfo = @{
								  @"carrier": @"",
								  @"mcc":@"",
								  @"mnc":@""
								  };
	
	
	platform = @"ios";
	osVersion = [UIDevice currentDevice].systemVersion;
	deviceName = [UIDevice currentDevice].model;
	
	carrierInfo = [WRSystemInfo getCarrierInfo];
	NSUUID* identifierForVendor = [UIDevice currentDevice].identifierForVendor;
	idfvString = [identifierForVendor UUIDString];
	
	
	NSString* apnsToken = @"";
	if(deviceToken) {
		apnsToken = [deviceToken stringWithHexBytes];
	}
	
	NSLocale* currentLocale = [NSLocale currentLocale];  // get the current locale.
	NSString* countryCode = [currentLocale objectForKey:NSLocaleCountryCode];
	NSString* languageCode = [currentLocale objectForKey:NSLocaleLanguageCode];
	
	NSTimeZone* tz = [NSTimeZone localTimeZone];
	NSInteger tzOffset = [tz secondsFromGMT];
	long hoursFromGMT = tzOffset / (60 * 60);
	
	NSDictionary* paramDict = @{
								@"auth": _mUUIDHash,
								
								@"uuid": _mUUID,
								@"device_id": idfvString,
								@"apns_token": apnsToken,
								@"language": languageCode,
								@"country": countryCode,
								
								@"time_zone": @(hoursFromGMT),
								@"platform": platform,
								@"osvers": osVersion,
								@"device": deviceName,
								@"carrier": carrierInfo[@"carrier"],
								
								@"mcc": carrierInfo[@"mcc"],
								@"mnc": carrierInfo[@"mnc"],
								@"imei": @""
								};
	
	//__weak __typeof__(self) bself = self;
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlStr = [self createApiUrl:kBackendAPI_registerDevice];
#if WRB_USE_AFNETWORKING20
	[httpClient
	 POST:urlStr
	 parameters:paramDict
	 success:^(AFHTTPRequestOperation *operation, id responseObject)
#else
	[httpClient
	 postPath:urlStr
	 parameters:paramDict
	 success:^(AFHTTPRequestOperation *operation, id responseObject)
#endif
	 {
		 NSDictionary* jsonDict = (NSDictionary*) responseObject;
		 
		 // check for error
		 NSString* result = jsonDict[@"result"];
		 if(![result isEqualToString:@"ok"])
		 {
			 WRDebugLog(@"Error in register_device: %@", result);
			 return;
		 }
		 
		 
	 }
	 failure:^(AFHTTPRequestOperation *operation, NSError *error)
	 {
		 WRErrorLog(@"Error registering device: %@", error);
		 
		 // analytics
		 NSString* exceptionStr = [NSString stringWithFormat:@"WRBackend register device error: %@", error];
		 [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
		 
		 
		 // operation self releases
	 }];
}

//===========================================================
- (void) saveAppUserInfo:(WRBackendAppHttpResultBlock)callback
{

	if(!self.mRegistered)
	{
		WRErrorLog(@"Cannot save app user info until registered.  Ignoring...");
		callback(FALSE, NULL);
		return;
	}

	// convert the app info to json
	NSString* jsonString = [NSJSONSerialization stringWithJSONObject:_mUserAuxInfo options:0];
	
	NSDictionary* paramDict = @{
								@"auth": _mUUIDHash,
								
								@"uuid": _mUUID,
								@"document": jsonString
								};
	
	//__weak __typeof__(self) bself = self;
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlPath = [[WRBackend sharedManager] createApiUrl:kBackendAPI_setAppUserInfo];
#if WRB_USE_AFNETWORKING20
	[httpClient
	 POST:urlPath
	 parameters:paramDict
	 success:^(AFHTTPRequestOperation *operation, id responseObject)
#else
	[httpClient
	 postPath:urlPath
	 parameters:paramDict
	 success:^(AFHTTPRequestOperation *operation, id responseObject)
#endif
	 {
		 NSDictionary* jsonDict = (NSDictionary*) responseObject;
		 
		 // check for error
		 NSString* result = jsonDict[@"result"];
		 if(![result isEqualToString:@"ok"])
		 {
			 WRDebugLog(@"Error saving appUserInfo: %@", result);
			 
			 callback(FALSE, NULL);
			 
			 return;
		 }
		 
		 // success callback
		 callback(TRUE, NULL);
		 
		 
	 }
	 failure:^(AFHTTPRequestOperation *operation, NSError *error)
	 {
		 WRErrorLog(@"Error saving appUserInfo: %@", error);
		 
		 callback(FALSE, error);
		 
		 // analytics
		 NSString* exceptionStr = [NSString stringWithFormat:@"WRBackend saveAppUserInfo error: %@", error];
		 [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
		 
		 
		 // operation self releases
	 }];
}



//===========================================================
// lookup url = @"http://itunes.apple.com/lookup?id=%d"
- (void) checkForAppUpdate:(WRBackendAppUpdateBlock)callback
{
	NSString* baseURLStr = @"http://itunes.apple.com";
///self.mAppId = @"384321301";
	NSString* urlStr = [NSString stringWithFormat:baseURLStr, _mAppId];
	NSURL* baseUrl = [NSURL URLWithString:urlStr];

	// query the apple server
#if WRB_USE_AFNETWORKING20
	AFHTTPRequestOperationManager* httpClient = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:baseUrl];
#else

	AFHTTPClient* httpClient = [[AFHTTPClient alloc] initWithBaseURL:baseUrl];
	[httpClient registerHTTPOperationClass:[AFJSONRequestOperation class]];
	[httpClient setDefaultHeader:@"Accept" value:@"application/json"];
#endif
	
	NSDictionary* paramDict = @{ @"id": _mAppId };

#if WRB_USE_AFNETWORKING20
	[httpClient GET:@"/lookup"
		 parameters:paramDict
			success:^(AFHTTPRequestOperation *operation, id jsonObj)
#else
	[httpClient getPath:@"/lookup"
			 parameters:paramDict
				success:^(AFHTTPRequestOperation *operation, id jsonObj)
#endif
		{
			NSDictionary* jsonDict = (NSDictionary*) jsonObj;
			WRInfoLog(@"jsonDict on app update check = %@", jsonDict);
			
			NSArray* results = [jsonDict objectForKey:@"results"];
			if([results count] == 0)
			{
				if(callback) {
					callback(FALSE);
				}
				return;
			}
			
			NSDictionary* firstResult = [results objectAtIndex:0];
			NSString* remoteVersion = [firstResult objectForKey:@"version"];
			if(!remoteVersion)
			{
				if(callback) {
					callback(FALSE);
				}
				return;
			}
			
			NSString* myVersion =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
///myVersion = @"1.1";
		
			BOOL retVal = [myVersion isLessThanVersionString:remoteVersion];
			WRInfoLog(@"My Version: %@, Remote Version: %@, upgrade?: %@", myVersion, remoteVersion, retVal ? @"yes":@"no");
			if(callback) {
				callback(retVal);
			}
			
		}
		failure:^(AFHTTPRequestOperation *operation, NSError *error)
		{
			WRErrorLog(@"Failed to check iTunes for app update");
			WRErrorLog(@"Error=%@", error);
			
			if(callback) {
				callback(FALSE);
			}
		}];
}


//===========================================================
// errors are deliberately opaque
- (void) submitCoupon:(NSString*)couponStr tickcountSalt:(int)tickcountSalt callback:(WRBackendResultBlock)callback
{
	NSString* uuid = [self safeStringParam:_mUUID];
	NSString* uuidHash = [self safeStringParam:_mUUIDHash];
	NSDictionary* paramDict = @{
								@"uuid": uuid,
								@"auth": uuidHash,
								@"coupon_code":couponStr,
								@"tickcount": @(tickcountSalt)
								};
	
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlPath = [[WRBackend sharedManager] createApiUrl:kBackendAPI_redeemCoupon];

#if WRB_USE_AFNETWORKING20
	[httpClient POST:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#else
	[httpClient postPath:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#endif
	 {
		 NSDictionary* jsonDict = (NSDictionary*) responseObject;
		 
		 // check for error
		 NSString* result = jsonDict[@"result"];
		 if(![result isEqualToString:@"ok"])
		 {
			 WRDebugLog(@"Error in redeem_coupon: %@", result);
			 callback(eResultErr_genericError, result);
			 return;
		 }
		 
		 WRDebugLog(@"Coupon redeemed: %@", jsonDict);
		 
		 NSDictionary* data = jsonDict[@"data"];
		 if(!data) {
			 WRDebugLog(@"Invalid JSON. No data.");
			 callback(eResultErr_genericError, result);
			 return;
		 }
		 
		 NSString* checksum = data[@"checksum"];
		 if(!checksum)
		 {
			 WRDebugLog(@"Invalid JSON. No checksum.");
			 callback(eResultErr_genericError, result);
			 return;
		 }
		 
		 // callback with the checksum
		 callback(eResultErr_ok, checksum);
		 
	 }
				 failure:^(AFHTTPRequestOperation *operation, NSError *error)
	 {
		 WRErrorLog(@"Error submitting coupon: %@", error);
		 
		 callback(eResultErr_httpFailure, error);
		 
		 // operation self releases
	 }
	 ];
	
}


//===========================================================
- (void) getAvailableFacebookGifts:(WRBackendAppHttpResultBlock)callback
{
	// must be registered
	if(!self.mRegistered)
	{
		WRErrorLog(@"Cannot getAvailableFacebookGifts info until registered.  Ignoring...");
		callback(FALSE, NULL);
		return;
	}
	
	// must have a facebook id or else nothing
	if([NSString isEmptyString:self.mUser.facebookId]) {
		WRErrorLog(@"Cannot getAvailableFacebookGifts no fbid.  Ignoring...");
		callback(FALSE, NULL);
		return;
	}
	

	
	// params
	NSDictionary* paramDict = @{
								@"auth": _mUUIDHash,

								@"uuid": _mUUID,
								@"user_social_id": self.mUser.facebookId
								};
	
	//__weak __typeof__(self) bself = self;
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlPath = [[WRBackend sharedManager] createApiUrl:kBackendAPI_getFacebookGifts];

#if WRB_USE_AFNETWORKING20
	[httpClient POST:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#else
	[httpClient postPath:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#endif
	 {
		 NSDictionary* jsonDict = (NSDictionary*) responseObject;
		 
		 // check for error
		 NSString* result = jsonDict[@"result"];
		 if(![result isEqualToString:@"ok"])
		 {
			 WRDebugLog(@"Error getting fb gifts: %@", result);
			 
			 callback(FALSE, NULL);
			 
			 return;
		 }
		 
		 // save the data
		 NSArray* giftArray = jsonDict[@"data"];
		 [_mUser setAvailableGifts:giftArray];

		 // success callback
		 callback(TRUE, NULL);
		 
	 }
	 failure:^(AFHTTPRequestOperation *operation, NSError *error)
	 {
		 WRErrorLog(@"Error getting fb gifts: %@", error);
		 
		 callback(FALSE, error);
		 
		 // analytics
		 NSString* exceptionStr = [NSString stringWithFormat:@"WRBackend getAvailableFacebookGifts error: %@", error];
		 [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
		 
		 
		 // operation self releases
	 }];
}

//===========================================================
//"user_social_id",
//"fb_id_list",
//"request_type"
- (void) sendFacebookGifts:(NSArray*)friendList requestType:(NSString*)requestType callback:(WRBackendResultBlock)callback
{
	// must be registered
	if(!self.mRegistered)
	{
		WRErrorLog(@"Cannot sendFacebookGifts info until registered.  Ignoring...");
		callback(eResultErr_genericError, NULL);
		return;
	}
	
	// must have a facebook id or else nothing
	if([NSString isEmptyString:self.mUser.facebookId]) {
		WRErrorLog(@"Cannot sendFacebookGifts no fbid.  Ignoring...");
		callback(eResultErr_genericError, NULL);
		return;
	}
	
	// params
	
	NSString* friendIdListStr = [friendList componentsJoinedByString:@","];
	NSDictionary* paramDict = @{
								@"auth": _mUUIDHash,
								@"uuid": _mUUID,
								
								@"user_social_id": self.mUser.facebookId,
								@"fb_id_list": friendIdListStr,
								@"request_type": requestType,
								@"fname": self.mUser.firstName,
								@"lname": self.mUser.lastName,
								};
	
	//__weak __typeof__(self) bself = self;
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlPath = [[WRBackend sharedManager] createApiUrl:kBackendAPI_sendFacebookGifts];
#if WRB_USE_AFNETWORKING20
	[httpClient POST:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#else
	[httpClient postPath:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#endif
		 {
			 NSDictionary* jsonDict = (NSDictionary*) responseObject;
			 
			 // check for error
			 NSString* result = jsonDict[@"result"];
			 if(![result isEqualToString:@"ok"])
			 {
				 WRDebugLog(@"Error sending fb gifts: %@", result);
				 
				 callback(eResultErr_invalidResult, result);
				 
				 return;
			 }
			 
			 // save the data - will look something like this:
//			 {
//				 "gifts_sent" = 2;
//				 "gifts_sent_to_friend_ids" =         (
//													   100008173900213,
//													   100003956314036
//													   );
//			 };
			 NSDictionary* resultData = jsonDict[@"data"];
			 
			 // success callback
			 callback(eResultErr_ok, resultData);
			 
			 
		 }
		 failure:^(AFHTTPRequestOperation *operation, NSError *error)
		 {
			 WRErrorLog(@"Error getting fb gifts: %@", error);
			 
			 callback(eResultErr_httpFailure, error);
			 
			 // analytics
			 NSString* exceptionStr = [NSString stringWithFormat:@"WRBackend sendFacebookGifts error: %@", error];
			 [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
			 
			 
			 // operation self releases
		 }];

}

//===========================================================
- (void) claimFacebookGiftsForRequestType:(NSArray*)requestTypeList callback:(WRBackendResultBlock)callback
{
	// must be registered
	if(!self.mRegistered)
	{
		WRErrorLog(@"Cannot claimFacebookGiftsForRequestType info until registered.  Ignoring...");
		callback(eResultErr_genericError, NULL);
		return;
	}
	
	// must have a facebook id or else nothing
	if([NSString isEmptyString:self.mUser.facebookId]) {
		WRErrorLog(@"Cannot claimFacebookGiftsForRequestType no fbid.  Ignoring...");
		callback(eResultErr_genericError, NULL);
		return;
	}
	
	NSString* requestType = [requestTypeList componentsJoinedByString:@"|"];
	
	// params
	NSDictionary* paramDict = @{
								@"auth": _mUUIDHash,
								@"uuid": _mUUID,
								
								@"user_social_id": self.mUser.facebookId,
								@"request_type": requestType,
								};
	
	//__weak __typeof__(self) bself = self;
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlPath = [[WRBackend sharedManager] createApiUrl:kBackendAPI_claimFacebookGifts];
#if WRB_USE_AFNETWORKING20
	[httpClient POST:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#else
	[httpClient postPath:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#endif
	 {
		 NSDictionary* jsonDict = (NSDictionary*) responseObject;
		 
		 // check for error
		 NSString* result = jsonDict[@"result"];
		 if(![result isEqualToString:@"ok"])
		 {
			 WRDebugLog(@"Error claiming fb gifts: %@", result);
			 
			 callback(eResultErr_invalidResult, result);
			 
			 return;
		 }
		 
		 // save the data - will look something like this:
		 NSDictionary* resultData = jsonDict[@"data"];
		 
		 // success callback
		 callback(eResultErr_ok, resultData);
		 
		 
	 }
	 failure:^(AFHTTPRequestOperation *operation, NSError *error)
	 {
		 WRErrorLog(@"Error claiming fb gifts: %@", error);
		 
		 callback(eResultErr_httpFailure, error);
		 
		 // analytics
		 NSString* exceptionStr = [NSString stringWithFormat:@"WRBackend claimFacebookGiftsForRequestType error: %@", error];
		 [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
		 
		 
		 // operation self releases
	 }];
}

//===========================================================
- (void) getPromoBanners:(WRBackendResultBlock)callback
{
	// must be registered
	if(!self.mRegistered)
	{
		WRErrorLog(@"Cannot getPromoBanners info until registered.  Ignoring...");
		callback(eResultErr_genericError, NULL);
		return;
	}

	// params
	NSDictionary* paramDict = @{
								@"auth": _mUUIDHash,
								@"uuid": _mUUID,
								};
	
	//__weak __typeof__(self) bself = self;
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlPath = [[WRBackend sharedManager] createApiUrl:kBackendAPI_getPromoBanners];
#if WRB_USE_AFNETWORKING20
	[httpClient POST:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#else
	[httpClient postPath:urlPath parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#endif
		 {
			 NSDictionary* jsonDict = (NSDictionary*) responseObject;
			 
			 // check for error
			 NSString* result = jsonDict[@"result"];
			 if(![result isEqualToString:@"ok"])
			 {
				 WRDebugLog(@"Error getting promo banners: %@", result);
				 
				 callback(eResultErr_invalidResult, result);
				 
				 return;
			 }
			 
			 // save the data - will look something like this:
			 NSDictionary* resultData = jsonDict[@"data"];
			 
			 // success callback
			 callback(eResultErr_ok, resultData);
			 
			 
		 }
		 failure:^(AFHTTPRequestOperation *operation, NSError *error)
		 {
			 WRErrorLog(@"Error claiming fb gifts: %@", error);
			 
			 callback(eResultErr_httpFailure, error);
			 
			 // analytics
			 NSString* exceptionStr = [NSString stringWithFormat:@"WRBackend getPromoBanners error: %@", error];
			 [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
			 
			 
			 // operation self releases
		 }];
}


@end
