//
//  WRBUser.h
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

#define kPref_userIsMonetized	@"pref.wrbackend.user_is_monetized"

@interface WRBUser : NSObject

@property (nonatomic, strong) NSString* userId;

@property (nonatomic, strong) NSString* facebookId;
@property (nonatomic, strong) NSString* firstName;
@property (nonatomic, strong) NSString* lastName;
@property (nonatomic, strong) NSString* gender;
@property (nonatomic, strong) NSString* emailAddress;
@property (nonatomic, strong) NSString* ageRange;
@property (nonatomic, strong) NSString* locale;
@property (nonatomic, strong) NSString* birthday;

@property (nonatomic, strong) NSString* gamecenterId;
@property (nonatomic, strong) NSString* gamecenterAlias;

@property (nonatomic, assign, readonly) BOOL	isMonetizer;

// Gift information
/// This is NULL if we haven't checked.
@property (nonatomic, strong, readonly) NSArray* mAvailableGifts;

	

- (void) setIsMonetizer;
- (NSString*) genderAsChar;	// returns "m", "f", ""

/// returns firstname + lastname or gamcenterAlias or default, depending on whats available
- (NSString*) getBestNameForUser:(NSString*)defaultName;

/// Sets availalbe gift arrays
- (void) setAvailableGifts:(NSArray*)gifts;
- (void) resetAvailableGifts;


- (void) debugSetMonetizer:(BOOL)isMonetizer;

@end
