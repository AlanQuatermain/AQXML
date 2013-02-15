//
//  DigestTransforms.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-18.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "DigestTransforms.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

#define CC_DIGEST_TRANSFORM_IMPL(type)                                              \
@implementation DIGEST_CLASS(type)                                                  \
- (id) main                                                                         \
{                                                                                   \
    uint8_t md[CC_##type##_DIGEST_LENGTH];                                          \
    if ( CC_##type([self.input bytes], (CC_LONG)[self.input length], md) == NULL ) {\
        return ( nil );                                                             \
    }                                                                               \
                                                                                    \
    return ( [NSData dataWithBytes: md length: CC_##type##_DIGEST_LENGTH] );        \
}                                                                                   \
@end

#define CC_HMAC_TRANSFORM_IMPL(type)                                                \
@implementation HMAC_CLASS(type)                                                    \
- (id) main                                                                         \
{                                                                                   \
    uint8_t mac[CC_##type##_DIGEST_LENGTH];                                         \
    CCHmac(kCCHmacAlg##type, [self.keyData bytes], [self.key length],               \
           [self.input bytes], [self.input length], mac);                           \
    return ( [NSData dataWithBytes: mac length: CC_##type##_DIGEST_LENGTH] );       \
}                                                                                   \
@end

@implementation AQXMLHMACTransform

- (NSData *) process
{
    if ( self.keyData == nil )
        return ( nil );
    return ( [super process] );
}

@end

// Required Digest Transforms
CC_DIGEST_TRANSFORM_IMPL(SHA1)
CC_DIGEST_TRANSFORM_IMPL(SHA256)

// Required HMAC Transforms
CC_HMAC_TRANSFORM_IMPL(SHA1)
CC_HMAC_TRANSFORM_IMPL(SHA256)

// Recommended HMAC Transforms
CC_HMAC_TRANSFORM_IMPL(SHA384)
CC_HMAC_TRANSFORM_IMPL(SHA512)

// Optional Digest Transforms
CC_DIGEST_TRANSFORM_IMPL(SHA384)
CC_DIGEST_TRANSFORM_IMPL(SHA512)
