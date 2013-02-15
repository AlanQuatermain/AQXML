//
//  AQXMLReader.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
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
