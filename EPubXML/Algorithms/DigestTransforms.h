//
//  DigestTransforms.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-18.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLTransform.h"

#define DIGEST_CLASS(type) type##DigestTransform
#define DIGEST_INTERFACE(type) @interface DIGEST_CLASS(type) : AQXMLTransform @end

@interface AQXMLHMACTransform : AQXMLTransform
@property (nonatomic, strong) NSData * keyData;
@end

#define HMAC_CLASS(type) HMAC##type##Transform
#define HMAC_INTERFACE(type) @interface HMAC_CLASS(type) : AQXMLHMACTransform @end

// Required Digest Transforms
DIGEST_INTERFACE(SHA1)
DIGEST_INTERFACE(SHA256)

// Required HMAC Transforms
HMAC_INTERFACE(SHA1)
HMAC_INTERFACE(SHA256)

// Recommended HMAC Transforms
HMAC_INTERFACE(SHA384)
HMAC_INTERFACE(SHA512)

// Optional Digest Transforms
DIGEST_INTERFACE(SHA384)
DIGEST_INTERFACE(SHA512)
