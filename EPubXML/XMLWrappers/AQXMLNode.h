//
//  AQXMLNode.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
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
