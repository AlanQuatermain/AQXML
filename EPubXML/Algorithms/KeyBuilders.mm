//
//  KeyBuilders.mm
//  EPubXML
//
//  Created by Jim Dovey on 2012-10-04.
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

#import "KeyBuilders.h"
#import "AQXMLSignatureAlgorithm.h"
#import "cryptlib.h"
#import "rsa.h"
#import "dsa.h"
#import "eccrypto.h"
#import "asn.h"
#import "oids.h"
#import <CommonCrypto/CommonDigest.h>

using namespace CryptoPP;

static OID OIDFromURN(NSString * urn)
{
    if ( [urn hasPrefix: @"urn:oid:"] )
        urn = [urn substringFromIndex: 8];
    
    OID oid;
    NSArray * comps = [urn componentsSeparatedByString: @"."];
    for ( NSString * comp in comps )
    {
        oid += [comp intValue];
    }
    
    return ( oid );
}

static CFDictionaryRef KeychainItemAttrs(CFTypeRef item)
{
    CFArrayRef matchList = CFArrayCreate(kCFAllocatorDefault, &item, 1, &kCFTypeArrayCallBacks);
    
    CFTypeRef keys[] = { kSecReturnAttributes, kSecUseItemList, kSecMatchItemList };
    CFTypeRef values[] = { kCFBooleanTrue, kCFBooleanTrue, matchList };
    CFDictionaryRef query = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    CFDictionaryRef attrs = NULL;
    (void) SecItemCopyMatching(query, (CFTypeRef *)&attrs);
    CFRelease(matchList);
    CFRelease(query);
    
    return ( attrs );
}

extern "C" SecKeyRef ImportKeyData( NSData * keyData, NSArray * keyUsage )
{
    SecExternalFormat format = kSecFormatOpenSSL;
    SecExternalItemType itemType = kSecItemTypePublicKey;
    SecItemImportExportKeyParameters keyImportParams = {
        .version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION,
        .flags = 0,
        .passphrase = NULL,
        .alertTitle = CFSTR("Unlocking"),
        .alertPrompt = CFSTR("Please enter your password."),
        .accessRef = NULL,
        .keyUsage = (__bridge CFArrayRef)keyUsage,
        .keyAttributes = (__bridge CFArrayRef)@[@(CSSM_KEYATTR_PERMANENT), @(CSSM_KEYATTR_EXTRACTABLE)]
    };
    
    CFArrayRef items = NULL;
    OSStatus err = SecItemImport((__bridge CFDataRef)keyData, NULL, &format, &itemType, 0, &keyImportParams, NULL, &items);
    if ( err != noErr )
        return ( NULL );
    
    SecKeyRef key = NULL;
    CFIndex i, count = CFArrayGetCount(items);
    for ( i = 0; i < count; i++ )
    {
        CFTypeRef obj = CFArrayGetValueAtIndex(items, i);
        if ( CFGetTypeID(obj) != SecKeyGetTypeID() )
            continue;
        
        NSDictionary * attrs = CFBridgingRelease(KeychainItemAttrs(obj));
        if ( attrs == nil )
            continue;
        
        if ( [attrs[(__bridge id)kSecAttrKeyClass] isEqual: (__bridge id)kSecAttrKeyClassPublic] )
        {
            key = (SecKeyRef) CFRetain(obj);
            break;
        }
    }
    
    CFRelease(items);
    return ( key );
}

extern "C" SecCertificateRef ImportCertificateData(NSData * data)
{
    NSArray * keyUsage = @[(__bridge id)kSecAttrCanVerify];
    SecExternalFormat format = kSecFormatX509Cert;
    SecExternalItemType itemType = kSecItemTypeCertificate;
    SecItemImportExportKeyParameters keyImportParams = {
        .version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION,
        .flags = 0,
        .passphrase = NULL,
        .alertTitle = CFSTR("Unlocking"),
        .alertPrompt = CFSTR("Please enter your password."),
        .accessRef = NULL,
        .keyUsage = (__bridge CFArrayRef)keyUsage,
        .keyAttributes = (__bridge CFArrayRef)@[@(CSSM_KEYATTR_PERMANENT), @(CSSM_KEYATTR_EXTRACTABLE)]
    };
    
    CFArrayRef items = NULL;
    OSStatus err = SecItemImport((__bridge CFDataRef)data, NULL, &format, &itemType, 0, &keyImportParams, NULL, &items);
    if ( err != noErr )
        return ( NULL );
    
    // output should be either a certificate or an identity
    if ( CFArrayGetCount(items) == 0 )
        return ( NULL );
    
    CFTypeRef cert = CFRetain(CFArrayGetValueAtIndex(items, 0));
    CFRelease(items);
    
    if ( CFGetTypeID(cert) == SecCertificateGetTypeID() )
    {
        return ( (SecCertificateRef)cert );
    }
    
    if ( CFGetTypeID(cert) == SecIdentityGetTypeID() )
    {
        SecIdentityRef identity = (SecIdentityRef)cert;
        SecCertificateRef c = NULL;
        (void) SecIdentityCopyCertificate(identity, &c);
        CFRelease(identity);
        
        return ( c );
    }
    
    return ( NULL );
}

extern "C" SecKeyRef BuildRSAKey(NSData * modulus, NSData * exponent)
{
    Integer mod((const byte *)[modulus bytes], [modulus length]);
    Integer exp((const byte *)[exponent bytes], [exponent length]);
    
    RSA::PublicKey pubkey;
    pubkey.Initialize(mod, exp);
    
    std::string keyBytes;
    pubkey.DEREncodePublicKey(StringSink(keyBytes).Ref());
    
    NSData * d = [[NSData alloc] initWithBytesNoCopy: (void *)keyBytes.data()
                                              length: keyBytes.length()
                                        freeWhenDone: NO];
    
    return ( ImportKeyData(d, @[(__bridge id)kSecAttrCanVerify]) );
}

extern "C" SecKeyRef BuildDSAKey(NSData * P, NSData * Q, NSData * G, NSData * Y, NSData * J,
                                 NSData * Seed, NSData * PGenCounter)
{
    DSA::PublicKey pubKey;
    
    if ( G == nil )
    {
        // can only use Y, which means I must supply params (grr)
        // I'll use empty and hope for the best
        pubKey.Initialize(DL_GroupParameters_DSA(), Integer((const byte *)[Y bytes], [Y length]));
    }
    else if ( P != nil )
    {
        if ( Q == nil )
        {
            pubKey.Initialize(Integer((const byte *)[P bytes], [P length]), Integer((const byte *)[G bytes], [G length]), Integer((const byte *)[Y bytes], [Y length]));
        }
        else
        {
            pubKey.Initialize(Integer((const byte *)[P bytes], [P length]), Integer((const byte *)[Q bytes], [Q length]), Integer((const byte *)[G bytes], [G length]), Integer((const byte *)[Y bytes], [Y length]));
        }
    }
    
    std::string keyBytes;
    pubKey.DEREncodePublicKey(StringSink(keyBytes).Ref());
    
    NSData * d = [[NSData alloc] initWithBytesNoCopy: (void *)keyBytes.data()
                                              length: keyBytes.length()
                                        freeWhenDone: NO];
    
    return ( ImportKeyData(d, @[(__bridge id)kSecAttrCanVerify]) );
}

template <class EC, class H, class I>
static SecKeyRef ECPublicKey(I &x, I &y, DL_GroupParameters_EC<EC> & params)
{
    typename ECDSA<EC, H>::PublicKey pubKey;
    typename EC::Point pt(x, y);
    
    pubKey.Initialize(params, pt);
    
    std::string keyBytes;
    pubKey.DEREncodePublicKey(StringSink(keyBytes).Ref());
    
    NSData * d = [[NSData alloc] initWithBytesNoCopy: (void *)keyBytes.data()
                                              length: keyBytes.length()
                                        freeWhenDone: NO];
    
    return ( ImportKeyData(d, @[(__bridge id)kSecAttrCanVerify]) );
}

extern "C" SecKeyRef BuildECDSAKey(id curveNameOrParameters, NSData * publicKey, AQXMLSignatureAlgorithm * alg)
{
    // sanity-check the public key: it should begin with 0x04 and have an ODD number of bytes as a result
    if ( [publicKey length] % 2 == 0 )
        return ( NULL );    // malformed key data
    
    const uint8_t *p = static_cast<const uint8_t *>([publicKey bytes]);
    if ( p[0] != 0x04 )
        return ( NULL );    // invalid data
    
    NSUInteger coordLen = ([publicKey length] - 1) >> 1;
    NSData * xData = [publicKey subdataWithRange: NSMakeRange(1, coordLen)];
    NSData * yData = [publicKey subdataWithRange: NSMakeRange(coordLen+1, coordLen)];
    
    Integer x(static_cast<const byte *>([xData bytes]), [xData length]);
    Integer y(static_cast<const byte *>([yData bytes]), [yData length]);
    PolynomialMod2 px(static_cast<const byte *>([xData bytes]), [xData length]);
    PolynomialMod2 py(static_cast<const byte *>([yData bytes]), [yData length]);
    
    if ( [curveNameOrParameters isKindOfClass: [NSString class]] )
    {
        // it's a curve name in a URN
        NSString * curveName = curveNameOrParameters;
        OID oid = OIDFromURN(curveName);
        
        try
        {
            DL_GroupParameters_EC<ECP> params(oid);
            if ( [alg.digestType isEqualToString: (__bridge NSString *)kSecDigestSHA1] )
            {
                return ( ECPublicKey<ECP, SHA1>(x, y, params) );
            }
            else
            {
                switch ( alg.digestLength )
                {
                    case CC_SHA224_DIGEST_LENGTH:
                        return ( ECPublicKey<ECP, SHA224, Integer>(x, y, params) );
                        break;
                    case CC_SHA256_DIGEST_LENGTH:
                        return ( ECPublicKey<ECP, SHA256, Integer>(x, y, params) );
                        break;
                    case CC_SHA384_DIGEST_LENGTH:
                        return ( ECPublicKey<ECP, SHA384, Integer>(x, y, params) );
                        break;
                    case CC_SHA512_DIGEST_LENGTH:
                        return ( ECPublicKey<ECP, SHA512, Integer>(x, y, params) );
                        break;
                    default:
                        break;
                }
                
                return ( NULL );
            }
        }
        catch (...)
        {
            // it's EC2N
            try
            {
                DL_GroupParameters_EC<EC2N> params(oid);if ( [alg.digestType isEqualToString: (__bridge NSString *)kSecDigestSHA1] )
                {
                    return ( ECPublicKey<EC2N, SHA1>(px, py, params) );
                }
                else
                {
                    switch ( alg.digestLength )
                    {
                        case CC_SHA224_DIGEST_LENGTH:
                            return ( ECPublicKey<EC2N, SHA224, PolynomialMod2>(px, py, params) );
                            break;
                        case CC_SHA256_DIGEST_LENGTH:
                            return ( ECPublicKey<EC2N, SHA256, PolynomialMod2>(px, py, params) );
                            break;
                        case CC_SHA384_DIGEST_LENGTH:
                            return ( ECPublicKey<EC2N, SHA384, PolynomialMod2>(px, py, params) );
                            break;
                        case CC_SHA512_DIGEST_LENGTH:
                            return ( ECPublicKey<EC2N, SHA512, PolynomialMod2>(px, py, params) );
                            break;
                        default:
                            break;
                    }
                    
                    return ( NULL );
                }
            }
            catch (...)
            {
                return ( NULL );
            }
        }
    }
    else if ( [curveNameOrParameters isKindOfClass: [NSDictionary class]] )
    {
        
    }
    
    return ( NULL );
}
