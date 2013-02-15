//
//  AQXMLSignatureAlgorithm.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-19.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AQXMLSignatureAlgorithm : NSObject

@property (nonatomic, assign) SecKeyRef key;

// to be supplied by subclassers
@property (nonatomic, readonly) NSString * digestType;
@property (nonatomic, readonly) int digestLength;
@property (nonatomic, readonly) CFTypeRef keyType;

- (NSData *) signData: (NSData *) data error: (NSError **) error;
- (BOOL) verifySignature: (NSData *) signature
                 forData: (NSData *) data
                   error: (NSError **) error;

@end

#define SIGN_CLASS(type) type##SignatureAlgorithm
#define SIGN_INTERFACE(type) \
@interface SIGN_CLASS(type) : AQXMLSignatureAlgorithm @end

// Required

SIGN_INTERFACE(RSAWithSHA256)
SIGN_INTERFACE(ECDSAWithSHA256)
SIGN_INTERFACE(DSAWithSHA1)

// Recommended

SIGN_INTERFACE(RSAWithSHA1)

// Optional

SIGN_INTERFACE(RSAWithSHA384)
SIGN_INTERFACE(RSAWithSHA512)
SIGN_INTERFACE(ECDSAWithSHA1)
SIGN_INTERFACE(ECDSAWithSHA384)
SIGN_INTERFACE(ECDSAWithSHA512)
SIGN_INTERFACE(DSAWithSHA256)
