//
//  AQXMLAttribute.m
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
