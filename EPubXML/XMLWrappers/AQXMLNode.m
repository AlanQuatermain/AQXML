//
//  AQXMLNode.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-06.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLNode.h"
#import "AQXMLElement.h"
#import "AQXMLAttribute.h"
#import "AQXMLDTDNode.h"
#import "AQXMLXPath.h"
#import "AQXMLUtilities.h"
#import "AQXML_Private.h"
#import <libxml/xmlmemory.h>
#import <libxml/tree.h>
#import <libxml/xmlsave.h>

@implementation AQXMLNode
{
    xmlNodePtr  _node;
}

+ (AQXMLNode *) nodeWithString: (NSString *) string
{
    xmlNodePtr newNode = xmlNewText([string xmlString]);
    if ( newNode == NULL )
        return ( nil );
    return ( [[self alloc] initWithXMLNode: newNode] );
}

+ (AQXMLNode *) nodeWithName: (NSString *) name
                        type: (AQXMLNodeType) type
                     content: (NSString *) content
                 inNamespace: (AQXMLNamespace *) namespaceOrNil
{
    xmlNodePtr newNode = NULL;
    switch ( type )
    {
        case AQXMLNodeTypeElement:
            return ( [AQXMLElement elementWithName: name content: content inNamespace: namespaceOrNil] );
            break;
            
        case AQXMLNodeTypeText:
            return ( [self nodeWithString: content] );
            break;
            
        case AQXMLNodeTypeAttribute:
            break;
            
        case AQXMLNodeTypeCDATASection:
        case AQXMLNodeTypeDOCBDocument:
        case AQXMLNodeTypeDocument:
        case AQXMLNodeTypeDocumentFragment:
        case AQXMLNodeTypeDTD:
        case AQXMLNodeTypeHTMLDocument:
            // we need the document to construct these
            break;
            
            
        case AQXMLNodeTypeComment:
            newNode = xmlNewComment([content xmlString]);
            break;
            
        case AQXMLNodeTypeProcessingInstruction:
            newNode = xmlNewPI([name xmlString], [content xmlString]);
            break;
            
        default:
            newNode = xmlNewNode(namespaceOrNil.xmlObj, [name xmlString]);
            break;
    }
    
    if ( newNode == NULL )
        return ( nil );
    
    return ( [[self alloc] initWithXMLNode: newNode] );
}

+ (AQXMLNode *) nodeWithXMLNode: (xmlNodePtr) node
{
    switch ( node->type )
    {
        case XML_ELEMENT_NODE:
            return ( [AQXMLElement elementWithXMLNode: node] );
            
        case XML_ATTRIBUTE_NODE:
            return ( [AQXMLAttribute attributeWithXMLNode: (xmlAttrPtr)node] );
            
        case XML_DOCUMENT_NODE:
        case XML_HTML_DOCUMENT_NODE:
        case XML_DOCB_DOCUMENT_NODE:
            return ( [AQXMLDocument documentWithXMLDocument: (xmlDocPtr)node] );
            
        case XML_DTD_NODE:
            return ( [AQXMLDTDNode DTDNodeWithXMLDTD: (xmlDtdPtr)node] );
            
        default:
            break;
    }
    
    return ( [[self alloc] initWithXMLNode: node] );
}

- (id) initWithXMLNode: (xmlNodePtr) node
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _node = node;
    if ( node->_private == NULL )
        node->_private = (void *)CFBridgingRetain(self);
    
    return ( self );
}

- (void) dealloc
{
    if ( _valid == NO )
        return;
    
    _node->_private = NULL;
    
    // only free if it's not linked to any other nodes
    if ( _node->parent == NULL && _node->next == NULL && _node->prev == NULL )
        xmlFreeNode(_node);
}

- (void) invalidate
{
    [super invalidate];
    _node = NULL;
}

- (id) copyWithZone: (NSZone *) zone
{
    if ( _valid == NO )
        return ( nil );
    
    xmlNodePtr copyNode = xmlCopyNode(_node, 1);
    // the corresponding ObjC class is created by the node registration callback
    return ( (__bridge AQXMLNode *)copyNode->_private );
}

- (xmlNodePtr) xmlObj
{
    return ( _node );
}

- (NSString *) name
{
    if ( _node->name == NULL )
        return ( nil );
    
    return ( [NSString stringWithXMLString: _node->name] );
}

- (void) setName: (NSString *) name
{
    xmlNodeSetName(_node, [name xmlString]);
}

- (NSString *) content
{
    if ( _node->content == NULL )
        return ( nil );
    
    return ( [NSString stringWithXMLString: _node->content] );
}

- (void) setContent: (NSString *) content
{
    xmlNodeSetContent(_node, [content xmlString]);
}

- (NSString *) language
{
    xmlChar * ch = xmlNodeGetLang(_node);
    if ( ch == NULL )
        return ( nil );
    
    return ( [NSString stringWithXMLString: ch] );
}

- (void) setLanguage: (NSString *) language
{
    xmlNodeSetLang(_node, [language xmlString]);
}

- (BOOL) preserveSpace
{
    return ( xmlNodeGetSpacePreserve(_node) == 1 );
}

- (void) setPreserveSpace: (BOOL) preserveSpace
{
    xmlNodeSetSpacePreserve(_node, (int)preserveSpace);
}

- (NSURL *) baseURL
{
    xmlChar * ch = xmlNodeGetBase(_node->doc, _node);
    if ( ch == NULL )
        return ( nil );
    
    return ( [NSURL URLWithString: [NSString stringWithXMLString: ch]] );
}

- (void) setBaseURL: (NSURL *) baseURL
{
    xmlNodeSetBase(_node, [[baseURL relativeString] xmlString]);
}

- (AQXMLNamespace *) ns
{
    if ( self.valid == NO )
        return ( nil );
    switch ( _node->type )
    {
        case XML_DOCUMENT_NODE:
        case XML_DOCUMENT_TYPE_NODE:
        case XML_DOCUMENT_FRAG_NODE:
        case XML_DTD_NODE:
        case XML_CDATA_SECTION_NODE:
        case XML_DOCB_DOCUMENT_NODE:
        case XML_HTML_DOCUMENT_NODE:
        case XML_PI_NODE:
            return ( nil );
            
        default:
            break;
    }
    
    if ( _node->ns == NULL )
        return ( nil );
    if ( _node->ns->_private != NULL )
        return ( (__bridge AQXMLNamespace *)self.xmlObj->ns->_private );
    
    return ( [AQXMLNamespace namespaceWithXMLNamespace: self.xmlObj->ns] );
}

- (void) setNs: (AQXMLNamespace *) ns
{
    xmlSetNs(_node, ns.xmlObj);
}

- (NSArray *) namespacesInScope
{
    xmlNsPtr *pNamespaces = xmlGetNsList(self.document.xmlObj, self.xmlObj);
    if ( pNamespaces == NULL )
        return ( nil );
    
    NSMutableArray * result = [NSMutableArray new];
    for ( int i = 0; pNamespaces[i] != NULL; i++ )
    {
        [result addObject: (__bridge AQXMLNamespace *)pNamespaces[i]->_private];
    }
    
    xmlMemFree(pNamespaces);
    return ( result );
}

- (AQXMLNodeType) type
{
    return ( (AQXMLNodeType)_node->type );
}

- (BOOL) isTextNode
{
    return ( xmlNodeIsText(_node) );
}

- (BOOL) isElementNode
{
    return ( _node->type == XML_ELEMENT_NODE );
}

- (NSInteger) index
{
    NSInteger idx = 1;
    xmlNodePtr child = _node->parent->children;
    while ( child != NULL && child != _node )
    {
        idx++;
        child = child->next;
    }
    
    if ( child == NULL )
        return ( NSNotFound );
    return ( idx );
}


- (AQXMLElement *) parent
{
    xmlNodePtr xmlParent = _node->parent;
    if ( xmlParent == NULL )
        return ( nil );
    
    if ( xmlParent->_private != nil )
        return ( (__bridge AQXMLElement *)xmlParent->_private );
    
    return ( [AQXMLElement elementWithXMLNode: xmlParent] );
}

- (AQXMLDocument *) document
{
    xmlDocPtr doc = _node->doc;
    if ( doc == NULL )
        return ( nil );
    return ( (__bridge AQXMLDocument *)doc->_private );
}

- (AQXMLNode *) nextNode
{
    AQXMLNode * next = [self nextSibling];
    if ( next == nil )
        next = self.parent.nextNode;
    return ( next );
}

- (AQXMLNode *) nextSibling
{
    xmlNodePtr next = _node->next;
    if ( next == NULL )
        return ( nil );
    
    if ( next->_private != NULL )
        return ( (__bridge AQXMLNode *)next->_private );
    
    return ( [AQXMLNode nodeWithXMLNode: next] );
}

- (AQXMLNode *) previousNode
{
    AQXMLNode * previous = [self previousSibling];
    if ( previous == nil )
        previous = self.parent;
    
    return ( previous );
}

- (AQXMLNode *) previousSibling
{
    xmlNodePtr previous = _node->prev;
    if ( previous == NULL )
        return ( nil );
    
    if ( previous->_private != NULL )
        return ( (__bridge AQXMLNode *)previous->_private );
    
    return ( [AQXMLNode nodeWithXMLNode: previous] );
}

- (AQXMLElement *) rootElement
{
    return ( self.document.rootElement );
}

- (NSString *) XMLString
{
    // render as an XML document fragment
    xmlBufferPtr buf = xmlBufferCreate();
    xmlNodeDump(buf, _node->doc, _node, 0, 0);
    
    NSString * result = [NSString stringWithXMLString: xmlBufferContent(buf)];
    xmlBufferFree(buf);
    
    return ( result );
}

- (NSString *) description
{
    return ( [NSString stringWithFormat: @"%@: xml=%@", [super description], self.XMLString] );
}

- (NSString *) stringValue
{
    xmlChar * content = xmlNodeGetContent(_node);
    if ( content == NULL )
        return ( nil );
    
    return ( [NSString stringWithXMLString: content] );
}

- (NSInteger) integerValue
{
    return ( [self.stringValue integerValue] );
}

- (double) doubleValue
{
    return ( [self.stringValue integerValue] );
}

- (BOOL) boolValue
{
    return ( [self.stringValue boolValue] );
}

- (NSDate *) dateValue
{
    static NSDateFormatter * XMLDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        XMLDateFormatter = [NSDateFormatter new];
        [XMLDateFormatter setDateFormat: @"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    });
    
    return ( [XMLDateFormatter dateFromString: self.stringValue] );
}

- (void) detach
{
    xmlUnlinkNode(_node);
}

- (void) addSiblingNode: (AQXMLNode *) sibling
{
    xmlAddSibling(_node, sibling.xmlObj);
}

- (BOOL) mergeWithTextNode: (AQXMLNode *) node error: (NSError **) error
{
    return ( xmlTextMerge(_node, node.xmlObj) != NULL );
}

- (BOOL) concatenateText: (NSString *) text error: (NSError **) error
{
    return ( xmlTextConcat(_node, [text xmlString], xmlStrlen([text xmlString])) );
}

- (void) addNodeAsNextSibling: (AQXMLNode *) node
{
    xmlAddNextSibling(_node, node.xmlObj);
}

- (void) addNodeAsPreviousSibling: (AQXMLNode *) node
{
    xmlAddPrevSibling(_node, node.xmlObj);
}

- (id) evaluateXPath: (NSString *) XPath error: (NSError **) error
{
    return ( [self evaluateXPath: XPath prepareNamespaces: nil error: error] );
}

- (id) evaluateXPath: (NSString *) XPath
   prepareNamespaces: (NSArray *) elementNames
               error: (NSError **) error
{
    AQXMLXPath * xPath = [[AQXMLXPath alloc] initWithString: XPath document: self.document];
    if ( xPath == nil )
        return ( nil );
    
    if ( elementNames != nil )
    {
        for ( NSString * name in elementNames )
        {
            NSRange r = [name rangeOfString: @":"];
            if ( r.location == NSNotFound )
                continue;
            
            NSString * prefix = [name substringToIndex: r.location];
            
            // When performing a query for a qualified element name such as geo:lat, libxml
			// requires you to register the namespace. We do so here and pass an empty string
			// as the URL that defines the namespace prefix because there's no way to know
			// what it is given the current API.
            [xPath registerNamespacePrefix: prefix withURI: @""];
        }
    }
    
    return ( [xPath evaluateOnNode: self error: error] );
}

@end
