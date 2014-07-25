//
//  WRBWallet.h
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



/////////////////////////////////////////////////////////////////

///These are some standard currencies that you probably want to use.
///  In your own appconst file you can redefine them to fit the app naming (e.g. tokens, gold, tickets, etc)
#define kCurrency_standard		@"standard"
#define kCurrency_premium		@"premium"
#define kCurrency_lives			@"lives"

/////////////////////////////////////////////////////////////////
//-- Handy macros
#define IS_AUTHORIZED(x)	[[WRBackend sharedManager].mWallet hasAuthorization:x]
#define IS_NOT_AUTHORIZED(x)	(![[WRBackend sharedManager].mWallet hasAuthorization:x])

/////////////////////////////////////////////////////////////////
@interface WRBWallet : NSObject

- (id) initWithDefaultBalances:(NSDictionary*)defaultBalances salt:(NSString*)salt;

// wallet / currencies
- (NSDictionary*) addCurrency:(int)units forType:(NSString*)currencyType;
- (NSDictionary*) deductCurrency:(int)units forType:(NSString*)currencyType;
- (NSDictionary*) getWalletBalances;
- (int) getBalanceForType:(NSString*)currencyType;

- (void) resetWallet; ///This is only for DEBUG builds

// authorizations / managed purchases
- (BOOL) addAuthorization:(NSString*)key forCurrency:(NSString*)currencyType amount:(int)amount;
- (BOOL) hasAmount:(int)amount ofCurrency:(NSString*)currency;

// managed purchases
- (void) addAuthorization:(NSString*)key;
- (BOOL) hasAuthorization:(NSString*)key;
- (void) removeAuthorization:(NSString*)key;///This is only for DEBUG builds



@end
