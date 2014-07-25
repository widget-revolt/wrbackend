//
//  WRBAppConfig.m
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



#import "WRBAppConfig.h"
#import "WRBackend.h"

#import "WRLogging.h"
#import "WRUtils.h"

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#define kAppConfigFileName	@"app_config"
#define kAppConfigFolderName @"app_config_dir"

//////////////////////////////////////////////////////////////////
@interface WRBAppConfig ()

@property (nonatomic, retain) NSDictionary* mAppConfig;				// this is built in
@property (nonatomic, retain) NSDictionary* mAppConfigOverride;		// this would come from server and saves to docs
@property (nonatomic, retain) NSDictionary* mAppConfigVolatile;		// this comes from the server and highest prio

@end

//////////////////////////////////////////////////////////////////
@implementation WRBAppConfig

#pragma mark - Object lifecycle

//==============================================================
- (id) init
{
	if( (self = [super init]) )
	{
		self.mAppConfig = [NSDictionary dictionary];
		self.mAppConfigOverride = [NSDictionary dictionary];
		self.mAppConfigVolatile = [NSDictionary dictionary];
		
		// now load fix assets
		[self reloadAppConfig];
	}
	
	return self;
}

//==============================================================
- (void) dealloc
{
	self.mAppConfig = NULL;
	self.mAppConfigOverride = NULL;
	self.mAppConfigVolatile = NULL;

}
//===========================================================
- (void) updateVolatileAppConfigWithDict:(NSDictionary*)dict
{
	NSMutableDictionary* newDict = [NSMutableDictionary dictionaryWithDictionary:_mAppConfigVolatile];
	
	[newDict addEntriesFromDictionary:dict];

	self.mAppConfigVolatile = newDict;
}
//===========================================================
- (void) updateBuiltInAppConfigWithDict:(NSDictionary*)dict
{
	NSMutableDictionary* newDict = [NSMutableDictionary dictionaryWithDictionary:_mAppConfig];
	
	[newDict addEntriesFromDictionary:dict];
	
	self.mAppConfig = newDict;
}
//===========================================================
- (void) onRegisterBackend:(NSDictionary*)launchOptions
{
	[self reloadAppConfig];

	// call the delegate to get in built in vals.
	NSDictionary* builtInVals = [[WRBackend sharedManager].delegate getBuiltinAppConfig];
	if(builtInVals) {
		[self updateBuiltInAppConfigWithDict:builtInVals];
	}
}

//==============================================================
- (void) reloadAppConfig
{
	
	// load the internal json file
	NSString* filePath = [[NSBundle mainBundle] pathForResource:kAppConfigFileName ofType:@"json"];
    NSData* data = [NSData dataWithContentsOfFile:filePath];
	if(!data) {
		WRErrorLog(@"No app config file");
		return;
	}
	
	NSError* error;
	NSDictionary* jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
	if(!jsonDict)
	{
		WRErrorLog(@"error (probably missing) loading app config json: %@", error);
		return;
	}
	self.mAppConfig = jsonDict;
	

	
	// now see if we have an override in the documents folder
	NSString* pathToOverride = [WRUtils filePathInDocumentsDirectory:kAppConfigFolderName];
	NSData* overrideData = [NSData dataWithContentsOfFile:pathToOverride options:NSDataReadingUncached error:&error];
	
	// We dont wanna fail here...but report it
	if(!overrideData) {
		WRDebugLog(@"could not find override appconfig: %@", error);
	}
	else
	{
		NSDictionary* jsonOverrideDict = [NSJSONSerialization JSONObjectWithData:overrideData options:0 error:&error];
		if(!jsonOverrideDict)
		{
			WRErrorLog(@"error loading app config override json: %@", error);
		}
		else
		{
			self.mAppConfigOverride = jsonOverrideDict;
			
			// post a notification that the app override data was loaded
			[[NSNotificationCenter defaultCenter] postNotificationName:kAppConfigNotification_wasReloadedRemote object:NULL];
			
		}
	}
	
}


#pragma mark - Getters

//==============================================================
- (id) objectForKey:(NSString*)key
{
	id retVal = NULL;
	
	retVal = [_mAppConfigVolatile objectForKey:key];
	if(!retVal)
	{
		retVal = [_mAppConfigOverride objectForKey:key];
		if(!retVal)
		{
			retVal = [_mAppConfig objectForKey:key];
		}
	}
	
	return retVal;
}
//==============================================================
- (NSString*) stringForKey:(NSString*)key default:(NSString*)defaultStr
{
	NSString* retVal = defaultStr;
	
	@try
	{
		NSString* val = [self objectForKey:key];
		if(val) {
			retVal = val;
		}
	}
	@catch(...)
	{
		retVal = defaultStr;
	}
	
	return retVal;
}
//==============================================================
- (BOOL) boolForKey:(NSString*)key default:(BOOL)defaultVal
{
	BOOL retVal = defaultVal;
	
	@try
	{
		NSNumber* val = [self objectForKey:key];
		if(val) {
			retVal = [val boolValue];
		}
	}
	@catch(...)
	{
		retVal = defaultVal;
	}
	
	return retVal;
}
//==============================================================
- (int) intForKey:(NSString*)key default:(int)defaultVal
{
	int retVal = defaultVal;
	
	@try
	{
		NSNumber* val = [self objectForKey:key];
		if(val) {
			retVal = [val intValue];
		}
	}
	@catch(...)
	{
		retVal = defaultVal;
	}
	
	return retVal;
}
//==============================================================
- (double) doubleForKey:(NSString*)key default:(double)defaultVal
{
	double retVal = defaultVal;
	
	@try
	{
		NSNumber* val = [self objectForKey:key];
		if(val) {
			retVal = [val doubleValue];
		}
	}
	@catch(...)
	{
		retVal = defaultVal;
	}
	
	return retVal;
}
//==============================================================
- (NSDictionary*) dictForKey:(NSString*)key
{
	NSDictionary* retObj = NULL;
	
	@try
	{
		NSDictionary* val = [self objectForKey:key];
		if(val) {
			retObj = val;
		}
	}
	@catch(...)
	{
		retObj = NULL;
	}
	
	return retObj;
}
//==============================================================
- (NSArray*) arrayForKey:(NSString*)key
{
	NSArray* retObj = NULL;
	
	@try
	{
		NSArray* val = [self objectForKey:key];
		if(val) {
			retObj = val;
		}
	}
	@catch(...)
	{
		retObj = NULL;
	}
	
	return retObj;
}

//===========================================================
- (NSString*) overrideString:(NSString*)key
{
	NSString* retStr = LOCALSTR(key);
	
	NSDictionary* stringDict = [self dictForKey:@"strings"];
	if(stringDict)
	{
		NSString* theStr = stringDict[key];
		if(![NSString isEmptyString:theStr])
		{
			retStr = theStr;
		}
	}
	
	return retStr;
}


@end
