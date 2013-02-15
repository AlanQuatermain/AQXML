//
//  DigestTransforms.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-18.
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
