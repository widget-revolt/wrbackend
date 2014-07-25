//
//  WRBWallet.m
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




#import "WRBWallet.h"
#import "WRUUID.h"
#import "WRBackend.h"
#import "WRLib.h"


#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

// iOS implementation
#ifndef ANDROID
#import "SSKeychain.h"
#endif

#define kWRBWallet_balances			@"wrbwallet__balances"

/////////////////////////////////////////////////////////////////
@interface WRBWallet()


@property (nonatomic, strong) NSDictionary* mDefaultBalances;	//balances to use for first time wallet
@property (nonatomic, strong) NSString* mHashKey;
@property (nonatomic, strong) NSString* mSalt;

@end

/////////////////////////////////////////////////////////////////
@implementation WRBWallet

#pragma mark - object initialization

//===========================================================
- (id) initWithDefaultBalances:(NSDictionary*)defaultBalances salt:(NSString*)salt
{
	if( (self = [super init]) )
	{
		self.mHashKey = NULL;
		self.mDefaultBalances = defaultBalances;
		self.mSalt = salt;
		
		// now lets check the balances str and make sure it ok
		NSDictionary* walletDict = [self openWallet];
		if(!walletDict) {
			WRErrorLog(@"Wallet not found.  Re-initializing");
			[self initializeOnce];
		}
	}
	
	return self;
}


//===========================================================
- (void) initializeOnce
{
	// Create a default/temp wallet
	[self saveWallet:_mDefaultBalances];
}


#pragma mark - private utils

//===========================================================
- (NSDictionary*) openWallet
{

	NSError __autoreleasing *error;

	NSString* appBundleId = [[NSBundle mainBundle] bundleIdentifier];
	NSString* walletStr = NULL;

	walletStr = [self passwordForService:appBundleId account:kWRBWallet_balances error:&error];


	if(!walletStr) {
		WRDebugLog(@"could not retrieve wallet string.  Re-initializing: %@", error);
		[self initializeOnce];
		return NULL;
	}


	NSDictionary* walletDict = [NSJSONSerialization JSONObjectWithString:walletStr options:0];
	if(!walletDict)
	{
		WRErrorLog(@"error unpacking wallet - json");
		return NULL;
	}

	NSString* storedHash = walletDict[@"hash"];
	if(!storedHash) {
		WRErrorLog(@"error unpacking wallet - invalid wallets (1)");
		return NULL;
	}

	NSDictionary* balances = walletDict[@"balances"];
	if(!balances) {
		WRErrorLog(@"error unpacking wallet - invalid wallets (2)");
		return NULL;
	}
	
	// wallet hashing code
	int sumWallets = 0;
	int countWallets = 0;
	for(NSString* key in balances)
	{
		NSNumber* walletVal = balances[key];
	
		int amount = [walletVal intValue];
		sumWallets += amount;
		countWallets++;
	}
	
	NSString* uuid = [WRBackend sharedManager].mUUID;
	NSString* baseString = [NSString stringWithFormat:_mSalt, sumWallets, countWallets, uuid];
	NSString* hash = [WRUtils sha256:baseString];
	
	if(![hash isEqualToString:storedHash]) {
		WRErrorLog(@"error unpacking wallet - invalid wallets (3)");
		return NULL;
	}

	
	// now save the wallet info
	return balances;
	
}
//===========================================================
- (BOOL) saveWallet:(NSDictionary*)walletBalances
{

	// create the hash
	int sumWallets = 0;
	int countWallets = 0;
	for(NSString* key in walletBalances)
	{
		NSNumber* walletVal = walletBalances[key];
		
		int amount = [walletVal intValue];
		sumWallets += amount;
		countWallets++;
	}
	
	// mix up the balance by making the hash embedded in a string.
	NSString* uuid = [WRBackend sharedManager].mUUID;
	NSString* baseString = [NSString stringWithFormat:_mSalt, sumWallets, countWallets, uuid];
	NSString* hash = [WRUtils sha256:baseString];
	
	// write out the
	NSDictionary* saveDict = @{
								@"hash": hash,
								@"balances": walletBalances
								};

	
	// serialize to json
	NSString* jsonStr = [NSJSONSerialization stringWithJSONObject:saveDict options:0];


	// save it
	NSError __autoreleasing *error;
	NSString* appBundleId = [[NSBundle mainBundle] bundleIdentifier];
	BOOL ok = [self setPassword:jsonStr forService:appBundleId account:kWRBWallet_balances error:&error];
	if(!ok)
	{
		WRErrorLog(@"Error writing wallet: %@", error);
		return FALSE;
	}

	
	return TRUE;
}

//===========================================================
- (NSDictionary*) changeCurrency:(int)units forType:(NSString*)currencyType
{
	NSDictionary* walletBalances = [self openWallet];
	if(!walletBalances) {
		WRErrorLog(@"ERROR: cannot update currency");
		return NULL;
	}
	
	NSMutableDictionary* mutableWallet = [NSMutableDictionary dictionaryWithDictionary:walletBalances];
	
	NSNumber* nCurAmount = mutableWallet[currencyType];
	//NSAssert1(nCurAmount, @"Currency doesnt exist: %@", currencyType);
	if(!nCurAmount) {
		mutableWallet[currencyType] = @(0);
		nCurAmount = mutableWallet[currencyType];
	}
	
	int curAmount = [nCurAmount intValue];
	curAmount += units;
	
	// make sure we didn't go negative
	if(curAmount < 0) {
		curAmount = 0;
	}
	
	mutableWallet[currencyType] = @(curAmount);
	
	BOOL ok = [self saveWallet:mutableWallet];
	if(!ok) {
		WRErrorLog(@"ERROR: cannot update currency (4)");
		return NULL;
	}
	
	return mutableWallet;
	
}


#pragma mark - public utils
//===========================================================
- (NSDictionary*) addCurrency:(int)units forType:(NSString*)currencyType
{
	NSAssert(units >= 0, @"addCurrency - units must be >= 0");
	NSAssert(currencyType != NULL, @"you must specify a currency type");
	
	NSDictionary* balances = [self changeCurrency:units forType:currencyType];
	return balances;
}
//===========================================================
- (NSDictionary*) deductCurrency:(int)units forType:(NSString*)currencyType
{
	NSAssert(units >= 0, @"addCurrency - units must be >= 0");
	NSAssert(currencyType != NULL, @"you must specify a currency type");
	
	NSDictionary* balances = [self changeCurrency:(-units) forType:currencyType];
	return balances;
}
//===========================================================
- (NSDictionary*) getWalletBalances
{
	NSDictionary* walletBalances = [self openWallet];
	if(!walletBalances) {
		WRErrorLog(@"ERROR: cannot update currency");
		return NULL;
	}
	
	return walletBalances;
}
//===========================================================
- (int) getBalanceForType:(NSString*)currencyType
{
	NSDictionary* balances = [self getWalletBalances];
	if(!balances) {
		return 0;
	}
	
	NSNumber* nBalance = [balances objectForKey:currencyType];
	if(!nBalance) {
		return 0;
	}
	
	return([nBalance intValue]);
}

//===========================================================
// This is solely used for testing and debugging purposes
- (void) resetWallet
{

#if DEBUG
	NSError __autoreleasing *error;
	
	NSString* appBundleId = [[NSBundle mainBundle] bundleIdentifier];
	BOOL ok = [self deletePasswordForService:appBundleId account:kWRBWallet_balances error:&error];
	if(!ok) {
		WRErrorLog(@"Error resetting wallet: %@", error);
		return;
	}
	
	//[self initializeOnce];

#endif

}

#pragma mark - authorizations

//===========================================================
- (BOOL) hasAmount:(int)amount ofCurrency:(NSString*)currencyType
{
	// make sure the user can purchase this
	NSDictionary* balances = [self getWalletBalances];
	
	NSNumber* nCurAmount = balances[currencyType];
	if(!nCurAmount) {
		WRErrorLog(@"Currency %@ does not exist", currencyType);
		return FALSE;
	}
	
	int curAmount = [nCurAmount intValue];
	if(curAmount - amount < 0) {
		WRErrorLog(@"Not enough currency.  User has %d.  Wanted to deduct %d", curAmount, amount);
		return FALSE;
	}
	
	return TRUE;
}
//===========================================================
- (BOOL) addAuthorization:(NSString*)key forCurrency:(NSString*)currencyType amount:(int)amount
{
	if(![self hasAmount:amount ofCurrency:currencyType]) {
		return FALSE;
	}
	
	NSDictionary* newBalance = [self changeCurrency:-(amount) forType:currencyType];
	if(newBalance == NULL) {
		return FALSE;
	}
	[self addAuthorization:key];
	 
	return TRUE;
	
}
//===========================================================
- (void) addAuthorization:(NSString*)key
{

	// see if user is authorized
	if([self hasAuthorization:key]) {
		return;
	}
	
	// get the key and create a salted key where its key..UUID
	NSString* uuid = [WRBackend sharedManager].mUUID;
	NSString* hashKey = [NSString stringWithFormat:@"%@_and_%@", key, uuid];
	
	// hash it
	NSString* appBundleID = [[NSBundle mainBundle] bundleIdentifier];
	NSString* hashedAuth = [WRUtils sha256:hashKey];
	
	// save to keychain
	[self setPassword:hashedAuth forService:appBundleID account:key error:NULL];

}
//===========================================================
- (BOOL) hasAuthorization:(NSString*)key
{

	// get the hash from the keychain
	NSString* appBundleID = [[NSBundle mainBundle] bundleIdentifier];
	NSString* curHash = [self passwordForService:appBundleID account:key error:NULL];
	if([NSString isEmptyString:curHash]) {
		return FALSE;
	}
	
	// create the salt+key
	NSString* appUUID = [WRBackend sharedManager].mUUID;
	NSString* hashKey = [NSString stringWithFormat:@"%@_and_%@", key, appUUID];
	NSString* hashedAuth = [WRUtils sha256:hashKey];
	
	// compare
	if([curHash isEqualToString:hashedAuth]) {
		return TRUE;
	}
	
	return FALSE;
}
//===========================================================
- (void) removeAuthorization:(NSString*)key;
{

	NSString* appBundleID = [[NSBundle mainBundle] bundleIdentifier];
	BOOL ok = [SSKeychain deletePasswordForService:appBundleID account:key error:NULL];
	NSLog(@"removing authorization: %@", ok ? @"yes" : @"no");

}


#pragma mark - cross platform factoring


//===========================================================
- (BOOL)setPassword:(NSString *)password forService:(NSString *)service account:(NSString *)account error:(NSError**)error
{
	

#ifndef ANDROID
	return ([SSKeychain setPassword:password forService:service account:account error:error]);
#else
	
	// on android we will just write to preferences.  You need to do a backup.  Yes people can hack this for now.  Add encryption if you must

	
	NSString* key = [NSString stringWithFormat:@"%@.%@", service, account];
	NSString* encryptKey = [NSString stringWithFormat:@"%@%@", key, _mSalt];
	NSData* encryptData = [self encryptString:password withKey:encryptKey];
	
	[[NSUserDefaults standardUserDefaults] setObject:encryptData forKey:key];
	BOOL ok = [[NSUserDefaults standardUserDefaults] synchronize];
	return ok;
#endif
}

//===========================================================
- (NSString*) passwordForService:(NSString*)service account:(NSString*)account error:(NSError**)error
{
#ifndef ANDROID
	return [SSKeychain passwordForService:service account:account error:error];
#else
	NSString* key = [NSString stringWithFormat:@"%@.%@", service, account];
	NSString* encryptKey = [NSString stringWithFormat:@"%@%@", key, _mSalt];
	NSData* retObj = (NSData*) [[NSUserDefaults standardUserDefaults] objectForKey:key];
	
	NSString* retStr = [self decryptData:retObj withKey:encryptKey];
	
	return retStr;
	
#endif
}

//===========================================================
- (BOOL)deletePasswordForService:(NSString *)service account:(NSString *)account error:(NSError **)error
{
#ifndef ANDROID
	return([SSKeychain deletePasswordForService:service account:account error:error]);
#else
	
	NSString* key = [NSString stringWithFormat:@"%@.%@", service, account];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
	
	BOOL ok = [[NSUserDefaults standardUserDefaults] synchronize];
	return ok;
	
#endif
}

// for working with encrypting decryption
- (NSData*) encryptString:(NSString*)plaintext withKey:(NSString*)key {
	return [[plaintext dataUsingEncoding:NSUTF8StringEncoding] AES256EncryptWithKey:key];
}

- (NSString*) decryptData:(NSData*)ciphertext withKey:(NSString*)key {

	return [[NSString alloc] initWithData:[ciphertext AES256DecryptWithKey:key]  encoding:NSUTF8StringEncoding];
}



@end


