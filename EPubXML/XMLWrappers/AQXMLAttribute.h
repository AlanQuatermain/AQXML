//
//  AQXMLAttribute.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AQXMLNode.h"

@class AQXMLElement, AQXMLNamespace;

typedef NS_ENUM(NSUInteger, AQXMLAttributeType) {
    AQXMLAttributeTypeCDATA = 1,
    AQXMLAttributeTypeID,
    AQXMLAttributeTypeIDRef	,
    AQXMLAttributeTypeIDRefs,
    AQXMLAttributeTypeEntity,
    AQXMLAttributeTypeEntities,
    AQXMLAttributeTypeNMToken,
    AQXMLAttributeTypeNMTokens,
    AQXMLAttributeTypeEnumeration,
    AQXMLAttributeTypeNotation
};

@interface AQXMLAttribute : AQXMLNode

// attributes must be created by adding a name/value pair to an AQXMLElement

@property (nonatomic, copy) NSString * value;
@property (nonatomic, assign) AQXMLAttributeType attributeType;

- (void) setName: (NSString *) name andValue: (NSString *) value;
- (void) setName: (NSString *) name andValue: (NSString *) value inNamespace: (AQXMLNamespace *) ns;

@end
