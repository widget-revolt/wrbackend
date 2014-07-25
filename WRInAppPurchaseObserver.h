//
//  WRInAppPurchaseObserver.h
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
#import <StoreKit/StoreKit.h>



// keys in json product def

#define kProductInfo_productId		@"product_id"
#define kProductInfo_name			@"name"
#define kProductInfo_description	@"description"
#define kProductInfo_iapType		@"iap_type"			// "managed" or "consumable"
	#define kIAPType_managed			@"managed"
	#define kIAPType_consumable			@"consumable"
#define kProductInfo_currencyType	@"currency_type"	// e.g "tokens", "tickets", "quatloos"
#define kProductInfo_currencyAmount	@"currency_amount"	// How much currency you get for buying
#define kProductInfo_rank			@"rank"				// rank (high to low) of display
#define kProductInfo_currentPrice	@"current_price"	// actual price
#define kProductInfo_suggestedPrice @"suggested_price"	// suggested price (without discount)
#define kProductInfo_highlight		@"highlight"		// text of special highlights to apply (e.g. Best Offer)

#define kNotification_inAppPurchaseSuccess	@"com.widgetrevolt.in_app_purchase_complete"


// Used in WRIAPPurchaseItemBlock as first argument
typedef enum
{
	
	eErr_purchaseOK = 0,
	eErr_purchaseCanceled = -1,
	eErr_managedPurchaseAlready = -2,	// this is a managed item the user has already purcahsed
	eErr_invalidProduct = -100,
	eErr_validationFailed = -101,
	eErr_validationOKTransactionFailed = -102,  // treat this as a failure as we will requeue the transaction
	eErr_internalErrorWalletFailed = -103,  // That currency doesn't exist or other bogusness
} EnumPurchaseErrors;

/////////////////////////////////////////////////////////////////

typedef void(^WRIAPGetInventoryBlock)(NSInteger err, NSArray* productList);
typedef void(^WRIAPPurchaseItemBlock)(NSInteger err, NSError* error, NSDictionary* transaction);
typedef void(^WRIAPRestoreCompleteBlock)(NSError* error);
typedef void(^WRIAPCheckReceiptCompleteBlock)(NSError* error, NSDictionary* resultDict);

/////////////////////////////////////////////////////////////////
@interface WRInAppPurchaseObserver : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>

// set this if the caller wants to provide inventory (as opposed to an online source)
//The format for fixed inventory looks something like this:
//  @[
//  @{ @"sku": @"wrairtestharness.test_2", @"name":@"test2"   },
//  @{ @"sku": @"wrairtestharness.test_1", @"name":@"test1"   },
//  @{ @"sku": @"wrairtestharness.test_NOFIND", @"name":@"Not available test"   },
//  @{ @"sku": @"non_consumable.1", @"name":@"Not available test"   },
//];
@property (nonatomic, strong) NSArray* mFixedInventory;
@property (nonatomic, strong, readonly) NSMutableArray* mAvailableProductsArray;

+ (WRInAppPurchaseObserver*) sharedManager;

//-- call these to register your observer.   You may immediately get events if transactions failed to complete
- (void) registerObserver:(WRIAPPurchaseItemBlock)callback;
- (void) removeObserver;

//-- inventory and purchase
- (void) getInventoryItems:(WRIAPGetInventoryBlock)callback;


	/// Call this to buy.  The callback returns an EnumPurchaseError as its first argument
- (void) purchaseItem:(NSString*)productId callback:(WRIAPPurchaseItemBlock)callback;

	/// this call is immediate and will only return info if getInventoryItems has been called.  You must be able handle a NULL response from this item
- (NSDictionary*) getInventoryItemInfo:(NSString*)productId;


//-- restoring transactions
- (void) restorePurchases:(WRIAPPurchaseItemBlock)callback completion:(WRIAPRestoreCompleteBlock)completion;

//-- checking receipts
- (void) checkReceipt:(WRIAPCheckReceiptCompleteBlock)callback;

@end
