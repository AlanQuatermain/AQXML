//
//  AQXMLSchema.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AQXMLObject.h"

@class AQXMLDocument, AQXMLElement;

@interface AQXMLSchema : AQXMLObject

+ (AQXMLSchema *) schemaWithDocument: (AQXMLDocument *) document;
+ (AQXMLSchema *) schemaWithURL: (NSURL *) url;
+ (AQXMLSchema *) schemaWithXMLString: (NSString *) string;
+ (AQXMLSchema *) schemaWithData: (NSData *) data;

- (BOOL) validateDocument: (AQXMLDocument *) document errorHandler: (void (^)(BOOL fatal, NSString * msg)) errorHandler;
- (BOOL) validateElement: (AQXMLElement *) element errorHandler: (void (^)(BOOL fatal, NSString * msg)) errorHandler;

- (NSDictionary *) defaultAttributesForElementName: (NSString *) name prefix: (NSString *) prefix;

@end
