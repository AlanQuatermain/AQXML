//
//  AQXMLAttribute.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012-2013 Kobo, Inc.
//  All rights reserved.
//  
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  
//  - Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//  - Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//  - Neither the name of Kobo, Inc. nor the names of its contributors
//    may be used to endorse or promote products derived from this
//    software without specific prior written permission.
//  
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//  COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
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
