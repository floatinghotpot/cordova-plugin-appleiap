//
//  InAppPurchaseManager.h
//  beetight
//
//  Created by Matt Kane on 20/02/2011.
//  Copyright 2011 Matt Kane. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/NSData+Base64.h>

#import "SKProduct+LocalizedPrice.h"

@interface InAppPurchaseManager : CDVPlugin <SKPaymentTransactionObserver> {

}
- (void) setup:(CDVInvokedUrlCommand *)command;
- (void) requestProductData:(CDVInvokedUrlCommand *)command;
- (void) makePurchase:(CDVInvokedUrlCommand *)command;
- (void) restoreCompletedTransactions:(CDVInvokedUrlCommand *)command;

- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;
- (void) paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error;
- (void) paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue;

@end

@interface ProductsRequestDelegate : NSObject <SKProductsRequestDelegate>{
	InAppPurchaseManager* command;
	NSString* callbackId;
}

@property (nonatomic, retain) InAppPurchaseManager* command;
@property (nonatomic, copy) NSString* callbackId;

@end;

