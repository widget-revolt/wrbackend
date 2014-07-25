//
//  WRBAppConfig.h
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

#define kAppConfigNotification_wasReloadedRemote		@"notification.app_config.was_reloaded_remote"

#define kAppConfig_updateFrequencyDays		1.0			//1 day


//////////////////////////////////////////////////////////////////
@interface WRBAppConfig : NSObject

- (void) onRegisterBackend:(NSDictionary*)launchOptions;

- (void) updateVolatileAppConfigWithDict:(NSDictionary*)dict;

- (NSString*) stringForKey:(NSString*)key default:(NSString*)defaultStr;
- (BOOL) boolForKey:(NSString*)key default:(BOOL)defaultVal;
- (int) intForKey:(NSString*)key default:(int)defaultVal;
- (double) doubleForKey:(NSString*)key default:(double)defaultVal;
- (NSDictionary*) dictForKey:(NSString*)key;
- (NSArray*) arrayForKey:(NSString*)key;


/// Gets string from app config if exist, else looks in Localizable.strings
- (NSString*) overrideString:(NSString*)key;

@end
