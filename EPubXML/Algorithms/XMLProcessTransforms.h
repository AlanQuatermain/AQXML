//
//  XMLProcessTransforms.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-20.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLTransform.h"

@class AQXMLElement;

@interface XMLNodeTransform : AQXMLTransform
// contents of this node are read to get any XPath/XSLT/filter details, and this node's XPath is used for the here() function, if any
@property (nonatomic, strong) AQXMLElement * node;
@end

@interface XPathTransform : XMLNodeTransform
@end

@interface XPathFilter2Transform : XMLNodeTransform
@end

@interface EnvelopedSignatureTransform : XMLNodeTransform
@end

@interface XSLTTransform : XMLNodeTransform
@end

// this one overrides -process to load its own input property based on its node
@interface DSIG2SelectionTransform : XMLNodeTransform
@end

@interface XMLSelectionTransform : DSIG2SelectionTransform
@end

@interface BinarySelectionTransform : DSIG2SelectionTransform
@end

@interface BinaryFromXMLSelectionTransform : DSIG2SelectionTransform
@end
