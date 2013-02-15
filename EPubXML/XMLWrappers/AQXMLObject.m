//
//  AQXMLObject.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-09.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLObject.h"

@implementation AQXMLObject

@synthesize valid=_valid;

- (id) init
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _valid = YES;
    
    return ( self );
}

- (void) invalidate
{
    _valid = NO;
}

@end
