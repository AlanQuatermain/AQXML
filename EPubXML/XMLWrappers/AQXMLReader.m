//
//  AQXMLReader.m
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

#import "AQXMLReader.h"
#import "AQXMLDocument.h"
#import "AQXMLUtilities.h"
#import "AQXML_Private.h"

@implementation AQXMLReader

+ (AQXMLDocument *) parseXMLFileAtURL: (NSURL *) url error: (NSError **) error
{
    NSStringEncoding enc = NSUTF8StringEncoding;
    NSString * str = [NSString stringWithContentsOfURL: url usedEncoding: &enc error: error];
    if ( str == nil )
        return ( nil );
    
    return ( [self parseXMLString: str error: error] );
}

+ (AQXMLDocument *) parseXMLString: (NSString *) string error: (NSError **) error
{
    const char * xml = [string UTF8String];
    return ( [self parseXML: [string UTF8String] length: strlen(xml) error: error] );
}

+ (AQXMLDocument *) parseXML: (const char *) xml length: (NSUInteger) length error: (NSError **) error
{
    if ( xml == NULL )
        return ( nil );
    
    AQXMLDocument * result = nil;
    @synchronized(self)
    {
        xmlParserCtxtPtr ctx = xmlNewParserCtxt();
        xmlDocPtr doc = xmlCtxtReadMemory(ctx, xml, (int)length, NULL, NULL, XML_PARSE_DTDATTR|XML_PARSE_NOENT|XML_PARSE_DTDATTR);
        if ( doc == NULL )
        {
            if ( error != NULL )
            {
                xmlError *err = xmlCtxtGetLastError(ctx);
                *error = [NSError errorWithXMLError: err];
            }
        }
        else if ( xmlDocGetRootElement(doc) == NULL )
        {
            xmlFreeDoc(doc);
        }
        else
        {
            result = [AQXMLDocument documentWithXMLDocument: doc];
        }
        
        xmlClearParserCtxt(ctx);
        xmlFreeParserCtxt(ctx);
    }
    
    return ( result );
}

@end
