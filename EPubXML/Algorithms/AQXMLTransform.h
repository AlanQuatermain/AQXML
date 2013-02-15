//
//  AQXMLTransform.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-18.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AQXMLTransform : NSObject
{
    AQXMLTransform * _next;
}

+ (void) registerTransform: (Class) transform
                    forURI: (NSString *) uri;
+ (id) transformForURI: (NSString *) uri;

@property (nonatomic, strong) id input;
@property (nonatomic, strong) AQXMLTransform * next;

- (id) process;

// subclassers implement this method
- (id) main;

@end

#pragma mark - Algorithm URIs

////////////////////////////////////////////////////////
// Algorithm URIs

extern NSString * const AQXMLAlgorithmSHA1;
extern NSString * const AQXMLAlgorithmSHA256;                   // dsig 1.1
extern NSString * const AQXMLAlgorithmSHA384;
extern NSString * const AQXMLAlgorithmSHA512;                   // dsig 1.1
extern NSString * const AQXMLAlgorithmHMACSHA1;
extern NSString * const AQXMLAlgorithmHMACSHA256;
extern NSString * const AQXMLAlgorithmHMACSHA384;
extern NSString * const AQXMLAlgorithmHMACSHA512;
extern NSString * const AQXMLAlgorithmBase64;
extern NSString * const AQXMLAlgorithmC14N10;
extern NSString * const AQXMLAlgorithmC14N10WithComments;
extern NSString * const AQXMLAlgorithmC14N10Exclusive;
extern NSString * const AQXMLAlgorithmC14N10ExclusiveWithComments;
extern NSString * const AQXMLAlgorithmC14N11;
extern NSString * const AQXMLAlgorithmC14N11WithComments;
extern NSString * const AQXMLAlgorithmC14N20;                   // dsig 2.0
extern NSString * const AQXMLAlgorithmDSAWithSHA1;
extern NSString * const AQXMLAlgorithmDSAWithSHA256;
extern NSString * const AQXMLAlgorithmRSAWithSHA1;
extern NSString * const AQXMLAlgorithmRSAWithSHA256;
extern NSString * const AQXMLAlgorithmRSAWithSHA384;
extern NSString * const AQXMLAlgorithmRSAWithSHA512;
extern NSString * const AQXMLAlgorithmECDSAWithSHA1;
extern NSString * const AQXMLAlgorithmECDSAWithSHA256;
extern NSString * const AQXMLAlgorithmECDSAWithSHA384;
extern NSString * const AQXMLAlgorithmECDSAWithSHA512;
extern NSString * const AQXMLAlgorithmXPath;
extern NSString * const AQXMLAlgorithmXPathFilter2;
extern NSString * const AQXMLAlgorithmEnvelopedSignature;
extern NSString * const AQXMLAlgorithmXSLT;
extern NSString * const AQXMLAlgorithmXMLSelection;             // dsig 2.0
extern NSString * const AQXMLAlgorithmBinarySelection;          // dsig 2.0
extern NSString * const AQXMLAlgorithmBinaryFromXMLSelection;   // dsig 2.0
extern NSString * const AQXMLAlgorithm3DES;
extern NSString * const AQXMLAlgorithmAES128CBC;
extern NSString * const AQXMLAlgorithmAES192CBC;
extern NSString * const AQXMLAlgorithmAES256CBC;
extern NSString * const AQXMLAlgorithmAES128GCM;                // enc 1.1
extern NSString * const AQXMLAlgorithmAES256GCM;                // enc 1.1
extern NSString * const AQXMLAlgorithmConcatKDF;                // enc 1.1
extern NSString * const AQXMLAlgorithmPBKDF;                    // enc 1.1
extern NSString * const AQXMLAlgorithmRSAv1_5;
extern NSString * const AQXMLAlgorithmRSAOAEPMGF1P;
extern NSString * const AQXMLAlgorithmRSAOAEP;                  // enc 1.1
extern NSString * const AQXMLAlgorithmECDHES;                   // enc 1.1
extern NSString * const AQXMLAlgorithmDH;
extern NSString * const AQXMLAlgorithmDHES;                     // enc 1.1
extern NSString * const AQXMLAlgorithmKeyWrap3DES;
extern NSString * const AQXMLAlgorithmKeyWrapAES128;
extern NSString * const AQXMLAlgorithmKeyWrapAES192;
extern NSString * const AQXMLAlgorithmKeyWrapAES256;
extern NSString * const AQXMLAlgorithmKeyWrapAES128Pad;         // enc 1.1
extern NSString * const AQXMLAlgorithmKeyWrapAES192Pad;         // enc 1.1
extern NSString * const AQXMLAlgorithmKeyWrapAES256Pad;         // enc 1.1
extern NSString * const AQXMLAlgorithmPIPEMD160;                // enc 1.1

extern NSString * const AQXMLAlgorithmSHA384_ENC;               // enc 1.0 uses a different URI from dsig
