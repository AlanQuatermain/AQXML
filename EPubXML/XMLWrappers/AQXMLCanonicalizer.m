//
//  AQXMLCanonicalizer.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-23.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLCanonicalizer.h"
#import "AQXML_Private.h"
#import "AQXMLParser.h"
#import <libxml/c14n.h>
#import <libxml/xpathInternals.h>

@class _StackContext;

static NSString * const AQXMLCanonicalizerOutputRunLoopMode = @"AQXMLCanonicalizerOutputRunLoopMode";

@interface AQXMLCanonicalizer () <AQXMLParserDelegate, NSStreamDelegate>
- (_StackContext *) newStackContext;
@end

@interface _StackContext : NSObject
@property (nonatomic, strong) NSMutableDictionary * namespaceContext; // prefix -> uri
@property (nonatomic, strong) NSMutableSet * outputPrefixes;
@property (nonatomic, strong) NSString * elementQName;
@property (nonatomic, readonly) NSString * elementLocalName;
@property (nonatomic, readonly) NSString * elementPrefix;
@property (nonatomic) BOOL preserveSpace;
@end

@implementation _StackContext

- (NSString *) elementLocalName
{
    NSString * q = self.elementQName;
    if ( q == nil )
        return ( nil );
    
    NSRange r = [q rangeOfString: @":"];
    if ( r.location != NSNotFound )
        return ( [q substringFromIndex: NSMaxRange(r)] );
    return ( q );
}

- (NSString *) elementPrefix
{
    NSString * q = self.elementQName;
    if ( q == nil )
        return ( nil );
    
    NSRange r = [q rangeOfString: @":"];
    if ( r.location == NSNotFound )
        return ( @"" );
    
    return ( [q substringToIndex: r.location] );
}

@end

@implementation AQXMLCanonicalizer
{
    AQXMLParser *           _parser;
    AQXMLDocument *         _document;
    
    NSMutableArray *        _stack;
    NSMutableDictionary *   _qnameAwareAttrs; // name -> uri
    NSMutableDictionary *   _qnameAwareElements;
    NSMutableDictionary *   _qnameAwareXPathElements;
    NSMutableDictionary *   _rewrittenPrefixes; // uri -> rewrittenPrefix
    NSUInteger              _nsRewriteCounter;
    NSMutableDictionary *   _schemas;
    NSMutableString *       _runningChars;
    NSMutableDictionary *   _pendingNamespaces;     // ns reported before element
    NSMutableDictionary *   _attrDecls;
    BOOL                    _documentRootEncountered;
    
    NSInvocation *          _qualifiedContentStartElementInvocation;
    
    NSOutputStream *        _output;
    NSError *               _error;
}

+ (NSMutableDictionary *) _schemaLookupTable
{
    static NSMutableDictionary * __lookup = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __lookup = [NSMutableDictionary new];
        __lookup[@"http://www.w3.org/2001/XMLSchema"] = @"http://www.w3.org/2001/05/XMLSchema.xsd";
        __lookup[@"http://www.w3.org/XML/1998/namespace"] = @"http://www.w3.org/2004/10/xml.xsd";
        __lookup[@"http://www.w3.org/1999/XSL/Transform"] = @"http://www.w3.org/2007/schema-for-xslt20.xsd";
        __lookup[@"http://www.w3.org/2000/09/xmldsig#"] = @"http://www.w3.org/TR/xmldsig-core/xmldsig-core-schema.xsd";
        __lookup[@"http://www.w3.org/2009/xmldsig11#"] = @"http://www.w3.org/TR/xmldsig-core1/xmldsig1-schema.xsd";
        __lookup[@"http://www.w3.org/2001/04/xmlenc#"] = @"http://www.w3.org/TR/xmlenc-core/xenc-schema.xsd";
        __lookup[@"http://www.w3.org/2009/xmlenc11#"] = @"http://www.w3.org/TR/xmlenc-core1/xenc-schema-11.xsd";
    });
    
    return ( __lookup );
}

static int __node_visible_callback(void *user_data, xmlNodePtr node, xmlNodePtr parent)
{
    BOOL (^block)(AQXMLNode *) = (__bridge BOOL(^)(AQXMLNode *))user_data;
    if ( block == nil )
        return ( 1 );       // assume it's included
    
    AQXMLNode * obj = (__bridge AQXMLNode *)node->_private;
    return ( block(obj) ? 1 : 0 );
}

+ (NSData *) canonicalizeDocument: (AQXMLDocument *) document
                      usingMethod: (AQXMLCanonicalizationMethod) method
                 visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible
{
    if ( (method & 0x7f) == AQXMLCanonicalizationMethod_2_0 )
    {
        AQXMLCanonicalizer * worker = [[self alloc] initWithDocument: document];
        worker.preserveComments = (method & AQXMLCanonicalizationMethod_with_comments);
        worker.isNodeVisible = isNodeVisible;
        NSOutputStream * output = [NSOutputStream outputStreamToMemory];
        if ( [worker canonicalizeToStream: output error: NULL] )
            return ( [output propertyForKey: NSStreamDataWrittenToMemoryStreamKey] );
        
        return ( nil );
    }
    
    // otherwise it's something libxml can handle
    xmlBufferPtr xmlBuf = xmlBufferCreate();
    xmlOutputBufferPtr output = xmlOutputBufferCreateBuffer(xmlBuf, NULL);
    
    int mode = (method & ~AQXMLCanonicalizationMethod_with_comments);
    int ok = xmlC14NExecute(document.xmlObj, &__node_visible_callback, (__bridge void *)isNodeVisible, mode, NULL, (method & AQXMLCanonicalizationMethod_with_comments), output);
    
    xmlOutputBufferClose(output);
    if ( ok != 0 )
    {
        xmlBufferFree(xmlBuf);
        return ( nil );
    }
    
    NSData * data = [NSData dataWithBytes: xmlBuf->content length: xmlBuf->use];
    xmlBufferFree(xmlBuf);
    
    return ( data );
}

+ (NSData *) canonicalizeElement: (AQXMLElement *) element
                     usingMethod: (AQXMLCanonicalizationMethod) method
                visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible
{
    if ( (method & 0x7f) == AQXMLCanonicalizationMethod_2_0 )
    {
        BOOL (^checkElementHierarchy)(AQXMLNode *) = ^BOOL(AQXMLNode * node) {
            AQXMLNode * check = node;
            while ( check != nil )
            {
                if ( check == node )
                    break;      // matched, so this one succeeds
                check = check.parent;
            }
            
            if ( check == nil )
                return ( NO );      // not a descendant of the element node
            
            if ( isNodeVisible != nil )
                return ( isNodeVisible(node) );
            return ( YES );
        };
        
        // get a data blob for stream processing
        AQXMLCanonicalizer * worker = [[self alloc] initWithDocument: element.document];
        worker.preserveComments = (method & AQXMLCanonicalizationMethod_with_comments);
        worker.isNodeVisible = checkElementHierarchy;
        NSOutputStream * output = [NSOutputStream outputStreamToMemory];
        if ( [worker canonicalizeToStream: output error: NULL] )
            return ( [output propertyForKey: NSStreamDataWrittenToMemoryStreamKey] );
        
        return ( nil );
    }
    
    // otherwise it's something libxml can handle
    xmlBufferPtr xmlBuf = xmlBufferCreate();
    xmlOutputBufferPtr output = xmlOutputBufferCreateBuffer(xmlBuf, NULL);
    
    int mode = (method & ~AQXMLCanonicalizationMethod_with_comments);
    int ok = xmlC14NExecute(element.document.xmlObj, &__node_visible_callback, (__bridge void *)isNodeVisible, mode, NULL, (method & AQXMLCanonicalizationMethod_with_comments), output);
    
    xmlOutputBufferClose(output);
    if ( ok != 0 )
    {
        xmlBufferFree(xmlBuf);
        return ( nil );
    }
    
    NSData * data = [NSData dataWithBytes: xmlBuf->content length: xmlBuf->use];
    xmlBufferFree(xmlBuf);
    
    return ( data );
}

+ (NSData *) canonicalizeContentAtURI: (NSURL *) uri
                          usingMethod: (AQXMLCanonicalizationMethod) method
                     visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible
{
    if ( (method & 0x7f) == AQXMLCanonicalizationMethod_2_0 )
    {
        NSInputStream * stream = [NSInputStream inputStreamWithURL: uri];
        AQXMLCanonicalizer * worker = [[self alloc] initWithStream: stream];
        worker.preserveComments = (method & AQXMLCanonicalizationMethod_with_comments);
        worker.fragment = [uri fragment];
        worker.isNodeVisible = isNodeVisible;
        NSOutputStream * output = [NSOutputStream outputStreamToMemory];
        if ( [worker canonicalizeToStream: output error: NULL] )
            return ( [output propertyForKey: NSStreamDataWrittenToMemoryStreamKey] );
        
        return ( nil );
    }
    
    AQXMLDocument * doc = [AQXMLDocument documentWithContentsOfURL: uri error: NULL];
    if ( [uri fragment] != nil )
    {
        NSArray * elements = [doc.rootElement elementsForXPath: [NSString stringWithFormat: @"id(\"%@\")", [uri fragment]]
                                                         error: NULL];
        if ( [elements count] == 0 )
            return ( nil );
        return ( [self canonicalizeElement: elements[0] usingMethod: method visibilityFilter: isNodeVisible] );
    }
    
    return ( [self canonicalizeDocument: doc usingMethod: method visibilityFilter: isNodeVisible] );
}

+ (NSData *) canonicalizeData: (NSData *) data
                  usingMethod: (AQXMLCanonicalizationMethod) method
             visibilityFilter: (BOOL (^)(AQXMLNode * node)) isNodeVisible
{
    if ( (method & 0x7f) == AQXMLCanonicalizationMethod_2_0 )
    {
        AQXMLCanonicalizer * worker = nil;
        
        if ( isNodeVisible != nil )
            worker = [[self alloc] initWithDocument: [AQXMLDocument documentWithXMLData: data error: NULL]];
        else
            worker = [[self alloc] initWithData: data];
        
        worker.preserveComments = (method & AQXMLCanonicalizationMethod_with_comments);
        worker.isNodeVisible = isNodeVisible;
        NSOutputStream * output = [NSOutputStream outputStreamToMemory];
        if ( [worker canonicalizeToStream: output error: NULL] )
            return ( [output propertyForKey: NSStreamDataWrittenToMemoryStreamKey] );
        
        return ( nil );
    }
    
    AQXMLDocument * doc = [AQXMLDocument documentWithXMLData: data error: NULL];
    return ( [self canonicalizeDocument: doc usingMethod: method visibilityFilter: isNodeVisible] );
}

- (id) initWithData: (NSData *) data
{
    return ( [self initWithStream: [NSInputStream inputStreamWithData: data]] );
}

- (id) initWithStream: (NSInputStream *) stream
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _parser = [[AQXMLParser alloc] initWithStream: stream];
    _parser.delegate = self;
    _parser.shouldProcessNamespaces = YES;
    _parser.shouldReportNamespacePrefixes = YES;
    _parser.shouldResolveExternalEntities = YES;
    
    _stack = [NSMutableArray new];
    _qnameAwareAttrs = [NSMutableDictionary new];
    _qnameAwareElements = [NSMutableDictionary new];
    _qnameAwareXPathElements = [NSMutableDictionary new];
    _rewrittenPrefixes = [NSMutableDictionary new];
    _nsRewriteCounter = 0;
    _schemas = [NSMutableDictionary new];
    _runningChars = [NSMutableString new];
    _pendingNamespaces = [NSMutableDictionary new];
    _attrDecls = [NSMutableDictionary new];
    
    return ( self );
}

- (id) initWithDocument: (AQXMLDocument *) document
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _document = document;
    
    _stack = [NSMutableArray new];
    _qnameAwareAttrs = [NSMutableDictionary new];
    _qnameAwareElements = [NSMutableDictionary new];
    _qnameAwareXPathElements = [NSMutableDictionary new];
    _rewrittenPrefixes = [NSMutableDictionary new];
    _nsRewriteCounter = 0;
    _schemas = [NSMutableDictionary new];
    _runningChars = [NSMutableString new];
    _pendingNamespaces = [NSMutableDictionary new];
    _attrDecls = [NSMutableDictionary new];
    
    return ( self );
}

- (void) addQNameAwareAttribute: (NSString *) name namespaceURI: (NSString *) namespaceURI
{
    _qnameAwareAttrs[name] = namespaceURI;
}

- (void) addQNameAwareElement: (NSString *) name namespaceURI: (NSString *) namespaceURI
{
    _qnameAwareElements[name] = namespaceURI;
}

- (void) addQNameAwareXPathElement: (NSString *) name namespaceURI: (NSString *) namespaceURI
{
    _qnameAwareXPathElements[name] = namespaceURI;
}

- (_StackContext *) newStackContext
{
    _StackContext * ctx = [_StackContext new];
    _StackContext * cur = [_stack lastObject];
    if ( cur != nil )
    {
        ctx.namespaceContext = [cur.namespaceContext mutableCopy];
        ctx.outputPrefixes = [cur.outputPrefixes mutableCopy];
        ctx.preserveSpace = cur.preserveSpace;
    }
    else
    {
        ctx.namespaceContext = [NSMutableDictionary new];
        ctx.outputPrefixes = [NSMutableSet new];
    }
    
    [_stack addObject: ctx];
    
    return ( ctx );
}

- (void) canonicalizeToStream: (NSOutputStream *) stream completionHandler: (void (^)(NSError * error)) handler
{
    void (^handlerCopy)(NSError *) = [handler copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError * error = nil;
        if ( [self canonicalizeToStream: stream error: &error] == NO )
            handlerCopy(error);
        else
            handlerCopy(nil);
    });
}

- (BOOL) canonicalizeToStream: (NSOutputStream *) stream error: (NSError **) error
{
    _output = stream;
    if ( [stream streamStatus] == NSStreamStatusNotOpen )
    {
        [self openOutputStream];
        if ( [_output streamStatus] != NSStreamStatusOpen )
        {
            if ( error != NULL )
                *error = [_output streamError];
            return ( NO );
        }
    }
    
    if ( _parser != nil )
    {
        // operating in streaming mode
        if ( [_parser parse] == NO )
        {
            if ( error != NULL )
            {
                if ( _error != nil )
                    *error = _error;
                else
                    *error = [_parser parserError];
            }
            
            return ( NO );
        }
        
        _output = nil;
        return ( YES );
    }
    else
    {
        // operating in DOM mode
        // this is a recursive algorithm
        AQXMLDocument * doc = _document;
        if ( self.rewritePrefixes )
            doc = [doc copy];       // we modify text nodes & attr values when rewriting
        [self canonicalizeSubtreeAtNode: [_document copy]];
    }
    
    _output = nil;
    return ( YES );
}

#pragma mark - Output Stream Helpers

- (void) stream: (NSStream *) aStream handleEvent: (NSStreamEvent) eventCode
{
    // not interested in the event, just that it wakes the runloop
}

- (void) openOutputStream
{
    [_output setDelegate: self];
    [_output scheduleInRunLoop: [NSRunLoop currentRunLoop]
                       forMode: AQXMLCanonicalizerOutputRunLoopMode];
    
    [_output open];
    
    do
    {
        @autoreleasepool
        {
            [[NSRunLoop currentRunLoop] runMode: AQXMLCanonicalizerOutputRunLoopMode
                                     beforeDate: [NSDate distantFuture]];
            
            BOOL done = NO;
            switch ( [_output streamStatus] )
            {
                case NSStreamStatusNotOpen:
                case NSStreamStatusOpening:
                    break;
                    
                default:
                    done = YES;
                    break;
            }
            
            if ( done )
                break;
        }
        
    } while (1);
    
    [_output setDelegate: nil];
    [_output removeFromRunLoop: [NSRunLoop currentRunLoop]
                       forMode: AQXMLCanonicalizerOutputRunLoopMode];
}

- (BOOL) outputData: (NSData *) data error: (NSError **) error
{
    NSInteger written = [_output write: [data bytes] maxLength: [data length]];
    if ( written < 0 )
    {
        if ( error != NULL )
            *error = [_output streamError];
        return ( NO );
    }
    
    if ( written == [data length] )
        return ( YES );
    
    [_output setDelegate: self];
    [_output scheduleInRunLoop: [NSRunLoop currentRunLoop]
                       forMode: AQXMLCanonicalizerOutputRunLoopMode];
    
    const uint8_t *p = [data bytes];
    NSUInteger len = [data length];
    p += written;
    len -= written;
    
    while ( len > 0 )
    {
        do
        {
            @autoreleasepool
            {
                [[NSRunLoop currentRunLoop] runMode: AQXMLCanonicalizerOutputRunLoopMode
                                         beforeDate: [NSDate distantFuture]];
            }
            
            if ( [_output streamStatus] == NSStreamStatusError )
            {
                if ( error != NULL )
                    *error = [_output streamError];
                break;
            }
            
        } while ( [_output hasSpaceAvailable] == NO );
        
        written = [_output write: p maxLength: len];
        if ( written < 0 )
        {
            if ( error != NULL )
                *error = [_output streamError];
            [_output setDelegate: nil];
            [_output removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: AQXMLCanonicalizerOutputRunLoopMode];
            return ( NO );
        }
        
        p += written;
        len -= written;
    }
    
    return ( YES );
}

#define WRITE(d, e) \
if ( [self outputData: d error: &e] == NO ) \
{ \
    [_parser abortParsing]; \
    _error = e; \
    return; \
}

#pragma mark - Streaming Mode

- (void) outputBufferedChars
{
    if ( [_runningChars length] > 0 )
    {
        if (self.preserveWhitespace == NO)
        {
            [_runningChars setString: [_runningChars stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        }
        
        if ( [_runningChars length] == 0 )
            return;
        
        NSError * error = nil;
        WRITE([_runningChars dataUsingEncoding: NSUTF8StringEncoding], error);
        [_runningChars setString: @""];
    }
}

- (void) parser: (AQXMLParser *) parser didStartMappingPrefix: (NSString *) prefix toURI: (NSString *) namespaceURI
{
    _pendingNamespaces[prefix] = namespaceURI;
    /*
    if ( _schemas[namespaceURI] == nil )
    {
        NSString * schemaURL = [[self class] _schemaLookupTable][namespaceURI];
        if ( schemaURL != nil )
        {
            AQXMLSchema * schema = [AQXMLSchema schemaWithURL: [NSURL URLWithString: schemaURL]];
            if ( schema != nil )
                _schemas[namespaceURI] = schema;
        }
    }
     */
}

- (void) parser: (AQXMLParser *) parser foundAttributeDeclarationWithName: (NSString *) attributeName forElement: (NSString *) elementName type: (NSString *) type defaultValue: (NSString *) defaultValue
{
    NSString * key = [elementName stringByAppendingFormat: @":%@", attributeName];
    NSMutableDictionary * dict = [NSMutableDictionary new];
    
    dict[@"type"] = type;
    if ( defaultValue != nil )
        dict[@"default"] = defaultValue;
    
    _attrDecls[key] = dict;
}

- (NSDictionary *) visiblyUsedNamespacesInContext: (_StackContext *) ctx fromAttributes: (NSMutableDictionary *) attributeDict
{
    NSMutableSet * visiblyUsed = [NSMutableSet new];
    NSString * prefix = ctx.elementPrefix;
    if ( [prefix length] > 0 )
    {
        [visiblyUsed addObject: prefix];
    }
    else
    {
        if ( self.rewritePrefixes )
        {
            // default namespace is being utilized (and will be renamed)
            [visiblyUsed addObject: @""];
        }
        
        // ensure it's in the context, to avoid redeclarations later
        if ( ctx.namespaceContext[@""] == nil )
        {
            ctx.namespaceContext[@""] = @"";
            [ctx.outputPrefixes addObject: @""];
        }
    }
    
    // now all the attributes
    NSMutableDictionary * rewrittenAttrNames = [NSMutableDictionary new];
    [attributeDict enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        // xmlns: prefixes can be ignored here: if the namespace prefix is used elsewhere the namespace will be emitted
        if ( [key hasPrefix: @"xmlns:"] )
            return;
        
        NSRange r = [key rangeOfString: @":"];
        NSString * qLookup = key;
        NSString * attrURI = @"";       // default namespace...?
        if ( r.location != NSNotFound )
        {
            NSString * pre = [key substringToIndex: r.location];
            [visiblyUsed addObject: pre];
            qLookup = [key substringFromIndex: NSMaxRange(r)];
            attrURI = ctx.namespaceContext[pre];
        }
        else if ( [prefix length] == 0 && [key isEqualToString: @"xmlns"] )
        {
            if ( [ctx.outputPrefixes containsObject: @""] == NO || [ctx.namespaceContext[@""] isEqualToString: obj] == NO )
                [visiblyUsed addObject: @""];
            
            // lookup URI of thue default namespace
            attrURI = ctx.namespaceContext[@""];
        }
        
        NSString *attrURICheck = _qnameAwareAttrs[qLookup];
        if ( [attrURICheck length] != 0 && [attrURI length] != 0 && [attrURICheck isEqualToString: attrURI] )
        {
            // value of the attribute should (also?) contain a prefix
            r = [obj rangeOfString: @":"];
            if ( r.location != NSNotFound )
            {
                NSString * pre = [obj substringToIndex: r.location];
                [visiblyUsed addObject: pre];
                
                if ( self.rewritePrefixes )
                    rewrittenAttrNames[key] = pre;
            }
        }
    }];
    
    // Even though an NSIndexSet will coalesce adjacent ranges, the nature of our search
    // ensures that we will never find any adjacent ranges: each range inserted is followed
    // by at least one non-matching character, ensuring the next range is non-adjacent
    NSMutableIndexSet * contentSubstitutions = [NSMutableIndexSet new];
    if ( [_runningChars length] != 0 )
    {
        // this element has been identified as QName-aware
        // is it Element or XPathElement ?
        BOOL contentIsQName = YES;
        NSString * uri = _qnameAwareElements[ctx.elementLocalName];
        if ( uri == nil )
        {
            uri = _qnameAwareXPathElements[ctx.elementLocalName];
            contentIsQName = NO;
        }
        
        if ( contentIsQName )
        {
            NSRange r = [_runningChars rangeOfString: @":"];
            if ( r.location != NSNotFound )
            {
                NSString * pre = [_runningChars substringToIndex: r.location];
                [visiblyUsed addObject: pre];
                
                if ( self.rewritePrefixes )
                {
                    // record the range to replace
                    NSRange replaced = NSMakeRange(0, r.location);
                    [contentSubstitutions addIndexesInRange: replaced];
                }
            }
        }
        else
        {
            NSRegularExpression * killQuoted = [NSRegularExpression regularExpressionWithPattern: @"(\".*?\"|\'.*?\')" options: 0 error: NULL];
            NSMutableIndexSet * quoteRanges = [NSMutableIndexSet new];
            [killQuoted enumerateMatchesInString: _runningChars options: 0 range: NSMakeRange(0, [_runningChars length]) usingBlock: ^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                [quoteRanges addIndexesInRange: result.range];
            }];
            
            NSRegularExpression * reg = [NSRegularExpression regularExpressionWithPattern: @"([[:alpha:]-_][[:alnum:]-_]*):[[:alpha:]-]" options: 0 error: NULL];
            [reg enumerateMatchesInString: _runningChars options: 0 range: NSMakeRange(0, [_runningChars length]) usingBlock: ^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                NSRange prefixRange = [result rangeAtIndex: 1];
                if ( prefixRange.location == NSNotFound || prefixRange.length == 0 )
                    return;
                
                // if the match is within a quoted range, ignore it
                if ( [quoteRanges containsIndexesInRange: prefixRange] )
                    return;
                
                NSString * pre = [_runningChars substringWithRange: prefixRange];
                [visiblyUsed addObject: pre];
                
                if ( self.rewritePrefixes )
                {
                    // record the range to replace
                    [contentSubstitutions addIndexesInRange: prefixRange];
                }
            }];
        }
    }
    
    if ( self.rewritePrefixes )
    {
        NSMutableSet * newNamespaceURIs = [NSMutableSet new];
        for ( NSString * prefix in visiblyUsed )
        {
            if ( [prefix isEqualToString: @"xml"] )
                continue;       // 'xml' is never rewritten
            
            NSString * uri = ctx.namespaceContext[prefix];
            if ( _rewrittenPrefixes[uri] == nil )
                [newNamespaceURIs addObject: uri];
        }
        
        NSArray * sorted = [[newNamespaceURIs allObjects] sortedArrayUsingSelector: @selector(compare:)];
        for ( NSString * uri in sorted )
        {
            NSString * newPrefix = [NSString stringWithFormat: @"n%lu", (unsigned long)(_nsRewriteCounter++)];
            _rewrittenPrefixes[uri] = newPrefix;
        }
        
        // now modify the contents of any attribute values
        [rewrittenAttrNames enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
            NSString * uri = ctx.namespaceContext[obj];
            NSString * newPrefix = _rewrittenPrefixes[uri];
            NSString * value = [attributeDict[key] stringByReplacingOccurrencesOfString: obj withString: newPrefix];
            attributeDict[key] = value;
        }];
        
        // now modify any element content, going in reverse so we handle length changes properly
        [contentSubstitutions enumerateRangesWithOptions: NSEnumerationReverse usingBlock: ^(NSRange range, BOOL *stop) {
            NSString * pre = [_runningChars substringWithRange: range];
            NSString * uri = ctx.namespaceContext[pre];
            NSString * newPrefix = _rewrittenPrefixes[uri];
            if ( newPrefix != nil )
                [_runningChars replaceCharactersInRange: range withString: newPrefix];
        }];
    }
    
    NSMutableDictionary * nsToBeOutputList = [NSMutableDictionary new];
    for ( NSString * __strong prefix in visiblyUsed )
    {
        if ( [prefix isEqualToString: @"xml"] )
            continue;
        
        NSString * uri = ctx.namespaceContext[prefix];
        if ( self.rewritePrefixes )
            prefix = _rewrittenPrefixes[uri];
        
        if ( [ctx.outputPrefixes containsObject: prefix] == NO )
        {
            [ctx.outputPrefixes addObject: prefix];
            nsToBeOutputList[prefix] = uri;
        }
    }
    
    return ( nsToBeOutputList );
}

- (NSString *) canonicalizeAttributeValue: (NSString *) value
                                   forKey: (NSString *) attrName
                                     type: (AQXMLAttributeType) typeOrZero
{
    _StackContext * ctx = [_stack lastObject];
    NSMutableString * mutable = [value mutableCopy];
    [mutable replaceOccurrencesOfString: @"&" withString: @"&amp;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @"<" withString: @"&lt;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @"\"" withString: @"&quot;" options: 0 range: NSMakeRange(0, [mutable length])];
    
    // replace characters 0xd, 0xa, 0x9 (\r, \n, \t) with canonical character references
    [mutable replaceOccurrencesOfString: @"\r" withString: @"&#xD;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @"\n" withString: @"&#xA;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @"\t" withString: @"&#x9;" options: 0 range: NSMakeRange(0, [mutable length])];
    
    // whitespace compression/replacement
    BOOL isNMTOKEN = NO;
    if ( typeOrZero == 0 )
    {
        NSString * key = [ctx.elementLocalName stringByAppendingFormat: @":%@", attrName];
        NSDictionary * dict = _attrDecls[key];
        if ( dict != nil && [dict[@"type"] hasSuffix: @"NMTOKENS"] )
            isNMTOKEN = YES;
    }
    else
    {
        isNMTOKEN = (typeOrZero == AQXMLAttributeTypeNMTokens);
    }
    
    // NMTOKENS type has all whitespace ranges compressed to a single space
    // CDATA type has all whitespace chars replaced with spaces, no compression
    NSRegularExpression * reg = [[NSRegularExpression alloc] initWithPattern: (isNMTOKEN ? @"\\s+" : @"\\s") options: 0 error: NULL];
    [reg replaceMatchesInString: mutable options: 0 range: NSMakeRange(0, [mutable length]) withTemplate: @" "];
    
    return ( [mutable copy] );
}

- (void) parser: (AQXMLParser *) parser didStartElement: (NSString *) elementName namespaceURI: (NSString *) namespaceURI qualifiedName: (NSString *) qName attributes: (NSDictionary *) attributeDict
{
    _documentRootEncountered = YES;
    
    // don't output buffered chars if we're being called via this invocation
    if ( _qualifiedContentStartElementInvocation == nil )
        [self outputBufferedChars];
    
    NSError * error = nil;
    _StackContext * ctx = nil;
    if ( _qualifiedContentStartElementInvocation == nil )
        ctx = [self newStackContext];
    else
        ctx = [_stack lastObject];  // context was already created
    
    // any namespaces reported prior to this call?
    [_pendingNamespaces enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        if ( [ctx.namespaceContext[key] isEqualToString: obj] )
            return;
        ctx.namespaceContext[key] = obj;
        [ctx.outputPrefixes removeObject: key];
    }];
    [_pendingNamespaces removeAllObjects];
    
    ctx.elementQName = qName;
    
    if ( _qualifiedContentStartElementInvocation == nil &&
        (_qnameAwareElements[elementName] != nil || _qnameAwareXPathElements[elementName] != nil) )
    {
        // need to inspect this element's content, so defer the call entirely
        _qualifiedContentStartElementInvocation = [NSInvocation invocationWithMethodSignature: [self methodSignatureForSelector: _cmd]];
        [_qualifiedContentStartElementInvocation setTarget: self];
        [_qualifiedContentStartElementInvocation setSelector: _cmd];
        [_qualifiedContentStartElementInvocation setArgument: &parser atIndex: 2];
        [_qualifiedContentStartElementInvocation setArgument: &elementName atIndex: 3];
        [_qualifiedContentStartElementInvocation setArgument: &namespaceURI atIndex: 4];
        [_qualifiedContentStartElementInvocation setArgument: &qName atIndex: 5];
        [_qualifiedContentStartElementInvocation setArgument: &attributeDict atIndex: 6];
        [_qualifiedContentStartElementInvocation retainArguments];
        
        return;
    }
    
    NSMutableDictionary * allAttrs = [attributeDict mutableCopy];
    NSString * prefix = ctx.elementPrefix;
    NSDictionary * usedNamespaces = [self visiblyUsedNamespacesInContext: ctx fromAttributes: allAttrs];
    
    // find out if we need to rewrite it based on
    
    WRITE([NSData dataWithBytesNoCopy: "<" length: 1 freeWhenDone: NO], error);
    
    @autoreleasepool
    {
        NSString * outName = prefix;
        if ( [outName length] != 0 || self.rewritePrefixes )
        {
            if ( self.rewritePrefixes )
            {
                if ( outName == nil )
                    outName = @"";
                NSString * uri = ctx.namespaceContext[prefix];
                outName = _rewrittenPrefixes[uri];
            }
            
            outName = [outName stringByAppendingString: @":"];
        }
        
        outName = [outName stringByAppendingString: ctx.elementLocalName];
        ctx.elementQName = outName;
        WRITE([outName dataUsingEncoding: NSUTF8StringEncoding], error);
        
        NSArray * namespaceKeys = [[usedNamespaces allKeys] sortedArrayUsingSelector: @selector(compare:)];
        for ( NSString * prefix in namespaceKeys )
        {
            NSString * output = nil;
            if ( [prefix length] == 0 )
                output = [NSString stringWithFormat: @" xmlns=\"%@\"", usedNamespaces[prefix]];
            else
                output = [NSString stringWithFormat: @" xmlns:%@=\"%@\"", prefix, usedNamespaces[prefix]];
            WRITE([output dataUsingEncoding: NSUTF8StringEncoding], error);
        }
    }
    
    AQXMLSchema * __block schema = _schemas[namespaceURI];
    if ( schema == nil )
    {
        // look for an [xsi]:schemaLocation attribute
        [allAttrs enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
            if ( [key hasSuffix: @":schemaLocation"] == NO )
                return;
            
            NSArray * comps = [obj componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            for ( NSUInteger i = 0; i < [comps count]; i += 2 )
            {
                if ( [comps[i] isEqualToString: namespaceURI] )
                {
                    schema = [AQXMLSchema schemaWithURL: [NSURL URLWithString: comps[i+1]]];
                    _schemas[namespaceURI] = schema;
                    *stop = YES;
                    return;
                }
            }
        }];
    }
    
    // insert any default attributes
    if ( schema != nil )
    {
        NSDictionary * defaultAttrs = [schema defaultAttributesForElementName: elementName prefix: ctx.elementPrefix];
        [defaultAttrs enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
            if ( allAttrs[key] == nil )
                allAttrs[key] = obj;
        }];
    }
    else
    {
        NSString * pre = [ctx.elementLocalName stringByAppendingString: @":"];
        [_attrDecls enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
            if ( [key hasPrefix: pre] == NO )
                return;
            
            // remove the prefix
            key = [key substringFromIndex: [pre length]];
            if ( allAttrs[key] != nil || allAttrs[[prefix stringByAppendingFormat: @":%@", key]] != nil )
                return;
            
            if ( obj[@"default"] != nil )
            {
                allAttrs[key] = obj[@"default"];
            }
        }];
    }
    
    @autoreleasepool
    {
        // sort attributes by URI, then prefix, then name
        NSArray * attrNames = [[allAttrs allKeys] sortedArrayUsingComparator: ^NSComparisonResult(id obj1, id obj2) {
            NSString * name1 = obj1, * name2 = obj2;
            NSString * prefix1 = @"", * prefix2 = @"";
            
            NSRange r = [name1 rangeOfString: @":"];
            if ( r.location != NSNotFound )
            {
                prefix1 = [name1 substringToIndex: r.location];
                name1 = [name1 substringFromIndex: NSMaxRange(r)];
            }
            
            r = [name2 rangeOfString: @":"];
            if ( r.location != NSNotFound )
            {
                prefix2 = [name2 substringToIndex: r.location];
                name2 = [name2 substringFromIndex: NSMaxRange(r)];
            }
            
            NSString * uri1 = ctx.namespaceContext[prefix1];
            NSString * uri2 = ctx.namespaceContext[prefix2];
            
            NSComparisonResult cr = [uri1 compare: uri2];
            if ( cr != NSOrderedSame )
                return ( cr );
            
            return ( [name1 compare: name2] );
        }];
        
        for ( NSString * __strong attrName in attrNames )
        {
            if ( [attrName isEqualToString: @"xmlns"] || [attrName hasPrefix: @"xmlns:"] )
                continue;
            
            NSString * value = allAttrs[attrName];
            if ( [attrName hasPrefix: @"xml:"] == NO && self.rewritePrefixes )
            {
                NSRange r = [attrName rangeOfString: @":"];
                if ( r.location != NSNotFound )
                {
                    NSString * pre = [attrName substringToIndex: r.location];
                    NSString * uri = ctx.namespaceContext[pre];
                    NSString * newPrefix = _rewrittenPrefixes[uri];
                    attrName = [newPrefix stringByAppendingFormat: @":%@", [attrName substringFromIndex: NSMaxRange(r)]];
                }
            }
            
            value = [self canonicalizeAttributeValue: value forKey: attrName type: 0];
            NSString * output = [NSString stringWithFormat: @" %@=\"%@\"", attrName, value];
            WRITE([output dataUsingEncoding: NSUTF8StringEncoding], error);
        }
    }
    
    WRITE([NSData dataWithBytesNoCopy: ">" length: 1 freeWhenDone: NO], error);
}

- (void) parser: (AQXMLParser *) parser didEndElement: (NSString *) elementName namespaceURI: (NSString *) namespaceURI qualifiedName: (NSString *) qName
{
    if ( _qualifiedContentStartElementInvocation != nil )
    {
        // reached the end of the content for an element containing qualified content
        // process the start element now
        [_qualifiedContentStartElementInvocation invoke];
        _qualifiedContentStartElementInvocation = nil;
        
        // at this point, the content has been correctly processed and even rewritten
    }
    
    [self outputBufferedChars];
    _StackContext * ctx = [_stack lastObject];
    
    @autoreleasepool
    {
        NSError * error = nil;
        WRITE([NSData dataWithBytesNoCopy: "</" length: 2 freeWhenDone: NO], error);
        WRITE([ctx.elementQName dataUsingEncoding: NSUTF8StringEncoding], error);
        WRITE([NSData dataWithBytesNoCopy: ">" length: 1 freeWhenDone: NO], error);
    }
    
    [_stack removeLastObject];
}

- (void) parser: (AQXMLParser *) parser foundIgnorableWhitespace: (NSString *) whitespaceString
{
    [self outputBufferedChars];
    
    if ( self.preserveWhitespace )
    {
        NSError * error = nil;
        WRITE([whitespaceString dataUsingEncoding: NSUTF8StringEncoding], error);
    }
}

- (void) parser: (AQXMLParser *) parser foundComment: (NSString *) comment
{
    [self outputBufferedChars];
    
    if ( self.preserveComments )
    {
        @autoreleasepool
        {
            NSError * error = nil;
            if ( _documentRootEncountered && [_stack count] == 0 )
            {
                WRITE([NSData dataWithBytesNoCopy: "\n" length: 1 freeWhenDone: NO], error);
            }
            
            WRITE([NSData dataWithBytesNoCopy: "<!--" length: 4 freeWhenDone: NO], error);
            WRITE([comment dataUsingEncoding: NSUTF8StringEncoding], error);
            WRITE([NSData dataWithBytesNoCopy: "-->" length: 3 freeWhenDone: NO], error);
            
            if ( !_documentRootEncountered )
            {
                WRITE([NSData dataWithBytesNoCopy: "\n" length: 1 freeWhenDone: NO], error);
            }
        }
    }
}

- (void) parser: (AQXMLParser *) parser foundProcessingInstructionWithTarget: (NSString *) target data: (NSString *) data
{
    [self outputBufferedChars];
    
    // the XML declaration and document type are removed
    if ( [target isEqualToString: @"xml"] )
        return;
    
    @autoreleasepool
    {
        NSError * error = nil;
        if ( _documentRootEncountered && [_stack count] == 0 )
        {
            WRITE([NSData dataWithBytesNoCopy: "\n" length: 1 freeWhenDone: NO], error);
        }
        
        WRITE([NSData dataWithBytesNoCopy: "<?" length: 2 freeWhenDone: NO], error);
        WRITE([target dataUsingEncoding: NSUTF8StringEncoding], error);
        
        if ( [data length] != 0 )
        {
            WRITE([NSData dataWithBytesNoCopy: " " length: 1 freeWhenDone: NO], error);
            WRITE([data dataUsingEncoding: NSUTF8StringEncoding], error);
        }
        
        WRITE([NSData dataWithBytesNoCopy: "?>" length: 2 freeWhenDone: NO], error);
        
        if ( !_documentRootEncountered )
        {
            WRITE([NSData dataWithBytesNoCopy: "\n" length: 1 freeWhenDone: NO], error);
        }
    }
}

- (void) parser: (AQXMLParser *) parser foundCDATA: (NSData *) CDATABlock
{
    // CDATA sections are replaced with their character content
    [self parser: parser foundCharacters: [[NSString alloc] initWithData: CDATABlock encoding: NSUTF8StringEncoding]];
}

- (void) parser: (AQXMLParser *) parser foundCharacters: (NSString *) string
{
    // replace certain characters with character entities
    NSMutableString * mutable = [string mutableCopy];
    [mutable replaceOccurrencesOfString: @"&" withString: @"&amp;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @"<" withString: @"&lt;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @">" withString: @"&gt;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @"\r" withString: @"&#xD;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @"\t" withString: @"&#x9;" options: 0 range: NSMakeRange(0, [mutable length])];
    
    if ( self.preserveWhitespace && _qualifiedContentStartElementInvocation == nil )
    {
        NSError * error = nil;
        WRITE([mutable dataUsingEncoding: NSUTF8StringEncoding], error);
        return;
    }
    
    [_runningChars appendString: mutable];
}

#pragma mark - DOM Mode

- (void) canonicalizeSubtreeAtNode: (AQXMLNode *) node
{
    // collect namespaces
    if ( node.parent != nil && node != node.document.rootElement )
    {
        (void) [self newStackContext];
        [self addNamespaces: node];
    }
    
    [self processNode: node];
}

- (void) processNode: (AQXMLNode *) node
{
    switch ( node.type )
    {
        case AQXMLNodeTypeDocument:
        case AQXMLNodeTypeDocumentFragment:
        case AQXMLNodeTypeDOCBDocument:
        case AQXMLNodeTypeHTMLDocument:
        {
            [self processDocumentNode: (AQXMLDocument *)node];
            break;
        }
            
        case AQXMLNodeTypeElement:
            [self processElement: (AQXMLElement *)node];
            break;
            
        case AQXMLNodeTypeComment:
            [self processComment: node];
            break;
            
        case AQXMLNodeTypeProcessingInstruction:
            [self processPI: node];
            break;
            
        case AQXMLNodeTypeCDATASection:
            [self processCDATA: node];
            break;
            
        case AQXMLNodeTypeText:
            [self processText: node];
            break;
            
        default:
            break;
    }
}

- (void) processDocumentNode: (AQXMLDocument *) docNode
{
    _documentRootEncountered = YES;
    [self processNode: docNode.rootElement];
}

- (void) processElement: (AQXMLElement *) element
{
    if ( self.isNodeVisible != nil && self.isNodeVisible(element) == NO )
        return;
    
    _StackContext * ctx = [self newStackContext];
    ctx.elementQName = element.qualifiedName;
    [element consolidateConsecutiveTextNodes];
    NSDictionary * nsToBeOutput = [self processNamespaces: element];
    
    NSError * error = nil;
    WRITE([NSData dataWithBytes: "<" length: 1], error);
    
    NSString * qName = ctx.elementQName;
    if ( self.rewritePrefixes )
        qName = [NSString stringWithFormat: @"%@:%@", _rewrittenPrefixes[ctx.elementPrefix], ctx.elementLocalName];
    
    WRITE([qName dataUsingEncoding: NSUTF8StringEncoding], error);
    
    NSArray * namespaceKeys = [[nsToBeOutput allKeys] sortedArrayUsingSelector: @selector(compare:)];
    for ( NSString * prefix in namespaceKeys )
    {
        NSString * output = nil;
        if ( [prefix length] == 0 )
            output = [NSString stringWithFormat: @" xmlns=\"%@\"", nsToBeOutput[prefix]];
        else
            output = [NSString stringWithFormat: @" xmlns:%@=\"%@\"", prefix, nsToBeOutput[prefix]];
        WRITE([output dataUsingEncoding: NSUTF8StringEncoding], error);
    }
    
    @autoreleasepool
    {
        // sort attributes by URI, then prefix, then name
        NSArray * attrNames = [element.attributeKeys sortedArrayUsingComparator: ^NSComparisonResult(id obj1, id obj2) {
            NSString * name1 = obj1, * name2 = obj2;
            NSString * prefix1 = @"", * prefix2 = @"";
            
            NSRange r = [name1 rangeOfString: @":"];
            if ( r.location != NSNotFound )
            {
                prefix1 = [name1 substringToIndex: r.location];
                name1 = [name1 substringFromIndex: NSMaxRange(r)];
            }
            
            r = [name2 rangeOfString: @":"];
            if ( r.location != NSNotFound )
            {
                prefix2 = [name2 substringToIndex: r.location];
                name2 = [name2 substringFromIndex: NSMaxRange(r)];
            }
            
            NSString * uri1 = ctx.namespaceContext[prefix1];
            NSString * uri2 = ctx.namespaceContext[prefix2];
            
            NSComparisonResult cr = [uri1 compare: uri2];
            if ( cr != NSOrderedSame )
                return ( cr );
            
            return ( [name1 compare: name2] );
        }];
        
        for ( NSString * __strong attrName in attrNames )
        {
            if ( [attrName isEqualToString: @"xmlns"] || [attrName hasPrefix: @"xmlns:"] )
                continue;
            
            AQXMLAttribute * attr = [element attributeNamed: attrName];
            NSString * value = attr.value;
            if ( [attrName hasPrefix: @"xml:"] == NO && self.rewritePrefixes )
            {
                NSRange r = [attrName rangeOfString: @":"];
                if ( r.location != NSNotFound )
                {
                    NSString * pre = [attrName substringToIndex: r.location];
                    NSString * uri = ctx.namespaceContext[pre];
                    NSString * newPrefix = _rewrittenPrefixes[uri];
                    attrName = [newPrefix stringByAppendingFormat: @":%@", [attrName substringFromIndex: NSMaxRange(r)]];
                }
            }
            
            value = [self canonicalizeAttributeValue: value
                                              forKey: attrName
                                                type: attr.attributeType];
            NSString * output = [NSString stringWithFormat: @" %@=\"%@\"", attrName, value];
            WRITE([output dataUsingEncoding: NSUTF8StringEncoding], error);
        }
    }
    
    WRITE([NSData dataWithBytesNoCopy: ">" length: 1 freeWhenDone: NO], error);
    
    [element enumerateChildrenUsingBlock: ^(AQXMLNode *child, NSUInteger idx, BOOL *stop) {
        [self processNode: child];
    }];
    
    WRITE([NSData dataWithBytes: "</" length: 2], error);
    WRITE([qName dataUsingEncoding: NSUTF8StringEncoding], error);
    WRITE([NSData dataWithBytes: ">" length: 1], error);
    
    [_stack removeLastObject];
}

- (void) processComment: (AQXMLNode *) commentNode
{
    if ( self.preserveComments )
    {
        @autoreleasepool
        {
            NSError * error = nil;
            if ( _documentRootEncountered && [_stack count] == 0 )
            {
                WRITE([NSData dataWithBytesNoCopy: "\n" length: 1 freeWhenDone: NO], error);
            }
            
            WRITE([NSData dataWithBytesNoCopy: "<!--" length: 4 freeWhenDone: NO], error);
            WRITE([commentNode.content dataUsingEncoding: NSUTF8StringEncoding], error);
            WRITE([NSData dataWithBytesNoCopy: "-->" length: 3 freeWhenDone: NO], error);
            
            if ( !_documentRootEncountered )
            {
                WRITE([NSData dataWithBytesNoCopy: "\n" length: 1 freeWhenDone: NO], error);
            }
        }
    }
}

- (void) processPI: (AQXMLNode *) PINode
{
    // the XML declaration and document type are removed
    if ( [PINode.name isEqualToString: @"xml"] )
        return;
    
    @autoreleasepool
    {
        NSError * error = nil;
        if ( _documentRootEncountered && [_stack count] == 0 )
        {
            WRITE([NSData dataWithBytesNoCopy: "\n" length: 1 freeWhenDone: NO], error);
        }
        
        WRITE([NSData dataWithBytesNoCopy: "<?" length: 2 freeWhenDone: NO], error);
        WRITE([PINode.name dataUsingEncoding: NSUTF8StringEncoding], error);
        
        if ( [PINode.content length] != 0 )
        {
            WRITE([NSData dataWithBytesNoCopy: " " length: 1 freeWhenDone: NO], error);
            WRITE([PINode.content dataUsingEncoding: NSUTF8StringEncoding], error);
        }
        
        WRITE([NSData dataWithBytesNoCopy: "?>" length: 2 freeWhenDone: NO], error);
        
        if ( !_documentRootEncountered )
        {
            WRITE([NSData dataWithBytesNoCopy: "\n" length: 1 freeWhenDone: NO], error);
        }
    }
}

- (void) processCDATA: (AQXMLNode *) CDATANode
{
    // just pretend it's a raw text node
    [self processText: CDATANode];
}

- (void) processText: (AQXMLNode *) textNode
{
    // we know that we've already consolidated adjacent text nodes
    NSMutableString * mutable = [textNode.content mutableCopy];
    
    if ( self.preserveWhitespace == NO )
        mutable = [[mutable stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] mutableCopy];
    
    // replace certain characters with character entities
    [mutable replaceOccurrencesOfString: @"&" withString: @"&amp;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @"<" withString: @"&lt;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @">" withString: @"&gt;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @"\r" withString: @"&#xD;" options: 0 range: NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString: @"\t" withString: @"&#x9;" options: 0 range: NSMakeRange(0, [mutable length])];
    
    NSError * error = nil;
    WRITE([mutable dataUsingEncoding: NSUTF8StringEncoding], error);
}

- (void) addNamespaces: (AQXMLNode *) element
{
    _StackContext * ctx = [_stack lastObject];
    for ( AQXMLNamespace * ns in element.namespacesInScope )
    {
        NSString * uri = [ns.uri absoluteString];
        NSString * currentURI = ctx.namespaceContext[ns.prefix];
        
        if ( [currentURI isEqualToString: uri] )
        {
            continue;
        }
        else if ( currentURI != nil )
        {
            [ctx.outputPrefixes removeObject: ns.prefix];
        }
        
        ctx.namespaceContext[ns.prefix] = uri;
    }
}

- (NSDictionary *) processNamespaces: (AQXMLElement *) element
{
    _StackContext * ctx = [_stack lastObject];
    [self addNamespaces: element];
    
    BOOL isQNameAware = NO;
    if ( _qnameAwareElements[ctx.elementLocalName] != nil || _qnameAwareXPathElements[ctx.elementLocalName] != nil )
    {
        [_runningChars setString: element.firstChild.content];
        isQNameAware = YES;
    }
    
    NSMutableDictionary * allAttrs = [element.attributes mutableCopy];
    
    NSDictionary * nsToBeOutputList = [self visiblyUsedNamespacesInContext: ctx fromAttributes: allAttrs];
    if ( self.rewritePrefixes )
    {
        if ( isQNameAware )
        {
            // update the content with the prefix-rewritten version
            element.firstChild.content = _runningChars;
        }
        
        // replace attributes, to ensure their prefixes are rewritten
        [element removeAllAttributes];
        [element addAttributes: allAttrs];
    }
    
    return ( nsToBeOutputList );
}

@end
