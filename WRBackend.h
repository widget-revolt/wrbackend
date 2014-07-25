//
//  WRBackend.h
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
#import "WRBUser.h"
#import "WRBAppConfig.h"
#import "WRBNotifications.h"
#import "WRBWallet.h"


#define USE_ANALYTICS	1




// urls
#define kBackendAPI_registerUser			@"/register_user"
#define kBackendAPI_addUserInstallInfo		@"/add_user_install_info"
#define kBackendAPI_getInventory			@"/get_inventory"
#define kBackendAPI_registerDevice			@"/register_device"
#define kBackendAPI_verifyReceipt			@"/validate_ios_purchase"
#define kBackendAPI_setAppUserInfo			@"/save_app_user_info"
#define kBackendAPI_getAppUserInfo			@"/get_app_user_info"
#define kBackendAPI_reportScore				@"/report_score"
#define kBackendAPI_getGlobalLeadersList	@"/global_leaders_list"
#define kBackendAPI_getFriendLeaders		@"/friend_leaders"
#define kBackendAPI_redeemCoupon			@"/redeem_coupon"
#define kBackendAPI_getFacebookGifts		@"/get_available_facebook_gifts"
#define kBackendAPI_sendFacebookGifts		@"/send_facebook_gifts"
#define kBackendAPI_claimFacebookGifts		@"/claim_facebook_gifts"
#define kBackendAPI_getPromoBanners			@"/get_promo_banners"

#define kBackendAPI_verifyReceiptAndroid	@"/validate_android_purchase"

// NSNotifications
#define kNotification_wrBackendDidRegister	@"com.widgetrevolt.wrbackend_did_register"

// analytics constants
#define kAnalError_apiFailure				@"error.server.api_failure"
#define kAnalError_iapValidationFailure		@"error.server.iap_validation"
#define kAnalError_transactionWriteFailed	@"error.server.transaction_write_fail"

// config settings
#define kWRBConfKey_sessionTimeout			@"session_timeout"			// session timeout in minutes
#define kWRBConfKey_sessionsToPush			@"sessions_until_push"		// session until push is asked

#define kWRBConfKey_devAppKey				@"wrbpush_dev_app_key"
#define kWRBConfKey_devAppSecret			@"wrbpush_dev_app_secret"
#define kWRBConfKey_prodAppKey				@"wrbpush_prod_app_key"
#define kWRBConfKey_prodAppSecret			@"wrbpush_prod_app_secret"
#define kWRBConfKey_precachePromoBannerImg	@"wrb_precache_promo_banner_image"	// TRUE/FALSE
#define kWRBConfKey_walletSalt				@"wrb_wallet_salt"	//needs to be in format xx%dxx%dxxx%@x


/////////////////////////////////////////////////////////////////
typedef enum
{
	eResultErr_ok = 0,
	
	eResultErr_genericError = -1,
	eResultErr_invalidResult = -2,		// result was not "ok".  Passes result
	eResultErr_httpFailure = -100,		// Will include the NSError as a result
	
} EnumResultError;

typedef void(^WRBackendAppUpdateBlock)(BOOL isUpgradeAvailable);
typedef void(^WRBackendAppHttpResultBlock)(BOOL success, NSError* err);
typedef void(^WRBackendResultBlock)(int/*EnumResultError*/ err, id result);

/////////////////////////////////////////////////////////////////
@protocol WRBackendDelegate;
@protocol WRBackendPlugin;

@class WRBLeaderboard;
@class WRBPromoBanners;

/////////////////////////////////////////////////////////////////
@interface WRBackend : NSObject

@property (weak) id<WRBackendDelegate> delegate;

@property (nonatomic, strong, readonly) NSString* mUUID;
@property (nonatomic, strong, readonly) NSString* mUUIDHash;
@property (nonatomic, strong, readonly) NSString* mODIN;

@property (nonatomic, strong, readonly) NSString* mAppId;
@property (nonatomic, retain, readonly) WRBUser* mUser;
@property (nonatomic, retain, readonly) WRBAppConfig* mAppConfig;
@property (nonatomic, retain, readonly) WRBNotifications* mNotifications;
@property (nonatomic, retain, readonly) WRBWallet* mWallet;
@property (nonatomic, retain, readonly) WRBLeaderboard* mLeaderboard;
@property (nonatomic, retain, readonly) WRBPromoBanners* mPromoBanners;

@property (nonatomic, strong, readonly) NSDate* mInstallDate;
@property (nonatomic, assign, readonly) BOOL mRegistered;
@property (nonatomic, assign, readonly) int	mLaunchCount;
@property (nonatomic, assign, readonly) int mActivationCount;	// # of times user has activated app
@property (nonatomic, assign, readonly) int mSessionCount;


+ (WRBackend*) sharedManager;

//--App lifecycle

///	This must be called during didFinishLaunchingWithOptions
- (void) registerBackend:(NSString*)protocol
				  server:(NSString*)server
			appUrlPrefix:(NSString*)appUrlPrefix
				   appId:(NSString*)appId
				delegate:(id<WRBackendDelegate>)delegate
				settings:(NSDictionary*)settings
		   launchOptions:(NSDictionary*)launchOptions;

- (void) handleAppDidBecomeActive;
- (void) handleAppWillResignActive;
- (void) handleAppWillTerminate;
- (void) handleDidReceiveLocalNotification:(UILocalNotification*)notif;
- (void) handleDidRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken;
- (void) handleDidFailToRegisterForRemoteNotificationsWithError:(NSError*)error;
- (void) handleDidReceiveRemoteNotification:(NSDictionary*)userInfo;

//-- api calls
- (void) registerUser;	/// register user on the backend
- (void) addInstallTrackerInfo:(NSString*)trackerId trackerName:(NSString*)trackerName referrer:(NSString*)referrer ip:(NSString*)ip callback:(WRBackendAppHttpResultBlock)callback;
- (void) saveAppUserInfo:(WRBackendAppHttpResultBlock)callback;
- (void) submitCoupon:(NSString*)couponStr tickcountSalt:(int)tickcountSalt callback:(WRBackendResultBlock)callback;
- (void) sendFacebookGifts:(NSArray*)friendList requestType:(NSString*)requestType callback:(WRBackendResultBlock)callback;
- (void) getAvailableFacebookGifts:(WRBackendAppHttpResultBlock)callback;
- (void) claimFacebookGiftsForRequestType:(NSArray*)requestTypeList callback:(WRBackendResultBlock)callback;
- (void) getPromoBanners:(WRBackendResultBlock)callback;

//-- persisted user info...call saveAppUserInfo to save
- (id) getAppUserInfoObjectForKey:(NSString*)key;
- (int) getAppUserInfoIntForKey:(NSString*)key default:(int)defaultInt;
- (double) getAppUserInfoDoubleForKey:(NSString*)key default:(double)defaultVal;
- (void) setAppUserInfoObject:(id)object forKey:(NSString*)key;

//--app update check
- (void) checkForAppUpdate:(WRBackendAppUpdateBlock)callback;

- (NSString*) getProtocol;
- (NSString*) getServer;
- (NSString*) getAppUrlPrefix;

//--utils
- (NSString*) createApiUrl:(NSString*)basePath;
	

	/// resets any debug pref/default vals
- (void) debugReset;

@end

/////////////////////////////////////////////////////////////////
@protocol WRBackendDelegate

/// This is called when the backend needs to initialize the wallet.  The delegate should return an NSDictionary with two key/value pairs with keys: kCurrency_standard and kCurrency_premium.  The value is an NSNumber of the starting balance.  Example: @{ kCurrency_standard: @(1000), kCurrency_premium: @(0) };
- (NSDictionary*) getWalletDefaultBalances;

/// called when registerUser api call is made.  The alreadyRegistered param is TRUE if this is an update (e.g the /register_user call has been made once
- (void) didCompleteRegistration:(BOOL)registered alreadyRegistered:(BOOL)alreadyRegistered;

/// This allows the app to act as a data source for app config data.  You can hardcode data and not expose it in json.
- (NSDictionary*) getBuiltinAppConfig;	// this gets called so that the app can register built-in, non data exposed dictionaries, etc.

@optional

/// This is called after on app activation when a new session is detected.  For session support, you need to configure the proper timeout time as an option when you register the app with the backend.
- (void) didStartNewSession:(int)sessionCount;


/// implement this to override canceling behavior.  By default local notifications are canceled by the notification handler on startup
- (BOOL) shouldCancelAllLocalNotifications;

/// implement this to open up an in-app StoreProductViewController dialog.  You will get the appID.  This comes from a push notification response
- (void) openAppStoreForId:(NSNumber*)appId;

@end

//////////////////////////////////////////////////////////////
// This is a protocol to being the process of transforming some of the backend items into plugins
// it isn't formally a plugin process yet
@protocol WRBackendPlugin

- (void) backendDidRegister:(NSDictionary*)configSettings;
//- (void) appDidLaunch;
- (void) appDidBecomeActive;
- (void) appWillResignActive;


@optional
- (void) backendUserDidRegister:(NSDictionary*)configData;


@end
