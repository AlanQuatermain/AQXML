//
//  AQXMLCanonicalizer.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-23.
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

@class AQXMLDocument, AQXMLElement, AQXMLNode, AQXMLNodeSet;

typedef NS_OPTIONS(uint8_t, AQXMLCanonicalizationMethod) {
    AQXMLCanonicalizationMethod_1_0             = 0,
    AQXMLCanonicalizationMethod_exclusive_1_0   = 1,
    AQXMLCanonicalizationMethod_1_1             = 2,
    AQXMLCanonicalizationMethod_2_0             = 3,
    
    AQXMLCanonicalizationMethod_with_comments   = 0x80
};

@interface AQXMLCanonicalizer : NSObject

// NB: node visibility isn't yet implemented for the streaming (v2.0) canonicalizer

+ (NSData *) canonicalizeDocument: (AQXMLDocument *) document
                      usingMethod: (AQXMLCanonicalizationMethod) method
               visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible;
+ (NSData *) canonicalizeElement: (AQXMLElement *) element
                     usingMethod: (AQXMLCanonicalizationMethod) method
                visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible;
+ (NSData *) canonicalizeContentAtURI: (NSURL *) uri
                          usingMethod: (AQXMLCanonicalizationMethod) method
                     visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible;
+ (NSData *) canonicalizeData: (NSData *) data
                  usingMethod: (AQXMLCanonicalizationMethod) method
             visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible;

// streaming mode initializer
- (id) initWithData: (NSData *) data;
- (id) initWithStream: (NSInputStream *) stream;    // designated initializer

// DOM mode initializer
- (id) initWithDocument: (AQXMLDocument *) document; // designated initializer too

@property (nonatomic) BOOL preserveWhitespace;
@property (nonatomic) BOOL preserveComments;
@property (nonatomic) BOOL rewritePrefixes;
@property (nonatomic, strong) NSString * fragment;
@property (nonatomic, copy) BOOL (^isNodeVisible)(AQXMLNode * node);

- (void) addQNameAwareAttribute: (NSString *) name namespaceURI: (NSString *) namespaceURI;
- (void) addQNameAwareElement: (NSString *) name namespaceURI: (NSString *) namespaceURI;
- (void) addQNameAwareXPathElement: (NSString *) name namespaceURI: (NSString *) namespaceURI;

- (void) canonicalizeToStream: (NSOutputStream *) stream completionHandler: (void (^)(NSError * error)) handler;
- (BOOL) canonicalizeToStream: (NSOutputStream *) stream error: (NSError **) error;

@end
