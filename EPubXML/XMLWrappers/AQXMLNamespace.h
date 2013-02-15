//
//  AQXMLNamespace.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AQXMLObject.h"

@class AQXMLNode, AQXMLDocument;

@interface AQXMLNamespace : AQXMLObject

+ (AQXMLNamespace *) namespaceWithNode: (AQXMLNode *) node
                                   URI: (NSString *) uri
                                prefix: (NSString *) prefix;
+ (AQXMLNamespace *) globalNamespaceForDocument: (AQXMLDocument *) doc
                                            URI: (NSURL *) uri
                                         prefix: (NSString *) prefix;

@property (readonly) NSURL * uri;
@property (readonly) NSString * prefix;

@end
