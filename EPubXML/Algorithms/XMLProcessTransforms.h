//
//  XMLProcessTransforms.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-20.
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
