/*
 *  AQXMLParser.h
 *  AQToolkit
 *
 *  Created by Jim Dovey on 17/3/2009.
 *
 *  Copyright (c) 2009, Jim Dovey
 *  All rights reserved.
 *  
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *  Redistributions of source code must retain the above copyright notice,
 *  this list of conditions and the following disclaimer.
 *  
 *  Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *  
 *  Neither the name of this project's author nor the names of its
 *  contributors may be used to endorse or promote products derived from
 *  this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
 *  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
 *  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

/* -I/usr/include/libxml -lxml */

#import "AQXMLParser.h"
#import "AQXMLParserInternal.h"

//#import "NSStream+HTTPMessage.h"

//#import "ASLogger+CFNetwork.h"

#import <libxml/parser.h>
#import <libxml/HTMLparser.h>
#import <libxml/parserInternals.h>
#import <libxml/SAX2.h>
#import <libxml/xmlerror.h>
#import <libxml/encoding.h>
#import <libxml/entities.h>

#if TARGET_OS_IPHONE
# import <CFNetwork/CFNetwork.h>
#else
# import <CFNetwork/CFNetwork.h>
#endif

//#import "KBUserSettings.h"
//#import "AQGzipStream.h"

#define AUTO_DEBUG_LOG_INPUT 0
#define RETURN_ON_ABORT()		if ([parser _parseAborted]) return
#define RETURN_VAL_ON_ABORT(x)	if ([parser _parseAborted]) return (x)

NSString * const AQXMLParserParsingRunLoopMode = @"AQXMLParserParsingRunLoopMode";

NSString * const AQXMLParserBrokenPipeNotification = @"AQXMLParserBrokenPipeNotification";

enum
{
	AQXMLParserShouldProcessNamespaces	= 1<<0,
	AQXMLParserShouldReportPrefixes		= 1<<1,
	AQXMLParserShouldResolveExternals	= 1<<2,
    
    // most significant bit indicates HTML mode
    AQXMLParserHTMLMode                 = 1<<31
	
};

@interface AQXMLParser (Internal)
- (void) _setParserError: (int) err;
- (xmlParserCtxtPtr) _xmlParserContext;
- (htmlParserCtxtPtr) _htmlParserContext;
- (void) _pushNamespaces: (NSDictionary *) nsDict;
- (void) _popNamespaces;
- (void) _initializeSAX2Callbacks;
- (void) _initializeParserWithBytes: (const void *) buf length: (NSUInteger) length;
- (void) _pushXMLData: (const void *) bytes length: (NSUInteger) length;
- (_AQXMLParserInternal *) _info;
- (void) _setStreamComplete: (BOOL) parsedOK;
- (void) _setupExpectedLength;
- (BOOL) _parseAborted;
@end

#pragma mark -

static inline NSString * NSStringFromXmlChar( const xmlChar * ch )
{
	if ( ch == NULL )
		return ( nil );
	
	return ( [[NSString allocWithZone: nil] initWithBytes: ch
												   length: strlen((const char *)ch)
												 encoding: NSUTF8StringEncoding] );
}

static inline NSString * AttributeTypeString( int type )
{
#define TypeCracker(t) case XML_ATTRIBUTE_ ## t: return @#t
	switch ( type )
	{
		TypeCracker(CDATA);
		TypeCracker(ID);
		TypeCracker(IDREF);
		TypeCracker(IDREFS);
		TypeCracker(ENTITY);
		TypeCracker(ENTITIES);
		TypeCracker(NMTOKEN);
		TypeCracker(NMTOKENS);
		TypeCracker(ENUMERATION);
		TypeCracker(NOTATION);
			
		default:
			break;
	}
	
	return ( @"" );
}

#define CTX(x) ((xmlParserCtxtPtr)(x))
#define PARSER(p) ((__bridge AQXMLParser *)(p->sax->_private))

static int __isStandalone( void * ctx )
{
	xmlParserCtxtPtr p = CTX(ctx);
	return ( p->myDoc->standalone );
}

static int __hasInternalSubset2( void * ctx )
{
	xmlParserCtxtPtr p = CTX(ctx);
	return ( p->myDoc->intSubset == NULL ? 0 : 1 );
}

static int __hasExternalSubset2( void * ctx )
{
	xmlParserCtxtPtr p = CTX(ctx);
	return ( p->myDoc->extSubset == NULL ? 0 : 1 );
}

static void __internalSubset2( void * ctx, const xmlChar * name, const xmlChar * ElementID,
							   const xmlChar * SystemID )
{
	xmlParserCtxtPtr p = CTX(ctx);
	xmlSAX2InternalSubset( p, name, ElementID, SystemID );
}

static void __externalSubset2( void * ctx, const xmlChar * name, const xmlChar * ExternalID,
							   const xmlChar * SystemID )
{
	xmlParserCtxtPtr p = CTX(ctx);
	xmlSAX2ExternalSubset( p, name, ExternalID, SystemID );
}

static xmlParserInputPtr __resolveEntity( void * ctx, const xmlChar * publicId, const xmlChar * systemId )
{
	xmlParserCtxtPtr p = CTX(ctx);
	return ( xmlSAX2ResolveEntity(p, publicId, systemId) );
}

static void __characters( void * ctx, const xmlChar * ch, int len )
{
    xmlParserCtxtPtr p = CTX(ctx);
    
	AQXMLParser * parser = PARSER(p);
    p = [parser _xmlParserContext];
	
	if ( (uintptr_t)(p->_private) == 1 )
	{
		p->_private = 0;
		return;
	}
	
	RETURN_ON_ABORT();
	
	id<AQXMLParserDelegate> delegate = parser.delegate;
	if ( [delegate respondsToSelector: @selector(parser:foundCharacters:)] == NO )
		return;
	
	NSString * str = [[NSString allocWithZone: nil] initWithBytes: ch
														   length: len
														 encoding: NSUTF8StringEncoding];
	[delegate parser: parser foundCharacters: str];
}

static void __reference(void * ctx, const xmlChar * name)
{
    //NSLog(@"Encountered reference '%s'", (const char *)name);
}

static xmlEntityPtr __getParameterEntity( void * ctx, const xmlChar * name )
{
	xmlParserCtxtPtr p = CTX(ctx);
	return ( xmlSAX2GetParameterEntity(p, name) );
}

static void __entityDecl( void * ctx, const xmlChar * name, int type, const xmlChar * publicId,
						  const xmlChar * systemId, xmlChar * content )
{
	xmlParserCtxtPtr p = CTX(ctx);
    AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	
	RETURN_ON_ABORT();
	
	xmlSAX2EntityDecl( p, name, type, publicId, systemId, content );
	
	NSString * contentStr = NSStringFromXmlChar( content );
	NSString * nameStr = NSStringFromXmlChar( name );
	
	if ( [contentStr length] != 0 )
	{
		if ( [delegate respondsToSelector: @selector(parser:foundInternalEntityDeclarationWithName:value:)] )
			[delegate parser: parser foundInternalEntityDeclarationWithName: nameStr value: contentStr];
	}
	else if ( [parser shouldResolveExternalEntities] )
	{
		if ( [delegate respondsToSelector: @selector(parser:foundExternalEntityDeclarationWithName:publicID:systemID:)] )
		{
			NSString * publicIDStr = NSStringFromXmlChar(publicId);
			NSString * systemIDStr = NSStringFromXmlChar(systemId);
			
			[delegate parser: parser foundExternalEntityDeclarationWithName: nameStr
					publicID: publicIDStr systemID: systemIDStr];
		}
	}
}

static void __attributeDecl( void * ctx, const xmlChar * elem, const xmlChar * fullname, int type, int def,
							 const xmlChar * defaultValue, xmlEnumerationPtr tree )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_ON_ABORT();
	
	if ( [delegate respondsToSelector: @selector(parser:foundAttributeDeclarationWithName:forElement:type:defaultValue:)] == NO )
		return;
	
	NSString * elemStr = NSStringFromXmlChar(elem);
	NSString * fullnameStr = NSStringFromXmlChar(fullname);
	NSString * defaultStr = NSStringFromXmlChar(defaultValue);
	
	[delegate parser: parser foundAttributeDeclarationWithName: fullnameStr forElement: elemStr
				type: AttributeTypeString(type) defaultValue: defaultStr];
}

static void __elementDecl( void * ctx, const xmlChar * name, int type, xmlElementContentPtr content )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_ON_ABORT();
	
	if ( [delegate respondsToSelector: @selector(parser:foundElementDeclarationWithName:model:)] == NO )
		return;
	
	NSString * nameStr = NSStringFromXmlChar(name);
	[delegate parser: parser foundElementDeclarationWithName: nameStr model: @""];;
}

static void __notationDecl( void * ctx, const xmlChar * name, const xmlChar * publicId, const xmlChar * systemId )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_ON_ABORT();
	
	if ( [delegate respondsToSelector: @selector(parser:foundNotationDeclarationWithName:publicID:systemID:)] == NO )
		return;
	
	NSString * nameStr = NSStringFromXmlChar(name);
	NSString * publicIDStr = NSStringFromXmlChar(publicId);
	NSString * systemIDStr = NSStringFromXmlChar(systemId);
	
	[delegate parser: parser foundNotationDeclarationWithName: nameStr
			publicID: publicIDStr systemID: systemIDStr];
}

static void __unparsedEntityDecl( void * ctx, const xmlChar * name, const xmlChar * publicId,
								  const xmlChar * systemId, const xmlChar * notationName )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_ON_ABORT();
	
	xmlSAX2UnparsedEntityDecl( p, name, publicId, systemId, notationName );
	
	if ( [delegate respondsToSelector: @selector(parser:foundUnparsedEntityDeclarationWithName:publicID:systemID:notationName:)] == NO )
		return;
	
	NSString * nameStr = NSStringFromXmlChar(name);
	NSString * publicIDStr = NSStringFromXmlChar(publicId);
	NSString * systemIDStr = NSStringFromXmlChar(systemId);
	NSString * notationNameStr = NSStringFromXmlChar(notationName);
	
	[delegate parser: parser foundUnparsedEntityDeclarationWithName: nameStr
			publicID: publicIDStr systemID: systemIDStr notationName: notationNameStr];
}

static void __startDocument( void * ctx )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_ON_ABORT();
	
	const char * encoding = (const char *) p->encoding;
	if ( encoding == NULL )
		encoding = (const char *) p->input->encoding;
	
	if ( encoding != NULL )
		xmlSwitchEncoding( p, xmlParseCharEncoding(encoding) );
	
	xmlSAX2StartDocument( p );
	
	if ( [delegate respondsToSelector: @selector(parserDidStartDocument:)] == NO )
		return;
	
	[delegate parserDidStartDocument: parser];
}

static void __endDocument( void * ctx )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_ON_ABORT();
	
	if ( [delegate respondsToSelector: @selector(parserDidEndDocument:)] == NO )
		return;
	
	[delegate parserDidEndDocument: parser];
}

static void __endElementNS( void * ctx, const xmlChar * localname, const xmlChar * prefix, const xmlChar * URI )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_ON_ABORT();
	
	NSString * prefixStr = nil;
	
	if ( [parser shouldProcessNamespaces] )
		prefixStr = NSStringFromXmlChar(prefix);
	
	NSString * localnameStr = NSStringFromXmlChar(localname);
	
	NSString * completeStr = localnameStr;
	if ( [prefixStr length] != 0 )
		completeStr = [[NSString alloc] initWithFormat: @"%@:%@", prefixStr, localnameStr];
	
	NSString * uriStr = NSStringFromXmlChar(URI);
	
	if ( [delegate respondsToSelector: @selector(parser:didEndElement:namespaceURI:qualifiedName:)] )
	{
		if ( prefixStr != nil )
		{
			if ( (completeStr == nil) && (uriStr == nil) )
				uriStr = @"";
			
			[delegate parser: parser didEndElement: localnameStr
				namespaceURI: uriStr qualifiedName: completeStr];
		}
		else
		{
			[delegate parser: parser didEndElement: localnameStr
				namespaceURI: nil qualifiedName: localnameStr];
		}
	}
	
	[parser _popNamespaces];
}

static void __processingInstruction( void * ctx, const xmlChar * target, const xmlChar * data )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_ON_ABORT();
	
	if ( [delegate respondsToSelector: @selector(parser:foundProcessingInstructionWithTarget:data:)] == NO )
		return;
	
	NSString * targetStr = NSStringFromXmlChar(target);
	NSString * dataStr = NSStringFromXmlChar(data);
	
	[delegate parser: parser foundProcessingInstructionWithTarget: targetStr data: dataStr];
}

static void __cdataBlock( void * ctx, const xmlChar * value, int len )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_ON_ABORT();
	
	if ( [delegate respondsToSelector: @selector(parser:foundCDATA:)] == NO )
		return;
	
	NSData * data = [[NSData allocWithZone: nil] initWithBytes: value length: len];
	[delegate parser: parser foundCDATA: data];
}

static void __comment( void * ctx, const xmlChar * value )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_ON_ABORT();
	
	if ( [delegate respondsToSelector: @selector(parser:foundComment:)] == NO )
		return;
	
	NSString * commentStr = NSStringFromXmlChar(value);
	[delegate parser: parser foundComment: commentStr];
}

static void __warningCallback( void * ctx, const char * msg, ... )
{
}

static void __errorCallback( void * ctx, const char * msg, ... )
{
    if ( ctx == NULL )
        return;
    
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_ON_ABORT();
	
	if ( [delegate respondsToSelector: @selector(parser:parseErrorOccurred:)] == NO )
		return;
	
	[delegate parser: parser parseErrorOccurred: [NSError errorWithDomain: NSXMLParserErrorDomain
																	 code: p->errNo
																 userInfo: nil]];
}

static void __structuredErrorFunc( void * ctx, xmlErrorPtr errorData )
{
    if ( ctx == NULL )
        return;
    
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	_AQXMLParserInternal * info = [parser _info];
	RETURN_ON_ABORT();
	
	if ( [delegate respondsToSelector: @selector(parser:parseErrorOccurred:)] == NO )
		return;
	
	int code = (info->delegateAborted ? 0x200 : errorData->code);
	[delegate parser: parser parseErrorOccurred: [NSError errorWithDomain: NSXMLParserErrorDomain
																	 code: code
																 userInfo: nil]];
}

static xmlEntityPtr __getEntity( void * ctx, const xmlChar * name )
{
    xmlParserCtxtPtr p = CTX(ctx);
	
	xmlEntityPtr entity = xmlGetPredefinedEntity( name );
	if ( entity != NULL )
		return ( entity );
    
    p->_private = (void *)1;
	entity = xmlSAX2GetEntity( p, name );
    p->_private = (void *)0;
    
	if ( entity != NULL )
	{
        switch ( p->instate )
        {
            case XML_PARSER_MISC:
            case XML_PARSER_PI:
            case XML_PARSER_DTD:
            {
                p->_private = (void *)1;
                break;
            }
            default:
                break;
        }
		return ( entity );
	}
    
    if ( p->userData == p )
        return ( NULL );
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = parser.delegate;
	RETURN_VAL_ON_ABORT(NULL);
	
	if ( [delegate respondsToSelector: @selector(parser:resolveExternalEntityName:systemID:)] == NO )
		return ( NULL );
	
	NSString * nameStr = NSStringFromXmlChar(name);
	
	NSData * data = [delegate parser: parser resolveExternalEntityName: nameStr systemID: nil];
	
    if ( data == nil )
		return ( NULL );
	
	if ( p->myDoc == NULL )
		return ( NULL );
	
	// got a string for the (parsed/resolved) entity, so just hand that in as characters directly
	NSString * str = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	const char * ch = [str UTF8String];
	__characters( ctx, (const xmlChar *)ch, (int)strlen(ch) );
	
	return ( NULL );
}

static void __startElementNS( void * ctx, const xmlChar *localname, const xmlChar *prefix,
							 const xmlChar *URI, int nb_namespaces, const xmlChar **namespaces,
							 int nb_attributes, int nb_defaulted, const xmlChar **attributes)
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = [parser delegate];
	RETURN_ON_ABORT();
	
	BOOL processNS = [parser shouldProcessNamespaces];
	BOOL reportNS = [parser shouldReportNamespacePrefixes];
	
	NSString * prefixStr = NSStringFromXmlChar(prefix);
	NSString * localnameStr = NSStringFromXmlChar(localname);
	
	NSString * completeStr = localnameStr;
	if ( [prefixStr length] != 0 )
		completeStr = [[NSString alloc] initWithFormat: @"%@:%@", prefixStr, localnameStr];
	
	NSString * uriStr = nil;
	if ( processNS )
		uriStr = NSStringFromXmlChar(URI);
	
	NSMutableDictionary * attrDict = [[NSMutableDictionary alloc] initWithCapacity: nb_attributes + nb_namespaces];
	
	NSMutableDictionary * nsDict = nil;
	if ( reportNS )
		nsDict = [[NSMutableDictionary alloc] initWithCapacity: nb_namespaces];
	
	int i;
	for ( i = 0; i < (nb_namespaces * 2); i += 2 )
	{
		NSString * namespaceStr = nil;
		NSString * qualifiedStr = nil;
		
		if ( namespaces[i] == NULL )
		{
            namespaceStr = @"";
			qualifiedStr = @"xmlns";
		}
		else
		{
			namespaceStr = NSStringFromXmlChar(namespaces[i]);
			qualifiedStr = [[NSString alloc] initWithFormat: @"xmlns:%@", namespaceStr];
		}
		
		NSString * val = nil;
		if ( namespaces[i+1] != NULL )
			val = NSStringFromXmlChar(namespaces[i+1]);
		else
			val = @"";
		
		[nsDict setObject: val forKey: namespaceStr];
		[attrDict setObject: val forKey: qualifiedStr];
	}
	
	if ( reportNS )
		[parser _pushNamespaces: nsDict];
	
	for ( i = 0; i < (nb_attributes * 5); i += 5 )
	{
		if ( attributes[i] == NULL )
			continue;
		
		NSString * attrLocalName = NSStringFromXmlChar(attributes[i]);
		
		NSString * attrPrefix = nil;
		if ( attributes[i+1] != NULL )
			attrPrefix = NSStringFromXmlChar(attributes[i+1]);
		
		NSString * attrQualified = attrLocalName;
		if ( [attrPrefix length] != 0 )
			attrQualified = [[NSString alloc] initWithFormat: @"%@:%@", attrPrefix, attrLocalName];
		
		NSString * attrValue = @"";
		if ( (attributes[i+3] != NULL) && (attributes[i+4] != NULL) )
		{
			NSUInteger length = attributes[i+4] - attributes[i+3];
			attrValue = [[NSString alloc] initWithBytes: attributes[i+3]
												 length: length
											   encoding: NSUTF8StringEncoding];
		}
		
		[attrDict setObject: attrValue forKey: attrQualified];
	}
	
	if ( [delegate respondsToSelector: @selector(parser:didStartElement:namespaceURI:qualifiedName:attributes:)] )
	{
		[delegate parser: parser
		 didStartElement: localnameStr
			namespaceURI: uriStr
		   qualifiedName: completeStr
			  attributes: attrDict];
	}
}

static void __startElement( void * ctx, const xmlChar * name, const xmlChar ** attrs )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = [parser delegate];
	RETURN_ON_ABORT();
    
    if ( [delegate respondsToSelector: @selector(parser:didStartElement:namespaceURI:qualifiedName:attributes:)] == NO )
        return;
    
    NSString * nameStr = NSStringFromXmlChar(name);
    NSMutableDictionary * attrDict = [[NSMutableDictionary alloc] init];
    
    if ( attrs != NULL )
    {
        while ( *attrs != NULL )
        {
            NSString * keyStr = NSStringFromXmlChar(*attrs);
            attrs++;
            
            NSString * valueStr = NSStringFromXmlChar(*attrs);
            attrs++;
            
            if ( (keyStr != nil) && (valueStr != nil) )
                [attrDict setObject: valueStr forKey: keyStr];
        }
    }
    
    [delegate parser: parser
     didStartElement: nameStr
        namespaceURI: nil
       qualifiedName: nil
          attributes: attrDict];
}

static void __endElement( void * ctx, const xmlChar * name )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = [parser delegate];
	RETURN_ON_ABORT();
    
    if ( [delegate respondsToSelector: @selector(parser:didEndElement:namespaceURI:qualifiedName:)] == NO )
        return;
    
    NSString * nameStr = NSStringFromXmlChar(name);
    
    [delegate parser: parser didEndElement: nameStr namespaceURI: nil qualifiedName: nil];
    
}

static void __ignorableWhitespace( void * ctx, const xmlChar * ch, int len )
{
    xmlParserCtxtPtr p = CTX(ctx);
	AQXMLParser * parser = PARSER(p);
	id<AQXMLParserDelegate> delegate = [parser delegate];
	RETURN_ON_ABORT();
    
    if ( [delegate respondsToSelector: @selector(parser:foundIgnorableWhitespace:)] == NO )
		return;
	
	NSString * str = [[NSString allocWithZone: nil] initWithBytes: ch
														   length: len
														 encoding: NSUTF8StringEncoding];
	[delegate parser: parser foundCharacters: str];
}

#pragma mark -

@implementation AQXMLParser

@synthesize delegate=_delegate;
@synthesize progressDelegate=_progressDelegate;

- (id) initWithStream: (NSInputStream *) stream
{
	self = [super init];
	if ( self == nil )
		return ( nil );
	
	_internal = [[_AQXMLParserInternal alloc] init];
#if TARGET_OS_IPHONE
	_internal->saxHandler = NSZoneMalloc( [self zone], sizeof(struct _xmlSAXHandler) );
#else
	_internal->saxHandler = NSAllocateCollectable( sizeof(struct _xmlSAXHandler), 0 );
#endif
	_internal->parserContext = NULL;
	_internal->error = nil;
	
	_stream = stream;
    if ( _internal->expectedDataLength != 0.0 )
        [self _setupExpectedLength];
	
	[self _initializeSAX2Callbacks];
#if 0
    self.debugLogInput = YES;
#endif
	return ( self );
}

- (id) initWithData: (NSData *) data
{
    NSInputStream * stream = [[NSInputStream alloc] initWithData: data];
    self = [self initWithStream: stream];
	
	if ( self == nil )
		return ( nil );
	
    _internal->expectedDataLength = (float) [data length];
    return ( self );
}

- (id) initWithURL: (NSURL *) fileUrl
{
    NSInputStream* myInput = [NSInputStream inputStreamWithURL:fileUrl];
    _internal = [[_AQXMLParserInternal alloc] init];
#if TARGET_OS_IPHONE
	_internal->saxHandler = NSZoneMalloc( [self zone], sizeof(struct _xmlSAXHandler) );
#else
	_internal->saxHandler = NSAllocateCollectable( sizeof(struct _xmlSAXHandler), 0 );
#endif
	_internal->parserContext = NULL;
	_internal->error = nil;
	
	_stream = myInput;
    
    _internal->expectedDataLength = (float) [[[NSFileManager defaultManager] attributesOfItemAtPath:fileUrl.path error:nil] fileSize];
    
    if ( _internal->expectedDataLength != 0.0 )
        NSLog(@"expected length %f", _internal->expectedDataLength);
        [self _setupExpectedLength];
	
	[self _initializeSAX2Callbacks];
#if 0
    self.debugLogInput = YES;
#endif
	return ( self );
}

- (void) dealloc
{
	NSZoneFree( nil, _internal->saxHandler );
	
	if ( _internal->parserContext != NULL )
	{
        if ( self.HTMLMode )
        {
            htmlFreeParserCtxt( _internal.htmlParserContext );
        }
        else    // XML mode
        {
            xmlParserCtxtPtr p = _internal.xmlParserContext;
            if ( p->myDoc != NULL )
                xmlFreeDoc( p->myDoc );
            xmlFreeParserCtxt( _internal->parserContext );
        }
	}
}

- (void) finalize
{
	if ( _internal->parserContext != NULL )
	{
        if ( self.HTMLMode )
        {
            htmlFreeParserCtxt( _internal.htmlParserContext );
        }
        else    // XML mode
        {
            xmlParserCtxtPtr p = _internal.xmlParserContext;
            if ( p->myDoc != NULL )
                xmlFreeDoc( p->myDoc );
            xmlFreeParserCtxt( _internal->parserContext );
        }
	}
	
	[super finalize];
}

- (BOOL) debugLogInput
{
	return ( _internal->debugOutputStream != nil );
}

- (void) setDebugLogInput: (BOOL) value
{
	if ( value )
	{
		if ( _internal->debugOutputStream == nil )
		{
			_internal->debugOutputStream = [[NSOutputStream alloc] initToMemory];
			[_internal->debugOutputStream open];
		}
	}
	else if ( _internal->debugOutputStream != nil )
	{
		[_internal->debugOutputStream close];
		_internal->debugOutputStream = nil;
	}
}

- (BOOL) shouldProcessNamespaces
{
	return ( (_internal->parserFlags & AQXMLParserShouldProcessNamespaces) == AQXMLParserShouldProcessNamespaces );
}

- (void) setShouldProcessNamespaces: (BOOL) value
{
	// don't change if we're already parsing
	if ( [self _xmlParserContext] != NULL )
		return;
	
	if ( value )
		_internal->parserFlags |= AQXMLParserShouldProcessNamespaces;
	else
		_internal->parserFlags &= ~AQXMLParserShouldProcessNamespaces;
}

- (BOOL) shouldReportNamespacePrefixes
{
	return ( (_internal->parserFlags & AQXMLParserShouldReportPrefixes) == AQXMLParserShouldReportPrefixes );
}

- (void) setShouldReportNamespacePrefixes: (BOOL) value
{
	if ( [self _xmlParserContext] != NULL )
		return;
	
	if ( value )
		_internal->parserFlags |= AQXMLParserShouldReportPrefixes;
	else
		_internal->parserFlags &= ~AQXMLParserShouldReportPrefixes;
}

- (BOOL) shouldResolveExternalEntities
{
	return ( (_internal->parserFlags & AQXMLParserShouldResolveExternals) == AQXMLParserShouldResolveExternals );
}

- (void) setShouldResolveExternalEntities: (BOOL) value
{
	if ( [self _xmlParserContext] != NULL )
		return;
	
	if ( value )
		_internal->parserFlags |= AQXMLParserShouldResolveExternals;
	else
		_internal->parserFlags &= ~AQXMLParserShouldResolveExternals;
}

- (BOOL) isInHTMLMode
{
    return ( (_internal->parserFlags & AQXMLParserHTMLMode) == AQXMLParserHTMLMode );
}

- (void) setHTMLMode: (BOOL) value
{
    if ( [self _htmlParserContext] != NULL )
        return;
    
    if ( value )
        _internal->parserFlags |= AQXMLParserHTMLMode;
    else
        _internal->parserFlags &= ~AQXMLParserHTMLMode;
}

- (BOOL) parse
{
	if ( [self parseAsynchronouslyUsingRunLoop: [NSRunLoop currentRunLoop]
                                          mode: AQXMLParserParsingRunLoopMode
                             notifyingDelegate: nil
                                      selector: NULL
                                       context: NULL] == NO )
    {
        return ( NO );
    }
	
	if ( _internal->delegateAborted )
		return ( NO );
	
	// run in the common runloop modes while we read the data from the stream
	_internal->waitingRunLoop = [NSRunLoop currentRunLoop];
	
	while ( _streamComplete == NO )
	{
		@autoreleasepool
        {
            [[NSRunLoop currentRunLoop] runMode: AQXMLParserParsingRunLoopMode
                                     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
        }
	}
	
	_internal->waitingRunLoop = nil;
	
	[_stream setDelegate: nil];
	[_stream removeFromRunLoop: [NSRunLoop currentRunLoop]
                       forMode: AQXMLParserParsingRunLoopMode];
	[_stream close];
	
	if ( _internal->debugOutputStream != nil && [_internal->debugOutputStream streamStatus] != NSStreamStatusClosed )
	{
		NSData * data = [_internal->debugOutputStream propertyForKey: NSStreamDataWrittenToMemoryStreamKey];
		if ( [_delegate respondsToSelector: @selector(writeReceivedData:)] )
			[_delegate performSelector: @selector(writeReceivedData:) withObject: data];
		
		NSString * str = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
		// DO NOT COMMENT OUT THIS LINE!!!!!!!!
		// NO, REALLY--- STOP DOING IT!!!!!
		NSLog( @"Response:\n%@", str );
		[_internal->debugOutputStream close];
	}
	
	return ( _internal->error == nil );
}

- (BOOL) parseAsynchronouslyUsingRunLoop: (NSRunLoop *) runloop
                                    mode: (NSString *) mode
                       notifyingDelegate: (id) asyncCompletionDelegate
                                selector: (SEL) completionSelector
                                 context: (void *) contextPtr
{
    if ( _stream == nil )
		return ( NO );
	
	// see if bytes are already available on the stream
	// if there are, we'll grab the first 4 bytes and use those to compute the encoding
	// otherwise, we'll just go with no initial data
	uint8_t buf[4];
	size_t buflen = 0;
	
	_streamComplete = NO;
	
	if ( [_stream hasBytesAvailable] )
    {
		buflen = [_stream read: buf maxLength: 4];
        [self _initializeParserWithBytes: buf length: buflen];
    }
    
    // store async callbacks details
    _internal->asyncDelegate = asyncCompletionDelegate;
    _internal->asyncSelector = completionSelector;
    _internal->asyncContext  = contextPtr;
	
	// start the stream processing going
	[_stream setDelegate: self];
	[_stream scheduleInRunLoop: runloop forMode: mode];
	
	if ( [_stream streamStatus] == NSStreamStatusNotOpen )
		[_stream open];
    
    return ( YES );
}

- (void) stream: (NSStream *) stream handleEvent: (NSStreamEvent) streamEvent
{
	NSInputStream * input = (NSInputStream *) _stream;
	
	switch ( streamEvent )
	{
		case NSStreamEventOpenCompleted:
            //_internal.requestMessage = [stream finalRequestMessage];
            _internal.isFinalRequest = NO;
            break;
            
		default:
			break;
			
		case NSStreamEventErrorOccurred:
		{
			_internal->error = [input streamError];
            NSLog(@"Stream error: %@ (%@)", _internal->error, [_internal->error userInfo]);

			if ( [_delegate respondsToSelector: @selector(parser:parseErrorOccurred:)] ) {
				[_delegate parser: self parseErrorOccurred: _internal->error];
				
				// Retrying entire process in response to broken pipe response (error code 32)
				if( [_internal->error code] == 32 ) {
					NSLog( @"Broken Pipe condition identified in AQXMLParser" );
					[[NSNotificationCenter defaultCenter] postNotificationName:AQXMLParserBrokenPipeNotification object:self];
				} else {
					NSLog( @"Error parsing response: %@", _internal->error );
				}

			}
			[self _setStreamComplete: NO];
			if ( [_internal->debugOutputStream streamStatus] != NSStreamStatusClosed )
			{
				[_internal->debugOutputStream close];
			}
			break;
		}
			
		case NSStreamEventEndEncountered:
		{
			xmlParseChunk( _internal->parserContext, NULL, 0, 1 );
			[self _setStreamComplete: YES];
			break;
		}
			
		case NSStreamEventHasBytesAvailable:
		{
            if ( _internal.isFinalRequest == NO )
            {
                //_internal.requestMessage = [stream finalRequestMessage];
                _internal.isFinalRequest = YES;
            }
            
			if ( _internal->delegateAborted )
                break;
			/*
			if ( _internal->responseMessage == nil )
			{
				_internal->responseMessage = [[input responseMessageHeader] retain];
				if ( _internal->responseMessage.statusCode >= 400 )
				{
					NSMutableDictionary * userInfo = [NSMutableDictionary new];
					[userInfo setObject: _internal.requestMessage.requestURL forKey: NSURLErrorFailingURLErrorKey];
					_internal->error = [[NSError alloc] initWithDomain: NSURLErrorDomain code: NSURLErrorUserAuthenticationRequired userInfo: userInfo];
					[userInfo release];
					
					[self abortParsing];
#if 0
					(void)[stream setProperty: [NSNumber numberWithBool: YES] forKey: @"LogAllInputData"];
#endif
					return;
				}
			}
            */
			uint8_t buf[1024];
			NSInteger len = [input read: buf maxLength: 1024];
			if ( len > 0 )
			{
				char * found = strnstr( (char *)buf, "&#x13;", len );
				if ( found != NULL )
					memcpy( found, "[ARGH]", 6 );
				
				[self _pushXMLData: buf length: len];
			}
			
			break;
		}
	}
}

- (void) abortParsing
{
	_internal->delegateAborted = YES;
	if ( _internal->parserContext != NULL )
		xmlStopParser( _internal->parserContext );
    
	[self _setStreamComplete: NO];  // must tell any async delegates that we're done parsing
	
	// if there's no async delegate (i.e. if we are parsing synchronously) then explicitly wake the runloop
	CFRunLoopRef rl = [_internal->waitingRunLoop getCFRunLoop];
	if ( rl != NULL )
		CFRunLoopWakeUp( rl );
}

- (NSError *) parserError
{
	return ( _internal->error );
}

@end

@implementation AQXMLParser (AQXMLParserLocatorAdditions)

- (NSString *) publicID
{
	return ( nil );
}

- (NSString *) systemID
{
	return ( nil );
}

- (NSInteger) lineNumber
{
	if ( _internal->parserContext == NULL )
		return ( 0 );
	
	return ( xmlSAX2GetLineNumber(_internal->parserContext) );
}

- (NSInteger) columnNumber
{
	if ( _internal->parserContext == NULL )
		return ( 0 );
	
	return ( xmlSAX2GetColumnNumber(_internal->parserContext) );
}

@end

@implementation AQXMLParser (AQXMLParserHTTPStreamAdditions)

- (HTTPMessage *) finalRequest
{
	return ( _internal.requestMessage );
}

- (HTTPMessage *) finalResponse
{
	return ( nil );// ( [_stream responseMessageHeader] );
}

@end


@implementation AQXMLParser (Internal)

- (void) _setParserError: (int) err
{
	_internal->error = [[NSError alloc] initWithDomain: NSXMLParserErrorDomain
												  code: err
											  userInfo: nil];
}

- (xmlParserCtxtPtr) _xmlParserContext
{
	return ( _internal.xmlParserContext );
}

- (htmlParserCtxtPtr) _htmlParserContext
{
    return ( _internal.htmlParserContext );
}

- (void) _pushNamespaces: (NSDictionary *) nsDict
{
	if ( _internal->namespaces == nil )
		_internal->namespaces = [[NSMutableArray alloc] init];
	
	if ( nsDict != nil )
	{
		[_internal->namespaces addObject: nsDict];
		
		if ( [_delegate respondsToSelector: @selector(parser:didStartMappingPrefix:toURI:)] )
		{
			for ( NSString * key in nsDict )
			{
				[_delegate parser: self didStartMappingPrefix: key toURI: [nsDict objectForKey: key]];
			}
		}
	}
	else
	{
		[_internal->namespaces addObject: [NSNull null]];
	}
}

- (void) _popNamespaces
{
	id obj = [_internal->namespaces lastObject];
	if ( obj == nil )
		return;
	
	if ( [obj isEqual: [NSNull null]] == NO )
	{
		if ( [_delegate respondsToSelector: @selector(parser:didEndMappingPrefix:)] )
		{
			for ( NSString * key in obj )
			{
				[_delegate parser: self didEndMappingPrefix: key];
			}
		}
	}
	
	[_internal->namespaces removeLastObject];
}

- (void) _initializeSAX2Callbacks
{
	xmlSAXHandlerPtr p = _internal.xmlSaxHandler;
	
	p->internalSubset = __internalSubset2;
	p->isStandalone = __isStandalone;
	p->hasInternalSubset = __hasInternalSubset2;
	p->hasExternalSubset = __hasExternalSubset2;
	p->resolveEntity = __resolveEntity;
	p->getEntity = __getEntity;
	p->entityDecl = __entityDecl;
	p->notationDecl = __notationDecl;
	p->attributeDecl = __attributeDecl;
	p->elementDecl = __elementDecl;
	p->unparsedEntityDecl = __unparsedEntityDecl;
	p->setDocumentLocator = NULL;
	p->startDocument = __startDocument;
	p->endDocument = __endDocument;
	p->startElement = NULL; //__startElement;
	p->endElement = NULL; //__endElement;
	p->startElementNs = __startElementNS;
	p->endElementNs = __endElementNS;
	p->reference = __reference;
	p->characters = __characters;
	p->ignorableWhitespace = __ignorableWhitespace;
	p->processingInstruction = __processingInstruction;
	p->warning = __warningCallback;
	p->error = __errorCallback;
    p->serror = __structuredErrorFunc;
	//xmlSetStructuredErrorFunc( self, __structuredErrorFunc );
	p->getParameterEntity = __getParameterEntity;
	p->cdataBlock = __cdataBlock;
	p->comment = __comment;
	p->externalSubset = __externalSubset2;
	p->initialized = XML_SAX2_MAGIC;
}

- (void) _initializeParserWithBytes: (const void *) buf length: (NSUInteger) length
{
    if ( self.HTMLMode )
    {
        // for HTML, we use the non-NS callbacks; for XML, we don't want these to get in the way.
        htmlSAXHandlerPtr saxPtr = _internal.htmlSaxHandler;
        saxPtr->startElement = __startElement;
        saxPtr->endElement = __endElement;
        
        _internal->parserContext = htmlCreatePushParserCtxt( saxPtr, (void *)&_internal->parserContext,
                                                             (const char *)(length > 0 ? buf : NULL),
                                                             (int)length, NULL, XML_CHAR_ENCODING_UTF8 );
        
        htmlCtxtUseOptions( _internal.htmlParserContext, XML_PARSE_RECOVER );
        _internal->parserContext->sax->_private = (__bridge void *)self;
    }
    else
    {
        _internal->parserContext = xmlCreatePushParserCtxt( _internal.xmlSaxHandler, (void *)&_internal->parserContext,
                                                           (const char *)(length > 0 ? buf : NULL),
                                                           (int)length, NULL );
    
        int options = [self shouldResolveExternalEntities] ? 
                XML_PARSE_RECOVER | XML_PARSE_NOENT | XML_PARSE_DTDLOAD :
                XML_PARSE_RECOVER | XML_PARSE_DTDATTR;
        
        xmlCtxtUseOptions( _internal->parserContext, options );
        _internal->parserContext->sax->_private = (__bridge void *)self;
    }
    
    _internal->parserContext->userData = _internal->parserContext;
}

- (void) _pushXMLData: (const void *) bytes length: (NSUInteger) length
{
	@autoreleasepool
    {
		if ( _internal->debugOutputStream != nil )
			[_internal->debugOutputStream write: bytes maxLength: length];
		
		if ( _internal->parserContext == NULL )
		{
			[self _initializeParserWithBytes: bytes length: length];
		}
		else
		{
			int err = XML_ERR_OK;
			if ( self.HTMLMode )
				err = htmlParseChunk( _internal.htmlParserContext, (const char *)bytes, (int)length, 0 );
			else
				err = xmlParseChunk( _internal.xmlParserContext, (const char *)bytes, (int)length, 0 );
			
			if ( (err != XML_ERR_OK) && (_internal->delegateAborted == NO) )
			{
				NSData * data = [[NSData alloc] initWithBytesNoCopy: (void *)bytes length: length freeWhenDone: NO];
				NSString * str = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
				NSLog( @"Error %d in bytes: %@ (str: %@)", err, data, str );
				
				[self _setParserError: err];
				[self _setStreamComplete: NO];
			}
		}
		
		if ( _progressDelegate != nil )
		{
			_internal->currentLength += (float) length;
			[_progressDelegate parser: self
			           updateProgress: (_internal->currentLength / _internal->expectedDataLength)];
		}
    }
}

- (_AQXMLParserInternal *) _info
{
	return ( _internal );
}

- (void) _setStreamComplete: (BOOL) parsedOK
{
    _streamComplete = YES;
    
    if ( _internal->asyncDelegate != nil )
    {
        @try
        {
            NSInvocation * invoc = [NSInvocation invocationWithMethodSignature: [_internal->asyncDelegate methodSignatureForSelector: _internal->asyncSelector]];
            
            CFTypeRef cfSelf = CFBridgingRetain(self);
            [invoc setTarget: _internal->asyncDelegate];
            [invoc setSelector: _internal->asyncSelector];
            [invoc setArgument: &cfSelf atIndex: 2];
            [invoc setArgument: &parsedOK atIndex: 3];
            [invoc setArgument: &_internal->asyncContext atIndex: 4];
            
            [invoc invoke];
            
            CFRelease(cfSelf);
        }
        @catch (NSException * e)
        {
            NSLog( @"Caught %@ while calling AQXMLParser async delegate: %@", e.name, e.reason );
            @throw;
        }
    }
}

- (void) _setupExpectedLength
{
    CFHTTPMessageRef msg = (__bridge CFHTTPMessageRef) [_stream propertyForKey: (__bridge NSString *)kCFStreamPropertyHTTPResponseHeader];
    if ( msg != NULL )
    {
        NSString * str = CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(msg, CFSTR("Content-Length")));
        if ( str != NULL )
        {
            _internal->expectedDataLength = [str floatValue];
        }
        return;
    }
    
    NSNumber * num = [_stream propertyForKey: (__bridge NSString *)kCFStreamPropertyFTPResourceSize];
    if ( num != NULL )
    {
        _internal->expectedDataLength = [num floatValue];
        return;
    }
    
    // for some forthcoming stream classes...
    NSNumber * guess = [_stream propertyForKey: @"UncompressedDataLength"];
    if ( guess != nil )
        _internal->expectedDataLength = [guess floatValue];
}

- (BOOL) _parseAborted
{
	return ( _internal->delegateAborted );
}

@end

