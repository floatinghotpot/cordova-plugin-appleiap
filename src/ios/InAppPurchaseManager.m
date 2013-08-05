//
//  InAppPurchaseManager.m
//  beetight
//
//  Created by Matt Kane on 20/02/2011.
//  Copyright 2011 Matt Kane. All rights reserved.
//

#import "InAppPurchaseManager.h"

// Help create NSNull objects for nil items (since neither NSArray nor NSDictionary can store nil values).
#define NILABLE(obj) ((obj) != nil ? (NSObject *)(obj) : (NSObject *)[NSNull null])

@implementation InAppPurchaseManager

-(void) setup:(CDVInvokedUrlCommand *)command {
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

- (void) requestProductData:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult;
    NSString *callbackId = command.callbackId;
    NSArray* arguments = command.arguments;

	if([arguments count] < 1) {
		return;
	}
	NSLog(@"Getting product data");
	NSSet *productIdentifiers = [NSSet setWithObject:[arguments objectAtIndex:0]];
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];

	ProductsRequestDelegate* delegate = [[ProductsRequestDelegate alloc] init];
	delegate.command = self;
	delegate.callbackId = callbackId;

    productsRequest.delegate = delegate;
    [productsRequest start];
}

- (void) makePurchase:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult;
    NSString *callbackId = command.callbackId;
    NSArray* arguments = command.arguments;

    NSLog(@"About to do IAP");
	if([arguments count] < 1) {
		return;
	}

    SKMutablePayment *payment = [SKMutablePayment paymentWithProductIdentifier:[arguments objectAtIndex:0]];

	if([arguments count] > 1) {
		id quantity = [arguments objectAtIndex:1];
		if ([quantity respondsToSelector:@selector(integerValue)]) {
			payment.quantity = [quantity integerValue];
		}
	}
	[[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void) restoreCompletedTransactions:(CDVInvokedUrlCommand *)command
{
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

// SKPaymentTransactionObserver methods
// called when the transaction status is updated
//
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
	NSString *state;
    for (SKPaymentTransaction *transaction in transactions) {
		state = @"";
        switch (transaction.transactionState) {
			case SKPaymentTransactionStatePurchasing:
				continue;

            case SKPaymentTransactionStatePurchased:
				state = @"PaymentTransactionStatePurchased";
				NSString *jsString =
						@"cordova.fireDocumentEvent('onInAppPurchaseSuccess',"
						@"{ 'productId': '%@', 'transactionId': '%@', 'transactionReceipt' : '%@' });";
				[self writeJavascript:[NSString stringWithFormat:jsString,
				                       transaction.payment.productIdentifier,
				                       transaction.transactionIdentifier,
				                       [[transaction transactionReceipt] base64EncodedString]]];
                break;

			case SKPaymentTransactionStateFailed:
				state = @"PaymentTransactionStateFailed";
				NSString *jsString =
					@"cordova.fireDocumentEvent('onInAppPurchaseFailed',"
					@"{ 'errorCode': '%@', 'errorMsg' : '%@' });";
				[self writeJavascript:[NSString stringWithFormat:jsString,
				                       transaction.error.code,
				                       transaction.error.localizedDescription]];
                break;

			case SKPaymentTransactionStateRestored:
				state = @"PaymentTransactionStateRestored";
				NSString *jsString =
						@"cordova.fireDocumentEvent('onInAppPurchaseRestored',"
						@"{ 'productId': '%@', 'transactionId': '%@', 'transactionReceipt' : '%@' });";
				[self writeJavascript:[NSString stringWithFormat:jsString,
				                       transaction.originalTransaction.payment.productIdentifier,
				                       transaction.originalTransaction.transactionIdentifier,
				                       [[transaction transactionReceipt] base64EncodedString];
				break;

            default:
				NSLog(@"Invalid state");
                continue;
        }
		NSLog(@"state: %@", state);

		[[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }

	[self writeJavascript:@"cordova.fireDocumentEvent('onInAppPurchaseFinished');"];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
	NSString *jsString =
		@"cordova.fireDocumentEvent('onRestoreCompletedTransactionsFailed',"
		@"{ 'errorCode': '%@', 'errorMsg' : '%@' });";
	[self writeJavascript:[NSString stringWithFormat:jsString, error.code, error.localizedDescription]];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
	[self writeJavascript:
	@"cordova.fireDocumentEvent('onRestoreCompletedTransactionsFinished');"];
}

@end

@implementation ProductsRequestDelegate

@synthesize command, callbackId;

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	NSLog(@"got iap product response");

	NSMutableArray * validProducts = [NSMutableArray array];
    for (SKProduct *product in response.products) {
    	NSDictionary * item = [NSDictionary dictionaryWithObjectsAndKeys:
    	                                  NILABLE(product.productIdentifier), @"id",
    	                                  NILABLE(product.localizedTitle), @"title",
    	                                  NILABLE(product.localizedDescription), @"description",
    	                                  NILABLE(product.localizedPrice), @"price",
    	                                  nil];
    	[validProducts addObject:item];
    }

    NSDictionary * reply = [NSDictionary dictionaryWithObjectsAndKeys:
                            validProducts, @"validProducts",
                            NILABLE(response.invalidProductIdentifiers), @"invalidIds",
                            nil];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:reply];
	[command.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];

	request.delegate = nil;
	request = nil;
	response = nil;
}

- (void) dealloc
{
	callbackId = nil;
    command = nil;
}


@end

