//
//  AQXMLNamespace.m
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
