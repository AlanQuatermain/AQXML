//
//  AQXMLObject.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-09.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AQXMLObject : NSObject
{
    BOOL _valid;
}
@property (nonatomic, readonly, getter=isValid) BOOL valid;
- (void) invalidate;
@end
