//
//  WRBUser.m
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



#import "WRBUser.h"



#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

@interface WRBUser()

@property (nonatomic, assign, readwrite) BOOL	isMonetizer;
@property (nonatomic, strong, readwrite) NSArray* mAvailableGifts;

@end

@implementation WRBUser

//===========================================================
- (id) init
{
	self = [super init];
	if(self)
	{
		self.userId = @"";
		self.facebookId = @"";
		self.firstName = @"";
		self.lastName = @"";
		self.gender = @"";
		self.emailAddress = @"";
		self.ageRange = @"";
		self.locale = @"";
		self.birthday = @"";
		
		self.gamecenterId = @"";
		self.gamecenterAlias = @"";
		
		self.isMonetizer = FALSE;
		
		self.isMonetizer = [[NSUserDefaults standardUserDefaults] boolForKey:kPref_userIsMonetized];
		
		self.mAvailableGifts = NULL;
		
	}
	
	return self;
}
//===========================================================
- (void) setIsMonetizer
{
	[[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:kPref_userIsMonetized];
	[[NSUserDefaults standardUserDefaults] synchronize];
	self.isMonetizer = TRUE;
}
//===========================================================
- (NSString*) genderAsChar
{
	NSString* retStr = [NSString stringWithString:_gender];
	if([NSString isEmptyString:retStr]) {
		return @"";
	}
	
	// make lower case
	retStr = [retStr lowercaseString];
	
	if([retStr isEqualToString:@"male"]) {
		retStr = @"m";
	}
	else if([retStr isEqualToString:@"female"]) {
		retStr = @"f";
	}
	
	return retStr;
}
//===========================================================
- (NSString*) getBestNameForUser:(NSString*)defaultName
{
	NSString* retName = [defaultName copy];
	
	if(![NSString isEmptyString:_gamecenterAlias]) {
		retName = [NSString stringWithFormat:@"%@", _gamecenterAlias];
	}
	
	if(![NSString isEmptyString:_firstName]) {
		retName = [NSString stringWithFormat:@"%@ %@", _firstName, _lastName];
	}
	
	return retName;
}
//===========================================================
- (void) setAvailableGifts:(NSArray*)gifts
{
	self.mAvailableGifts = gifts;
}
//===========================================================
- (void) resetAvailableGifts
{
	self.mAvailableGifts = NULL;
}
//===========================================================
// only usable by debug code
- (void) debugSetMonetizer:(BOOL)isMonetizer
{
#if DEBUG
	[[NSUserDefaults standardUserDefaults] setBool:isMonetizer forKey:kPref_userIsMonetized];
	[[NSUserDefaults standardUserDefaults] synchronize];
	self.isMonetizer = isMonetizer;
#endif
}

@end
