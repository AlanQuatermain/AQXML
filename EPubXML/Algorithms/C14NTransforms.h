//
//  C14NTransforms.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-20.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLTransform.h"
#import "AQXMLCanonicalizer.h"

@class AQXMLElement;

// input to each transform should be either NSData or an AQXMLElement or AQXMLDocument

@interface C14NTransform : AQXMLTransform
@property (nonatomic, readonly) AQXMLCanonicalizationMethod method;
@end

#define C14N_CLASS(type) C14N##type##Transform
#define C14N_INTERFACE(type) @interface C14N_CLASS(type) : C14NTransform @end

// Required

C14N_INTERFACE(10)
C14N_INTERFACE(11)
C14N_INTERFACE(10Exclusive)

// Recommended

C14N_INTERFACE(10WithComments)
C14N_INTERFACE(11WithComments)
C14N_INTERFACE(10ExclusiveWithComments)

// XML Canonicalization 2.0 actually provides some parameters
@interface C14N20Transform : AQXMLTransform
@property (nonatomic, strong) AQXMLElement * methodElement;
@end
