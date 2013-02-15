//
//  AQXMLCanonicalizer.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-23.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AQXMLDocument, AQXMLElement, AQXMLNode, AQXMLNodeSet;

typedef NS_OPTIONS(uint8_t, AQXMLCanonicalizationMethod) {
    AQXMLCanonicalizationMethod_1_0             = 0,
    AQXMLCanonicalizationMethod_exclusive_1_0   = 1,
    AQXMLCanonicalizationMethod_1_1             = 2,
    AQXMLCanonicalizationMethod_2_0             = 3,
    
    AQXMLCanonicalizationMethod_with_comments   = 0x80
};

@interface AQXMLCanonicalizer : NSObject

// NB: node visibility isn't yet implemented for the streaming (v2.0) canonicalizer

+ (NSData *) canonicalizeDocument: (AQXMLDocument *) document
                      usingMethod: (AQXMLCanonicalizationMethod) method
               visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible;
+ (NSData *) canonicalizeElement: (AQXMLElement *) element
                     usingMethod: (AQXMLCanonicalizationMethod) method
                visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible;
+ (NSData *) canonicalizeContentAtURI: (NSURL *) uri
                          usingMethod: (AQXMLCanonicalizationMethod) method
                     visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible;
+ (NSData *) canonicalizeData: (NSData *) data
                  usingMethod: (AQXMLCanonicalizationMethod) method
             visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible;

// streaming mode initializer
- (id) initWithData: (NSData *) data;
- (id) initWithStream: (NSInputStream *) stream;    // designated initializer

// DOM mode initializer
- (id) initWithDocument: (AQXMLDocument *) document; // designated initializer too

@property (nonatomic) BOOL preserveWhitespace;
@property (nonatomic) BOOL preserveComments;
@property (nonatomic) BOOL rewritePrefixes;
@property (nonatomic, strong) NSString * fragment;
@property (nonatomic, copy) BOOL (^isNodeVisible)(AQXMLNode * node);

- (void) addQNameAwareAttribute: (NSString *) name namespaceURI: (NSString *) namespaceURI;
- (void) addQNameAwareElement: (NSString *) name namespaceURI: (NSString *) namespaceURI;
- (void) addQNameAwareXPathElement: (NSString *) name namespaceURI: (NSString *) namespaceURI;

- (void) canonicalizeToStream: (NSOutputStream *) stream completionHandler: (void (^)(NSError * error)) handler;
- (BOOL) canonicalizeToStream: (NSOutputStream *) stream error: (NSError **) error;

@end
