//
//  AQXMLCryptoAlgorithm.mm
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

#import "AQXMLCryptoAlgorithm.h"
#import <CommonCrypto/CommonCryptor.h>
#import "cryptlib.h"
#import "gcm.h"
#import "aes.h"
#import "filters.h"

@implementation AQXMLCryptoAlgorithm

- (NSData *) encryptData: (NSData *) data withIV: (NSData *) iv
{
    return ( nil );
}

- (NSData *) decryptData: (NSData *) data
{
    return ( nil );
}

- (uint8_t) blockSize
{
    return ( 8 );
}

- (NSData *) padData: (NSData *) data
{
    uint8_t blockSize = self.blockSize;
    NSUInteger padLen = [data length] % blockSize;
    if ( padLen == 0 )
        padLen = blockSize;
    
    NSMutableData * padded = [data mutableCopy];
    [padded setLength: [padded length] + padLen-1];
    [padded appendBytes: &blockSize length: sizeof(blockSize)];
    return ( padded );
}

- (NSData *) removePadding: (NSData *) data
{
    const uint8_t * p = (const uint8_t *)[data bytes];
    uint8_t padLen = p[[data length]-1];
    if ( p[[data length]-1] > self.blockSize )
        return ( data );
    
    return ( [data subdataWithRange: NSMakeRange(0, [data length]-padLen)] );
}

- (NSData *) embedIV: (NSData *) iv inCipherText: (NSData *) cipherText
{
    if ( iv == nil || [iv length] == 0 )
        return ( cipherText );
    
    NSMutableData * result = [iv mutableCopy];
    [result appendData: cipherText];
    return ( result );
}

- (BOOL) verifyKey: (NSDictionary *) expectedAttributes
{
    if ( self.key == nil )
        return ( NO );
    
    NSMutableDictionary * query = [expectedAttributes mutableCopy];
    query[_SEC(kSecClass)] = _SEC(kSecClassKey);
    query[_SEC(kSecMatchItemList)] = @[_SEC(self.key)];
    query[_SEC(kSecReturnAttributes)] = @YES;
    
    CFTypeRef result = NULL;
    if ( SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != noErr )
        return ( NO );
    
    CFRelease(result);
    return ( YES );
}

- (BOOL) verifyKeyType: (CFTypeRef) keyType
{
    return ( [self verifyKey: @{_SEC(kSecAttrKeyType):(__bridge id)keyType}] );
}

- (NSData *) keyBytes
{
    NSDictionary * query = @{
        _SEC(kSecMatchItemList) : @[_SEC(self.key)],
        _SEC(kSecReturnData) : @YES
    };
    
    CFTypeRef data = NULL;
    if ( SecItemCopyMatching((__bridge CFDictionaryRef)query, &data) != noErr )
        return ( nil );
    
    return ( CFBridgingRelease(data) );
}

@end

static NSData * _GenericCryptCC(CCOperation op, CCAlgorithm alg, CCMode mode, NSData * key, NSData * iv, NSData * data)
{
    if ( key == nil )
        return ( nil );
    
    CCCryptorRef cryptor = NULL;
    CCCryptorStatus status = CCCryptorCreateWithMode(kCCEncrypt, kCCModeCBC, kCCAlgorithm3DES, ccNoPadding, [iv bytes], [key bytes], [key length], NULL, 0, 0, 0, &cryptor);
    if ( status != kCCSuccess )
        return ( nil );
    
    // NB: CCCryptorFinal() is unnecessary when not padding output
    NSMutableData * encrypted = [NSMutableData dataWithLength: CCCryptorGetOutputLength(cryptor, [data length], false)];
    
    size_t moved = 0;
    status = CCCryptorUpdate(cryptor, [data bytes], [data length], [encrypted mutableBytes], [encrypted length], &moved);
    // no CCCryptorFinal() call since we're not padding the output
    CCCryptorRelease(cryptor);
    if ( status != kCCSuccess )
        return ( nil );
    
    [encrypted setLength: moved];
    return ( encrypted );
}

static NSData * _GenericCryptSec(CCOperation op, CFStringRef mode, SecKeyRef key, NSData * iv, NSData * data)
{
    SecTransformRef cipher = NULL;
    if ( op == kCCEncrypt )
        cipher = SecEncryptTransformCreate(key, NULL);
    else
        cipher = SecDecryptTransformCreate(key, NULL);
    
    if ( cipher == NULL )
        return ( nil );
    
    SecTransformSetAttribute(cipher, kSecTransformInputAttributeName, (__bridge CFDataRef)data, NULL);
    SecTransformSetAttribute(cipher, kSecPaddingKey, kSecPaddingNoneKey, NULL);
    SecTransformSetAttribute(cipher, kSecIVKey, (__bridge CFDataRef)iv, NULL);
    SecTransformSetAttribute(cipher, kSecEncryptionMode, mode, NULL);
    CFDataRef output = (CFDataRef)SecTransformExecute(cipher, NULL);
    CFRelease(cipher);
    
    return ( CFBridgingRelease(output) );
}

@implementation ENC_CLASS(TripleDES)

- (uint8_t) blockSize
{
    return ( kCCBlockSize3DES );
}

- (NSData *) encryptData: (NSData *) plainText withIV: (NSData *) iv
{
    NSParameterAssert(plainText != nil);
    NSParameterAssert(iv != nil && [iv length] == self.blockSize);
    NSAssert([self verifyKeyType: kSecAttrKeyType3DES], @"Invalid key type for 3DES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( plainText == nil || iv == nil || [iv length] != self.blockSize || [self verifyKeyType: kSecAttrKeyType3DES] == NO )
        return ( nil );
#endif
    plainText = [self padData: plainText];
    NSData * encrypted = nil;
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    encrypted = _GenericCryptCC(kCCEncrypt, kCCAlgorithm3DES, kCCModeCBC, self.keyBytes, iv, plainText);
#else
    encrypted = _GenericCryptSec(kCCEncrypt, kSecModeCBCKey, self.key, iv, plainText);
#endif
    if ( encrypted == nil )
        return ( nil );
    return ( [self embedIV: iv inCipherText: encrypted] );
}

- (NSData *) decryptData: (NSData *) cipherText
{
    NSParameterAssert(cipherText != nil);
    NSAssert([self verifyKeyType: kSecAttrKeyType3DES], @"Invalid key type for 3DES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( cipherText == nil ||[self verifyKeyType: kSecAttrKeyType3DES] == NO )
        return ( nil );
#endif
    // pull out the IV
    NSData * iv = [cipherText subdataWithRange: NSMakeRange(0, self.blockSize)];
    cipherText = [cipherText subdataWithRange: NSMakeRange(self.blockSize, [cipherText length]-self.blockSize)];
    NSData * padded = nil;
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    padded = _GenericCryptCC(kCCDecrypt, kCCAlgorithm3DES, kCCModeCBC, self.keyBytes, iv, cipherText);
#else
    padded = _GenericCryptSec(kCCDecrypt, kSecModeCBCKey, self.key, iv, cipherText);
#endif
    if ( padded == nil )
        return ( nil );
    return ( [self removePadding: padded] );
}

@end

@implementation ENC_CLASS(AES128CBC)

- (uint8_t) blockSize
{
    return ( kCCBlockSizeAES128 );
}

- (NSData *) encryptData: (NSData *) plainText withIV: (NSData *) iv
{
    NSParameterAssert(plainText != nil);
    NSParameterAssert(iv != nil && [iv length] == self.blockSize);
    NSAssert([self verifyKeyType: kSecAttrKeyTypeAES], @"Invalid key type for AES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( plainText == nil || iv == nil || [iv length] != self.blockSize || [self verifyKeyType: kSecAttrKeyTypeAES] == NO )
        return ( nil );
#endif
    plainText = [self padData: plainText];
    NSData * encrypted = nil;
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    encrypted = _GenericCryptCC(kCCEncrypt, kCCAlgorithmAES128, kCCModeCBC, self.keyBytes, iv, plainText);
#else
    encrypted = _GenericCryptSec(kCCEncrypt, kSecModeCBCKey, self.key, iv, plainText);
#endif
    if ( encrypted == nil )
        return ( nil );
    return ( [self embedIV: iv inCipherText: encrypted] );
}

- (NSData *) decryptData: (NSData *) cipherText
{
    NSParameterAssert(cipherText != nil);
    NSAssert([self verifyKeyType: kSecAttrKeyTypeAES], @"Invalid key type for AES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( cipherText == nil ||[self verifyKeyType: kSecAttrKeyTypeAES] == NO )
        return ( nil );
#endif
    // pull out the IV
    NSData * iv = [cipherText subdataWithRange: NSMakeRange(0, self.blockSize)];
    cipherText = [cipherText subdataWithRange: NSMakeRange(self.blockSize, [cipherText length]-self.blockSize)];
    NSData * padded = nil;
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    padded = _GenericCryptCC(kCCDecrypt, kCCAlgorithmAES, kCCModeCBC, self.keyBytes, iv, cipherText);
#else
    padded = _GenericCryptSec(kCCDecrypt, kSecModeCBCKey, self.key, iv, cipherText);
#endif
    if ( padded == nil )
        return ( nil );
    return ( [self removePadding: padded] );
}

@end

@implementation ENC_CLASS(AES256CBC)

- (uint8_t) blockSize
{
    return ( kCCBlockSizeAES128 );
}

- (NSData *) encryptData: (NSData *) plainText withIV: (NSData *) iv
{
    NSParameterAssert(plainText != nil);
    NSParameterAssert(iv != nil && [iv length] == self.blockSize);
    NSAssert([self verifyKeyType: kSecAttrKeyTypeAES], @"Invalid key type for AES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( plainText == nil || iv == nil || [iv length] != self.blockSize || [self verifyKeyType: kSecAttrKeyTypeAES] == NO )
        return ( nil );
#endif
    plainText = [self padData: plainText];
    NSData * encrypted = nil;
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    encrypted = _GenericCryptCC(kCCEncrypt, kCCAlgorithmAES128, kCCModeCBC, self.keyBytes, iv, plainText);
#else
    encrypted = _GenericCryptSec(kCCEncrypt, kSecModeCBCKey, self.key, iv, plainText);
#endif
    if ( encrypted == nil )
        return ( nil );
    return ( [self embedIV: iv inCipherText: encrypted] );
}

- (NSData *) decryptData: (NSData *) cipherText
{
    NSParameterAssert(cipherText != nil);
    NSAssert([self verifyKeyType: kSecAttrKeyTypeAES], @"Invalid key type for AES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( cipherText == nil ||[self verifyKeyType: kSecAttrKeyTypeAES] == NO )
        return ( nil );
#endif
    // pull out the IV
    NSData * iv = [cipherText subdataWithRange: NSMakeRange(0, self.blockSize)];
    cipherText = [cipherText subdataWithRange: NSMakeRange(self.blockSize, [cipherText length]-self.blockSize)];
    NSData * padded = nil;
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    padded = _GenericCryptCC(kCCDecrypt, kCCAlgorithmAES, kCCModeCBC, self.keyBytes, iv, cipherText);
#else
    padded = _GenericCryptSec(kCCDecrypt, kSecModeCBCKey, self.key, iv, cipherText);
#endif
    if ( padded == nil )
        return ( nil );
    return ( [self removePadding: padded] );
}

@end

@implementation ENC_CLASS(AES192CBC)

- (uint8_t) blockSize
{
    return ( kCCBlockSizeAES128 );
}

- (NSData *) encryptData: (NSData *) plainText withIV: (NSData *) iv
{
    NSParameterAssert(plainText != nil);
    NSParameterAssert(iv != nil && [iv length] == self.blockSize);
    NSAssert([self verifyKeyType: kSecAttrKeyTypeAES], @"Invalid key type for AES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( plainText == nil || iv == nil || [iv length] != self.blockSize || [self verifyKeyType: kSecAttrKeyTypeAES] == NO )
        return ( nil );
#endif
    plainText = [self padData: plainText];
    NSData * encrypted = nil;
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    encrypted = _GenericCryptCC(kCCEncrypt, kCCAlgorithmAES128, kCCModeCBC, self.keyBytes, iv, plainText);
#else
    encrypted = _GenericCryptSec(kCCEncrypt, kSecModeCBCKey, self.key, iv, plainText);
#endif
    if ( encrypted == nil )
        return ( nil );
    return ( [self embedIV: iv inCipherText: encrypted] );
}

- (NSData *) decryptData: (NSData *) cipherText
{
    NSParameterAssert(cipherText != nil);
    NSAssert([self verifyKeyType: kSecAttrKeyTypeAES], @"Invalid key type for AES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( cipherText == nil ||[self verifyKeyType: kSecAttrKeyTypeAES] == NO )
        return ( nil );
#endif
    // pull out the IV
    NSData * iv = [cipherText subdataWithRange: NSMakeRange(0, self.blockSize)];
    cipherText = [cipherText subdataWithRange: NSMakeRange(self.blockSize, [cipherText length]-self.blockSize)];
    NSData * padded = nil;
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    padded = _GenericCryptCC(kCCDecrypt, kCCAlgorithmAES, kCCModeCBC, self.keyBytes, iv, cipherText);
#else
    padded = _GenericCryptSec(kCCDecrypt, kSecModeCBCKey, self.key, iv, cipherText);
#endif
    if ( padded == nil )
        return ( nil );
    return ( [self removePadding: padded] );
}

@end

@implementation ENC_CLASS(AES128GCM)

- (uint8_t) blockSize
{
    return ( kCCBlockSizeAES128 );
}

- (NSData *) encryptData: (NSData *) plainText withIV: (NSData *) iv
{
    NSParameterAssert(plainText != nil);
    NSParameterAssert(iv != nil && [iv length] == 96/8);
    NSAssert([self verifyKeyType: kSecAttrKeyTypeAES], @"Invalid key type for AES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( plainText == nil || iv == nil || [iv length] != self.blockSize || [self verifyKeyType: kSecAttrKeyTypeAES] == NO )
        return ( nil );
#endif
    plainText = [self padData: plainText];
    NSData * keyData = [self keyBytes];
    if ( keyData == nil )
        return ( nil );
    
    NSData * encrypted = nil;
    
    try
    {
        CryptoPP::GCM<CryptoPP::AES>::Encryption cipher;
        cipher.SetKeyWithIV((const byte *)[keyData bytes], [keyData length], (const byte *)[iv bytes], [iv length]);
        
        CryptoPP::SecByteBlock pdata((const byte *)[plainText bytes], [plainText length]);
        std::string cdata;
        
        // C++ code like this makes Uncle Jim cry...
        CryptoPP::ArraySource(pdata, pdata.size(), true, new CryptoPP::AuthenticatedEncryptionFilter(cipher, new CryptoPP::StringSink(cdata), false, 128/8));
        
        // it's C++, so it throws on ANY ERROR (grrr)
        // The authentication tag is already appended to the data here
        encrypted = [NSData dataWithBytes: cdata.data() length: cdata.length()];
    }
    catch ( CryptoPP::Exception & e )
    {
        NSLog(@"CryptoPP Exception caught: %s", e.what());
    }
    
    if ( encrypted == nil )
        return ( nil );
    return ( [self embedIV: iv inCipherText: encrypted] );
}

- (NSData *) decryptData: (NSData *) cipherText
{
    NSParameterAssert(cipherText != nil);
    NSAssert([self verifyKeyType: kSecAttrKeyTypeAES], @"Invalid key type for AES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( cipherText == nil ||[self verifyKeyType: kSecAttrKeyTypeAES] == NO )
        return ( nil );
#endif
    // pull out the IV
    NSData * iv = [cipherText subdataWithRange: NSMakeRange(0, self.blockSize)];
    cipherText = [cipherText subdataWithRange: NSMakeRange(self.blockSize, [cipherText length]-self.blockSize)];
    
    NSData * keyData = [self keyBytes];
    if ( keyData == nil )
        return ( nil );
    
    NSData * padded = nil;
    
    try
    {
        CryptoPP::GCM<CryptoPP::AES>::Decryption cipher;
        cipher.SetKeyWithIV((const byte *)[keyData bytes], [keyData length], (const byte *)[iv bytes], [iv length]);
        
        CryptoPP::SecByteBlock cdata((const byte *)[cipherText bytes], [cipherText length]);
        std::string pdata;
        
        CryptoPP::AuthenticatedDecryptionFilter df(cipher, new CryptoPP::StringSink(pdata), CryptoPP::AuthenticatedDecryptionFilter::DEFAULT_FLAGS, 128/8);
        
        // Note the funky class they created just so they can avoid using instance variables
        // but still capture output that is deallocated by the expression's destructor...
        CryptoPP::ArraySource(cdata, cdata.size(), true, new CryptoPP::Redirector(df));
        
        // decrypted OK, let's check the data integrity
        if ( df.GetLastResult() )
            padded = [NSData dataWithBytes: pdata.data() length: pdata.length()];
    }
    catch ( CryptoPP::Exception & e )
    {
        NSLog(@"CryptoPP Exception caught: %s", e.what());
    }
    
    if ( padded == nil )
        return ( nil );
    return ( [self removePadding: padded] );
}

@end

@implementation ENC_CLASS(AES256GCM)

- (uint8_t) blockSize
{
    return ( kCCBlockSizeAES128 );
}

- (NSData *) encryptData: (NSData *) plainText withIV: (NSData *) iv
{
    NSParameterAssert(plainText != nil);
    NSParameterAssert(iv != nil && [iv length] == 96/8);
    NSAssert([self verifyKeyType: kSecAttrKeyTypeAES], @"Invalid key type for AES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( plainText == nil || iv == nil || [iv length] != self.blockSize || [self verifyKeyType: kSecAttrKeyTypeAES] == NO )
        return ( nil );
#endif
    plainText = [self padData: plainText];
    NSData * keyData = [self keyBytes];
    if ( keyData == nil )
        return ( nil );
    
    NSData * encrypted = nil;
    
    try
    {
        CryptoPP::GCM<CryptoPP::AES>::Encryption cipher;
        cipher.SetKeyWithIV((const byte *)[keyData bytes], [keyData length], (const byte *)[iv bytes], [iv length]);
        
        CryptoPP::SecByteBlock pdata((const byte *)[plainText bytes], [plainText length]);
        std::string cdata;
        
        // C++ code like this makes Uncle Jim cry...
        CryptoPP::ArraySource(pdata, pdata.size(), true, new CryptoPP::AuthenticatedEncryptionFilter(cipher, new CryptoPP::StringSink(cdata), false, 128/8));
        
        // it's C++, so it throws on ANY ERROR (grrr)
        // The authentication tag is already appended to the data here
        encrypted = [NSData dataWithBytes: cdata.data() length: cdata.length()];
    }
    catch ( CryptoPP::Exception & e )
    {
        NSLog(@"CryptoPP Exception caught: %s", e.what());
    }
    
    if ( encrypted == nil )
        return ( nil );
    return ( [self embedIV: iv inCipherText: encrypted] );
}

- (NSData *) decryptData: (NSData *) cipherText
{
    NSParameterAssert(cipherText != nil);
    NSAssert([self verifyKeyType: kSecAttrKeyTypeAES], @"Invalid key type for AES cipher");
#ifdef NS_BLOCK_ASSERTIONS
    if ( cipherText == nil ||[self verifyKeyType: kSecAttrKeyTypeAES] == NO )
        return ( nil );
#endif
    // pull out the IV
    NSData * iv = [cipherText subdataWithRange: NSMakeRange(0, self.blockSize)];
    cipherText = [cipherText subdataWithRange: NSMakeRange(self.blockSize, [cipherText length]-self.blockSize)];
    
    NSData * keyData = [self keyBytes];
    if ( keyData == nil )
        return ( nil );
    
    NSData * padded = nil;
    
    try
    {
        CryptoPP::GCM<CryptoPP::AES>::Decryption cipher;
        cipher.SetKeyWithIV((const byte *)[keyData bytes], [keyData length], (const byte *)[iv bytes], [iv length]);
        
        CryptoPP::SecByteBlock cdata((const byte *)[cipherText bytes], [cipherText length]);
        std::string pdata;
        
        CryptoPP::AuthenticatedDecryptionFilter df(cipher, new CryptoPP::StringSink(pdata), CryptoPP::AuthenticatedDecryptionFilter::DEFAULT_FLAGS, 128/8);
        
        // Note the funky class they created just so they can avoid using instance variables
        // but still capture output that is deallocated by the expression's destructor...
        CryptoPP::ArraySource(cdata, cdata.size(), true, new CryptoPP::Redirector(df));
        
        // decrypted OK, let's check the data integrity
        if ( df.GetLastResult() )
            padded = [NSData dataWithBytes: pdata.data() length: pdata.size()];
    }
    catch ( CryptoPP::Exception & e )
    {
        NSLog(@"CryptoPP Exception caught: %s", e.what());
    }
    
    if ( padded == nil )
        return ( nil );
    return ( [self removePadding: padded] );
}

@end
