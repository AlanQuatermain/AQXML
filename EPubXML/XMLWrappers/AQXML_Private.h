//
//  AQXML_Private.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLDocument.h"
#import "AQXMLElement.h"
#import "AQXMLNode.h"
#import "AQXMLDTDNode.h"
#import "AQXMLNamespace.h"
#import "AQXMLSchema.h"
#import "AQXMLAttribute.h"
#import "AQXMLNodeSet.h"
#import <libxml/xmlmemory.h>
#import <libxml/xpath.h>

@interface AQXMLObject ()
@property (nonatomic, readwrite, getter=isValid) BOOL valid;
@end

@interface AQXMLDocument ()
+ (AQXMLDocument *) documentWithXMLDocument: (xmlDocPtr) doc;
- (id) initWithXMLDocument: (xmlDocPtr) doc;
@property (nonatomic, readonly) xmlDocPtr xmlObj;
@end

@interface AQXMLNode ()
+ (AQXMLNode *) nodeWithXMLNode: (xmlNodePtr) node;
- (id) initWithXMLNode: (xmlNodePtr) node;
@property (nonatomic, readonly) xmlNodePtr xmlObj;
@end

@interface AQXMLNodeSet ()
+ (AQXMLNodeSet *) nodeSetWithXMLNodeSet: (xmlNodeSetPtr) nodeSet;
- (id) initWithXMLNodeSet: (xmlNodeSetPtr) nodeSet;
@property (nonatomic, readonly) xmlNodeSetPtr xmlObj;
@end

@interface AQXMLElement ()
+ (AQXMLElement *) elementWithXMLNode: (xmlNodePtr) node;
@end

@interface AQXMLAttribute ()
+ (AQXMLAttribute *) attributeWithXMLNode: (xmlAttrPtr) node;
@property (nonatomic, readonly) xmlAttrPtr xmlObj;
@end

@interface AQXMLDTDNode ()
+ (AQXMLDTDNode *) DTDNodeWithXMLDTD: (xmlDtdPtr) dtd;
- (id) initWithXMLDTD: (xmlDtdPtr) dtd;
@property (nonatomic, readonly) xmlDtdPtr xmlObj;
@end

@interface AQXMLNamespace ()
+ (AQXMLNamespace *) namespaceWithXMLNamespace: (xmlNsPtr) ns;
- (id) initWithXMLNamespace: (xmlNsPtr) ns;
@property (nonatomic, readonly) xmlNsPtr xmlObj;
@end
