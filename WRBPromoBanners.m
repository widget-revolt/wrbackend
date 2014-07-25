//
//  WRBPromoBanners.m
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

#import "WRBPromoBanners.h"
#import "WRBackend.h"
#import "NSArray+WRAdditions.h"
#import "NSDate+WRAdditions.h"
#import "WRImageCache.h"



#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

/////////////////////////////////////////////////////////////////
@interface WRBPromoBanners()

@property (nonatomic, strong) NSArray* mPromoBannerData;

@property (nonatomic, assign) BOOL mShouldPrecacheImages;

@end

/////////////////////////////////////////////////////////////////
@implementation WRBPromoBanners

#pragma mark - lifecycle

//===========================================================
- (id) init
{
	self = [super init];
	if(self)
	{
		self.mShouldPrecacheImages = FALSE;
	}
	
	return self;
}


#pragma mark - WRBackendPlugin

//===========================================================
- (void) backendDidRegister:(NSDictionary*)configSettings
{
	self.mShouldPrecacheImages = [configSettings[kWRBConfKey_precachePromoBannerImg] boolValue];

}
//===========================================================
- (void) appDidBecomeActive
{
}

//===========================================================
- (void) appWillResignActive
{
}

//===========================================================
- (void) backendUserDidRegister:(NSDictionary*)configData
{
	NSArray* promoBannerData = configData[@"_promo_banners"];
	if(promoBannerData)
	{
		self.mPromoBannerData = [NSArray arrayWithArray:promoBannerData];
		
		if(_mShouldPrecacheImages)
		{
			// cache images
			for(NSDictionary* item in _mPromoBannerData)
			{
				NSString* mediaURL = item[@"media_url"];
				if(![NSString isEmptyString:mediaURL])
				{
					NSURL* imageURL = [NSURL URLWithString:mediaURL];
					[[WRImageCache sharedManager] getImageForUrl:imageURL];
				}
			
			}
		
		}

	}
}

#pragma mark - promo banner public

//===========================================================
- (NSDictionary*) pickPromoBanner
{
	if([_mPromoBannerData count] == 0) {
		return NULL;
	}
	
	
	NSMutableArray* availableBanners = [self getFilteredPromoBanners];
	
	// weight the items - default weight = 100
	NSMutableDictionary* weightedDict = [NSMutableDictionary dictionary];
	int curWeight = 0;
	for(NSDictionary* item in availableBanners)
	{
		int iWeight = 100;
		NSString* weight = item[@"rank"];
		if(weight)
		{
			iWeight = [weight intValue];
		}
		weightedDict[@(curWeight)] = item;
		
		curWeight += iWeight;
	}


	// pick a random a banner
	int randomInt = RANDOM_INT(1, curWeight);
	
	NSDictionary* bannerData = [weightedDict vectorRangeLookupForValue:randomInt];//[availableBanners randomElement];
	return bannerData;
}



//===========================================================
- (void) refreshPromoBannerData:(WRBackendResultBlock)callback
{
	[[WRBackend sharedManager] getPromoBanners:^(int err, id result) {
		
		if(err == eResultErr_ok) {
			NSArray* resultArray = (NSArray*) result;
			if(resultArray)
			{
				self.mPromoBannerData = resultArray;
				
				// notify
				[[NSNotificationCenter defaultCenter] postNotificationName:kNotification_promoBannersDidUpdate object:self];
			}
		}
		callback(err, result);
	}];

}

#pragma mark - private utils

//===========================================================
- (NSMutableArray*) getFilteredPromoBanners
{
	NSMutableArray* availableBanners = [NSMutableArray array];
	
	for(NSDictionary* item in _mPromoBannerData)
	{
		
		BOOL bannerPassesFilter = [self checkBannerRules:item];
		if(bannerPassesFilter) {
			[availableBanners addObject:item];
		}
		
	}
	
	return availableBanners;
}

//===========================================================
- (BOOL) checkBannerRules:(NSDictionary*)item
{
	WRBUser* user = [WRBackend sharedManager].mUser;
	NSDate* now = [NSDate date];
	
	NSString* monetizerRule = item[@"rule_is_monetizer"];
	NSString* dateStartStr = item[@"rule_date_start"];
	NSString* dateEndStr = item[@"rule_date_end"];
	NSString* gender = item[@"rule_gender"];
	NSNumber* nFrequency = item[@"rule_frequency"];
	int frequency = 1;
	if(nFrequency)
	{
		frequency = [nFrequency intValue];
		if(frequency < 1) {
			frequency = 1;
		}
	}
	
	// check session/frequency
	if(frequency > 1)
	{
		int curSession = [WRBackend sharedManager].mSessionCount;
		if(curSession % frequency != 0) {
			return FALSE;
		}
	}
	
	// check monetizer
	if(item[@"rule_is_monetizer"] != [NSNull null])
	{
		if([monetizerRule isEqualToString:@"y"])
		{
			if(!user.isMonetizer) {
				return FALSE;
			}
		}
		else if([monetizerRule isEqualToString:@"n"])
		{
			if(user.isMonetizer) {
				return FALSE;
			}
		}
	}
	
	// check date start
	// These come out like: 2014-06-24T00:00:00.000Z
	// So strip everything past the first 10 chars
	if(item[@"rule_date_start"] != [NSNull null] && ![NSString isEmptyString:dateStartStr])
	{
		dateStartStr = [dateStartStr substringToIndex:10];
		NSDate* startDate = [NSDate dateForShortDateString:dateStartStr];
		if(startDate)
		{
			//The receiver is earlier in time than anotherDate, NSOrderedAscending.
			if([now compare:startDate] == NSOrderedAscending) {
				return FALSE;
			}
		}
	}
	
	if(item[@"rule_date_end"] != [NSNull null] && ![NSString isEmptyString:dateEndStr])
	{
		dateEndStr = [dateEndStr substringToIndex:10];
		NSDate* endDate = [NSDate dateForShortDateString:dateEndStr];
		if(endDate)
		{
			//The receiver is later in time than anotherDate, NSOrderedDescending
			if([now compare:endDate] == NSOrderedDescending) {
				return FALSE;
			}
		}
	}
	
	// check gender
	if(item[@"rule_gender"] != [NSNull null])
	{
		if(![NSString isEmptyString:gender])
		{
			NSString* userGender = [user genderAsChar];
			if(![gender isEqualToString:userGender]) {
				return FALSE;
			}
		}
	}
	
	return TRUE;
}

@end
