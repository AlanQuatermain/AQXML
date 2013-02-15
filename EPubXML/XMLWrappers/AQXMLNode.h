//
//  AQXMLNode.h
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
#import "AQXMLObject.h"

@class AQXMLElement, AQXMLDocument, AQXMLAttribute, AQXMLNamespace, AQXMLXPath;

// These match the definitions in DOM level 1
typedef NS_ENUM(uint8_t, AQXMLNodeType) {
    AQXMLNodeTypeElement                = 1,
    AQXMLNodeTypeAttribute              = 2,
    AQXMLNodeTypeText                   = 3,
    AQXMLNodeTypeCDATASection           = 4,
    AQXMLNodeTypeEntityReference        = 5,
    AQXMLNodeTypeEntity                 = 6,
    AQXMLNodeTypeProcessingInstruction  = 7,
    AQXMLNodeTypeComment                = 8,
    AQXMLNodeTypeDocument               = 9,
    AQXMLNodeTypeDocumentType           = 10,
    AQXMLNodeTypeDocumentFragment       = 11,
    AQXMLNodeTypeNotation               = 12,
    AQXMLNodeTypeHTMLDocument           = 13,
    AQXMLNodeTypeDTD                    = 14,
    AQXMLNodeTypeElementDeclaration     = 15,
    AQXMLNodeTypeAttributeDeclaration   = 16,
    AQXMLNodeTypeEntityDeclaration      = 17,
    AQXMLNodeTypeNamespaceDeclaration   = 18,
    AQXMLNodeTypeXIncludeStart          = 19,
    AQXMLNodeTypeXIncludeEnd            = 20,
    AQXMLNodeTypeDOCBDocument           = 21
};

@interface AQXMLNode : AQXMLObject <NSCopying>

+ (AQXMLNode *) nodeWithString: (NSString *) string;
+ (AQXMLNode *) nodeWithName: (NSString *) name
                        type: (AQXMLNodeType) type
                     content: (NSString *) content
                 inNamespace: (AQXMLNamespace *) namespaceOrNil;

@property (nonatomic, copy) NSString * name;
@property (nonatomic, copy) NSString * content;
@property (nonatomic, strong) NSString * language;
@property (nonatomic) BOOL preserveSpace;
@property (nonatomic, copy) NSURL * baseURL;
@property (nonatomic, strong) AQXMLNamespace * ns;

@property (nonatomic, readonly) NSArray * namespacesInScope;

@property (nonatomic, readonly) AQXMLNodeType type;
@property (nonatomic, readonly) BOOL isTextNode;
@property (nonatomic, readonly) BOOL isElementNode;

@property (nonatomic, readonly) NSInteger index;
@property (nonatomic, readonly) AQXMLElement * parent;
@property (nonatomic, readonly) AQXMLDocument * document;

@property (nonatomic, readonly) AQXMLNode * nextNode;
@property (nonatomic, readonly) AQXMLNode * nextSibling;
@property (nonatomic, readonly) AQXMLNode * previousNode;
@property (nonatomic, readonly) AQXMLNode * previousSibling;

@property (nonatomic, readonly) AQXMLElement * rootElement;

@property (nonatomic, readonly) NSString * XMLString;

@property (nonatomic, readonly) NSString * stringValue;
@property (nonatomic, readonly) NSInteger integerValue;
@property (nonatomic, readonly) double doubleValue;
@property (nonatomic, readonly) BOOL boolValue;
@property (nonatomic, readonly) NSDate * dateValue;

@property (nonatomic, readonly) NSString * path;

- (void) detach;

- (void) addSiblingNode: (AQXMLNode *) sibling;

- (BOOL) mergeWithTextNode: (AQXMLNode *) node error: (NSError **) error;
- (BOOL) concatenateText: (NSString *) text error: (NSError **) error;

- (void) addNodeAsNextSibling: (AQXMLNode *) node;
- (void) addNodeAsPreviousSibling: (AQXMLNode *) node;

// these return an appropriately boxed type, if a box exists
// if no box exists, the fact (and the required type) will be noted in the error
- (id) evaluateXPath: (NSString *) XPath error: (NSError **) error;
- (id) evaluateXPath: (NSString *) XPath
   prepareNamespaces: (NSArray *) elementNames
               error: (NSError **) error;

@end
