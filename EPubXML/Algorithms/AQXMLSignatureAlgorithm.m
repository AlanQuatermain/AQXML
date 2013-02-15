//
//  AQXMLSignatureAlgorithm.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-19.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLSignatureAlgorithm.h"
#import <CommonCrypto/CommonDigest.h>

@implementation AQXMLSignatureAlgorithm

- (void) dealloc
{
    if ( _key != NULL )
        CFRelease(_key);
}

- (void) setKey: (SecKeyRef) key
{
    if ( _key != NULL )
        CFRelease(_key);
    
    if ( key != NULL )
        CFRetain(key);
    
    _key = key;
}

- (NSString *) digestType
{
    return ( nil );
}

- (int) digestLength
{
    return ( 0 );
}

- (CFTypeRef) keyType
{
    return ( NULL );
}

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
- (SecPadding) _padding
{
    // RSA signatures apparently need PKCS1 padding
    if ( [NSStringFromClass([self class]) hasPrefix: @"RSA"] )
        return ( kSecPaddingPKCS1 );
    return ( kSecPaddingNone );
}

- (NSData *) signData: (NSData *) data error: (NSError **) error
{
    NSAssert(data != nil, @"-[AQXMLSignatureAlgorithm signData:error:] : nil data");
    NSAssert(self.digestType != nil, @"-[AQXMLSignatureAlgorithm signData:error:] : nil digestType");
    NSAssert(self.digestLength != 0, @"-[AQXMLSignatureAlgorithm signData:error:] : zero digestLength");
    NSAssert(self.key != NULL, @"-[AQXMLSignatureAlgorithm signData:error:] : nil key");
    
    if ( data == nil || self.digestType == nil || self.digestLength == 0 || self.key == NULL )
        return ( nil );
    
    uint8_t sigBuf[256];
    size_t sigLen = 256;
    OSStatus err = SecKeyRawSign(self.key, [self _padding], [data bytes], [data length], sigBuf, &sigLen);
    if ( err != noErr )
    {
        if ( error != NULL )
            *error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
        return ( nil );
    }
    
    return ( [NSData dataWithBytes: sigBuf length: sigLen] );
}

- (BOOL) verifySignature: (NSData *) signature forData: (NSData *) data error: (NSError **) error
{
    NSAssert(signature != nil, @"-[AQXMLSignatureAlgorithm verifySignature:forData:error:] : nil signature");
    NSAssert(data != nil, @"-[AQXMLSignatureAlgorithm verifySignature:forData:error:] : nil data");
    NSAssert(self.digestType != nil, @"-[AQXMLSignatureAlgorithm verifySignature:forData:error:] : nil digestType");
    NSAssert(self.digestLength != 0, @"-[AQXMLSignatureAlgorithm verifySignature:forData:error:] : zero digestLength");
    NSAssert(self.key != NULL, @"-[AQXMLSignatureAlgorithm verifySignature:forData:error:] : nil key");
    
    if ( data == nil || self.digestType == nil || self.digestLength == 0 || self.key == NULL )
        return ( NO );
    
    OSStatus err = SecKeyRawVerify(self.key, [self _padding], [data bytes], [data length], [signature bytes], [signature length]);
    if ( err != noErr )
    {
        if ( error != NULL )
            *error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
        return ( NO );
    }
    
    return ( YES );
}
#else
- (NSData *) signData: (NSData *) data error: (NSError **) error
{
    NSAssert(data != nil, @"-[AQXMLSignatureAlgorithm signData:error:] : nil data");
    NSAssert(self.digestType != nil, @"-[AQXMLSignatureAlgorithm signData:error:] : nil digestType");
    NSAssert(self.digestLength != 0, @"-[AQXMLSignatureAlgorithm signData:error:] : zero digestLength");
    NSAssert(self.key != NULL, @"-[AQXMLSignatureAlgorithm signData:error:] : nil key");
    
    if ( data == nil || self.digestType == nil || self.digestLength == 0 || self.key == NULL )
        return ( nil );
    
    CFErrorRef cfErr = NULL;
    SecTransformRef tx = SecSignTransformCreate(self.key, &cfErr);
    if ( tx == NULL )
    {
        if ( error != NULL )
            *error = CFBridgingRelease(cfErr);
        else if ( cfErr != NULL )
            CFRelease(cfErr);
        return ( nil );
    }
    
    SecTransformSetAttribute(tx, kSecDigestTypeAttribute,
                             (__bridge CFStringRef)self.digestType, NULL);
    SecTransformSetAttribute(tx, kSecDigestLengthAttribute,
                             (__bridge CFNumberRef)@(self.digestLength), NULL);
    SecTransformSetAttribute(tx, kSecTransformInputAttributeName,
                             (__bridge CFDataRef)data, NULL);
    
    NSData * output = CFBridgingRelease(SecTransformExecute(tx, &cfErr));
    CFRelease(tx);
    if ( output == nil && cfErr != NULL )
    {
        if ( error != NULL )
            *error = CFBridgingRelease(cfErr);
        else
            CFRelease(cfErr);
    }
    
    return ( output );
}

- (BOOL) verifySignature: (NSData *) signature forData: (NSData *) data error: (NSError **) error
{
    NSAssert(signature != nil, @"-[AQXMLSignatureAlgorithm verifySignature:forData:error:] : nil signature");
    NSAssert(data != nil, @"-[AQXMLSignatureAlgorithm verifySignature:forData:error:] : nil data");
    NSAssert(self.digestType != nil, @"-[AQXMLSignatureAlgorithm verifySignature:forData:error:] : nil digestType");
    NSAssert(self.digestLength != 0, @"-[AQXMLSignatureAlgorithm verifySignature:forData:error:] : zero digestLength");
    NSAssert(self.key != NULL, @"-[AQXMLSignatureAlgorithm verifySignature:forData:error:] : nil key");
    
    if ( data == nil || self.digestType == nil || self.digestLength == 0 || self.key == NULL )
        return ( NO );
    
    CFErrorRef cfErr = NULL;
    SecTransformRef tx = SecVerifyTransformCreate(self.key, (__bridge CFDataRef)signature, &cfErr);
    if ( tx == NULL )
    {
        if ( error != NULL )
            *error = CFBridgingRelease(cfErr);
        else if ( cfErr != NULL )
            CFRelease(cfErr);
        return ( NO );
    }
    
    SecTransformSetAttribute(tx, kSecDigestTypeAttribute,
                             (__bridge CFStringRef)self.digestType, NULL);
    SecTransformSetAttribute(tx, kSecDigestLengthAttribute,
                             (__bridge CFNumberRef)@(self.digestLength), NULL);
    SecTransformSetAttribute(tx, kSecTransformInputAttributeName,
                             (__bridge CFDataRef)data, NULL);
    
    NSNumber * output = CFBridgingRelease(SecTransformExecute(tx, &cfErr));
    CFRelease(tx);
    if ( [output boolValue] == NO && cfErr != NULL )
    {
        if ( error != NULL )
            *error = CFBridgingRelease(cfErr);
        else
            CFRelease(cfErr);
    }
    
    return ( [output boolValue] );
}
#endif

@end

#define SIGN_IMPL(type, dType, dLen, keyType)                                       \
@implementation SIGN_CLASS(type)                                                    \
- (NSString *) digestType { return (__bridge NSString *)dType; }                    \
- (int) digestLen  { return (CC_##dLen##_DIGEST_LENGTH * 8); }                      \
- (CFTypeRef) keyType { return kSecAttrKeyType##keyType; }                          \
@end

// Required

SIGN_IMPL(RSAWithSHA256, kSecDigestSHA2, SHA256, RSA)
SIGN_IMPL(ECDSAWithSHA256, kSecDigestSHA2, SHA256, ECDSA)
SIGN_IMPL(DSAWithSHA1, kSecDigestSHA1, SHA1, DSA)

// Recommended

SIGN_IMPL(RSAWithSHA1, kSecDigestSHA1, SHA1, RSA)

// Optional

SIGN_IMPL(RSAWithSHA384, kSecDigestSHA2, SHA384, RSA)
SIGN_IMPL(RSAWithSHA512, kSecDigestSHA2, SHA512, RSA)
SIGN_IMPL(ECDSAWithSHA1, kSecDigestSHA1, SHA1, ECDSA)
SIGN_IMPL(ECDSAWithSHA384, kSecDigestSHA2, SHA384, ECDSA)
SIGN_IMPL(ECDSAWithSHA512, kSecDigestSHA2, SHA512, ECDSA)
SIGN_IMPL(DSAWithSHA256, kSecDigestSHA2, SHA256, DSA)
