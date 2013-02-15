//
//  AQXMLElement.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
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
