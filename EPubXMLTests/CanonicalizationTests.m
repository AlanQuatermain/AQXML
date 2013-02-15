//
//  CanonicalizationTests.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-24.
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

#import "CanonicalizationTests.h"
#import <EPubXML/EPubXML.h>
#import "AQXMLParser.h"

@implementation CanonicalizationTests

+ (NSBundle *) bundle
{
    static NSBundle * __bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __bundle = [NSBundle bundleForClass: self];
    });
    return ( __bundle );
}

+ (NSData *) inputForTestNamed: (NSString *) name
{
    NSURL * url = [[self bundle] URLForResource: [NSString stringWithFormat: @"in%@", name] withExtension: @"xml"];
    return ( [NSData dataWithContentsOfURL: url] );
}

+ (NSDictionary *) outputsForTestNamed: (NSString *) name
{
    NSMutableDictionary * dict = [NSMutableDictionary new];
    
    NSString * cmp = [NSString stringWithFormat: @"out_in%@_", name];
    for ( NSURL * url in [[self bundle] URLsForResourcesWithExtension: @"xml" subdirectory: nil] )
    {
        if ( [[url lastPathComponent] hasPrefix: cmp] == NO )
            continue;
        
        NSString * rule = [[[url lastPathComponent] stringByDeletingPathExtension] substringFromIndex: [cmp length]];
        dict[rule] = url;
    }
    
    return ( dict );
}

+ (NSDictionary *) rulesWithName: (NSString *) name
{
    static NSDictionary * __rulesByName = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary * dict = [NSMutableDictionary new];
        for ( NSURL * url in [[self bundle] URLsForResourcesWithExtension: @"xml" subdirectory: nil] )
        {
            if ( [[url lastPathComponent] hasPrefix: @"in"] || [[url lastPathComponent] hasPrefix: @"out_"] )
                continue;
            
            NSError * error = nil;
            AQXMLDocument * doc = [AQXMLDocument documentWithContentsOfURL: url error: &error];
            if ( doc == nil )
            {
                NSLog(@"Error loading from %@: %@", url, error);
                continue;
            }
            
            BOOL preserveComments = [doc.rootElement firstChildNamed: @"c14n2:IgnoreComments"].boolValue;
            BOOL rewritePrefixes = [[doc.rootElement firstChildNamed: @"c14n2:PrefixRewrite"].stringValue isEqualToString: @"sequential"];
            BOOL preserveWhitespace = ![doc.rootElement firstChildNamed: @"c14n2:TrimTextNodes"].boolValue;
            
            NSMutableDictionary * qAttrs = [NSMutableDictionary new];
            AQXMLElement * qNames = [doc.rootElement firstChildNamed: @"c14n2:QNameAware"];
            
            for ( AQXMLElement * element in [qNames childrenNamed: @"c14n2:QualifiedAttr"] )
            {
                AQXMLAttribute * nameAttr = [element attributeNamed: @"Name"];
                AQXMLAttribute * nsAttr = [element attributeNamed: @"NS"];
                if ( nameAttr == nil || nsAttr == nil )
                    continue;
                
                qAttrs[nameAttr.value] = nsAttr.value;
            }
            
            NSMutableDictionary * qElems = [NSMutableDictionary new];
            for ( AQXMLElement * element in [qNames childrenNamed: @"c14n2:Element"] )
            {
                AQXMLAttribute * nameAttr = [element attributeNamed: @"Name"];
                AQXMLAttribute * nsAttr = [element attributeNamed: @"NS"];
                if ( nameAttr == nil || nsAttr == nil )
                    continue;
                
                qElems[nameAttr.value] = nsAttr.value;
            }
            
            NSMutableDictionary * qXElems = [NSMutableDictionary new];
            for ( AQXMLElement * element in [qNames childrenNamed: @"c14n2:XPathElement"] )
            {
                AQXMLAttribute * nameAttr = [element attributeNamed: @"Name"];
                AQXMLAttribute * nsAttr = [element attributeNamed: @"NS"];
                if ( nameAttr == nil || nsAttr == nil )
                    continue;
                
                qXElems[nameAttr.value] = nsAttr.value;
            }
            
            NSString * ruleName = [[url lastPathComponent] stringByDeletingPathExtension];
            NSDictionary * rules = @{
                @"preserveComments" :  @(preserveComments),
                @"rewritePrefixes" : @(rewritePrefixes),
                @"preserveWhitespace" : @(preserveWhitespace),
                @"qualifiedAttrs" : qAttrs,
                @"qualifiedElements" : qElems,
                @"qualifiedXPathElements" : qXElems
            };
            
            dict[ruleName] = rules;
        }
        
        __rulesByName = [dict copy];
    });
    
    return ( __rulesByName[name] );
}

- (void) setUp
{
    [[NSFileManager defaultManager] changeCurrentDirectoryPath: [[[self class] bundle] resourcePath]];
}

- (void) runCaseCoreForName: (NSString *) name
{
    NSData * input = [[self class] inputForTestNamed: name];
    NSLog(@"Input:\n%@", [[NSString alloc] initWithData: input encoding: NSUTF8StringEncoding]);
    STAssertNotNil(input, @"Failed to load test input");
    
    NSDictionary * outputs = [[self class] outputsForTestNamed: name];
    
    [outputs enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        NSDictionary * rules = [[self class] rulesWithName: key];
        NSData * output = [NSData dataWithContentsOfURL: obj];
        
        if ( rules == nil && output == nil )
            STFail(@"Failed to load test output or rules");
        
        AQXMLCanonicalizer * canon = [[AQXMLCanonicalizer alloc] initWithData: input];
        
        canon.preserveComments = [rules[@"preserveComments"] boolValue];
        canon.preserveWhitespace = [rules[@"preserveWhitespace"] boolValue];
        canon.rewritePrefixes = [rules[@"rewritePrefixes"] boolValue];
        
        [rules[@"qualifiedAttrs"] enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
            [canon addQNameAwareAttribute: key namespaceURI: obj];
        }];
        [rules[@"qualifiedElements"] enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
            [canon addQNameAwareElement: key namespaceURI: obj];
        }];
        [rules[@"qualifiedXPathElements"] enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
            [canon addQNameAwareXPathElement: key namespaceURI: obj];
        }];
        
        NSOutputStream * stream = [NSOutputStream outputStreamToMemory];
        NSError * error = nil;
        STAssertTrue([canon canonicalizeToStream: stream error: &error], @"Canonicalization failed: %@", error);
        
        NSData * canonicalized = [stream propertyForKey: NSStreamDataWrittenToMemoryStreamKey];
        STAssertNotNil(canonicalized, @"Canonicalization succeeded but produced no data");
        
        STAssertTrue([output isEqualToData: canonicalized], @"Expected:\n%@\n\nGot:\n%@\n", [[NSString alloc] initWithData: output encoding: NSUTF8StringEncoding], [[NSString alloc] initWithData: canonicalized encoding: NSUTF8StringEncoding]);
    }];
}
#if 0
- (void) testAAAAA
{
    NSData * data = [[self class] inputForTestNamed: @"C14N4"];
    AQXMLParser * parser = [[AQXMLParser alloc] initWithData: data];
    [parser parse];
}
#else
- (void) testPICommentsAndOutsideDoc
{
    [self runCaseCoreForName: @"C14N1"];
}

- (void) testWhitespace
{
    [self runCaseCoreForName: @"C14N2"];
}

- (void) testStartEndTags
{
    [self runCaseCoreForName: @"C14N3"];
}

- (void) testCharacters
{
    [self runCaseCoreForName: @"C14N4"];
}

- (void) testEntityReferences
{
    [self runCaseCoreForName: @"C14N5"];
}

- (void) testUTF8
{
    [self runCaseCoreForName: @"C14N6"];
}

- (void) testNamespacePushDown
{
    [self runCaseCoreForName: @"NsPushdown"];
}

- (void) testDefaultNamespace
{
    [self runCaseCoreForName: @"NsDefault"];
}

- (void) testNamespaceSorting
{
    [self runCaseCoreForName: @"NsSort"];
}

- (void) testNamespaceRedeclarations
{
    [self runCaseCoreForName: @"NsRedecl"];
}

- (void) testSuperfluousNamespaceDeclarations
{
    [self runCaseCoreForName: @"NsSuperfluous"];
}

- (void) testSpecialNamespaces
{
    [self runCaseCoreForName: @"NsXml"];
}

- (void) testNamespacePrefixesInContent
{
    [self runCaseCoreForName: @"NsContent"];
}
#endif
@end
