//
//  AQXMLAttribute.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLAttribute.h"
#import "AQXMLUtilities.h"
#import "AQXML_Private.h"
#import <libxml/tree.h>

@implementation AQXMLAttribute

+ (AQXMLAttribute *) attributeWithXMLNode: (xmlAttrPtr) node
{
    return ( [[self alloc] initWithXMLNode: (xmlNodePtr)node] );
}

- (id) initWithXMLNode: (xmlNodePtr) node
{
    NSParameterAssert(node->type == XML_ATTRIBUTE_NODE);
    if ( node->type != XML_ATTRIBUTE_NODE )
        return ( nil );
    
    return ( [super initWithXMLNode: node] );
}

- (xmlAttrPtr) xmlObj
{
    return ( (xmlAttrPtr)[super xmlObj] );
}

- (AQXMLNode *) contentNode
{
    return ( (__bridge AQXMLNode *)self.xmlObj->children->_private );
}

- (AQXMLAttributeType) attributeType
{
    return ( (AQXMLAttributeType)self.xmlObj->atype );
}

- (void) setAttributeType: (AQXMLAttributeType) attributeType
{
    self.xmlObj->atype = (xmlAttributeType)attributeType;
}

- (NSString *) value
{
    return ( self.contentNode.content );
}

- (void) setValue: (NSString *) value
{
    self.contentNode.content = value;
}

- (void) setName: (NSString *) name andValue: (NSString *) value
{
    xmlSetProp(self.parent.xmlObj, [name xmlString], [value xmlString]);
}

- (void) setName: (NSString *) name andValue: (NSString *) value inNamespace: (AQXMLNamespace *) ns
{
    if ( ns == nil )
        xmlSetProp(self.parent.xmlObj, [name xmlString], [value xmlString]);
    else
        xmlSetNsProp(self.parent.xmlObj, ns.xmlObj, [name xmlString], [value xmlString]);
}

@end
