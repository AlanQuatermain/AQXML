//
//  AQXMLElement.h
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

@class AQXMLNamespace, AQXMLAttribute, AQXMLNodeSet;

@interface AQXMLElement : AQXMLNode

+ (AQXMLElement *) elementWithName: (NSString *) name
                           content: (NSString *) content
                       inNamespace: (AQXMLNamespace *) namespaceOrNil;

@property (readonly) NSString * namespacePrefix;

@property (readonly) NSUInteger childCount;
- (NSArray *) children;
- (NSArray *) descendants;

// NB: As per the XML spec, all indices are 1-based

- (void) enumerateChildrenUsingBlock: (void (^)(AQXMLNode * child, NSUInteger idx, BOOL *stop)) block;
- (void) enumerateChildrenWithOptions: (NSEnumerationOptions) options
                           usingBlock: (void (^)(AQXMLNode * child, NSUInteger idx, BOOL *stop)) block;

@property (readonly) AQXMLNode * firstChild;
@property (readonly) AQXMLNode * lastChild;
- (AQXMLNode *) childAtIndex: (NSUInteger) index;

@property (readonly) NSString * qualifiedName;

- (NSDictionary *) attributes;
- (NSString *) attributesString;

- (AQXMLElement *) firstChildNamed: (NSString *) matchName;
- (AQXMLElement *) firstDescendantNamed: (NSString *) matchName;
- (NSArray *) childrenNamed: (NSString *) matchName;
- (NSArray *) descendantsNamed: (NSString *) matchName;
- (NSArray *) elementsWithAttributeNamed: (NSString *) attributeName;
- (NSArray *) elementsWithAttributeNamed: (NSString *) attributeName attributeValue: (NSString *) attributeValue;

- (NSArray *) elementsForXPath: (NSString *) XPath error: (NSError **) error;
- (NSArray *) elementsForXPath: (NSString *) XPath
             prepareNamespaces: (NSArray *) elementNames
                         error: (NSError **)error;
- (AQXMLElement *) elementWithID: (NSString *) idValue;

- (void) insertChild: (AQXMLNode *) node atIndex: (NSUInteger) index;
- (AQXMLNode *) addChild: (AQXMLNode *) node;
- (AQXMLNode *) addTextChild: (NSString *) text;
- (AQXMLNode *) addCDATAChild: (NSString *) cdata;
- (AQXMLElement *) addChildNamed: (NSString *) childName;
- (AQXMLElement *) addChildNamed: (NSString *) childName
                 withTextContent: (NSString *) nodeContent;
- (AQXMLElement *) addChildNamed: (NSString *) childName
                withCDATAContent: (NSString *) cdataContent;

- (void) consolidateConsecutiveTextNodes;

- (AQXMLAttribute *) attributeNamed: (NSString *) name;
- (AQXMLAttribute *) addAttributeNamed: (NSString *) attributeName withValue: (NSString *) attributeValue;
- (void) deleteAttributeNamed: (NSString *) attributeName;
- (void) removeAllAttributes;
- (void) addAttributes: (NSDictionary *) attributes;        // @{ name : value }

@end
