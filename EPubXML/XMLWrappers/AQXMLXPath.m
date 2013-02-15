//
//  AQXMLXPath.m
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

#import "AQXMLXPath.h"
#import "AQXMLDocument.h"
#import "AQXMLElement.h"
#import "AQXMLNodeSet.h"
#import "AQXMLUtilities.h"
#import "AQXML_Private.h"

#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>

static NSString * const AQXMLXPathInstanceVarName = @"instance";
static NSString * const AQXMLXPathNamespace = @"http://alanquatermain.me/AQXMLXPath";

@interface AQXMLXPath ()
- (void) _performFunction: (NSString *) name uri: (NSString *) uri context: (xmlXPathParserContextPtr) ctx nargs: (int) nargs;
@end

static void _XPathBlockFunctionWrapper(xmlXPathParserContextPtr ctx, int nargs)
{
    NSString * name = [NSString stringWithXMLString: ctx->context->function];
    NSString * ns = [NSString stringWithXMLString: ctx->context->functionURI];
    NSString * varName = AQXMLXPathInstanceVarName;
    NSString * varNS = AQXMLXPathNamespace;
    
    xmlXPathObjectPtr instObj = xmlXPathVariableLookupNS(ctx->context, [varName xmlString], [varNS xmlString] );
    AQXMLXPath * inst = nil;
    if ( instObj != NULL )
        inst = (__bridge AQXMLXPath *)instObj->user;
    
    if ( inst == nil )
    {
        // pop all arguments & return 'zero'
        for ( int i = 0; i < nargs; i++ )
        {
            valuePop(ctx);
        }
        
        valuePush(ctx, xmlXPathNewBoolean(0));
        return;
    }
    
    [inst _performFunction: name uri: ns context: ctx nargs: nargs];
}

@implementation AQXMLXPath
{
    xmlXPathContextPtr      _ctx;
    NSMutableDictionary *   _functions;     // so we definitively own the function blocks
    NSMutableDictionary *   _variables;     // for logging purposes
}

+ (AQXMLXPath *) XPathWithString: (NSString *) XPathString
                        document: (AQXMLDocument *) document
{
    return ( [[self alloc] initWithString: XPathString document: document] );
}

- (id) initWithString: (NSString *) XPathString document: (AQXMLDocument *) document
{
    if ( document == nil || XPathString == nil )
        return ( nil );
    
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _ctx = xmlXPathNewContext(document.xmlObj);
    if ( _ctx == NULL )
        return ( nil );
    
    _XPath = [XPathString copy];
    _functions = [NSMutableDictionary new];
    _variables = [NSMutableDictionary new];
    
    xmlXPathObjectPtr p = xmlMemMalloc(sizeof(xmlXPathObject));
    p->type = XPATH_USERS;
    p->user = (__bridge void *)self;
    xmlXPathObjectPtr xValue = xmlXPathObjectCopy(p);
    xmlMemFree(p);
    
    xmlXPathRegisterVariableNS(_ctx, [AQXMLXPathInstanceVarName xmlString], [AQXMLXPathNamespace xmlString], xValue);
    
    return ( self );
}

- (void) dealloc
{
    if ( _ctx != NULL )
        xmlXPathFreeContext(_ctx);
}

- (AQXMLDocument *) document
{
    if ( _ctx == NULL || _ctx->doc == NULL )
        return ( nil );
    return ( (__bridge AQXMLDocument *)_ctx->doc->_private );
}

- (NSString *) description
{
    return ( [NSString stringWithFormat: @"%@: %@ {user functions: %@, user variables: %@}", [super description], _XPath, [_functions allKeys], _variables] );
}

- (xmlXPathObjectPtr) _evaluateOnNode: (AQXMLNode *) node
                                error: (NSError **) error
{
    const xmlChar * query = [self.XPath xmlString];
    if ( query == NULL )
    {
        if ( error != NULL )
        {
            *error = [NSError errorWithDomain: AQXMLErrorDomain code: 0 userInfo: @{NSLocalizedFailureReasonErrorKey : @"-[AQXMLElement _evaluateXPath:] XPath argument is nil."}];
        }
        
		return ( NULL );
    }
    
    _ctx->node = node.xmlObj;
    xmlXPathObjectPtr queryResults = xmlXPathEvalExpression(query, _ctx);
    if ( queryResults == NULL && error != NULL )
    {
        *error = [NSError errorWithXMLError: &_ctx->lastError];
    }
    
    return ( queryResults );
}

- (NSString *) _stringifyXPathType: (xmlXPathObjectType) type
{
    switch ( type )
    {
        case XPATH_UNDEFINED:
            return ( @"undefined" );
        case XPATH_NODESET:
            return ( @"Node-set" );
        case XPATH_BOOLEAN:
            return ( @"boolean" );
        case XPATH_NUMBER:
            return ( @"number" );
        case XPATH_STRING:
            return ( @"string" );
        case XPATH_POINT:
            return ( @"point" );
        case XPATH_RANGE:
            return ( @"range" );
        case XPATH_LOCATIONSET:
            return ( @"location-set" );
        case XPATH_USERS:
            return ( @"users" );
        case XPATH_XSLT_TREE:
            return ( @"XSLT tree" );
            
        default:
            break;
    }
    
    return ( [NSString stringWithFormat: @"Unknown type %d", type] );
}

- (id) evaluateOnNode: (AQXMLNode *) node error: (NSError **) error
{
    xmlXPathObjectPtr queryResult = [self _evaluateOnNode: node error: error];
    if ( queryResult == NULL )
        return ( nil );
    
    id result = nil;
    switch ( queryResult->type )
    {
        case XPATH_NODESET:
            // this copies out the node set
            result = [AQXMLNodeSet nodeSetWithXMLNodeSet: queryResult->nodesetval];
            break;
        case XPATH_BOOLEAN:
            result = (queryResult->boolval == 0 ? @NO : @YES);
            break;
        case XPATH_NUMBER:
            result = @(queryResult->floatval);
            break;
        case XPATH_STRING:
            result = [NSString stringWithXMLString: queryResult->stringval];
            break;
        default:
            if ( error != NULL )
            {
                *error = [NSError xmlGenericErrorWithDescription: [NSString stringWithFormat: @"Non-boxable XPath result type '%@'", [self _stringifyXPathType: queryResult->type]]];
            }
            break;
    }
    
    return ( result );
}

#pragma mark -

- (BOOL) registerNamespace: (AQXMLNamespace *) ns
{
    return ( xmlXPathRegisterNs(_ctx, [ns.prefix xmlString], [[ns.uri absoluteString] xmlString]) == 0 );
}

- (BOOL) registerNamespacePrefix: (NSString *) prefix
                         withURI: (NSString *) uri
{
    return ( xmlXPathRegisterNs(_ctx, [prefix xmlString], [uri xmlString]) == 0 );
}

- (BOOL) registerNamespaces: (NSArray *) namespaces
{
    BOOL result = YES;
    for ( AQXMLNamespace * ns in namespaces )
    {
        if ( [self registerNamespace: ns] == NO )
        {
            result = NO;
            break;
        }
    }
    
    return ( result );
}

- (BOOL) registerNamespacesApplicableToElement: (AQXMLElement *) element
{
    // don't register any namespace twice
    NSMutableSet * registered = [NSMutableSet new];
    
    // namespaces for all attributes
    for ( AQXMLAttribute * attribute in [element.attributes allValues] )
    {
        AQXMLNamespace * ns = attribute.ns;
        if ( ns == nil || [registered containsObject: ns] )
            continue;
        
        if ( [self registerNamespace: ns] == NO )
            return ( NO );
        
        [registered addObject: ns];
    }
    
    // now look at the element and its ancestors
    while ( element != nil )
    {
        AQXMLNamespace * ns = element.ns;
        if ( ns != nil && [registered containsObject: ns] == NO )
        {
            if ( [self registerNamespace: ns] == NO )
                return ( NO );
            [registered addObject: ns];
        }
        
        element = element.parent;
    }
    
    return ( YES );
}

- (void) _performFunction: (NSString *) name uri: (NSString *) uri
                  context: (xmlXPathParserContextPtr) ctx nargs: (int) nargs
{
    NSString * key = name;
    if ( uri != nil )
        key = [name stringByAppendingFormat: @"—%@", uri];
    
    void (^fn)(xmlXPathParserContextPtr, int) = _functions[key];
    if ( fn == nil )
    {
        // pop arguments & return 'zero'
        for ( int i = 0; i < nargs; i++ )
        {
            valuePop(ctx);
        }
        
        valuePush(ctx, xmlXPathNewBoolean(0));
        return;
    }
    
    // call the block
    fn(ctx, nargs);
}

- (BOOL) registerFunctionWithName: (NSString *) name
                   implementation: (void (^)(xmlXPathParserContextPtr ctx, int nargs)) function
{
    if ( xmlXPathRegisterFunc(_ctx, [name xmlString], &_XPathBlockFunctionWrapper) == 0 )
    {
        // store the implementation block
        _functions[name] = [function copy];
        return ( YES );
    }
    
    return ( NO );
}

- (BOOL) registerFunctionWithName: (NSString *) name
                     namespaceURI: (NSString *) namespaceURI
                   implementation: (void (^)(xmlXPathParserContextPtr ctx, int nargs)) function
{
    if ( xmlXPathRegisterFuncNS(_ctx, [name xmlString], [namespaceURI xmlString], &_XPathBlockFunctionWrapper) == 0 )
    {
        // store the implementation block
        NSString * key = [name stringByAppendingFormat: @"–%@", namespaceURI];
        _functions[key] = [function copy];
        return ( YES );
    }
    
    return ( NO );
}

- (xmlXPathObjectPtr) xmlObjectFromObjCObject: (id) value
{
    // determine a suitable type
    xmlXPathObjectPtr xValue = NULL;
    if ( [value isKindOfClass: [NSNumber class]] )
    {
        if ( value == (__bridge id)kCFBooleanFalse || value == (__bridge id)kCFBooleanTrue )
        {
            xValue = xmlXPathNewBoolean([value intValue]);
        }
        else
        {
            xValue = xmlXPathNewFloat([value doubleValue]);
        }
    }
    else if ( [value isKindOfClass: [NSString class]] )
    {
        xValue = xmlXPathNewString([value xmlString]);
    }
    else if ( [value isKindOfClass: [AQXMLNode class]] )
    {
        xValue = xmlXPathNewNodeSet([(AQXMLNode *)value xmlObj]);
    }
    else if ( [value isKindOfClass: [AQXMLNodeSet class]] )
    {
        xValue = xmlXPathNewNodeSetList([(AQXMLNodeSet *)value xmlObj]);
    }
    else
    {
        NSAssert(0, @"Unexpected variable value class: %@", NSStringFromClass([value class]));
        NSLog(@"Unsupported variable value class: %@", NSStringFromClass([value class]));
    }
    
    return ( xValue );
}

- (BOOL) registerVariableWithName: (NSString *) name
                            value: (id) value
{
    xmlXPathObjectPtr xValue = [self xmlObjectFromObjCObject: value];
    if ( xValue == NULL )
        return ( NO );
    
    if ( xmlXPathRegisterVariable(_ctx, [name xmlString], xValue) == 0 )
    {
        _variables[name] = value;
        return ( YES );
    }
    
    return ( NO );
}

- (BOOL) registerVariableWithName: (NSString *) name
                     namespaceURI: (NSString *) namespaceURI
                            value: (id) value
{
    xmlXPathObjectPtr xValue = [self xmlObjectFromObjCObject: value];
    if ( xValue == NULL )
        return ( NO );
    
    if ( xmlXPathRegisterVariableNS(_ctx, [name xmlString], [namespaceURI xmlString], xValue) == 0 )
    {
        NSString * key = [name stringByAppendingFormat: @"—%@", namespaceURI];
        _variables[key] = value;
        return ( YES );
    }
    
    return ( NO );
}

@end
