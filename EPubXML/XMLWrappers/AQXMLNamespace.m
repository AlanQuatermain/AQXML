//
//  AQXMLNamespace.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLNamespace.h"
#import "AQXMLNode.h"
#import "AQXMLDocument.h"
#import "AQXMLUtilities.h"
#import "AQXML_Private.h"

@implementation AQXMLNamespace
{
    xmlNsPtr    _ns;
}

+ (AQXMLNamespace *) namespaceWithXMLNamespace: (xmlNsPtr) ns
{
    return ( [[self alloc] initWithXMLNamespace: ns] );
}

+ (AQXMLNamespace *) namespaceWithNode: (AQXMLNode *) node
                                   URI: (NSString *) uri
                                prefix: (NSString *) prefix
{
    xmlNsPtr newNS = xmlNewNs(node.xmlObj, [uri xmlString], [prefix xmlString]);
    if ( newNS == NULL )
        return ( nil );
    
    return ( [[self alloc] initWithXMLNamespace: newNS] );
}

+ (AQXMLNamespace *) globalNamespaceForDocument: (AQXMLDocument *) doc
                                            URI: (NSURL *) uri
                                         prefix: (NSString *) prefix
{
    xmlNsPtr newNS = xmlNewGlobalNs(doc.xmlObj, [[uri absoluteString] xmlString], [prefix xmlString]);
    if ( newNS == NULL )
        return ( nil );
    
    return ( [[self alloc] initWithXMLNamespace: newNS] );
}

- (id) initWithXMLNamespace: (xmlNsPtr) ns
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _ns = ns;
    if ( _ns->_private == NULL )
        _ns->_private = (void *)CFBridgingRetain(self);
    
    return ( self );
}

- (void) dealloc
{
    if ( _valid == NO )
        return;
    
    _ns->_private = NULL;
    if ( _ns->next == NULL && _ns->context == NULL )
        xmlFreeNs(_ns);
}

- (NSString *) prefix
{
    if ( _ns->prefix == NULL )
        return ( nil );
    return ( [NSString stringWithXMLString: _ns->prefix] );
}

- (NSURL *) uri
{
    if ( _ns->href == NULL )
        return ( nil );
    return ( [NSURL URLWithString: [NSString stringWithXMLString: _ns->href]] );
}

- (BOOL) isEqual: (id) object
{
    if ( [object isKindOfClass: [AQXMLNamespace class]] == NO )
        return ( NO );
    
    return ( [self.prefix isEqualToString: [object prefix]] && [self.uri isEqual: [object uri]] );
}

@end
