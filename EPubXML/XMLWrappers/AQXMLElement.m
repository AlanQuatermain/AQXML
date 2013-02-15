//
//  AQXMLElement.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLElement.h"
#import "AQXMLAttribute.h"
#import "AQXMLNamespace.h"
#import "AQXMLUtilities.h"
#import "AQXML_Private.h"
#import "AQXMLNodeSet.h"

#import <libxml/tree.h>
#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>

@implementation AQXMLElement
{
    dispatch_semaphore_t    _enumerationSemaphore;
}

+ (AQXMLElement *) elementWithName: (NSString *) name
                           content: (NSString *) content
                       inNamespace: (AQXMLNamespace *) namespaceOrNil
{
    xmlNodePtr newNode = xmlNewNode(namespaceOrNil.xmlObj, [name xmlString]);
    if ( newNode == NULL )
        return ( nil );
    if ( content != nil )
        xmlNodeSetContent(newNode, [content xmlString]);
    return ( [[self alloc] initWithXMLNode: newNode] );
}

+ (AQXMLElement *) elementWithXMLNode: (xmlNodePtr) node
{
    NSParameterAssert(node->type == XML_ELEMENT_NODE);
    return ( [[self alloc] initWithXMLNode: node] );
}

- (id) initWithXMLNode: (xmlNodePtr) node
{
    NSParameterAssert(node != NULL && node->type == XML_ELEMENT_NODE);
    if ( node == NULL || node->type != XML_ELEMENT_NODE )
        return ( nil );
    
    self = [super initWithXMLNode: node];
    if ( self == nil )
        return ( nil );
    
    _enumerationSemaphore = dispatch_semaphore_create(1);
    
    return ( self );
}

- (NSString *) namespacePrefix
{
    if ( self.xmlObj->ns == NULL )
        return ( nil );
    
    return ( [NSString stringWithXMLString: self.xmlObj->ns->prefix] );
}

- (NSUInteger) childCount
{
    dispatch_semaphore_wait(_enumerationSemaphore, DISPATCH_TIME_FOREVER);
    
    NSUInteger count = 0;
    xmlNodePtr child = self.xmlObj->children;
    while ( child != NULL )
    {
        count++;
        child = child->next;
    }
    
    dispatch_semaphore_signal(_enumerationSemaphore);
    
    return ( count );
}

- (NSArray *) children
{
    NSMutableArray * children = [NSMutableArray new];
    
    dispatch_semaphore_wait(_enumerationSemaphore, DISPATCH_TIME_FOREVER);
    
    xmlNodePtr child = self.xmlObj->children;
    while ( child != NULL )
    {
        if ( child->_private != NULL )
        {
            [children addObject: (__bridge id)child->_private];
        }
        else
        {
            AQXMLNode * node = [AQXMLNode nodeWithXMLNode: child];
            [children addObject: node];
        }
        
        child = child->next;
    }
    
    dispatch_semaphore_signal(_enumerationSemaphore);
    
    return ( children );
}

- (NSArray *) descendants
{
    NSMutableArray * descendants = [NSMutableArray new];
    
    [self enumerateChildrenUsingBlock: ^(AQXMLNode *child, NSUInteger idx, BOOL *stop) {
        [descendants addObject: child];
        
        if ( child.isElementNode )
            [descendants addObjectsFromArray: [(AQXMLElement *)child descendants]];
    }];
    
    return ( descendants );
}

- (void) enumerateChildrenUsingBlock: (void (^)(AQXMLNode * child, NSUInteger idx, BOOL *stop)) block
{
    [self enumerateChildrenWithOptions: 0 usingBlock: block];
}

- (void) enumerateChildrenWithOptions: (NSEnumerationOptions) options
                           usingBlock: (void (^)(AQXMLNode * child, NSUInteger idx, BOOL *stop)) block
{
    dispatch_semaphore_wait(_enumerationSemaphore, DISPATCH_TIME_FOREVER);
    
    xmlNodePtr childNode = self.xmlObj->children;
    __block BOOL stop = NO;
    NSUInteger idx = 1;
    
    void (^perChild)(xmlNodePtr, NSUInteger, BOOL*) = ^(xmlNodePtr child, NSUInteger i, BOOL *stop){
        AQXMLNode * node = nil;
        if ( child->_private != NULL )
            node = (__bridge AQXMLNode *)child->_private;
        else
            node = [AQXMLNode nodeWithXMLNode: child];
        
        block(node, i, stop);
    };
    
    if ( options == 0 )
    {
        while ( childNode != NULL && stop == NO )
        {
            perChild(childNode, idx++, &stop);
            childNode = childNode->next;
        }
        
        dispatch_semaphore_signal(_enumerationSemaphore);
        
        return;
    }
    
    NSUInteger count = self.childCount;
    xmlNodePtr *childList = malloc(count * sizeof(xmlNodePtr));
    idx = 0;
    while ( childNode != NULL )
    {
        childList[idx++] = childNode;
        childNode = childNode->next;
    }
    
    dispatch_semaphore_signal(_enumerationSemaphore);
    
    if ( options & NSEnumerationConcurrent )
    {
        // TODO: determine optimal stride
#define STRIDE 1
        dispatch_apply(count / STRIDE, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
            if ( stop )
                return;
            
            if ( options & NSEnumerationReverse )
                i = (count-1) - i;
            
            for ( int j = 0; j < STRIDE; j++ )
            {
                perChild(childList[i], i+1, &stop);
                if ( stop )
                    return;
                
                if ( options & NSEnumerationReverse )
                {
                    if ( i-- == 0 )
                        return;
                }
                else if ( ++i == count )
                {
                    return;
                }
            }
        });
    }
    else    // by elimination NSEnumerationReverse must be set
    {
        for ( NSUInteger i = 0; i < count; i++ )
        {
            NSUInteger j = (count-1) - i;
            perChild(childList[j], j+1, &stop);
        }
    }
    
    free(childList);
}

- (AQXMLNode *) firstChild
{
    xmlNodePtr n = self.xmlObj->children;
    if ( n == NULL )
        return ( nil );
    
    if ( n->_private != NULL )
        return ( (__bridge AQXMLNode *)n->_private );
    
    return ( [AQXMLNode nodeWithXMLNode: n] );
}

- (AQXMLNode *) lastChild
{
    xmlNodePtr n = xmlGetLastChild(self.xmlObj);
    if ( n == NULL )
        return ( nil );
    
    if ( n->_private != NULL )
        return ( (__bridge AQXMLNode *)n->_private );
    
    return ( [AQXMLNode nodeWithXMLNode: n] );
}

- (AQXMLNode *) childAtIndex: (NSUInteger) idx
{
    xmlNodePtr child = self.xmlObj->children;
    if ( child == NULL )
    {
        [NSException raise: NSRangeException format: @"-[%@ %@]: Index %lu outside range {1,0}", NSStringFromClass([self class]), NSStringFromSelector(_cmd), (unsigned long)idx];
    }
    
    NSUInteger curIdx = 1;
    while ( curIdx < idx && child != NULL )
    {
        child = child->next;
        curIdx++;
    }
    
    if ( curIdx < idx || child == NULL )
    {
        [NSException raise: NSRangeException format: @"-[%@ %@]: Index %lu outside range {1,%lu}", NSStringFromClass([self class]), NSStringFromSelector(_cmd), (unsigned long)idx, (unsigned long)curIdx-1];
    }
    
    if ( child->_private != NULL )
        return ( (__bridge AQXMLNode *)child->_private );
    
    return ( [AQXMLNode nodeWithXMLNode: child] );
}

- (NSString *) qualifiedName
{
    if ( self.namespacePrefix == nil )
        return ( self.name );
    
    return ( [NSString stringWithFormat: @"%@:%@", self.namespacePrefix, self.name] );
}

- (NSDictionary *) attributes
{
    NSMutableDictionary * attrs = [NSMutableDictionary new];
    xmlAttrPtr attr = self.xmlObj->properties;
    while ( attr != NULL )
    {
        NSString * key = [NSString stringWithXMLString: attr->name];
        xmlChar * attValue = xmlGetProp(self.xmlObj, attr->name);
        if ( attValue != NULL )
        {
            attrs[key] = [NSString stringWithXMLString: attValue];
            xmlFree(attValue);
        }
        
        attr = attr->next;
    }
    
    return ( attrs );
}

- (NSString *) attributesString
{
    NSMutableArray * attrList = [NSMutableArray new];
    xmlAttrPtr attr = self.xmlObj->properties;
    while ( attr != NULL )
    {
        NSString * key = [NSString stringWithXMLString: attr->name];
        xmlChar * val = xmlGetProp(self.xmlObj, attr->name);
        if ( val != NULL )
        {
            [attrList addObject: [NSString stringWithFormat: @"%@=\"%@\"", key, [NSString stringWithXMLString: val]]];
            xmlFree(val);
        }
        
        attr = attr->next;
    }
    
    return ( [attrList componentsJoinedByString: @" "] );
}

- (AQXMLElement *) firstChildNamed: (NSString *) matchName
{
    NSString * prefix = nil;
    NSString * local = matchName;
    
    NSRange r = [matchName rangeOfString: @":"];
    if ( r.location != NSNotFound )
    {
        prefix = [matchName substringToIndex: r.location];
        local = [matchName substringFromIndex: NSMaxRange(r)];
    }
    
    xmlNodePtr xml = self.xmlObj->children;
    while ( xml != NULL )
    {
        if ( xml->type == XML_ELEMENT_NODE )
        {
            if ( xmlStrEqual([local xmlString], xml->name) )
            {
                if ( prefix == nil )
                {
                    return ( (__bridge AQXMLElement *)xml->_private );
                }
                else if ( xml->ns != NULL  && xmlStrEqual([prefix xmlString], xml->ns->prefix) )
                {
                    return ( (__bridge AQXMLElement *)xml->_private );
                }
            }
        }
        
        xml = xml->next;
    }
    
    return ( nil );
}

- (AQXMLElement *) firstDescendantNamed: (NSString *) matchName
{
    __block AQXMLElement * element = [self firstChildNamed: matchName];
    if ( element != nil )
        return ( element );
    
    [self enumerateChildrenUsingBlock: ^(AQXMLNode *child, NSUInteger idx, BOOL *stop) {
        if ( child.type != AQXMLNodeTypeElement )
            return;
        AQXMLElement * childElem = (AQXMLElement *)child;
        element = [childElem firstDescendantNamed: matchName];
        if ( element != nil )
            *stop = YES;
    }];
    
    return ( element );
}

- (NSArray *) childrenNamed: (NSString *) matchName
{
    BOOL qualified = [matchName rangeOfString: @":"].location != NSNotFound;
    
    NSMutableArray * children = [NSMutableArray new];
    [self enumerateChildrenUsingBlock: ^(AQXMLNode *child, NSUInteger idx, BOOL *stop) {
        if ( child.type != AQXMLNodeTypeElement )
            return;
        AQXMLElement * element = (AQXMLElement *)child;
        BOOL matched = NO;
        if ( qualified )
            matched = [element.qualifiedName isEqualToString: matchName];
        else
            matched = [element.name isEqualToString: matchName];
        
        if ( matched )
            [children addObject: element];
    }];
    
    return ( children );
}

- (NSArray *) descendantsNamed: (NSString *) matchName
{
    BOOL qualified = [matchName rangeOfString: @":"].location != NSNotFound;
    
    NSMutableArray * descendants = [NSMutableArray new];
    [self enumerateChildrenUsingBlock: ^(AQXMLNode *child, NSUInteger idx, BOOL *stop) {
        if ( child.type != AQXMLNodeTypeElement )
            return;
        AQXMLElement * element = (AQXMLElement *)child;
        BOOL matched = NO;
        if ( qualified )
            matched = [element.qualifiedName isEqualToString: matchName];
        else
            matched = [element.name isEqualToString: matchName];
        
        if ( matched )
            [descendants addObject: element];
        
        [descendants addObjectsFromArray: [element descendantsNamed: matchName]];
    }];
    
    return ( descendants );
}

- (NSArray *) elementsWithAttributeNamed: (NSString *) attributeName
{
    NSString * xpath = [NSString stringWithFormat: @"//*[@%@]", attributeName];
    return ( [self elementsForXPath: xpath prepareNamespaces: nil error: NULL] );
}

- (NSArray *) elementsWithAttributeNamed: (NSString *) attributeName attributeValue: (NSString *) attributeValue
{
    NSString * xpath = [NSString stringWithFormat: @"//*[@%@='%@']", attributeName, attributeValue];
    return ( [self elementsForXPath: xpath prepareNamespaces: nil error: NULL] );
}

- (NSArray *) elementsForXPath: (NSString *) XPath error: (NSError **) error
{
    return ( [self elementsForXPath: XPath prepareNamespaces: nil error: error] );
}

- (NSArray *) elementsForXPath: (NSString *) XPath
             prepareNamespaces: (NSArray *) elementNames
                         error: (NSError **) error
{
    AQXMLNodeSet * nodes = [self evaluateXPath: XPath prepareNamespaces: elementNames error: error];
    if ( [nodes isKindOfClass: [AQXMLNodeSet class]] == NO )
        return ( nil );
    
    NSMutableArray * elements = [NSMutableArray arrayWithCapacity: nodes.count];
    [nodes enumerateNodesUsingBlock: ^(AQXMLNode *node, BOOL *stop) {
        if ( node.type == AQXMLNodeTypeElement )
            [elements addObject: node];
    }];
    
    return ( elements );
}

- (AQXMLElement *) elementWithID: (NSString *) idValue
{
    NSString * xp = [NSString stringWithFormat: @"id('%@')", idValue];
    NSArray * list = [self elementsForXPath: xp error: NULL];
    if ( [list count] == 0 )
        return ( nil );
    
    return ( list[0] );
}

- (void) insertChild: (AQXMLNode *) node atIndex: (NSUInteger) index
{
    NSParameterAssert(index <= self.childCount && index > 0);
    AQXMLNode * cur = [self childAtIndex: index];
    [cur addNodeAsPreviousSibling: node];
}

- (AQXMLNode *) addChild: (AQXMLNode *) node
{
    [node detach];
    xmlNodePtr newNode = xmlAddChild(self.xmlObj, node.xmlObj);
    return ( (__bridge AQXMLNode *)newNode->_private );
}

- (AQXMLNode *) _addRawChild: (xmlNodePtr) rawNode
{
    NSParameterAssert(rawNode != NULL);
    xmlUnlinkNode(rawNode);
    xmlNodePtr newNode = xmlAddChild(self.xmlObj, rawNode);
    return ( [AQXMLNode nodeWithXMLNode: newNode] );
}

- (AQXMLNode *) addTextChild: (NSString *) text
{
    xmlNodePtr node = xmlNewText([text xmlString]);
    return ( [self _addRawChild: node] );
}

- (AQXMLNode *) addCDATAChild: (NSString *) cdata
{
    NSData * data = [cdata dataUsingEncoding: NSUTF8StringEncoding];
    xmlNodePtr newNode = xmlNewCDataBlock(self.xmlObj->doc, (const xmlChar *)[data bytes], (int)[data length]);
    return ( [self _addRawChild: newNode] );
}

- (AQXMLElement *) addChildNamed: (NSString *) childName
{
    xmlNodePtr node = xmlNewChild(self.xmlObj, NULL, [childName xmlString], NULL);
    return ( (AQXMLElement *)[self _addRawChild: node] );
}

- (AQXMLElement *) addChildNamed: (NSString *) childName
                 withTextContent: (NSString *) nodeContent
{
    xmlNodePtr node = xmlNewTextChild(self.xmlObj, NULL, [childName xmlString], [nodeContent xmlString]);
    return ( (AQXMLElement *)[self _addRawChild: node] );
}

- (AQXMLElement *) addChildNamed: (NSString *) childName
                withCDATAContent: (NSString *) cdataContent
{
    AQXMLElement * element = [self addChildNamed: childName];
    [element addCDATAChild: cdataContent];
    return ( element );
}

- (void) consolidateConsecutiveTextNodes
{
    xmlNodePtr prior = NULL, child = self.xmlObj->children;
    while ( child != NULL )
    {
        // pre-fetch the next node, because the current one may be removed
        xmlNodePtr next = child->next;
        
        if ( child->type == XML_TEXT_NODE )
        {
            if ( prior != NULL && prior->type == XML_TEXT_NODE )
            {
                // merge current into prior
                // ideally we'd use xmlTextMerge(), but since that might delete an
                //  xmlNodePtr out from underneath an ObjC object, we inline it
                xmlNodeAddContent(prior, child->content);
                if ( child->_private != NULL )
                {
                    AQXMLNode * dead = (__bridge AQXMLNode *)child->_private;
                    [dead detach];
                    // leave the xmlNodePtr around, it'll be deleted when the wrapper deallocates
                }
                else
                {
                    // no wrapper == unlink & delete
                    xmlUnlinkNode(child);
                    xmlFreeNode(child);
                }
            }
            else
            {
                // store this as the preceding text node
                prior = child;
            }
        }
        else
        {
            prior = NULL;
        }
        
        child = next;
    }
}

- (xmlAttrPtr) _rawAttributeNamed: (NSString *) name
{
    return ( xmlHasProp(self.xmlObj, [name xmlString]) );
}

- (AQXMLAttribute *) attributeNamed: (NSString *) name
{
    NSParameterAssert(name != nil);
    xmlAttrPtr attr = [self _rawAttributeNamed: name];
    if ( attr == NULL )
        return ( nil );
    
    if ( attr->_private != NULL )
        return ( (__bridge AQXMLAttribute *)attr->_private );
    
    return ( [AQXMLAttribute attributeWithXMLNode: attr] );
}

- (AQXMLAttribute *) addAttributeNamed: (NSString *) attributeName withValue: (NSString *) attributeValue
{
    xmlAttrPtr newAttr = xmlNewProp(self.xmlObj, [attributeName xmlString], [attributeValue xmlString]);
    if ( newAttr == NULL )
        return ( nil );
    return ( [AQXMLAttribute attributeWithXMLNode: newAttr] );
}

- (void) deleteAttributeNamed: (NSString *) attributeName
{
    xmlAttrPtr attr = [self _rawAttributeNamed: attributeName];
    if ( attr != NULL )
        xmlRemoveProp(attr);
}

- (void) removeAllAttributes
{
    for ( NSString * name in self.attributeKeys )
    {
        [self deleteAttributeNamed: name];
    }
}

- (void) addAttributes: (NSDictionary *) attributes
{
    [attributes enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        [self addAttributeNamed: key withValue: obj];
    }];
}

@end
