//
//  AQXMLXPath.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-20.
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
#import <libxml/xpath.h>

@class AQXMLNode, AQXMLDocument, AQXMLElement, AQXMLNamespace;

@interface AQXMLXPath : NSObject

+ (AQXMLXPath *) XPathWithString: (NSString *) XPathString
                        document: (AQXMLDocument *) document;
- (id) initWithString: (NSString *) XPathString
             document: (AQXMLDocument *) document;

@property (nonatomic, readonly) NSString * XPath;
@property (nonatomic, readonly) AQXMLDocument * document;

- (id) evaluateOnNode: (AQXMLNode *) node error: (NSError **) error;

//////////////////////////////////////////////////////////////////////
// modifications to the XPath's execution context

- (BOOL) registerNamespace: (AQXMLNamespace *) ns;
- (BOOL) registerNamespacePrefix: (NSString *) prefix
                         withURI: (NSString *) uri;
- (BOOL) registerNamespaces: (NSArray *) namespaces;    // AQXMLNamespace objects
- (BOOL) registerNamespacesApplicableToElement: (AQXMLElement *) element;

- (BOOL) registerFunctionWithName: (NSString *) name
                   implementation: (void (^)(xmlXPathParserContextPtr ctx, int nargs)) function;
- (BOOL) registerFunctionWithName: (NSString *) name
                     namespaceURI: (NSString *) namespaceURI
                   implementation: (void (^)(xmlXPathParserContextPtr ctx, int nargs)) function;

- (BOOL) registerVariableWithName: (NSString *) name
                            value: (id) value;
- (BOOL) registerVariableWithName: (NSString *) name
                     namespaceURI: (NSString *) namespaceURI
                            value: (id) value;

@end
