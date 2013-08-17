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
    productRequests = [NSMutableDictionary dictionary];
    cachedProducts = [NSMutableDictionary dictionary];

    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

- (void) dealloc
{
    [productRequests removeAllObjects];
    productRequests = nil;
    
    [cachedProducts removeAllObjects];
    cachedProducts = nil;
}

- (void) requestProductData:(CDVInvokedUrlCommand *)command
{
    NSString *callbackId = command.callbackId;
    NSArray* arguments = command.arguments;

	if([arguments count] < 1) {
		return;
	}
    
    NSSet * productIdentifiers = [arguments objectAtIndex:0];
	NSLog(@"requestProductData: %@", productIdentifiers);
     
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    
    [productRequests setValue:request forKey:callbackId];
    request.delegate = self;
    [request start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	NSLog(@"got response for requestProductData");
    
	NSMutableArray * validProducts = [NSMutableArray array];
    for (SKProduct *product in response.products) {
        [cachedProducts setObject:product forKey:product.productIdentifier];

    	NSDictionary * item = [NSDictionary dictionaryWithObjectsAndKeys:
                               NILABLE(product.productIdentifier), @"productId",
                               NILABLE(product.localizedTitle), @"title",
                               NILABLE(product.localizedDescription), @"description",
                               NILABLE(product.localizedPrice), @"price",
                               nil];
    	[validProducts addObject:item];
    }
    
    NSLog(@"valid products - count: %d", [validProducts count]);
    
    NSDictionary * reply = [NSDictionary dictionaryWithObjectsAndKeys:
                            validProducts, @"validProducts",
                            NILABLE(response.invalidProductIdentifiers), @"invalidIds",
                            nil];
    
    for( NSString *callbackId in productRequests) {
        SKProductsRequest * req = [productRequests objectForKey:callbackId];
        if( req == request ) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:reply];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
            [productRequests removeObjectForKey:callbackId];
            request.delegate = nil;
            break;
        }
    }
}


- (void) makePurchase:(CDVInvokedUrlCommand *)command
{
    NSArray* arguments = command.arguments;

    NSLog(@"makePurchase called");
	if([arguments count] < 1) {
		return;
	}

    NSString * productId = [arguments objectAtIndex:0];
    NSLog(@"makePurchase - Id: %@", productId);
    
    SKProduct * product = [cachedProducts objectForKey:productId];
    NSLog(@"makePurchase - product: %@", product);
    
    if( product != nil ) {
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        if([arguments count] > 1) {
            id quantity = [arguments objectAtIndex:1];
            if ([quantity respondsToSelector:@selector(integerValue)]) {
                payment.quantity = [quantity integerValue];
            }
        }
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
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
	NSString *state, *jsString;
    for (SKPaymentTransaction *transaction in transactions) {
		state = @"";
        switch (transaction.transactionState) {
			case SKPaymentTransactionStatePurchasing:
				continue;

            case SKPaymentTransactionStatePurchased:
				state = @"PaymentTransactionStatePurchased";
                NSLog(@"state: %@, productId: %@",
                      state,
                      transaction.payment.productIdentifier);
				jsString =
						@"cordova.fireDocumentEvent('onInAppPurchaseSuccess',"
						@"{ 'productId': '%@', 'transactionId': '%@', 'transactionReceipt' : '%@' });";
				[self writeJavascript:[NSString stringWithFormat:jsString,
				                       transaction.payment.productIdentifier,
				                       transaction.transactionIdentifier,
				                       [[transaction transactionReceipt] base64EncodedString]]];
                break;

			case SKPaymentTransactionStateFailed:
				state = @"PaymentTransactionStateFailed";
                NSLog(@"state: %@, errorCode: %d, errorMsg: %@",
                      state,
                      transaction.error.code,
                      transaction.error.localizedDescription);
				jsString =
					@"cordova.fireDocumentEvent('onInAppPurchaseFailed',"
					@"{ 'errorCode': '%d', 'errorMsg' : '%@' });";
				[self writeJavascript:[NSString stringWithFormat:jsString,
				                       transaction.error.code,
                                       @"In-App purchase failed." ]];
                                       // cannot pass the japanese localized string, so we avoid pass the text message as a workaround.
				                       //transaction.error.localizedDescription]];
                break;

			case SKPaymentTransactionStateRestored:
				state = @"PaymentTransactionStateRestored";
                NSLog(@"state: %@, productId: %@",
                      state,
                      transaction.originalTransaction.payment.productIdentifier);
				jsString =
						@"cordova.fireDocumentEvent('onInAppPurchaseRestored',"
						@"{ 'productId': '%@', 'transactionId': '%@', 'transactionReceipt' : '%@' });";
				[self writeJavascript:[NSString stringWithFormat:jsString,
				                       transaction.originalTransaction.payment.productIdentifier,
				                       transaction.originalTransaction.transactionIdentifier,
				                       [[transaction transactionReceipt] base64EncodedString]]];
				break;

            default:
				NSLog(@"Invalid state");
                continue;
        }
		

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
	[self writeJavascript:@"cordova.fireDocumentEvent('onRestoreCompletedTransactionsFinished');"];
}

@end

