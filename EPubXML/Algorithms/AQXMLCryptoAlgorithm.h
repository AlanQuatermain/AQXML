//
//  AQXMLCryptoAlgorithm.h
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

// Please note: some encryptors specify that IVs and similar be concatenated into
// the stored ciphertext value. See http://www.w3.org/TR/xmlenc-core1/#sec-Algorithms

@interface AQXMLCryptoAlgorithm : NSObject

@property (nonatomic, assign) SecKeyRef key;

// to be implemented by subclassers
@property (nonatomic, readonly) uint8_t blockSize;
- (NSData *) encryptData: (NSData *) plainText withIV: (NSData *) iv;
- (NSData *) decryptData: (NSData *) cipherText;

// plain text must be padded to a multiple of the cipher's block size
- (NSData *) padData: (NSData *) data;
- (NSData *) removePadding: (NSData *) data;

// All algorithms specified by XML-ENC require an IV, and require that it be
// concatenated with the ciphertext output. This method returns a mutable data
// object as a convenience to callers that need to concatenate further input data,
// such as the GCM ciphers.
- (NSMutableData *) embedIV: (NSData *) iv inCipherText: (NSData *) cipherText;

// helper macro for building dictionaries/arrays with kSec... CF types
#define _SEC(x) ((__bridge id)x)

// utility function, used by subclassers to verify correct key type, etc.
- (BOOL) verifyKey: (NSDictionary *) expectedAttributes;
// a simple thing to verify by key type alone
- (BOOL) verifyKeyType: (CFTypeRef) keyType;
// obtain the raw unpadded bytes of a key, for use outside the Sec* APIs
- (NSData *) keyBytes;

@end

#define ENC_CLASS(type) type##EncryptionAlgorithm
#define ENC_INTERFACE(type) @interface ENC_CLASS(type) : AQXMLCryptoAlgorithm @end

// Required

ENC_INTERFACE(TripleDES)        // IV (64 bits) . Ciphertext
ENC_INTERFACE(AES128CBC)        // IV (128 bits) . Ciphertext
ENC_INTERFACE(AES256CBC)        // IV (128 bits) . Ciphertext
ENC_INTERFACE(AES128GCM)        // IV (96 bits) . Ciphertext . Auth (128 bits)

// Optional

ENC_INTERFACE(AES192CBC)        // IV (128 bits) . Ciphertext
ENC_INTERFACE(AES256GCM)        // IV (96 bits) . Ciphertext . Auth (128 bits)
