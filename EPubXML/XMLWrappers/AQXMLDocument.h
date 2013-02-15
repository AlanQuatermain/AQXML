//
//  AQXMLDocument.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
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
#import "AQXMLNode.h"
#import "AQXMLElement.h"
#import "AQXMLDTDNode.h"
#import "AQXMLAttribute.h"
#import "AQXMLCanonicalizer.h"
#import <libxml/xmlmemory.h>

// Based on Apple's XMLDocument sample code

@interface AQXMLDocument : AQXMLNode

@property (nonatomic, readwrite, strong) AQXMLElement *rootElement;
@property (nonatomic, readonly) NSArray * namespaces;

+ (AQXMLDocument *) documentWithXMLData: (NSData *) data error: (NSError **) error;
+ (AQXMLDocument *) documentWithXMLString: (NSString *) string error: (NSError **) error;
+ (AQXMLDocument *) documentWithContentsOfURL: (NSURL *) url error: (NSError **) error;

+ (AQXMLDocument *) emptyDocument;
+ (AQXMLDocument *) documentWithRootElement: (AQXMLElement *) root;

- (NSString *) canonicalizedStringUsingMethod: (AQXMLCanonicalizationMethod) method;
- (NSData *) canonicalizedDataUsingMethod: (AQXMLCanonicalizationMethod) method
                             usedEncoding: (NSStringEncoding *) usedEncoding;

- (NSString *) canonicalizedStringForElement: (AQXMLElement *) element
                                 usingMethod: (AQXMLCanonicalizationMethod) method;
- (NSData *) canonicalizedDataForElement: (AQXMLElement *) element
                             usingMethod: (AQXMLCanonicalizationMethod) method
                            usedEncoding: (NSStringEncoding *) usedEncoding;

- (AQXMLDTDNode *) createDTDWithName: (NSString *) name
                          externalID: (NSString *) externalID
                            systemID: (NSString *) systemID;

- (AQXMLDTDNode *) createInternalSubsetWithName: (NSString *) name
                                     externalID: (NSString *) externalID
                                       systemID: (NSString *) systemID;

- (AQXMLAttribute *) addAttributeWithName: (NSString *) name
                                    value: (NSString *) value;
- (AQXMLAttribute *) attributeWithName: (NSString *) name;
- (void) removeAttribute: (NSString *) name;

@end
