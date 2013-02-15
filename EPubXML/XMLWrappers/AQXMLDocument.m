//
//  AQXMLDocument.m
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

#import "AQXMLDocument.h"
#import "AQXMLReader.h"

#import "AQXMLUtilities.h"
#import "AQXML_Private.h"
#import "AQXMLCanonicalizer.h"
#import <libxml/tree.h>

// Based on Apple's XMLDocument sample code

@implementation AQXMLDocument
{
    NSArray * _namespaces;
}

+ (AQXMLDocument *) documentWithXMLDocument: (xmlDocPtr) doc
{
    if ( doc->_private != NULL )
        return ( (__bridge AQXMLDocument *)doc->_private );
    
    return ( [[self alloc] initWithXMLDocument: doc] );
}

- (xmlDocPtr) xmlObj
{
    return ( (xmlDocPtr)[super xmlObj] );
}

- (AQXMLElement *) rootElement
{
    xmlNodePtr node = xmlDocGetRootElement(self.xmlObj);
    if ( node == NULL )
        return ( nil );
    return ( (__bridge AQXMLElement *)node->_private );
}

- (void) setRootElement: (AQXMLElement *) rootElement
{
    xmlDocSetRootElement(self.xmlObj, rootElement.xmlObj);
}

- (NSArray *) namespaces
{
    if ( _namespaces != nil )
        return ( _namespaces );
    
    NSMutableSet * set = [NSMutableSet new];
    for ( AQXMLNode * node in self.rootElement.descendants )
    {
        if ( node.ns != nil )
            [set addObject: node.ns];
    }
    
    _namespaces = [set allObjects];
    return ( _namespaces );
}

+ (AQXMLDocument *) documentWithXMLData: (NSData *) data error: (NSError **) error
{
    return ( [AQXMLReader parseXML: [data bytes] length: [data length] error: error] );
}

+ (AQXMLDocument *) documentWithXMLString: (NSString *) string error: (NSError **) error
{
    return ( [AQXMLReader parseXMLString: string error: error] );
}

+ (AQXMLDocument *) documentWithContentsOfURL: (NSURL *) url error: (NSError **) error
{
    AQXMLDocument * doc = [AQXMLReader parseXMLFileAtURL: url error: error];
    doc.baseURL = url;
    return ( doc );
}

+ (AQXMLDocument *) emptyDocument
{
    xmlDocPtr node = xmlNewDoc((const xmlChar *)"1.0");
    if ( node == NULL )
        return ( nil );
    return ( (__bridge AQXMLDocument *)node->_private );
}

+ (AQXMLDocument *) documentWithRootElement: (AQXMLElement *) root
{
    AQXMLDocument * doc = [self emptyDocument];
    doc.rootElement = [root copy];
    return ( doc );
}

- (id) initWithXMLDocument: (xmlDocPtr) doc
{
    return ( [super initWithXMLNode: (xmlNodePtr)doc] );
}

- (id) copyWithZone: (NSZone *) zone
{
    xmlDocPtr ptr = xmlCopyDoc(self.xmlObj, 1);
    return ( [[AQXMLDocument alloc] initWithXMLDocument: ptr] );
}

- (NSString *) canonicalizedStringUsingMethod: (AQXMLCanonicalizationMethod) method
{
    NSStringEncoding enc = NSUTF8StringEncoding;
    NSData * data = [self canonicalizedDataUsingMethod: method usedEncoding: &enc];
    if ( data == nil )
        return ( nil );
    return ( [[NSString alloc] initWithData: data encoding: enc] );
}

- (NSData *) canonicalizedDataUsingMethod: (AQXMLCanonicalizationMethod) method
                             usedEncoding: (NSStringEncoding *) usedEncoding
{
    NSData * data = [AQXMLCanonicalizer canonicalizeDocument: self usingMethod: method visibilityFilter: nil];
    if ( data == nil )
        return ( nil );
    
    if ( usedEncoding != NULL )
        *usedEncoding = NSUTF8StringEncoding;
    
    return ( data );
}

- (NSString *) canonicalizedStringForElement: (AQXMLElement *) element
                                 usingMethod: (AQXMLCanonicalizationMethod) method
{
    NSStringEncoding enc = NSUTF8StringEncoding;
    NSData * data = [self canonicalizedDataForElement: element usingMethod: method usedEncoding: &enc];
    if ( data == nil )
        return ( nil );
    return ( [[NSString alloc] initWithData: data encoding: enc] );
}

- (NSData *) canonicalizedDataForElement: (AQXMLElement *) element
                             usingMethod: (AQXMLCanonicalizationMethod) method
                            usedEncoding: (NSStringEncoding *) usedEncoding
{
    NSData * data = [AQXMLCanonicalizer canonicalizeElement: element usingMethod: method visibilityFilter: nil];
    if ( data == nil )
        return ( nil );
    
    if ( usedEncoding != NULL )
        *usedEncoding = NSUTF8StringEncoding;
    
    return ( data );
}

- (AQXMLDTDNode *) createDTDWithName: (NSString *) name
                          externalID: (NSString *) externalID
                            systemID: (NSString *) systemID
{
    xmlDtdPtr newDTD = xmlNewDtd(self.xmlObj, [name xmlString],
                                 [externalID xmlString], [systemID xmlString]);
    return ( (__bridge AQXMLDTDNode *)newDTD->_private );
}

- (AQXMLDTDNode *) createInternalSubsetWithName: (NSString *) name
                                     externalID: (NSString *) externalID
                                       systemID: (NSString *) systemID
{
    xmlDtdPtr newDTD = xmlCreateIntSubset(self.xmlObj, [name xmlString],
                                          [externalID xmlString], [systemID xmlString]);
    return ( (__bridge AQXMLDTDNode *)newDTD->_private );
}

- (AQXMLAttribute *) addAttributeWithName: (NSString *) name
                                    value: (NSString *) value
{
    xmlAttrPtr node = xmlNewDocProp(self.xmlObj, [name xmlString], [value xmlString]);
    if ( node == NULL )
        return ( nil );
    return ( (__bridge AQXMLAttribute *)node->_private );
}

- (AQXMLAttribute *) attributeWithName: (NSString *) name
{
    xmlAttrPtr node = xmlHasProp((xmlNodePtr)self.xmlObj, [name xmlString]);
    if ( node == NULL )
        return ( nil );
    return ( (__bridge AQXMLAttribute *)node->_private );
}

- (void) removeAttribute: (NSString *) name
{
    AQXMLAttribute * attr = [self attributeWithName: name];
    if ( attr != nil )
        xmlRemoveProp(attr.xmlObj);
}

@end
