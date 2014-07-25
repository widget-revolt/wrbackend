//
//  WRBLeaderboard.m
//
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

#import "WRBLeaderboard.h"

#import "WRBackend.h"
#import "WRBHttpClient.h"
#import "AnalyticsHelper.h"

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#define kPref_friendLeaderboardCacheBase	@"com.wrbackend.friend_leader_cache"

////////////////////////////////////////////////////////////////////
@interface WRBLeaderboard()

@property (nonatomic, strong) NSDictionary* mGlobalScoreLeaders;
@property (nonatomic, strong) NSMutableDictionary* mFriendLeaders;	// this is a cache for results from friend leaders


@end

////////////////////////////////////////////////////////////////////
@implementation WRBLeaderboard

#pragma mark - lifecycle

//===========================================================
- (id) init
{
	self = [super init];
	if(self)
	{
		self.mGlobalScoreLeaders = [NSDictionary dictionary];
		self.mFriendLeaders = [NSMutableDictionary dictionary];
	}
	
	return self;
}

#pragma mark - WRBackendPlugin interface

//===========================================================
- (void) backendDidRegister:(NSDictionary*)configSettings
{
}
//===========================================================
- (void) appDidBecomeActive
{
	[self refreshGlobalLeaderList];
}
//===========================================================
- (void) appWillResignActive
{
}

#pragma mark - user scores

//===========================================================
- (void) reportScore:(int)score forId:(NSString*)leaderboardId
{
	//TODO: game kit?
	
	WRBackend* backend = [WRBackend sharedManager];
	
	NSString* appId = [WRUtils getBundleIdentifier];
	NSString* uuid = backend.mUUID;
	NSString* uuidHash = backend.mUUIDHash;
	
	// build up params
	NSDictionary* paramDict = @{
@"auth": uuidHash,
@"uuid": uuid,

@"app_id": appId,
@"leaderboard_id": leaderboardId,
@"score": @(score),

	};
	
	//NOTE: this is not failsafe.  If it fails to transmit a score we don't care and it will get dismissed.
	// Kinda sucks to be you but its not ecommerce
	
	// make the https request
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlStr = [backend createApiUrl:kBackendAPI_reportScore];
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
				 WRDebugLog(@"Error in report_score: %@", result);
				 return;
			 }
		 
		 
	 }
	 failure:^(AFHTTPRequestOperation *operation, NSError *error)
	 {
		 WRErrorLog(@"Error report_score: %@", error);
		 
		 // analytics
		 NSString* exceptionStr = [NSString stringWithFormat:@"WRBackend report_score error: %@", error];
		 [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
		 
		 
		 // operation self releases
	 }];
}

#pragma mark - global leaders

//===========================================================
- (void) refreshGlobalLeaderList
{
	WRBackend* backend = [WRBackend sharedManager];
	
	NSString* appId = [WRUtils getBundleIdentifier];
	NSString* uuid = backend.mUUID;
	NSString* uuidHash = backend.mUUIDHash;
	
	// build up params
	NSDictionary* paramDict = @{
								@"auth": uuidHash,
								@"uuid": uuid,
								@"app_id": appId,
								
								};
	
	//NOTE: this is not failsafe.  If it fails to transmit a score we don't care and it will get dismissed.
	// Kinda sucks to be you but its not ecommerce
	
	// make the https request
	__weak __typeof__(self) bself = self;
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlStr = [backend createApiUrl:kBackendAPI_getGlobalLeadersList];
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
				 WRDebugLog(@"Error in report_score: %@", result);
				 return;
			 }
			 
			 // all good...lets save the score
			[bself updateGlobalScores:jsonDict];
		}
		failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			WRErrorLog(@"Error report_score: %@", error);

			// analytics
			NSString* exceptionStr = [NSString stringWithFormat:@"WRBackend report_score error: %@", error];
			[[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];


			// operation self releases
		}];
}
//===========================================================
- (void) updateGlobalScores:(NSDictionary*)jsonDict
{
	NSDictionary* globalScores = jsonDict[@"data"];
	if(globalScores)
	{
		self.mGlobalScoreLeaders = globalScores;
	}
}
//===========================================================
//	"com.widgetrevolt.tiltputter.rollover_tutorial" =     {
//        fname = Bchen;
//        "gamecenter_alias" = "";
//        lname = WidgetRevolt;
//        score = 52030;
//        uuid = "369B24CE-8D48-4C88-9E23-5E112FF77A67";
//    };

- (NSDictionary*) getBestScoreForLevel:(NSString*)leaderboardId
{
	NSDictionary* retObj = _mGlobalScoreLeaders[leaderboardId];
	if(retObj == nil) {
		retObj = @{};
	}
	return retObj;
}
//===========================================================
- (void) refeshFriendScoresForLevel:(NSString*)leaderboardId
					   fbFriendList:(NSString*)fbFriendList
					   gkFriendList:(NSString*)gkFriendList
{
	WRBackend* backend = [WRBackend sharedManager];
	
	NSString* appId = [WRUtils getBundleIdentifier];
	NSString* uuid = backend.mUUID;
	NSString* uuidHash = backend.mUUIDHash;
	
	NSString* fbParamList = fbFriendList;
	if(!fbParamList) {
		fbParamList = @"";
	}
	NSString* gkParamList = gkFriendList;
	if(!gkParamList) {
		gkParamList = @"";
	}
	
	// build up params
	NSDictionary* paramDict = @{
								@"auth": uuidHash,
								@"uuid": uuid,
								@"app_id": appId,
			
								@"leaderboard_id":leaderboardId,
								@"fb_list":fbParamList,
								@"gk_list":gkParamList,
								};
	
	//NOTE: this is not failsafe.  If it fails to transmit a score we don't care and it will get dismissed.
	// Kinda sucks to be you but its not ecommerce
	
	// make the https request
	__weak __typeof__(self) bself = self;
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSString* urlStr = [backend createApiUrl:kBackendAPI_getFriendLeaders];
#if WRB_USE_AFNETWORKING20
	[httpClient POST:urlStr
			  parameters:paramDict
				 success:^(AFHTTPRequestOperation *operation, id responseObject)
#else
	[httpClient postPath:urlStr
		parameters:paramDict
		success:^(AFHTTPRequestOperation *operation, id responseObject)
#endif
		{
			NSDictionary* jsonDict = (NSDictionary*) responseObject;

			// check for error
			NSString* result = jsonDict[@"result"];
			if(![result isEqualToString:@"ok"])
			{
				WRDebugLog(@"Error in friend_leaders: %@", result);
				return;
			}
			
			// save this to the cache
			[bself cacheFriendScoreResult:jsonDict leaderboardId:leaderboardId];

	 }
	 failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		 WRErrorLog(@"Error friend_leaders: %@", error);
		 
		 // analytics
		 NSString* exceptionStr = [NSString stringWithFormat:@"WRBackend friend_leaders error: %@", error];
		 [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
		 
		 
		 // operation self releases
	 }];

}
//===========================================================
- (void) cacheFriendScoreResult:(NSDictionary*)jsonDict leaderboardId:(NSString*)leaderboardId
{
	NSArray* scoreArray = jsonDict[@"data"][@"scores"];
	if(!scoreArray) {
		return;
	}
	
	NSDate* now = [NSDate date];
	
	NSDictionary* scoreListDef = @{
		@"updated": now,
		@"scores": scoreArray
	
	};
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSString* cacheKey = [NSString stringWithFormat:@"%@.%@", kPref_friendLeaderboardCacheBase, leaderboardId];
	[defaults setObject:scoreListDef forKey:cacheKey];
	[defaults synchronize];
	
	// broadcast that this happened
	NSDictionary* userInfo = @{
	@"leaderboard_id": leaderboardId,
	@"scores": scoreArray
	};
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotification_wrLeaderboardDidUpdateFriends object:self userInfo:userInfo];
}
//===========================================================
- (NSDictionary*) getScoresForLevel:(NSString*)leaderboardId
				  fbFriendList:(NSString*)fbFriendList
				  gkFriendList:(NSString*)gkFriendList
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	NSString* cacheKey = [NSString stringWithFormat:@"%@.%@", kPref_friendLeaderboardCacheBase, leaderboardId];
	
	NSDictionary* scoreDef = [defaults dictionaryForKey:cacheKey];
	if(!scoreDef) {
		scoreDef = [NSDictionary dictionary];
	}
	
	if(fbFriendList || gkFriendList)
	{
		
		// kick off a refresh for this level
		[self refeshFriendScoresForLevel:leaderboardId
					  fbFriendList:fbFriendList
					  gkFriendList:gkFriendList];
	}
	
	return scoreDef;
}

@end
