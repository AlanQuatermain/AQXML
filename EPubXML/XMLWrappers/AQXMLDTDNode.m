//
//  AQXMLDTDNode.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLDTDNode.h"
#import "AQXML_Private.h"
#import <libxml/tree.h>

@implementation AQXMLDTDNode

+ (AQXMLDTDNode *) DTDNodeWithXMLDTD: (xmlDtdPtr) dtd
{
    return ( [[self alloc] initWithXMLDTD: dtd] );
}

- (id) initWithXMLDTD: (xmlDtdPtr) dtd
{
    return ( [super initWithXMLNode: (xmlNodePtr)dtd] );
}

- (xmlDtdPtr) xmlObj
{
    return ( (xmlDtdPtr)[super xmlObj] );
}

@end
