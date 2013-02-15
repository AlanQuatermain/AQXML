//
//  AQXMLSignatureAlgorithm.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-19.
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
