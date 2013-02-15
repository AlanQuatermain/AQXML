//
//  xml_glue.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-18.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXML_Private.h"
#import <libxml/globals.h>

static xmlRegisterNodeFunc defNodeRegister = NULL;
static xmlRegisterNodeFunc defThrNodeRegister = NULL;
static xmlDeregisterNodeFunc defNodeDeregister = NULL;
static xmlDeregisterNodeFunc defThrNodeDeregister = NULL;

static void __registerNode(xmlNodePtr aNode)
{
    id obj = nil;
    switch ( aNode->type )
    {
        case XML_DOCUMENT_NODE:
        case XML_DOCUMENT_FRAG_NODE:
        case XML_HTML_DOCUMENT_NODE:
        case XML_DOCB_DOCUMENT_NODE:
            obj = [AQXMLDocument documentWithXMLDocument: (xmlDocPtr)aNode];
            break;
            
        case XML_DTD_NODE:
            obj = [AQXMLDTDNode DTDNodeWithXMLDTD: (xmlDtdPtr)aNode];
            break;
            
        case XML_NAMESPACE_DECL:
            obj = [AQXMLNamespace namespaceWithXMLNamespace: (xmlNsPtr)aNode];
            break;
            
        case XML_ATTRIBUTE_NODE:
            obj = [AQXMLAttribute attributeWithXMLNode: (xmlAttrPtr)aNode];
            break;
            
        default:
            obj = [AQXMLNode nodeWithXMLNode: aNode];
            break;
    }
    
    aNode->_private = (void *)CFBridgingRetain(obj);
}

static void __deregisterNode(xmlNodePtr aNode)
{
    if ( aNode->_private == NULL )
        return;
    
    AQXMLObject * obj = CFBridgingRelease(aNode->_private);
    [obj invalidate];
}

__attribute__((constructor))
static void __setupLibXML(void)
{
    xmlInitGlobals();
    defNodeRegister = xmlRegisterNodeDefault(&__registerNode);
    defThrNodeRegister = xmlThrDefRegisterNodeDefault(&__registerNode);
    defNodeDeregister = xmlDeregisterNodeDefault(&__deregisterNode);
    defThrNodeDeregister = xmlThrDefDeregisterNodeDefault(&__deregisterNode);
    
    xmlSubstituteEntitiesDefault(1);
    xmlLoadExtDtdDefaultValue = 1;
}

__attribute__((destructor))
static void __resetLibXMLOverrides(void)
{
    xmlRegisterNodeDefault(defNodeRegister);
    xmlThrDefRegisterNodeDefault(defThrNodeRegister);
    xmlDeregisterNodeDefault(defNodeDeregister);
    xmlThrDefDeregisterNodeDefault(defThrNodeDeregister);
}
