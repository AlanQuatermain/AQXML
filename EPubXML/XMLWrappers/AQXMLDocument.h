//
//  AQXMLDocument.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AQXMLNode.h"
#import "AQXMLElement.h"
#import "AQXMLDTDNode.h"
#import "AQXMLAttribute.h"
#import "AQXMLCanonicalizer.h"
#import <libxml/xmlmemory.h>

// Based on Apple's XMLDocument sample code

@interface AQXMLDocument : AQXMLNode

@property (nonatomic, readwrite, strong) AQXMLElement *rootElement;
@property (nonatomic, readonly) NSArray * namespaces;

+ (AQXMLDocument *) documentWithXMLData: (NSData *) data error: (NSError **) error;
+ (AQXMLDocument *) documentWithXMLString: (NSString *) string error: (NSError **) error;
+ (AQXMLDocument *) documentWithContentsOfURL: (NSURL *) url error: (NSError **) error;

+ (AQXMLDocument *) emptyDocument;
+ (AQXMLDocument *) documentWithRootElement: (AQXMLElement *) root;

- (NSString *) canonicalizedStringUsingMethod: (AQXMLCanonicalizationMethod) method;
- (NSData *) canonicalizedDataUsingMethod: (AQXMLCanonicalizationMethod) method
                             usedEncoding: (NSStringEncoding *) usedEncoding;

- (NSString *) canonicalizedStringForElement: (AQXMLElement *) element
                                 usingMethod: (AQXMLCanonicalizationMethod) method;
- (NSData *) canonicalizedDataForElement: (AQXMLElement *) element
                             usingMethod: (AQXMLCanonicalizationMethod) method
                            usedEncoding: (NSStringEncoding *) usedEncoding;

- (AQXMLDTDNode *) createDTDWithName: (NSString *) name
                          externalID: (NSString *) externalID
                            systemID: (NSString *) systemID;

- (AQXMLDTDNode *) createInternalSubsetWithName: (NSString *) name
                                     externalID: (NSString *) externalID
                                       systemID: (NSString *) systemID;

- (AQXMLAttribute *) addAttributeWithName: (NSString *) name
                                    value: (NSString *) value;
- (AQXMLAttribute *) attributeWithName: (NSString *) name;
- (void) removeAttribute: (NSString *) name;

@end
