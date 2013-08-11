/** 
 * A plugin to enable iOS In-App Purchases.
 *
 * Copyright (c) Matt Kane 2011
 * Copyright (c) Guillaume Charhon 2012
 */

var argscheck = require('cordova/argscheck'),
    exec = require('cordova/exec');

var iapExport = {};

iapExport.setup = function(successCallback, failureCallback) {
	cordova.exec(successCallback, failureCallback, 'InAppPurchaseManager', 'setup', []);
};

/**
 * Retrieves localised product data, including price (as localised
 * string), name, description of multiple products.
 *
 * @param {Array} productIds
 *   An array of product identifier strings.
 *
 * @param {Function} callback
 *   Called once with the result of the products request. 
 *   {
 *     validProducts : [ ... ],
 *     invalidIds: [ ... ]
 *   }
 *
 *   where validProducts receives an array of objects of the form
 *     {
 *      id: "<productId>",
 *      title: "<localised title>",
 *      description: "<localised escription>",
 *      price: "<localised price>"
 *     }
 *
 *  and invalidProductIds receives an array of product identifier strings
 *  which were rejected by the app store.
 */
iapExport.requestProductData = function(Ids, successCallback, failureCallback) {
	cordova.exec(successCallback, failureCallback, 'InAppPurchaseManager', 'requestProductData', [Ids]);
};

/**
 * Makes an in-app purchase. 
 * 
 * @param {String} productId The product identifier. e.g. "com.example.MyApp.myproduct"
 * @param {int} quantity 
 */
iapExport.makePurchase = function(Id, quantity, successCallback, failureCallback) {
	cordova.exec(successCallback, failureCallback, 'InAppPurchaseManager', 'makePurchase', [Id, quantity]);
};

/**
 * Asks the payment queue to restore previously completed purchases.
 * The restored transactions are passed to the onRestored callback, so make sure you define a handler for that first.
 * 
 */
iapExport.restoreCompletedTransactions = function(successCallback, failureCallback) {
	cordova.exec(successCallback, failureCallback, 'InAppPurchaseManager', 'restoreCompletedTransactions', []);		
};

/*
 * This queue stuff is here because we may be sent events before listeners have been registered. This is because if we have 
 * incomplete transactions when we quit, the app will try to run these when we resume. If we don't register to receive these
 * right away then they may be missed. As soon as a callback has been registered then it will be sent any events waiting
 * in the queue.
 */


module.exports = iapExport;


