//
//  AQXMLXPath.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-20.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
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
