//
//  AQXMLUtilities.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libxml/xmlmemory.h>

// based on XMLDocument sample code from Apple

extern NSString * const AQXMLErrorDomain;

@interface NSError (AQXMLErrors)
+ (NSError *) errorWithXMLError: (xmlError *) xError;
+ (NSError *) xmlGenericErrorWithDescription: (NSString *) desc;
@end

@interface NSString (AQXMLStrings)
+ (NSString *) stringWithXMLString: (const xmlChar *) xStr;
- (id) initWithXMLString: (const xmlChar *) xStr;
- (const xmlChar *) xmlString NS_RETURNS_INNER_POINTER;
@end
