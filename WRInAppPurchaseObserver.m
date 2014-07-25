//
//  WRInAppPurchaseObserver.m
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



#import "WRInAppPurchaseObserver.h"



#import "WRUUID.h"
#import "AFNetworking.h"
#import "WRBackend.h"
#import "WRBHttpClient.h"
#import "WRLib.h"
#import "AnalyticsHelper.h"

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#define kWRIAPErrDomain  @"com.widgetrevolt.wrbackend.wrinapppurchaseobserver"


static WRInAppPurchaseObserver* gSharedInstance_wrInAppPurchaseObserver = NULL;

//this hack is to make the xcode function parser not break!
#if WRB_USE_AFNETWORKING20
#define	AFN_POST_METHOD		POST
#else
#define	AFN_POST_METHOD		postPath
#endif


#ifdef zAPPORTABLE

@interface SKPaymentQueue(WRApportable)
- (BOOL)consumePurchase:(SKPaymentTransaction *)transaction;
@end

#endif

//////////////////////////////////////////////////////////////////
@interface WRInAppPurchaseObserver ()

// strong refs
@property (nonatomic, strong, readwrite) NSMutableArray* mAvailableProductsArray;
@property (nonatomic, strong) NSArray* mInventoryArray;	// this is the list of items on our server
@property (nonatomic, strong) NSArray* mProductArray;
@property (nonatomic, strong) SKProductsRequest* mProductRequest;

@property (nonatomic, assign) BOOL mRegistered;

// blocks
@property (readwrite, nonatomic, copy) WRIAPGetInventoryBlock bGetInventoryCallback;
@property (readwrite, nonatomic, copy) WRIAPPurchaseItemBlock bPurchaseItemCallback;
@property (readwrite, nonatomic, copy) WRIAPPurchaseItemBlock bRestoreItemCallback;
@property (readwrite, nonatomic, copy) WRIAPRestoreCompleteBlock bRestoreCompleteCallback;
@end

//////////////////////////////////////////////////////////////////
@implementation WRInAppPurchaseObserver

#pragma mark - Object lifecycle

//==============================================================
+ (WRInAppPurchaseObserver*) sharedManager
{
	static dispatch_once_t onceQueue;
	
    dispatch_once(&onceQueue, ^{
        gSharedInstance_wrInAppPurchaseObserver = [[WRInAppPurchaseObserver alloc] init];
    });
	
    return gSharedInstance_wrInAppPurchaseObserver;
}
//===========================================================
- (id) init
{
	self = [super init];
	if(self)
	{
		_mRegistered = FALSE;
	
		self.bGetInventoryCallback = NULL;
		self.bPurchaseItemCallback = NULL;
		self.bRestoreItemCallback = NULL;
		self.bRestoreCompleteCallback = NULL;
		
		self.mFixedInventory = NULL;	// set this to NULL.  Let caller supply
		
		self.mInventoryArray = [NSMutableArray array];
		self.mAvailableProductsArray = [NSMutableArray array];
		self.mProductArray = [NSArray array];
	}
	
	return self;
}

//===========================================================
- (void) dealloc
{
	// release strong refs
	self.mInventoryArray = NULL;
	self.mAvailableProductsArray = NULL;
	self.mProductArray = NULL;
	self.mFixedInventory = NULL;
	

}

#pragma mark - registration

//===========================================================
- (void) registerObserver:(WRIAPPurchaseItemBlock)callback;
{
	if(_mRegistered) {
		WRErrorLog(@"ERROR: The inapp purchase observer is already registered");
		return;
	}
	
	self.bRestoreItemCallback = callback;
	
	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
	_mRegistered = TRUE;
	
	
	
#ifdef ANDROID

	//on IABv3, restoring purchases is cheap.
	//we should do this to find any consumable purchases that are consumable
	//and consume them before the user buys again to prevent errors
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
#endif

}
//===========================================================
- (void) removeObserver
{
	if(!_mRegistered) {
		WRErrorLog(@"ERROR: The inapp purchase observer is not registered");
		return;
	}
	
	[[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
	_mRegistered = FALSE;
}

#pragma mark - Getting Inventory


//===========================================================
- (void) updateInventory
{
	
	NSString* uuid = [WRUUID getAppUUID];
	NSString* uuidHash = [WRUUID getAppUUIDHash];
	
	
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	NSDictionary* paramDict = @{
								@"uuid": uuid,
								@"auth": uuidHash
								};
	
	__weak __typeof__(self) bself = self;
	NSString* urlStr = [[WRBackend sharedManager] createApiUrl:kBackendAPI_getInventory];
	

	

	[httpClient AFN_POST_METHOD:urlStr parameters:paramDict success:^(AFHTTPRequestOperation* operation, id jsonObj)
				  {
								  
								  NSDictionary* jsonDict = (NSDictionary*) jsonObj;
								  NSString* result = jsonDict[@"result"];
								  if([result isEqualToString:@"ok"])
								  {
									  // save the inventory array
									  NSDictionary* data = jsonDict[@"data"];
									  NSArray* inventory = data[@"items"];
									  bself.mInventoryArray = inventory;
									  
									  // and rerun the itms product request to resync items
									  
									  [bself startITMSProductsRequest];
									  
								  }
				}
				failure:^(AFHTTPRequestOperation *operation, NSError *error)
				  {
					  
#if WRB_USE_AFNETWORKING20
					  id jsonObj = operation.responseObject;
#else
					  id jsonObj = [(AFJSONRequestOperation *)operation responseJSON];
#endif
					  
					  NSDictionary* jsonDict = (NSDictionary*) jsonObj;
					  NSString* str = [NSString stringWithFormat:@"Error: %@\nJSON:\n%@", error, jsonDict];
					  WRErrorLog(@"%@", str);
					  
					  
					  NSString* exceptionStr = [NSString stringWithFormat:@"IAP getInventory failure: %@", error];
					  [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
					  
					  if(_bGetInventoryCallback) {
						  _bGetInventoryCallback(error.code, NULL);
					  }
					  
					  
				  }];
}
//===========================================================
// 
- (NSDictionary*) getInventoryItemInfo:(NSString*)productId
{
	// if the available products array has not been populated then we need to do that first
	if([_mAvailableProductsArray count] == 0) {
		return NULL;
	}
	
	for(NSDictionary* dict in _mAvailableProductsArray)
	{
		if([dict[@"product_id"] isEqualToString:productId])
		{
			return dict;
		}
	}
	
	return NULL;

}
//===========================================================
- (void) getInventoryItems:(WRIAPGetInventoryBlock)callback
{
	self.bGetInventoryCallback = callback;
	
	// if the user assigned inventory use that
	if(_mFixedInventory)
	{
		self.mInventoryArray = _mFixedInventory;
		
		// now make the ITMS request
		[self startITMSProductsRequest];
	}
	else
	{
		[self updateInventory];
	}
	
	

}
//===========================================================
// asks the ITMS server for products list
- (void) startITMSProductsRequest
{
	
    WRTraceLog(@"--");
    
    NSMutableArray* productIDList = [NSMutableArray array];
    
    for(NSDictionary* dataDict in _mInventoryArray)
    {
        NSString* productID = [dataDict objectForKey:@"product_id"];
        
        // prepend info
        [productIDList addObject:productID];
    }
	
	
    NSSet* itemIDSet = [NSSet setWithArray:productIDList];
    
	self.mProductRequest= [[SKProductsRequest alloc] initWithProductIdentifiers:itemIDSet];
	self.mProductRequest.delegate = self;
	[_mProductRequest start];
	
	WRDebugLog(@"SKProducts request started");
}

//===========================================================
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	WRTraceLog(@"--");
    WRDebugLog(@"Product request result: %@", response.products);
    WRDebugLog(@"Invalid product ids: %@", response.invalidProductIdentifiers);
    
    // create a new dictionary for the json response with products
    NSMutableArray* availableArray = [NSMutableArray array];
    
    // save the product array
    self.mProductArray = response.products;
	
	// we need to merge the two sets and get the intersection, then do some additional populating so
	// we can get things like formatted price.
    NSArray* responseArray = response.products;
    for(NSDictionary* dataDict in _mInventoryArray)
    {
        NSString* productID = [dataDict objectForKey:@"product_id"];
        SKProduct* foundProduct = NULL;
        for(SKProduct* product in responseArray)
        {
            if([product.productIdentifier isEqualToString:productID])
            {
                foundProduct = product;
                break;
            }
        }
        
        
        // We HAVE to create a composite dict.  The pricing that is accurate must come from the app store.  The rest can come from
        // the original dict
        if(foundProduct)
        {
            NSMutableDictionary* massagedDict = [NSMutableDictionary dictionaryWithDictionary:dataDict];
            
			
            NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
            [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
            [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
            [numberFormatter setLocale:foundProduct.priceLocale];
            NSString* formattedString = [numberFormatter stringFromNumber:foundProduct.price];
			
			NSString* currencyCode = [foundProduct.priceLocale objectForKey:NSLocaleCurrencyCode];
			
			// Override the price so we dispaly what is coming from ITMS and not our server
			massagedDict[@"price"] = foundProduct.price;
			massagedDict[@"formattedPrice"] = formattedString;
			massagedDict[@"currency_code"] = currencyCode;


            // add the dict
            [availableArray addObject:massagedDict];
        }
    }
	
	// save it
	self.mAvailableProductsArray = availableArray;
    
	// Awesome - now lets callback our block
    if(_bGetInventoryCallback)
	{
		_bGetInventoryCallback(0, _mAvailableProductsArray);
	}
    
    
	// dealloc the request
	self.mProductRequest = NULL;
}

//===========================================================
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
	
    WRTraceLog(@"--");
    
    WRErrorLog(@"ERROR making ITC request: %@", error);
	
	NSInteger errCode = [error code];
	if(_bGetInventoryCallback)
	{
		_bGetInventoryCallback(errCode, NULL);
	}

	
	// clean up
	self.mProductRequest = NULL;
	
}

#pragma mark - purchasing



//===========================================================
- (void) purchaseItem:(NSString*)sku callback:(WRIAPPurchaseItemBlock)callback
{
	 WRTraceLog(@"--");

	// if the available products array has not been populated then we need to do that first
	if([_mAvailableProductsArray count] == 0)
	{
		__weak __typeof__(self) bself = self;
		[self getInventoryItems:^(NSInteger err, NSArray *productList) {
			[bself purchaseProduct:sku callback:callback];
		}];
	}
	else
	{
		[self purchaseProduct:sku callback:callback];
	}
}
//===========================================================
// inner method - only gets called after inventory is loaded for sure
- (void) purchaseProduct:(NSString*)sku callback:(WRIAPPurchaseItemBlock)callback
{
	 WRTraceLog(@"--");

	self.bPurchaseItemCallback = callback;

	// ensure we have the item in the list, else callback with an error
	SKProduct* foundProduct = NULL;
	for(SKProduct* product in _mProductArray)
	{
		if([product.productIdentifier isEqualToString:sku]) {
			foundProduct = product;
			break;
		}
	}
	
	// callback if not found
	if(!foundProduct)
	{
		int errCode = eErr_invalidProduct;
		[self performSelector:@selector(callPurchaseErrorBlock:) withObject:@(errCode)];
		return;
	}
	
	// now buy the darn thing
	SKPayment* payment = [SKPayment paymentWithProduct:foundProduct];
	[[SKPaymentQueue defaultQueue] addPayment:payment];
}
//===========================================================
- (void) callPurchaseErrorBlock:(NSNumber*)nErrCode
{
	 WRTraceLog(@"--");

	if(_bPurchaseItemCallback)
	{
		_bPurchaseItemCallback([nErrCode intValue], NULL, NULL);
	}
}

#pragma mark - restoration

//===========================================================
- (void) restorePurchases:(WRIAPPurchaseItemBlock)callback completion:(WRIAPRestoreCompleteBlock)completion
{
	self.bPurchaseItemCallback = callback;
	self.bRestoreCompleteCallback = completion;

	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - receipt check

//===========================================================
- (void) checkReceipt:(WRIAPCheckReceiptCompleteBlock)callback
{

	
	NSError* err;
	
	
	//Get the receipt URL
    NSURL* receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
	if(!receiptURL) {
		err = MAKE_NSERROR(kWRIAPErrDomain, -1, @"no receipt URL");
		callback(err, NULL);
		return;
	}
	
	// if not exists error
	if (![[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]) {
		err = MAKE_NSERROR(kWRIAPErrDomain, -1, @"receipt doesnt yet exist at path");
		callback(err, NULL);
		return;
	}
	
	
	//Encapsulate the base64 encoded receipt on NSData
	NSData* receiptData = [NSData dataWithContentsOfFile:receiptURL.path];
	NSString* base64Receipt = [receiptData base64EncodedString:FALSE];
	
	//Prepare the request to send "receipt-data:[the receipt]" via POST method as json object
	NSString* urlStr = @"https://buy.itunes.apple.com/verifyReceipt"; //PROD
	
#if DEBUG
	urlStr = @"https://sandbox.itunes.apple.com/verifyReceipt";//sandbox
#endif
	
	NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlStr]];
	[request setHTTPMethod:@"POST"];
	
	NSDictionary* requestDic = [NSDictionary dictionaryWithObject:base64Receipt forKey:@"receipt-data"];
	
	NSData* jsonData = [NSJSONSerialization dataWithJSONObject:requestDic options:0 error:nil];
	[request setHTTPBody:jsonData];
	
	// Send the request
	
	NSOperationQueue* queue = [[NSOperationQueue alloc] init];
	[NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError){
		
		
		NSError* cbErr;
		if (!data) {
			NSString* errStr = [NSString stringWithFormat:@"Error connecting to receipt verification server:%@", connectionError];
			cbErr = MAKE_NSERROR(kWRIAPErrDomain, -1, errStr);
			callback(cbErr, NULL);
			return; //A connection error ocurred
		}
		
		//Get a NSDictionary from the json object
		
		NSError* parseError;
		
		NSDictionary* responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&parseError];
		
		if (!responseDict)
		{
			NSString* errStr = [NSString stringWithFormat:@"Error parsing json response from verificaiton server:%@", connectionError];
			cbErr = MAKE_NSERROR(kWRIAPErrDomain, -1, errStr);
			callback(cbErr, NULL);
			return; //A connection error ocurred
		}
		
		// yay - pass the result
		callback(NULL, responseDict);
		
		
	}];
	
    
}


#pragma mark - IAP observer

//===========================================================
- (void)paymentQueue:(SKPaymentQueue*)queue updatedTransactions:(NSArray*)transactions
{
	WRTraceLog(@"--");
	
	for (SKPaymentTransaction *transaction in transactions)
	{
		WRDebugLog(@"-- WRIAPObserver: transaction %@ state: %ld", [transaction transactionIdentifier], (long)transaction.transactionState);
		WRDebugLog(@"-- WRIAPObserver: transaction: %@", transaction);
		
		switch (transaction.transactionState)
		{
			case SKPaymentTransactionStatePurchased:
			{
				[self completeTransaction:transaction];
			}
			break;
			
			case SKPaymentTransactionStateFailed:
			{
				[self failedTransaction:transaction];
				if (transaction.error.code!=SKErrorPaymentCancelled) {
					[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
				}
			}
			break;
			
			case SKPaymentTransactionStateRestored:
			{
				[self restoreTransaction:transaction];
			}
			break;
			
			default:
			 break;
		}
	}
}

//===========================================================
- (void) completeTransaction: (SKPaymentTransaction*)transaction
{
	WRTraceLog(@"--");
	WRDebugLog(@"WRIAPObserver: completing transaction: %@", transaction.transactionIdentifier);
    
	// tell the services to validate the transaction
	[self verifyTransaction:transaction];
}

//===========================================================
- (void) restoreTransaction:(SKPaymentTransaction *)transaction
{
    WRTraceLog(@"--");
	
	NSString* productID = transaction.originalTransaction.payment.productIdentifier;
	#pragma unused(productID)
	WRDebugLog(@"WRIAPObserver: InApp purchase observer: restoring transaction - %@, id=%@", productID, transaction.transactionIdentifier);
	
	// call the server to validate the transaction
    [self completeTransaction:transaction];
}
//=======================================================================================
- (void) failedTransaction: (SKPaymentTransaction *)transaction
{	
	WRTraceLog(@"--");
    
	BOOL hasError = FALSE;
    if (transaction.error.code != SKErrorPaymentCancelled)
    {
        // Optionally, display an error here.
		hasError = TRUE;
    }
	
	NSInteger errorCode = transaction.error.code;
	if (transaction.error.code == SKErrorPaymentCancelled)
	{
		errorCode = eErr_purchaseCanceled;
	}
	
	// remove from the payment queue
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];


	// call the callback
	if(_bPurchaseItemCallback)
	{
		_bPurchaseItemCallback(errorCode, transaction.error, NULL);
	}
    
}

//=======================================================================================
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    WRTraceLog(@"--");
	
	if(_bRestoreCompleteCallback) {
		_bRestoreCompleteCallback(error);
	}
	
}
//=======================================================================================
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    WRTraceLog(@"--");

	if(_bRestoreCompleteCallback) {
		_bRestoreCompleteCallback(NULL);
	}
	
}

#pragma mark - server verification

//==============================================================
- (void) verifyTransaction:(SKPaymentTransaction*) transaction
{
	WRTraceLog(@"--");
	
	// lookup the price if we can from the productIdentifider
	double price = 0.0;
	NSDictionary* productInfo = [self getInventoryItemInfo:transaction.payment.productIdentifier];
	if(productInfo)
	{
		NSDecimalNumber* nPrice = productInfo[@"price"];
		if(nPrice) {
			price = [nPrice doubleValue];
		}
	}
	
	// encode the receipt as base64
	NSString* uuid = [WRUUID getAppUUID];
	NSString* uuidHash = [WRUUID getAppUUIDHash];
	
	
#ifdef ANDROID


	WRDebugLog(@"WRIAPObserver: validating android receipt");
	
	//ANDROID
	NSError* error;
	
	
	
	NSString* purchaseData = @"INVALID";
	NSString* signature = @"INVALID";
	NSDictionary* transactionDict = [NSJSONSerialization JSONObjectWithData:transaction.transactionReceipt options:0 error:&error];
	if(transactionDict)
	{
		purchaseData = transactionDict[SKPaymentTransactionReceiptSignedData];
		signature = transactionDict[SKPaymentTransactionReceiptSignature];
	}
	else
	{
		WRErrorLog(@"WRIAPObserver: invalid android json dict: %@", error);
	}
	
	
	// Debugging
	WRDebugLog(@"transaction purchaseData:%@", purchaseData);
	WRDebugLog(@"transaction signature:%@", signature);

	NSDictionary* paramDict = @{
								@"uuid": uuid,
								@"auth": uuidHash,
								@"signature": signature,
								@"purchase_data": purchaseData,
								@"price": @(price)
								};
	
	NSString* urlPath = [[WRBackend sharedManager] createApiUrl:kBackendAPI_verifyReceiptAndroid];

#else

	//IOS
	NSString* encodedReceipt = [transaction.transactionReceipt base64EncodedString:FALSE];
	
	// Debugging
	WRDebugLog(@"trnasaction product id:%@", transaction.payment.productIdentifier);
	WRDebugLog(@"transaction id: %@", transaction.transactionIdentifier);
	WRDebugLog(@"transaction date: %@", transaction.transactionDate);
	WRDebugLog(@"transaction receipt:\n%@", encodedReceipt);

	NSDictionary* paramDict = @{
		@"uuid": uuid,
		@"auth": uuidHash,
		@"receipt": encodedReceipt,
		@"price": @(price)
		};
		
	NSString* urlPath = [[WRBackend sharedManager] createApiUrl:kBackendAPI_verifyReceipt];
	
#endif
	
	WRBHttpClient* httpClient = [WRBHttpClient sharedManager];
	__weak __typeof__(self) bself = self;
	


	 [httpClient AFN_POST_METHOD:urlPath
			   parameters:paramDict
				  success:^(AFHTTPRequestOperation* operation, id jsonObj)

		  {
			  NSDictionary* jsonDict = (NSDictionary*) jsonObj;
			  
#ifdef APPORTABLE
			  [self consumeTransactionIfNeeded:transaction productInfo:productInfo];
#endif
			  
			  [bself handleVerifyReceiptComplete:NULL result:jsonDict transaction:transaction];

		  }
		  failure:^(AFHTTPRequestOperation *operation, NSError *error)
		  {
#if WRB_USE_AFNETWORKING20
			  id jsonObj = operation.responseObject;
#else
			  id jsonObj = [(AFJSONRequestOperation *)operation responseJSON];
#endif

#ifdef APPORTABLE
			  [self consumeTransactionIfNeeded:transaction productInfo:productInfo];
#endif

			  NSDictionary* jsonDict = (NSDictionary*) jsonObj;
			  NSString* str = [NSString stringWithFormat:@"Error: %@\nJSON:\n%@", error, jsonDict];
			  WRErrorLog(@"%@", str);
			  
			  NSString* exceptionStr = [NSString stringWithFormat:@"WRIAPObserver verifyReceipt failure: %@", error];
			  [[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_apiFailure errParam:exceptionStr];
			  
			  [bself handleVerifyReceiptComplete:error result:NULL transaction:transaction];

		  }
	 ];


}
//===========================================================
- (void) consumeTransactionIfNeeded:(SKPaymentTransaction*)transaction productInfo:(NSDictionary*)productInfo
{
#ifdef APPORTABLE
	BOOL managed = FALSE;
	if(productInfo)
	{
		NSString* iapType = productInfo[@"iap_type"];
		if(iapType && [iapType isEqualToString:@"managed"]) {
			managed = TRUE;
		}
	}
	
	if(!managed)
	{
		WRDebugLog(@"WRIAPObserver: consuming transaction: %@", transaction);
		
//		BOOL isConsumed = [[SKPaymentQueue defaultQueue] consumePurchase:transaction];
//		WRInfoLog(@"Consumed transaction: %c", isConsumed);
	}
#endif
}

//===========================================================
#define kResult_ok								@"ok"
#define kResult_errOKRevalidated				@"ok_revalidated"
#define kResult_errIAPInvalid					@"err_iap_invalid"
#define kResult_errIAPTransactionSaveFailed		@"err_iap_transaction_save_fail"  // this means the IAP worked but the transaction failed to save.  The client can err out or treat as ok

- (void) handleVerifyReceiptComplete:(NSError*)error result:(NSDictionary*)jsonResult transaction:(SKPaymentTransaction*)transaction
{
	// resolve to the correct callback.  Give precedence to an immediate handler
	WRIAPPurchaseItemBlock callback = _bPurchaseItemCallback;
	if(!callback) {
		callback = _bRestoreItemCallback;
	}

	if(error)
	{
		//NOTE: call back but don't mark as compelte.  This is an error on our http server that we want to correct
		if(callback) {
			callback([error code], error, NULL);
		}
		
		return;
	}
	
	WRDebugLog(@"----------\nVerify Result:\n%@\n----------\n", jsonResult);
	
	// check the json result
	NSString* result = jsonResult[@"result"];
	

	if([result isEqualToString:kResult_ok] || [result isEqualToString:kResult_errOKRevalidated])
	{
		// get the inventory info
		NSDictionary* transactionData = jsonResult[@"data"];
		NSString* productId = transaction.payment.productIdentifier;
		NSDictionary* invItemDict = [self getInventoryItemInfo:productId];
		NSString* iapType = invItemDict[kProductInfo_iapType];
		
		// managed is ok either way.  A consumable purcahse is only good if result=ok
		int callbackErr = eErr_validationFailed;
		if([iapType isEqualToString:kIAPType_managed])
		{
			callbackErr = eErr_purchaseOK;
			if([result isEqualToString:kResult_errOKRevalidated]) {
				callbackErr = eErr_managedPurchaseAlready;
			}
			
			// authorize the item
			[[WRBackend sharedManager].mWallet addAuthorization:productId];
		}
		else
		{
			// consumable
			if([result isEqualToString:kResult_ok])
			{
				callbackErr = eErr_purchaseOK;
				
				// add the item to the wallet
				NSString* currencyType = invItemDict[kProductInfo_currencyType];
				NSNumber* currencyAmount = invItemDict[kProductInfo_currencyAmount];
				if(currencyType && currencyAmount)
				{
				
					int units = [currencyAmount intValue];
					NSDictionary* newWallet = [[WRBackend sharedManager].mWallet addCurrency:units forType:currencyType];
					if(!newWallet) {
						callbackErr = eErr_internalErrorWalletFailed;
					}
				}
			}
		}
		
		// make the callback
		if(callback) {
			callback(callbackErr, NULL, transactionData);
		}
		
		// always mark these as cleared - we don't want fake purchases spamming our verificatino
		[[SKPaymentQueue defaultQueue] finishTransaction: transaction];
		
		
		// Broadcast to anyone who cares
		NSDictionary* userInfo = @{ @"result": @(callbackErr) };
		[[NSNotificationCenter defaultCenter] postNotificationName:kNotification_inAppPurchaseSuccess object:NULL userInfo:userInfo];

		// mark as monetizer
		[[WRBackend sharedManager].mUser setIsMonetizer];
		
		
		//analytics
		if(callbackErr == eErr_purchaseOK )
		{
			if(invItemDict)
			{
				NSDecimalNumber* nsdPrice = invItemDict[@"price"];
				NSString* currencyCode = invItemDict[@"currency_code"];
				if(nsdPrice && currencyCode)
				{

					NSString* name = invItemDict[@"name"];
					double price = [nsdPrice doubleValue];
					[[AnalyticsHelper sharedManager] trackPurchase:productId
															  name:name
															 price:price
														  quantity:1
													 transactionId:transaction.transactionIdentifier];
					
				}
			}
		}

		
	}
	else
	{
		// post this event to analytics
		NSString* exceptionStr = [NSString stringWithFormat:@"IAP validation failure: %@", result];
		[[AnalyticsHelper sharedManager] trackCaughtException:kAnalError_iapValidationFailure errParam:exceptionStr];

		
		// translate our errors and make a callback
		int err = eErr_validationFailed;
		if([result isEqualToString:kResult_errIAPTransactionSaveFailed]) {
			err = eErr_validationOKTransactionFailed;
			
		}
		
		if(callback) {
			callback(err, NULL, NULL);
		}

	}
	


	
}


@end
