//
//  AQXMLReader.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AQXMLDocument;

@interface AQXMLReader : NSObject

+ (AQXMLDocument *) parseXMLFileAtURL: (NSURL *) url error: (NSError **) error;
+ (AQXMLDocument *) parseXMLString: (NSString *) string error: (NSError **) error;
+ (AQXMLDocument *) parseXML: (const char *) xml length: (NSUInteger) length error: (NSError **) error;

@end
