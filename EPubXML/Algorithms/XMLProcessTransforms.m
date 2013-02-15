//
//  XMLProcessTransforms.m
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

#import "XMLProcessTransforms.h"
#import "AQXMLDocument.h"
#import "AQXMLElement.h"
#import "AQXMLXPath.h"
#import "AQXMLNodeSet.h"
#import "AQXML_Private.h"
#import "Base64Transform.h"
#import <libxml/xpathInternals.h>
#import <libxslt/documents.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

@implementation XMLNodeTransform
@end

@implementation XPathTransform

- (id) main
{
    if ( self.node == nil )
        return ( nil );
    
    AQXMLNodeSet * nodeSet = (AQXMLNodeSet *)self.input;
    if ( [nodeSet isKindOfClass: [AQXMLNode class]] )
    {
        nodeSet = [AQXMLNodeSet nodeSetWithNode: (AQXMLNode *)nodeSet];
    }
    
    AQXMLDocument * doc = self.node.document;
    NSString * xpathString = self.node.content;
        
    AQXMLXPath * xPath = [AQXMLXPath XPathWithString: xpathString document: doc];
    [xPath registerFunctionWithName: @"here" implementation: ^(xmlXPathParserContextPtr ctx, int nargs) {
        // no arguments
        valuePush(ctx, xmlXPathNewNodeSet(self.node.xmlObj));
    }];
    
    [nodeSet expandSubtree];
    [nodeSet sort];
    
    AQXMLNodeSet * result = [AQXMLNodeSet nodeSet];
    [nodeSet enumerateNodesUsingBlock: ^(AQXMLNode *node, BOOL *stop) {
        NSError * error = nil;
        AQXMLNodeSet * xPathResult = [xPath evaluateOnNode: node error: &error];
        if ( result == nil )
        {
            NSLog(@"Error running XPath %@ on node %@: %@", xPath, node, error);
            return;
        }
        
        if ( [xPathResult isKindOfClass: [AQXMLNodeSet class]] )
        {
            [result unionSet: xPathResult];
        }
        else
        {
            NSLog(@"XPath %@ on node %@ returned non-node-set object %@", xPath, node, xPathResult);
        }
    }];
    
    return ( result );
}

@end

@implementation XPathFilter2Transform

- (id) main
{
    AQXMLElement * txElement = (AQXMLElement *)self.node;
    if ( txElement == nil || [txElement isKindOfClass: [AQXMLElement class]] == NO )
        return ( nil );
    
    AQXMLNodeSet * inputSet = (AQXMLNodeSet *) self.input;
    if ( [inputSet isKindOfClass: [NSString class]] )
    {
        AQXMLDocument * doc = [AQXMLDocument documentWithXMLString: (NSString *)inputSet
                                                             error: NULL];
        if ( doc == nil )
            return ( nil );
        
        inputSet = [AQXMLNodeSet nodeSetWithNode: doc];
    }
    else if ( [inputSet isKindOfClass: [NSData class]] )
    {
        AQXMLDocument * doc = [AQXMLDocument documentWithXMLData: (NSData *)inputSet
                                                           error: NULL];
        if ( doc == nil )
            return ( nil );
        
        inputSet = [AQXMLNodeSet nodeSetWithNode: doc];
    }
    else if ( [inputSet isKindOfClass: [AQXMLNode class]] )
    {
        inputSet = [AQXMLNodeSet nodeSetWithNode: (AQXMLNode *)inputSet];
    }
    
    if ( [inputSet isKindOfClass: [AQXMLNodeSet class]] == NO )
        return ( nil );
    
    [inputSet expandSubtree];
    [inputSet sort];
    
    AQXMLNodeSet * output = [inputSet copy];
    
    AQXMLDocument * doc = txElement.document;
    AQXMLNodeSet * complete = [AQXMLNodeSet nodeSetWithNode: doc.rootElement];
    [complete expandSubtree];
    [complete sort];
    
    // enumerate the filters
    for ( AQXMLElement * XPathElement in [txElement childrenNamed: @"XPath"] )
    {
        NSString * XPathString = [XPathElement.content stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        AQXMLXPath * xPath = [AQXMLXPath XPathWithString: XPathString document: doc];
        
        for ( AQXMLNamespace * ns in doc.namespaces )
        {
            [xPath registerNamespace: ns];
        }
        
        [xPath registerFunctionWithName: @"here" implementation: ^(xmlXPathParserContextPtr ctx, int nargs) {
            // no arguments to pop, just push a new node-set
            valuePush(ctx, xmlXPathNewNodeSet(XPathElement.xmlObj));
        }];
        
        AQXMLNodeSet * nodeSet = [xPath evaluateOnNode: doc.rootElement error: NULL];
        if ( nodeSet == nil )
            continue;
        if ( [nodeSet isKindOfClass: [AQXMLNodeSet class]] == NO )
            return ( nil );     // hard error
        
        AQXMLAttribute * attr = [XPathElement attributeNamed: @"Filter"];
        if ( [attr.value isEqualToString: @"intersect"] )
        {
            [complete intersectSet: nodeSet];
        }
        else if ( [attr.value isEqualToString: @"subtract"] )
        {
            [complete subtractSet: nodeSet];
        }
        else if ( [attr.value isEqualToString: @"union"] )
        {
            [complete unionSet: nodeSet];
        }
    }
    
    [output intersectSet: complete];
    return ( output );
}

@end

@implementation EnvelopedSignatureTransform

- (id) main
{
    // input must be a node-set
    AQXMLNodeSet * nodeSet = self.input;
    if ( [nodeSet isKindOfClass: [AQXMLNodeSet class]] == NO )
        return ( nil );
    
    // scan up the hierarchy to find the ancestor Signature node
    AQXMLElement * element = self.node;
    while ( element != nil )
    {
        if ( [element.name isEqualToString: @"Signature"] )
            break;
        
        element = element.parent;
    }
    
    if ( element == nil )
        return ( nodeSet );     // *shrugs*
    
    
    AQXMLNodeSet * output = [nodeSet copy];
    [output subtractSet: [AQXMLNodeSet nodeSetWithTreeAtElement: element]];
    return ( output );
}

@end

@implementation XSLTTransform

- (id) main
{
    // input and output are both octet-streams
    NSData * data = self.input;
    if ( [data isKindOfClass: [NSString class]] )
        data = [self.input dataUsingEncoding: NSUTF8StringEncoding];
    
    NSArray * sub = [self.node childrenNamed: @"stylesheet"];
    if ( [sub count] == 0 )
        sub = [self.node childrenNamed: @"transform"];      // synonym for 'stylesheet'
    if ( [sub count] == 0 )
        return ( nil );         // invalid
    
    AQXMLDocument * doc = [AQXMLDocument documentWithRootElement: sub[0]];
    
    // create an XSLT stylesheet for this document
    xsltStylesheetPtr stylesheet = xsltParseStylesheetDoc(doc.xmlObj);
    xmlDocPtr applied = xsltApplyStylesheet(stylesheet, self.node.document.xmlObj, NULL);
    
    xmlChar *output = NULL;
    int outputLen = 0;
    xsltSaveResultToString(&output, &outputLen, applied, stylesheet);
    
    xmlFreeNode((xmlNodePtr)doc.xmlObj);
    xmlFreeNode((xmlNodePtr)applied);
    xsltFreeStylesheet(stylesheet);
    
    return ( [NSData dataWithBytesNoCopy: output length: outputLen] );
}

@end

@implementation DSIG2SelectionTransform

- (id) process
{
    if ( self.node == nil )
        return ( nil );
    
    @autoreleasepool
    {
        if ( [self.node.name isEqualToString: @"Selection"] == NO )
            return ( nil );
        
        AQXMLAttribute * uriAttr = [self.node attributeNamed: @"URI"];
        if ( uriAttr == nil )
            return ( nil );
        
        NSString * uri = [uriAttr value];
        if ( uri == nil )
            return ( nil );
        
        if ( [uri length] == 0 )
        {
            // same document reference, complete document
            self.input = self.node.rootElement;
            return ( [super process] );
        }
        
        if ( [uri hasPrefix: @"#"] )
        {
            // same-document fragment
            // ensure there is no dsig2:IncludedXPath element of our node
            if ( [self.node firstChildNamed: @"IncludedXPath"] != nil )
            {
                // invalid selection
                return ( nil );
            }
            
            NSString * xPath = [NSString stringWithFormat: @"id('%@')", [uri substringFromIndex: 1]];
            NSArray * elements = [self.node.rootElement elementsForXPath: xPath error: NULL];
            if ( [elements count] == 0 )
                return ( nil );
            
            self.input = elements[0];
            return ( [super process] );
        }
        
        NSURL * url = [NSURL URLWithString: uri];
        if ( [self isKindOfClass: [BinarySelectionTransform class]] )
        {
            // read a plain octet-stream
            self.input = [NSData dataWithContentsOfURL: url];
            return ( [super process] );
        }
        
        AQXMLDocument * doc = [AQXMLDocument documentWithContentsOfURL: url error: NULL];
        if ( doc == nil )
            return ( nil );
        
        if ( [url fragment] != nil )
        {
            NSString * xPath = [NSString stringWithFormat: @"id('%@')", [url fragment]];
            NSArray * elements = [doc.rootElement elementsForXPath: xPath error: NULL];
            if ( [elements count] == 0 )
                return ( nil );
            
            self.input = elements[0];
            return ( [super process] );
        }
        
        self.input = doc.rootElement;
    }
    
    return ( [super process] );
}

- (id) canonicalizeOutput: (id) output specNode: (AQXMLElement *) specNode
{
    if ( [output isKindOfClass: [AQXMLNodeSet class]] == NO )
        return ( output );      // no canonicalization except for node sets
    
    AQXMLNodeSet * nodeSet = (AQXMLNodeSet *)output;
    if ( nodeSet.count == 0 )
        return ( [NSData data] );   // empty node-set is valid
    
    AQXMLElement * canonicalization = [specNode firstChildNamed: @"CanonicalizationMethod"];
    if ( canonicalization == nil )
        canonicalization = [specNode firstChildNamed: @"Canonicalization"];
    
    if ( canonicalization == nil )
        return ( output );
    
    NSString * algorithm = [canonicalization attributeNamed: @"Algorithm"].value;
    if ( algorithm == nil )
        return ( output );          // should be an error?
    
    static NSDictionary * __algLookup = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __algLookup = @{
            @"http://www.w3.org/TR/2001/REC-xml-c14n-20010315" : @(AQXMLCanonicalizationMethod_1_0),
            @"http://www.w3.org/TR/2001/REC-xml-c14n-20010315#WithComments" : @(AQXMLCanonicalizationMethod_1_0|AQXMLCanonicalizationMethod_with_comments),
            @"http://www.w3.org/2006/12/xml-c14n11" : @(AQXMLCanonicalizationMethod_1_1),
            @"http://www.w3.org/2006/12/xml-c14n11#WithComments" : @(AQXMLCanonicalizationMethod_1_1|AQXMLCanonicalizationMethod_with_comments),
            @"http://www.w3.org/2001/10/xml-exc-c14n#" : @(AQXMLCanonicalizationMethod_exclusive_1_0),
            @"http://www.w3.org/2001/10/xml-exc-c14n#WithComments" : @(AQXMLCanonicalizationMethod_exclusive_1_0|AQXMLCanonicalizationMethod_with_comments),
            @"http://www.w3.org/2010/xml-c14n2" : @(AQXMLCanonicalizationMethod_2_0)
        };
    });
    
    AQXMLCanonicalizationMethod method = [__algLookup[algorithm] integerValue];
    
    // node set MUST have already gone through subtree expansion
    AQXMLDocument * doc = nodeSet[0].document;
    if ( method == AQXMLCanonicalizationMethod_2_0 )
    {
        AQXMLCanonicalizer * canon = [[AQXMLCanonicalizer alloc] initWithDocument: doc];
        canon.preserveComments = [specNode firstChildNamed: @"c14n2:IgnoreComments"].firstChild.boolValue;
        canon.rewritePrefixes = [[specNode firstChildNamed: @"c14n2:PrefixRewrite"].firstChild.stringValue isEqualToString: @"sequential"];
        canon.preserveWhitespace = ![specNode firstChildNamed: @"c14n2:TrimTextNodes"].firstChild.boolValue;
        
        AQXMLElement * qNames = [doc.rootElement firstChildNamed: @"c14n2:QNameAware"];
        if ( qNames != nil )
        {
            for ( AQXMLElement * element in [qNames childrenNamed: @"c14n2:QualifiedAttr"] )
            {
                AQXMLAttribute * nameAttr = [element attributeNamed: @"Name"];
                AQXMLAttribute * nsAttr = [element attributeNamed: @"NS"];
                if ( nameAttr == nil || nsAttr == nil )
                    continue;
                
                [canon addQNameAwareAttribute: nameAttr.value namespaceURI: nsAttr.value];
            }
            
            for ( AQXMLElement * element in [qNames childrenNamed: @"c14n2:Element"] )
            {
                AQXMLAttribute * nameAttr = [element attributeNamed: @"Name"];
                AQXMLAttribute * nsAttr = [element attributeNamed: @"NS"];
                if ( nameAttr == nil || nsAttr == nil )
                    continue;
                
                [canon addQNameAwareElement: nameAttr.value namespaceURI: nsAttr.value];
            }
            
            for ( AQXMLElement * element in [qNames childrenNamed: @"c14n2:XPathElement"] )
            {
                AQXMLAttribute * nameAttr = [element attributeNamed: @"Name"];
                AQXMLAttribute * nsAttr = [element attributeNamed: @"NS"];
                if ( nameAttr == nil || nsAttr == nil )
                    continue;
                
                [canon addQNameAwareXPathElement: nameAttr.value namespaceURI: nsAttr.value];
            }
        }
        
        canon.isNodeVisible = ^BOOL(AQXMLNode * node) {
            return ( [nodeSet containsNode: node] );
        };
        
        NSOutputStream * stream = [NSOutputStream outputStreamToMemory];
        if ( [canon canonicalizeToStream: stream error: NULL] == NO )
            return ( nil );
        
        return ( [stream propertyForKey: NSStreamDataWrittenToMemoryStreamKey] );
    }
    
    return ( [AQXMLCanonicalizer canonicalizeDocument: doc usingMethod: method visibilityFilter: ^BOOL(AQXMLNode *node) {
        return ( [nodeSet containsNode: node] );
    }] );
}

@end

@implementation XMLSelectionTransform

- (id) main
{
    // we know that the input is valid at this point, because -process validated it for us
    AQXMLElement * element = self.input;
    AQXMLNodeSet * nodeSet = [AQXMLNodeSet nodeSet];
    
    // there can be up to two XPaths below our input node
    AQXMLElement * incElement = [self.node firstChildNamed: @"IncludedXPath"];
    if ( incElement != nil )
    {
        [incElement consolidateConsecutiveTextNodes];
        NSString * xPathStr = [incElement.firstChild.content stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        AQXMLXPath * xPath = [AQXMLXPath XPathWithString: xPathStr document: element.document];
        [xPath registerNamespaces: incElement.namespacesInScope];
        
        AQXMLNodeSet * includedNodes = [xPath evaluateOnNode: element error: NULL];
        if ( includedNodes.count != 0 )
            [nodeSet unionSet: includedNodes];
    }
    else if ( [[self.node attributeNamed: @"URI"].value rangeOfString: @"#"].location == NSNotFound )
    {
        // XML-DSig 2.0 says that if the Selection URI has no fragment, the *document node* is added to the inclusion set
        [nodeSet addNode: element.document];
    }
    else
    {
        [nodeSet addNode: element];
    }
    
    [nodeSet expandSubtree];
    
    AQXMLElement * excElement = [self.node firstChildNamed: @"ExcludedXPath"];
    if ( excElement != nil )
    {
        [excElement consolidateConsecutiveTextNodes];
        NSString * xPathStr = [excElement.firstChild.content stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        AQXMLXPath * xPath = [AQXMLXPath XPathWithString: xPathStr document: element.document];
        [xPath registerNamespaces: excElement.namespacesInScope];
        
        AQXMLNodeSet * excludedNodes = [xPath evaluateOnNode: element error: NULL];
        if ( excludedNodes.count != 0 )
        {
            [excludedNodes expandSubtree];
            [nodeSet subtractSet: excludedNodes];
        }
    }
    
    [nodeSet sort];
    return ( nodeSet );
}

@end

@implementation BinarySelectionTransform

- (id) main
{
    NSData * octetStream = self.input;
    NSMutableIndexSet * ranges = [NSMutableIndexSet indexSet];
    
    AQXMLElement * rangeElem = [self.node firstChildNamed: @"ByteRange"];
    if ( rangeElem != nil )
    {
        // parse ranges in HTTP 1.1 format (a-b,c-d,e-f)
        [rangeElem consolidateConsecutiveTextNodes];
        @autoreleasepool
        {
            NSArray * pairs = [rangeElem.firstChild.content componentsSeparatedByString: @","];
            for ( NSString * pairStr in pairs )
            {
                NSArray * pair = [pairStr componentsSeparatedByString: @"-"];
                if ( [pair count] != 2 )
                    continue;
                
                NSRange r = NSMakeRange([pair[0] integerValue], [pair[1] integerValue]);
                [ranges addIndexesInRange: r];
            }
        }
    }
    else
    {
        // entire range
        [ranges addIndexesInRange: NSMakeRange(0, [octetStream length])];
    }
    
    NSMutableData * output = [NSMutableData new];
    const uint8_t *p = [output bytes];
    [ranges enumerateRangesInRange: NSMakeRange(0, [octetStream length]) options: 0 usingBlock: ^(NSRange range, BOOL *stop) {
        [output appendBytes: p + range.location length: range.length];
    }];
    
    return ( output );
}

@end

@implementation BinaryFromXMLSelectionTransform

- (id) main
{
    AQXMLElement * element = self.input;
    
    NSData * data = nil;
    AQXMLElement * incElement = [self.node firstChildNamed: @"IncludedXPath"];
    if ( incElement != nil )
    {
        [incElement consolidateConsecutiveTextNodes];
        NSString * xPathStr = [incElement.firstChild.content stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        AQXMLXPath * xPath = [AQXMLXPath XPathWithString: xPathStr document: element.document];
        [xPath registerNamespaces: incElement.namespacesInScope];
        
        AQXMLNodeSet * includedNodes = [xPath evaluateOnNode: element error: NULL];
        if ( includedNodes.count != 1 )
            return ( nil );     // XPath MUST return a single node
        
        AQXMLElement * elem = (AQXMLElement *)includedNodes[0];
        if ( elem.type != AQXMLNodeTypeElement )
            return ( nil );     // XPath MUST select only element nodes
        
        [elem consolidateConsecutiveTextNodes];
        data = [Base64Transform decode: [elem.firstChild.content dataUsingEncoding: NSUTF8StringEncoding]];
    }
    else
    {
        [element consolidateConsecutiveTextNodes];
        data = [Base64Transform decode: [element.firstChild.content dataUsingEncoding: NSUTF8StringEncoding]];
    }
    
    // let's use a plain binary transform to do the work for us & keep things DRY
    BinarySelectionTransform * binaryTx = [BinarySelectionTransform new];
    binaryTx.input = data;
    binaryTx.node = self.node;
    
    return ( [binaryTx main] );
}

@end
