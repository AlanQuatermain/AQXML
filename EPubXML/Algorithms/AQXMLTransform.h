//
//  AQXMLTransform.h
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
