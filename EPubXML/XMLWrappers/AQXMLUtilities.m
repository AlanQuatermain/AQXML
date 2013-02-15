//
//  AQXMLUtilities.m
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
