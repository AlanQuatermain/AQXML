//
//  Base64Transform.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-18.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLTransform.h"

@interface Base64Transform : AQXMLTransform
+ (NSString *) encode: (NSData *) data;
+ (NSData *) decode: (NSData *) encoded;
@end
