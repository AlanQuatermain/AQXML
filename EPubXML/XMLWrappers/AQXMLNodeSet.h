//
//  AQXMLNodeSet.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-18.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLObject.h"

@class AQXMLNode, AQXMLElement, AXMLNamespace;

@interface AQXMLNodeSet : AQXMLObject <NSCopying>

// returns a new, empty node set
+ (AQXMLNodeSet *) nodeSet;
+ (AQXMLNodeSet *) nodeSetWithNode: (AQXMLNode *) node;
+ (AQXMLNodeSet *) nodeSetWithTreeAtElement: (AQXMLElement *) element;

- (id) initWithNode: (AQXMLNode *) node;

@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSArray * nodes;

- (AQXMLNode *) nodeAtIndex: (NSUInteger) idx;
- (AQXMLNode *) objectAtIndexedSubscript: (NSUInteger) idx;

- (BOOL) boolValue;
- (NSNumber *) numberValue;
- (NSString *) stringValue;

- (void) expandSubtree;
- (void) sort;      // places nodes in document order
- (AQXMLNodeSet *) sortedNodeSet;       // copies receiver & sorts it

- (void) addNode: (AQXMLNode *) node;
- (void) removeNode: (AQXMLNode *) node;
- (BOOL) containsNode: (AQXMLNode *) node;

- (void) addUniqueNode: (AQXMLNode *) node;
- (void) unionSet: (AQXMLNodeSet *) set;
- (void) intersectSet: (AQXMLNodeSet *) set;
- (void) subtractSet: (AQXMLNodeSet *) set;

#if NS_BLOCKS_AVAILABLE
- (void) enumerateNodesUsingBlock: (void (^)(AQXMLNode * node, BOOL *stop)) block;
#endif

@end
