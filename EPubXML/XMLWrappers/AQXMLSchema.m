//
//  AQXMLSchema.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLSchema.h"
#import "AQXML_Private.h"
#import "AQXMLUtilities.h"
#import <libxml/xmlschemas.h>
#import <libxml/xmlschemastypes.h>
#import <libxml/schemasInternals.h>

typedef void (^errorWarningBlock)(BOOL, NSString *);

static void _schemaWarning(void *ctx, const char * msg, ...) LIBXML_ATTR_FORMAT(2, 3);
void _schemaWarning(void *ctx, const char * msg, ...)
{
    errorWarningBlock handler = (__bridge errorWarningBlock)ctx;
    
    va_list args;
    va_start(args, msg);
    NSString * str = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: msg] arguments: args];
    va_end(args);
    
    if ( handler != nil )
    {
        handler(NO, str);
    }
    else
    {
        NSLog(@"Schema warning: %@", str);
    }
}

static void _schemaError(void *ctx, const char * msg, ...) LIBXML_ATTR_FORMAT(2, 3);
void _schemaError(void *ctx, const char * msg, ...)
{
    errorWarningBlock handler = (__bridge errorWarningBlock)ctx;
    
    va_list args;
    va_start(args, msg);
    NSString * str = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: msg] arguments: args];
    va_end(args);
    
    if ( handler != nil )
    {
        handler(YES, str);
    }
    else
    {
        NSLog(@"Schema error: %@", str);
    }
}

// yay brittleness
/**
 * xmlSchemaImport:
 * (extends xmlSchemaBucket)
 *
 * Reflects a schema. Holds some information
 * about the schema and its toplevel components. Duplicate
 * toplevel components are not checked at this level.
 */
typedef struct _xmlSchemaImport xmlSchemaImport;
typedef xmlSchemaImport *xmlSchemaImportPtr;
struct _xmlSchemaImport {
    int type; /* Main OR import OR include. */
    int flags;
    const xmlChar *schemaLocation; /* The URI of the schema document. */
    /* For chameleon includes, @origTargetNamespace will be NULL */
    const xmlChar *origTargetNamespace;
    /*
     * For chameleon includes, @targetNamespace will be the
     * targetNamespace of the including schema.
     */
    const xmlChar *targetNamespace;
    xmlDocPtr doc; /* The schema node-tree. */
    /* @relations will hold any included/imported/redefined schemas. */
    /*xmlSchemaSchemaRelationPtr*/ void * relations;
    int located;
    int parsed;
    int imported;
    int preserveDoc;
    /*xmlSchemaItemListPtr*/ void * globals;
    /*xmlSchemaItemListPtr*/ void * locals;
    /* The imported schema. */
    xmlSchemaPtr schema;
};

#define XML_SCHEMAS_NO_NAMESPACE (const xmlChar *) "##"

@implementation AQXMLSchema
{
    xmlSchemaPtr    _schema;
}

+ (NSURL *) localURLForSchemaURL: (NSURL *) url
{
    NSString * name = [url lastPathComponent];
    NSBundle * bundle = [NSBundle bundleForClass: self];
    return ( [bundle URLForResource: [name stringByDeletingPathExtension] withExtension: [name pathExtension]] );
}

+ (AQXMLSchema *) schemaWithDocument: (AQXMLDocument *) document
{
    xmlSchemaParserCtxtPtr ctx = xmlSchemaNewDocParserCtxt(document.xmlObj);
    return ( [[self alloc] initWithParserContext: ctx] );
}

+ (AQXMLSchema *) schemaWithURL: (NSURL *) url
{
    NSURL * localURL = [self localURLForSchemaURL: url];
    if ( localURL != nil )
        url = localURL;
    xmlSchemaParserCtxtPtr ctx = xmlSchemaNewParserCtxt([[url absoluteString] UTF8String]);
    return ( [[self alloc] initWithParserContext: ctx] );
}

+ (AQXMLSchema *) schemaWithXMLString: (NSString *) string
{
    return ( [self schemaWithData: [string dataUsingEncoding: NSUTF8StringEncoding]] );
}

+ (AQXMLSchema *) schemaWithData: (NSData *) data
{
    xmlSchemaParserCtxtPtr ctx = xmlSchemaNewMemParserCtxt([data bytes], (int)[data length]);
    return ( [[self alloc] initWithParserContext: ctx] );
}

- (id) initWithParserContext: (xmlSchemaParserCtxtPtr) ctx
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    __block BOOL parseFailed = NO;
    xmlSchemaSetParserErrors(ctx, &_schemaError, &_schemaWarning, (__bridge void *)^(BOOL fatal, NSString *msg) {
        NSLog(@"Schema parse %@: %@", (fatal ? @"error" : @"warning"), msg);
        if ( fatal )
            parseFailed = YES;
    });
    
    _schema = xmlSchemaParse(ctx);
    
    xmlSchemaSetParserErrors(ctx, NULL, NULL, NULL);
    xmlSchemaFreeParserCtxt(ctx);
    
    if ( parseFailed )
        return ( nil );
    
    return ( self );
}

- (void) dealloc
{
    xmlSchemaFree(_schema);
}

- (BOOL) validateDocument: (AQXMLDocument *) document errorHandler: (void (^)(BOOL failure, NSString * msg)) errorHandler
{
    xmlSchemaValidCtxtPtr ctx = xmlSchemaNewValidCtxt(_schema);
    xmlSchemaSetValidErrors(ctx, &_schemaError, &_schemaWarning, (__bridge void *)errorHandler);
    
    int err = xmlSchemaValidateDoc(ctx, document.xmlObj);
    xmlSchemaFreeValidCtxt(ctx);
    
    return ( err == 0 );
}

- (BOOL) validateElement: (AQXMLElement *) element errorHandler: (void (^)(BOOL failure, NSString * msg)) errorHandler
{
    xmlSchemaValidCtxtPtr ctx = xmlSchemaNewValidCtxt(_schema);
    xmlSchemaSetValidErrors(ctx, &_schemaError, &_schemaWarning, (__bridge void *)errorHandler);
    
    int err = xmlSchemaValidateOneElement(ctx, element.xmlObj);
    xmlSchemaFreeValidCtxt(ctx);
    
    return ( err == 0 );
}

- (NSDictionary *) defaultAttributesForElementName: (NSString *) name prefix: (NSString *) prefix
{
    if ( name == nil )
        return ( nil );
    
    xmlSchemaElementPtr elem = NULL;
    if ( prefix == nil || xmlStrEqual([prefix xmlString], _schema->targetNamespace) )
    {
        elem = xmlHashLookup(_schema->elemDecl, [name xmlString]);
    }
    
    if ( elem == NULL && xmlHashSize(_schema->schemasImports) > 1 )
    {
        xmlSchemaImportPtr import = NULL;
        if ( prefix == nil )
            import = xmlHashLookup(_schema->schemasImports, XML_SCHEMAS_NO_NAMESPACE);
        else
            import = xmlHashLookup(_schema->schemasImports, [prefix xmlString]);
        if ( import != NULL )
            elem = xmlHashLookup(import->schema->elemDecl, [name xmlString]);
    }
    
    if ( elem == NULL )
        return ( nil );
    
    NSMutableDictionary * dict = [NSMutableDictionary new];
    
    xmlSchemaAttributePtr attr = elem->attributes;
    while ( attr != NULL )
    {
        if ( attr->defValue != NULL )
        {
            NSString * key = [NSString stringWithXMLString: attr->name];
            dict[key] = [NSString stringWithXMLString: attr->defValue];
        }
        
        attr = attr->next;
    }
    
    return ( dict );
}

@end
