//
//  AQXMLUtilities.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

// based on XMLDocument sample code from Apple

#import "AQXMLUtilities.h"

NSString * const AQXMLErrorDomain = @"AQXMLErrorDomain";

@implementation NSError (AQXMLErrors)

/**
 * xmlError:
 *
 * An XML Error instance.
 */
//
//typedef struct _xmlError xmlError;
//typedef xmlError *xmlErrorPtr;
//struct _xmlError {
//    int		domain;	/* What part of the library raised this error */
//    int		code;	/* The error code, e.g. an xmlParserError */
//    char       *message;/* human-readable informative error message */
//    xmlErrorLevel level;/* how consequent is the error */
//    char       *file;	/* the filename */
//    int		line;	/* the line number if available */
//    char       *str1;	/* extra string information */
//    char       *str2;	/* extra string information */
//    char       *str3;	/* extra string information */
//    int		int1;	/* extra number information */
//    int		int2;	/* extra number information */
//    void       *ctxt;   /* the parser context if available */
//    void       *node;   /* the node in the tree */
//};

+ (NSError *) errorWithXMLError: (xmlError *) xError
{
    NSString * msg = [NSString stringWithUTF8String: xError->message];
    return ( [NSError errorWithDomain: AQXMLErrorDomain code: xError->code userInfo: @{ NSLocalizedDescriptionKey : msg }] );
}

+ (NSError *) xmlGenericErrorWithDescription: (NSString *) desc
{
    return ( [NSError errorWithDomain: AQXMLErrorDomain code: -1 userInfo: @{ NSLocalizedDescriptionKey : desc }] );
}

@end

@implementation NSString (AQXMLStrings)

+ (NSString *) stringWithXMLString: (const xmlChar *) xStr
{
    // ugly cast is to avoid the editor picking the wrong object & flagging a type error
    return ( [(NSString *)[self alloc] initWithXMLString: xStr] );
}

- (id) initWithXMLString: (const xmlChar *) xStr
{
    return ( [self initWithUTF8String: (const char *)xStr] );
}

- (const xmlChar *) xmlString
{
    return ( (xmlChar *)[self UTF8String] );
}

@end
