//
//  DigestTransforms.h
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
