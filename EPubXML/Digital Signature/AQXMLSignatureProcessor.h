//
//  AQXMLSignatureProcessor.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-28.
//  Copyright (c) 2012-2013 Kobo, Inc.
//  All rights reserved.
//  
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  
//  - Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//  - Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//  - Neither the name of Kobo, Inc. nor the names of its contributors
//    may be used to endorse or promote products derived from this
//    software without specific prior written permission.
//  
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//  COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
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
