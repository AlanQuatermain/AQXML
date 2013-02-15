//
//  AQXMLTransform.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-18.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLTransform.h"
#import "DigestTransforms.h"
#import "C14NTransforms.h"
#import "Base64Transform.h"
#import "XMLProcessTransforms.h"
#import "AQXMLSignatureAlgorithm.h"
#import "AQXMLCryptoAlgorithm.h"

static NSMutableDictionary * __transforms = nil;

NSString * const AQXMLAlgorithmSHA1 = @"http://www.w3.org/2000/09/xmldsig#sha1";
NSString * const AQXMLAlgorithmSHA256 = @"http://www.w3.org/2001/04/xmlenc#sha256";
NSString * const AQXMLAlgorithmSHA384 = @"http://www.w3.org/2001/04/xmldsig-more#sha384";
NSString * const AQXMLAlgorithmSHA512 = @"http://www.w3.org/2001/04/xmlenc#sha512";
NSString * const AQXMLAlgorithmHMACSHA1 = @"http://www.w3.org/2000/09/xmldsig#hmac-sha1";
NSString * const AQXMLAlgorithmHMACSHA256 = @"http://www.w3.org/2001/04/xmldsig-more#hmac-sha256";
NSString * const AQXMLAlgorithmHMACSHA384 = @"http://www.w3.org/2001/04/xmldsig-more#hmac-sha384";
NSString * const AQXMLAlgorithmHMACSHA512 = @"http://www.w3.org/2001/04/xmldsig-more#hmac-sha512";
NSString * const AQXMLAlgorithmBase64 = @"http://www.w3.org/2000/09/xmldsig#base64";
NSString * const AQXMLAlgorithmC14N10 = @"http://www.w3.org/TR/2001/REC-xml-c14n-20010315";
NSString * const AQXMLAlgorithmC14N10WithComments = @"http://www.w3.org/TR/2001/REC-xml-c14n-20010315#WithComments";
NSString * const AQXMLAlgorithmC14N10Exclusive = @"http://www.w3.org/2001/10/xml-exc-c14n#";
NSString * const AQXMLAlgorithmC14N10ExclusiveWithComments = @"http://www.w3.org/2001/10/xml-exc-c14n#WithComments";
NSString * const AQXMLAlgorithmC14N11 = @"http://www.w3.org/2006/12/xml-c14n11";
NSString * const AQXMLAlgorithmC14N11WithComments = @"http://www.w3.org/2006/12/xml-c14n11#WithComments";
NSString * const AQXMLAlgorithmC14N20 = @"http://www.w3.org/2010/xml-c14n2";
NSString * const AQXMLAlgorithmDSAWithSHA1 = @"http://www.w3.org/2000/09/xmldsig#dsa-sha1";
NSString * const AQXMLAlgorithmDSAWithSHA256 = @"http://www.w3.org/2009/xmldsig11#dsa-sha256";
NSString * const AQXMLAlgorithmRSAWithSHA1 = @"http://www.w3.org/2000/09/xmldsig#rsa-sha1";
NSString * const AQXMLAlgorithmRSAWithSHA256 = @"http://www.w3.org/2001/04/xmldsig-more#rsa-sha256";
NSString * const AQXMLAlgorithmRSAWithSHA384 = @"http://www.w3.org/2001/04/xmldsig-more#rsa-sha384";
NSString * const AQXMLAlgorithmRSAWithSHA512 = @"http://www.w3.org/2001/04/xmldsig-more#rsa-sha512";
NSString * const AQXMLAlgorithmECDSAWithSHA1 = @"http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha1";
NSString * const AQXMLAlgorithmECDSAWithSHA256 = @"http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha256";
NSString * const AQXMLAlgorithmECDSAWithSHA384 = @"http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha384";
NSString * const AQXMLAlgorithmECDSAWithSHA512 = @"http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha512";
NSString * const AQXMLAlgorithmXPath = @"http://www.w3.org/TR/1999/REC-xpath-19991116";
NSString * const AQXMLAlgorithmXPathFilter2 = @"http://www.w3.org/2002/06/xmldsig-filter2";
NSString * const AQXMLAlgorithmEnvelopedSignature = @"http://www.w3.org/2000/09/xmldsig#enveloped-signature";
NSString * const AQXMLAlgorithmXSLT = @"http://www.w3.org/TR/1999/REC-xslt-19991116";
NSString * const AQXMLAlgorithmXMLSelection = @"http://www.w3.org/2010/xmldsig2#xml";
NSString * const AQXMLAlgorithmBinarySelection = @"http://www.w3.org/2010/xmldsig2#binaryExternal";
NSString * const AQXMLAlgorithmBinaryFromXMLSelection = @"http://www.w3.org/2010/xmldsig2#binaryFromBase64";
NSString * const AQXMLAlgorithm3DES = @"http://www.w3.org/2001/04/xmlenc#tripledes-cbc";
NSString * const AQXMLAlgorithmAES128CBC = @"http://www.w3.org/2001/04/xmlenc#aes128-cbc";
NSString * const AQXMLAlgorithmAES192CBC = @"http://www.w3.org/2001/04/xmlenc#aes192-cbc";
NSString * const AQXMLAlgorithmAES256CBC = @"http://www.w3.org/2001/04/xmlenc#aes256-cbc";
NSString * const AQXMLAlgorithmAES128GCM = @"http://www.w3.org/2009/xmlenc11#aes128-gcm";
NSString * const AQXMLAlgorithmAES256GCM = @"http://www.w3.org/2009/xmlenc11#aes256-gcm";
NSString * const AQXMLAlgorithmConcatKDF = @"http://www.w3.org/2009/xmlenc11#ConcatKDF";
NSString * const AQXMLAlgorithmPBKDF = @"http://www.w3.org/2009/xmlenc11#pbkdf2";
NSString * const AQXMLAlgorithmRSAv1_5 = @"http://www.w3.org/2001/04/xmlenc#rsa-1_5";
NSString * const AQXMLAlgorithmRSAOAEPMGF1P = @"http://www.w3.org/2001/04/xmlenc#rsa-oaep-mgf1p";
NSString * const AQXMLAlgorithmRSAOAEP = @"http://www.w3.org/2009/xmlenc11#rsa-oaep";
NSString * const AQXMLAlgorithmECDHES = @"http://www.w3.org/2009/xmlenc11#ECDH-ES";
NSString * const AQXMLAlgorithmDH = @"http://www.w3.org/2001/04/xmlenc#dh";
NSString * const AQXMLAlgorithmDHES = @"http://www.w3.org/2009/xmlenc11#dh-es";
NSString * const AQXMLAlgorithmKeyWrap3DES = @"http://www.w3.org/2001/04/xmlenc#kw-tripledes";
NSString * const AQXMLAlgorithmKeyWrapAES128 = @"http://www.w3.org/2001/04/xmlenc#kw-aes128";
NSString * const AQXMLAlgorithmKeyWrapAES192 = @"http://www.w3.org/2001/04/xmlenc#kw-aes192";
NSString * const AQXMLAlgorithmKeyWrapAES256 = @"http://www.w3.org/2001/04/xmlenc#kw-aes256";
NSString * const AQXMLAlgorithmKeyWrapAES128Pad = @"http://www.w3.org/2009/xmlenc11#kw-aes-128-pad";
NSString * const AQXMLAlgorithmKeyWrapAES192Pad = @"http://www.w3.org/2009/xmlenc11#kw-aes-192-pad";
NSString * const AQXMLAlgorithmKeyWrapAES256Pad = @"http://www.w3.org/2009/xmlenc11#kw-aes-256-pad";
NSString * const AQXMLAlgorithmPIPEMD160 = @"http://www.w3.org/2001/04/xmlenc#ripemd160";
NSString * const AQXMLAlgorithmSHA384_ENC = @"http://www.w3.org/2001/04/xmlenc#sha384";

@implementation AQXMLTransform

+ (void) initialize
{
    if ( self != [AQXMLTransform class] )
        return;
    
    __transforms = [NSMutableDictionary new];
    
#define TX_CLASS(uri, sym) __transforms[uri] = [sym class]
    // register the built-in transforms now, so others can override them
    TX_CLASS(AQXMLAlgorithmSHA1, DIGEST_CLASS(SHA1));
    TX_CLASS(AQXMLAlgorithmSHA256, DIGEST_CLASS(SHA256));
    TX_CLASS(AQXMLAlgorithmSHA384_ENC, DIGEST_CLASS(SHA384));
    TX_CLASS(AQXMLAlgorithmSHA384, DIGEST_CLASS(SHA384));
    TX_CLASS(AQXMLAlgorithmSHA512, DIGEST_CLASS(SHA512));
    TX_CLASS(AQXMLAlgorithmHMACSHA1, HMAC_CLASS(SHA1));
    TX_CLASS(AQXMLAlgorithmHMACSHA256, HMAC_CLASS(SHA256));
    TX_CLASS(AQXMLAlgorithmHMACSHA384, HMAC_CLASS(SHA384));
    TX_CLASS(AQXMLAlgorithmHMACSHA512, HMAC_CLASS(SHA512));
    TX_CLASS(AQXMLAlgorithmBase64, Base64Transform);
    TX_CLASS(AQXMLAlgorithmC14N10, C14N_CLASS(10));
    TX_CLASS(AQXMLAlgorithmC14N10WithComments, C14N_CLASS(10WithComments));
    TX_CLASS(AQXMLAlgorithmC14N11, C14N_CLASS(11));
    TX_CLASS(AQXMLAlgorithmC14N11WithComments, C14N_CLASS(11WithComments));
    TX_CLASS(AQXMLAlgorithmC14N10Exclusive, C14N_CLASS(10Exclusive));
    TX_CLASS(AQXMLAlgorithmC14N10ExclusiveWithComments, C14N_CLASS(10ExclusiveWithComments));
    TX_CLASS(AQXMLAlgorithmC14N20, C14N20Transform);
    TX_CLASS(AQXMLAlgorithmDSAWithSHA1, SIGN_CLASS(DSAWithSHA1));
    TX_CLASS(AQXMLAlgorithmDSAWithSHA256, SIGN_CLASS(DSAWithSHA256));
    TX_CLASS(AQXMLAlgorithmRSAWithSHA1, SIGN_CLASS(RSAWithSHA1));
    TX_CLASS(AQXMLAlgorithmRSAWithSHA256, SIGN_CLASS(RSAWithSHA256));
    TX_CLASS(AQXMLAlgorithmRSAWithSHA384, SIGN_CLASS(RSAWithSHA384));
    TX_CLASS(AQXMLAlgorithmRSAWithSHA512, SIGN_CLASS(RSAWithSHA512));
    TX_CLASS(AQXMLAlgorithmECDSAWithSHA1, SIGN_CLASS(ECDSAWithSHA1));
    TX_CLASS(AQXMLAlgorithmECDSAWithSHA256, SIGN_CLASS(ECDSAWithSHA256));
    TX_CLASS(AQXMLAlgorithmECDSAWithSHA384, SIGN_CLASS(ECDSAWithSHA384));
    TX_CLASS(AQXMLAlgorithmECDSAWithSHA512, SIGN_CLASS(ECDSAWithSHA512));
    TX_CLASS(AQXMLAlgorithm3DES, ENC_CLASS(TripleDES));
    TX_CLASS(AQXMLAlgorithmAES128CBC, ENC_CLASS(AES128CBC));
    TX_CLASS(AQXMLAlgorithmAES192CBC, ENC_CLASS(AES192CBC));
    TX_CLASS(AQXMLAlgorithmAES256CBC, ENC_CLASS(AES256CBC));
    TX_CLASS(AQXMLAlgorithmAES128GCM, ENC_CLASS(AES128GCM));
    TX_CLASS(AQXMLAlgorithmAES256GCM, ENC_CLASS(AES256GCM));
    TX_CLASS(AQXMLAlgorithmXPath, XPathTransform);
    TX_CLASS(AQXMLAlgorithmXPathFilter2, XPathFilter2Transform);
    TX_CLASS(AQXMLAlgorithmEnvelopedSignature, EnvelopedSignatureTransform);
    TX_CLASS(AQXMLAlgorithmXSLT, XSLTTransform);
    TX_CLASS(AQXMLAlgorithmXMLSelection, XMLSelectionTransform);
    TX_CLASS(AQXMLAlgorithmBinarySelection, BinarySelectionTransform);
    TX_CLASS(AQXMLAlgorithmBinaryFromXMLSelection, BinaryFromXMLSelectionTransform);
}

+ (void) registerTransform: (Class) transform
                    forURI: (NSString *) uri
{
    if ( transform == Nil )
        [__transforms removeObjectForKey: uri];
    else
        __transforms[uri] = transform;
}

+ (id) transformForURI: (NSString *) uri
{
    Class cls = __transforms[uri];
    if ( cls == Nil )
        return ( nil );
    
    return ( [[cls alloc] init] );
}

- (id) process
{
    if ( self.input == nil )
        return ( nil );
    
    NSData * output = [self main];
    
    if ( self.next == nil )
        return ( output );
    
    self.next.input = output;
    return ( [self.next process] );
}

- (id) main
{
    return ( nil );
}

@end
