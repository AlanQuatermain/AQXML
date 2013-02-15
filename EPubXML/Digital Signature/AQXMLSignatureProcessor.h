//
//  AQXMLSignatureProcessor.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-28.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

@class AQXMLDocument, AQXMLElement, AQXMLNode;

typedef NS_ENUM(NSUInteger, AQXMLSignatureVersion) {
    AQXMLSignatureVersion1_0,
    AQXMLSignatureVersion1_1,
    AQXMLSignatureVersion2_0
};

typedef NS_ENUM(NSUInteger, AQDigestAlgorithm) {
    AQDigestAlgorithmSHA1,
    AQDigestAlgorithmSHA256,
    AQDigestAlgorithmSHA384,
    AQDigestAlgorithmSHA512
};

typedef NS_ENUM(NSUInteger, AQSignatureAlgorithm) {
    AQSignatureAlgorithmHMACSHA1,
    AQSignatureAlgorithmHMACSHA256,
    AQSignatureAlgorithmHMACSHA384,
    AQSignatureAlgorithmHMACSHA512,
    
    AQSignatureAlgorithmRSAWithSHA1,
    AQSignatureAlgorithmRSAWithSHA256,
    AQSignatureAlgorithmRSAWithSHA384,
    AQSignatureAlgorithmRSAWithSHA512,
    
    AQSignatureAlgorithmDSAWithSHA1,
    AQSignatureAlgorithmDSAWithSHA256,
    
    AQSignatureAlgorithmECDSAWithSHA1,
    AQSignatureAlgorithmECDSAWithSHA256,
    AQSignatureAlgorithmECDSAWithSHA384,
    AQSignatureAlgorithmECDSAWithSHA512,
};

@interface AQXMLSignatureProcessor : NSObject

+ (BOOL) validateSignatureInDocument: (AQXMLDocument *) document;

// generate a signature which can be inserted into any document, including the one being signed
+ (AQXMLElement *) signatureForDocument: (AQXMLDocument *) document
                                version: (AQXMLSignatureVersion) version
                   usingDigestAlgorithm: (AQDigestAlgorithm) digestAlgorithm
                     signatureAlgorithm: (AQSignatureAlgorithm) signatureAlgorithm
                             signingKey: (SecKeyRef) signingKey;

// returns a new document with digests of the supplied URLs in /Signature/Object/Manifest
+ (AQXMLDocument *) signatureReferencingDataAtURLs: (NSArray *) URLs
                                           version: (AQXMLSignatureVersion) version
                              usingDigestAlgorithm: (AQDigestAlgorithm) digestAlgorithm
                                signatureAlgorithm: (AQSignatureAlgorithm) signatureAlgorithm
                                        signingKey: (SecKeyRef) signingKey;

// helper routine to generate Reference elements for SignedInfo or Manifest
+ (AQXMLElement *) referenceElementWithURL: (NSURL *) url
                                   version: (AQXMLSignatureVersion) version
                              digestMethod: (AQDigestAlgorithm) digestAlgorithm;

- (id) initWithSignatureVersion: (AQXMLSignatureVersion) version;

// validate a signature
- (BOOL) validateSignature: (AQXMLElement *) signatureElement
                inDocument: (AQXMLDocument *) document;

// sign a full document by enveloping it within Signature/Object/SignatureProperties/SignatureProperty
- (AQXMLDocument *) signatureForEmbeddedDocument: (AQXMLDocument *) document;
- (AQXMLElement *) signatureElementForDocument: (AQXMLDocument *) document;
- (AQXMLDocument *) signatureForExternalResource: (NSURL *) resourceURL;

// append manifest items to an internal document
- (void) appendManifestReference: (AQXMLElement *) element;

// generates a signature based on its internal Manifest list
- (AQXMLDocument *) generateSignatureDocument;

// these return NO if the algorithm is not supported by the given XML-DSig version
- (BOOL) setDigestAlgorithm: (AQDigestAlgorithm) algorithm;
- (BOOL) setSignatureAlgorithm: (AQSignatureAlgorithm) algorithm withKey: (SecKeyRef) key;

@property (nonatomic, readonly) AQXMLSignatureVersion version;

@property (nonatomic, readonly) AQDigestAlgorithm digestAlgorithm;
@property (nonatomic, readonly) AQSignatureAlgorithm signatureAlgorithm;
@property (nonatomic, readonly) SecKeyRef signingKey;

@property (nonatomic) BOOL useEnvelopedSignatureTransform;

@end
