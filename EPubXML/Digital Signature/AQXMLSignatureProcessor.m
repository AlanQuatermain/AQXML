//
//  AQXMLSignatureProcessor.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-28.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLSignatureProcessor.h"
#import "DigestTransforms.h"
#import "C14NTransforms.h"
#import "AQXMLSignatureAlgorithm.h"
#import "AQXMLDocument.h"
#import "AQXMLElement.h"
#import "AQXMLNamespace.h"
#import "AQXMLNodeSet.h"
#import "Base64Transform.h"
#import "KeyBuilders.h"
#import "AQXMLXPath.h"

static NSString * const AQXMLDSig10NamespaceURI = @"http://www.w3.org/2000/09/xmldsig#";
static NSString * const AQXMLDSig11NamespaceURI = @"http://www.w3.org/2009/xmldsig11#";
static NSString * const AQXMLDSig20NamespaceURI = @"http://www.w3.org/2010/xmldsig2#";
static NSString * const AQXMLC14N2NamespaceURI = @"http://www.w3.org/2010/xml-c14n2";

#define B64_CHILD(elem, name) [Base64Transform decode: [[elem firstChildNamed: name].stringValue dataUsingEncoding: NSUTF8StringEncoding]]
#define _SEC(x) ((__bridge id)x)

NSString * TransformURIFromCanonicalizationMethod( AQXMLCanonicalizationMethod method )
{
    NSString * base = nil;
    switch ( method & ~AQXMLCanonicalizationMethod_with_comments )
    {
        case AQXMLCanonicalizationMethod_1_0:
            base = @"http://www.w3.org/TR/2001/REC-xml-c14n-20010315";
        case AQXMLCanonicalizationMethod_1_1:
            base = @"http://www.w3.org/2006/12/xml-c14n11";
        case AQXMLCanonicalizationMethod_exclusive_1_0:
            base = @"http://www.w3.org/2001/10/xml-exc-c14n#";
        case AQXMLCanonicalizationMethod_2_0:
            base = @"http://www.w3.org/2010/xml-c14n2";
        default:
            return ( nil );
    }
    
    if ( (method & AQXMLCanonicalizationMethod_with_comments) != 0 )
    {
        if ( [base hasSuffix: @"#"] )
            return ( [base stringByAppendingString: @"WithComments"] );
        
        return ( [base stringByAppendingString: @"#WithComments"] );
    }
    
    return ( base );
}

NSString * TransformURIForDigestAlgorithm(AQDigestAlgorithm alg)
{
    switch ( alg )
    {
        case AQDigestAlgorithmSHA1:
            return ( @"http://www.w3.org/2000/09/xmldsig#sha1" );
        case AQDigestAlgorithmSHA256:
            return ( @"http://www.w3.org/2001/04/xmlenc#sha256" );
        case AQDigestAlgorithmSHA384:
            return ( @"http://www.w3.org/2001/04/xmldsig-more#sha384" );
        case AQDigestAlgorithmSHA512:
            return ( @"http://www.w3.org/2001/04/xmlenc#sha512" );
        default:
            break;
    }
    
    return ( nil );
}

static AQXMLNodeSet * NodeSetFromXPointer(AQXMLElement * origin, NSString * xpointer)
{
    AQXMLXPath * xPath = [AQXMLXPath XPathWithString: xpointer
                                            document: origin.document];
    [xPath registerNamespaces: origin.namespacesInScope];
    [xPath registerNamespacesApplicableToElement: origin];
    
    AQXMLNodeSet * nodes = [xPath evaluateOnNode: origin error: NULL];
    if ( [nodes isKindOfClass: [AQXMLNodeSet class]] == NO )
        return ( nil );
    
    return ( nodes );
}

static AQXMLElement * ElementAtURI(NSString * uri, AQXMLTransform * transform)
{
    NSURL * url = [NSURL URLWithString: uri];
    AQXMLDocument * doc = [AQXMLDocument documentWithContentsOfURL: url error: NULL];
    if ( doc == nil )
        return ( nil );
    
    AQXMLElement * element = doc.rootElement;
    if ( [url fragment] != nil )
    {
        NSString * fragment = [url fragment];
        if ( [fragment hasPrefix: @"xpointer("] )
        {
            AQXMLNodeSet * nodeSet = NodeSetFromXPointer(element, fragment);
            if ( nodeSet.count == 0 )
                return ( nil );
            
            [nodeSet expandSubtree];
            [nodeSet sort];
            NSData * data = [AQXMLCanonicalizer canonicalizeDocument: nodeSet[0].document usingMethod: AQXMLCanonicalizationMethod_1_0|AQXMLCanonicalizationMethod_with_comments visibilityFilter: ^BOOL(AQXMLNode *node) {
                return ( [nodeSet containsNode: node] );
            }];
            
            if ( [data length] == 0 )
                return ( nil );
            
            doc = [AQXMLDocument documentWithXMLData: data error: NULL];
            element = doc.rootElement;
            if ( element == nil )
                return ( nil );
        }
        else
        {
            element = [element elementWithID: [url fragment]];
        }
    }
    
    if ( transform != nil )
    {
        transform.input = element;
        id transformed = [transform process];
        
        if ( [transformed isKindOfClass: [NSData class]] )
        {
            doc = [AQXMLDocument documentWithXMLData: transformed error: NULL];
            return ( [doc.rootElement copy] );
        }
        else if ( [transformed isKindOfClass: [AQXMLDocument class]] )
        {
            return ( [doc.rootElement copy] );
        }
        else if ( [transformed isKindOfClass: [AQXMLNodeSet class]] )
        {
            AQXMLNodeSet * nodes = (AQXMLNodeSet *)transformed;
            if ( nodes.count == 0 )
                return ( nil );
            
            // use the canonicalizer
            NSData * data = [AQXMLCanonicalizer canonicalizeDocument: nodes[0].document usingMethod: AQXMLCanonicalizationMethod_1_0 visibilityFilter: ^BOOL(AQXMLNode *node) {
                return ( [nodes containsNode: node] );
            }];
            
            doc = [AQXMLDocument documentWithXMLData: data error: NULL];
            return ( doc.rootElement.copy );
        }
        else if ( [transformed isKindOfClass: [AQXMLElement class]] )
        {
            return ( [transformed copy] );
        }
    }
    
    return ( [element copy] );
}

@implementation AQXMLSignatureProcessor
{
    AQXMLDocument *     _document;
}

+ (BOOL) validateSignatureInDocument: (AQXMLDocument *) document
{
    // find the Signature element(s)
    NSArray * signatures = [document.rootElement descendantsNamed: @"Signature"];
    if ( [signatures count] == 0 )
        return ( NO );      // assuming validity is in doubt unless verified
    
    // assuming that v2.0 can validate anything
    AQXMLSignatureProcessor * proc = [[AQXMLSignatureProcessor alloc] initWithSignatureVersion: AQXMLSignatureVersion2_0];
    
    for ( AQXMLElement * signature in signatures )
    {
        if ( [proc validateSignature: signature inDocument: document] == NO )
            return ( NO );
    }
    
    return ( YES );
}

+ (AQXMLElement *) signatureForDocument: (AQXMLDocument *) document
                                version: (AQXMLSignatureVersion) version
                   usingDigestAlgorithm: (AQDigestAlgorithm) digestAlgorithm
                     signatureAlgorithm: (AQSignatureAlgorithm) signatureAlgorithm
                             signingKey: (SecKeyRef) signingKey
{
    AQXMLSignatureProcessor * proc = [[AQXMLSignatureProcessor alloc] initWithSignatureVersion: version];
    if ( proc == nil )
        return ( nil );
    
    if ( [proc setDigestAlgorithm: digestAlgorithm] == NO )
        return ( nil );
    if ( [proc setSignatureAlgorithm: signatureAlgorithm withKey: signingKey] == NO )
        return ( nil );
    
    proc.useEnvelopedSignatureTransform = YES;
    return ( [proc signatureElementForDocument: document] );
}

+ (AQXMLDocument *) signatureReferencingDataAtURLs: (NSArray *) URLs
                                           version: (AQXMLSignatureVersion) version
                              usingDigestAlgorithm: (AQDigestAlgorithm) digestAlgorithm
                                signatureAlgorithm: (AQSignatureAlgorithm) signatureAlgorithm
                                        signingKey: (SecKeyRef) signingKey
{
    AQXMLSignatureProcessor * proc = [[AQXMLSignatureProcessor alloc] initWithSignatureVersion: version];
    if ( proc == nil )
        return ( nil );
    
    if ( [proc setDigestAlgorithm: digestAlgorithm] == NO )
        return ( nil );
    if ( [proc setSignatureAlgorithm: signatureAlgorithm withKey: signingKey] == NO )
        return ( nil );
    
    for ( NSURL * url in URLs )
    {
        AQXMLElement * reference = [self referenceElementWithURL: url
                                                         version: version
                                                    digestMethod: digestAlgorithm];
        if ( reference == nil )
            return ( nil );
        
        [proc appendManifestReference: reference];
    }
    
    return ( [proc generateSignatureDocument] );
}

+ (AQXMLElement *) referenceElementWithURL: (NSURL *) url
                                   version: (AQXMLSignatureVersion) version
                              digestMethod: (AQDigestAlgorithm) digestAlgorithm
{
    NSData * data = [[NSData alloc] initWithContentsOfURL: url];
    if ( data == nil )
        return ( nil );
    
    NSMutableArray * transformURIs = [NSMutableArray new];
    
    // is it an XML document? If so, this canonicaiization will work:
    AQXMLCanonicalizationMethod canonMethod = AQXMLCanonicalizationMethod_1_1;
    if ( version == AQXMLSignatureVersion2_0 )
        canonMethod = AQXMLCanonicalizationMethod_2_0;
    canonMethod |= AQXMLCanonicalizationMethod_with_comments;
    
    NSData * canonicalized = [AQXMLCanonicalizer canonicalizeData: data usingMethod: canonMethod visibilityFilter: nil];
    if ( canonicalized != nil )
    {
        data = canonicalized;
        [transformURIs addObject: TransformURIFromCanonicalizationMethod(canonMethod)];
    }
    
    // digest it !
    NSString * digestTransformURI = TransformURIForDigestAlgorithm(digestAlgorithm);
    AQXMLTransform * tx = [AQXMLTransform transformForURI: digestTransformURI];
    if ( tx == nil )
        return ( nil );
    
    tx.input = data;
    NSData * digest = [tx process];
    if ( digest == nil )
        return ( nil );
    
    AQXMLElement * reference = [AQXMLElement elementWithName: @"Reference" content: nil inNamespace: nil];
    AQXMLNamespace * dsigNS = [AQXMLNamespace namespaceWithNode: reference URI: AQXMLDSig10NamespaceURI prefix: nil];
    reference.ns = dsigNS;
    
    AQXMLElement * transforms = [reference addChildNamed: @"Transforms"];
    
    for ( NSString * transformURI in transformURIs )
    {
        AQXMLElement * transform = [transforms addChildNamed: @"Transform"];
        
        // special-case for XML Canonicalization 2.0
        if ( [transformURI hasSuffix: @"xml-c14n2#WithComments"] )
        {
            // that's not a real transform URI-- remove the fragment and add sub-elements to specify comment preservation
            [transform addAttributeNamed: @"Algorithm" withValue: [transformURI substringToIndex: [transformURI length] - 13]];
            
            AQXMLNamespace * c14n2ns = [AQXMLNamespace namespaceWithNode: transform URI: AQXMLC14N2NamespaceURI prefix: @"c14n2"];
            transform.ns = c14n2ns;
            
            [transform addChild: [AQXMLElement elementWithName: @"IgnoreComments"
                                                       content: @"true"
                                                   inNamespace: c14n2ns]];
        }
        else
        {
            [transform addAttributeNamed: @"Algorithm" withValue: transformURI];
        }
    }
    
    AQXMLElement * digestMethod = [reference addChildNamed: @"DigestMethod"];
    [digestMethod addAttributeNamed: @"Algorithm" withValue: digestTransformURI];
    
    // now the digest -- which must be base64-encoded to a string value
    (void) [reference addChildNamed: @"DigestValue" withTextContent: [Base64Transform encode: digest]];
    
    return ( reference );
}

#pragma mark -

- (id) initWithSignatureVersion: (AQXMLSignatureVersion) version
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _version = version;
    
    return ( self );
}

- (NSData *) ensureDigestable: (id) object
{
    AQXMLCanonicalizationMethod defaultCanonMethod = (self.version == AQXMLSignatureVersion2_0 ? AQXMLCanonicalizationMethod_2_0 : AQXMLCanonicalizationMethod_1_0 );
    if ( [object isKindOfClass: [NSData class]] )
    {
        return ( object );
    }
    else if ( [object isKindOfClass: [AQXMLElement class]] )
    {
        return ( [AQXMLCanonicalizer canonicalizeElement: object usingMethod: defaultCanonMethod visibilityFilter: nil] );
    }
    else if ( [object isKindOfClass: [AQXMLNodeSet class]] )
    {
        if ( [object count] == 0 )
            return ( [NSData data] );       // empty data
        
        [AQXMLCanonicalizer canonicalizeDocument: [object nodeAtIndex: 0].document usingMethod: defaultCanonMethod visibilityFilter: ^BOOL(AQXMLNode *node) {
            return ( [object containsNode: node] );
        }];
    }
    
    // otherwise, the object is invalid
    return ( nil );
}

- (BOOL) validateReferenceElement: (AQXMLElement *) reference
{
    @autoreleasepool
    {
        // NB: According to XML-DSIG 1.1, the Type attribute is advisory, and
        //  needs no verification.
        
        // load the referenced item
        NSString * uri = [reference attributeNamed: @"URI"].value;
        if ( uri == nil )
            return ( NO );      // we don't support this yet
        
        AQXMLDocument * document NS_VALID_UNTIL_END_OF_SCOPE = reference.document;
        NSURL * target = nil;
        NSURL * base = reference.document.baseURL;
        if ( base != nil )
        {
            target = [NSURL URLWithString: uri relativeToURL: base];
        }
        else
        {
            target = [NSURL URLWithString: uri];
        }
        
        id referencedObject = nil;
        
        NSRange r = [uri rangeOfString: @"#"];
        if ( r.location == NSNotFound )
        {
            // it's a plain item somewhere -- just load data
            referencedObject = [NSData dataWithContentsOfURL: target];
        }
        else if ( r.location == 0 )
        {
            // it's a same-document reference
            referencedObject = [document.rootElement elementWithID: [uri substringFromIndex: 1]];
        }
        else
        {
            // a fragment of an external XML document
            NSString * idValue = [uri substringFromIndex: r.location+1];
            
            document = [AQXMLDocument documentWithContentsOfURL: target error: NULL];
            if( document == nil )
                return ( NO );
            
            referencedObject = [document.rootElement elementWithID: idValue];
        }
        
        // invalid reference ?
        if ( referencedObject == nil )
            return ( NO );
        
        // build a Transform list
        AQXMLTransform * tx = [self buildTransformFromList: [[reference firstChildNamed: @"Transforms"] childrenNamed: @"Transform"]];
        if ( tx == nil )
            return ( NO );
        
        NSData * dataToDigest = nil;
        if ( tx != nil )
        {
            tx.input = referencedObject;
            dataToDigest = [self ensureDigestable: [tx process]];
        }
        else
        {
            dataToDigest = [self ensureDigestable: referencedObject];
        }
        
        if ( [dataToDigest isKindOfClass: [NSData class]] )
        {
            if ( [dataToDigest isKindOfClass: [AQXMLElement class]] )
            {
                dataToDigest = [AQXMLCanonicalizer canonicalizeElement: (AQXMLElement *)dataToDigest
                                                         usingMethod: AQXMLCanonicalizationMethod_1_0
                                                    visibilityFilter: nil];
            }
            else if ( [dataToDigest isKindOfClass: [AQXMLNodeSet class]] )
            {
                AQXMLNodeSet * nodes = (AQXMLNodeSet *)dataToDigest;
                if ( [nodes count] != 0 )
                {
                    dataToDigest = [AQXMLCanonicalizer canonicalizeDocument: nodes[0].document usingMethod: AQXMLCanonicalizationMethod_1_0 visibilityFilter: ^BOOL(AQXMLNode *node) {
                        return ( [nodes containsNode: node] );
                    }];
                }
                else
                {
                    // empty data is actually permitted by the standard
                    dataToDigest = [NSData data];
                }
            }
            else
            {
                // flag this for follow-up -- might need more processing
                NSLog(@"Transformed data from URI %@ is of non-data class %@",
                      uri, NSStringFromClass([referencedObject class]));
                return ( NO );
            }
        }
        
        // now get the digest transformation & expected output
        AQXMLElement * digestMethod = [referencedObject firstChildNamed: @"DigestMethod"];
        if ( digestMethod == nil )
            return ( NO );
        
        AQXMLTransform * digestTransform = [AQXMLTransform transformForURI: [digestMethod attributeNamed: @"Algorithm"].value];
        if ( digestTransform == nil )
            return ( NO );      // unknown transform algorithm
        
        // set the transform's input
        digestTransform.input = dataToDigest;
        
        AQXMLElement * digestValue = [referencedObject firstChildNamed: @"DigestValue"];
        if ( digestValue == nil )
            return ( NO );
        
        NSData * expectedDigest = [Base64Transform decode: [digestValue.stringValue dataUsingEncoding: NSUTF8StringEncoding]];
        
        // run the digest operation and compare results
        NSData * digested = [digestTransform process];
        return ( [digested isEqualToData: expectedDigest] );
    }
}

- (AQXMLTransform *) buildTransformFromList: (NSArray *) transformElements
{
    AQXMLTransform * tx = nil;
    AQXMLTransform * lastTx = nil;
    for ( AQXMLElement * element in transformElements )
    {
        AQXMLTransform * transform = [AQXMLTransform transformForURI: [element attributeNamed: @"Algorithm"].value];
        if ( transform == nil )
            return ( nil );
        
        if ( lastTx == nil )
        {
            tx = transform, lastTx = transform;
        }
        else
        {
            lastTx.next = transform;
            lastTx = transform;
        }
    }
    
    return ( tx );
}

- (SecKeyRef) keyWithName: (NSString *) name
{
    CFMutableDictionaryRef query = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if ( query == NULL )
        return ( NULL );
    
    // to save us from a million bridged casts...
    CFStringRef matchName = (__bridge CFStringRef)name;
    
    CFDictionarySetValue(query, kSecReturnRef, kCFBooleanTrue);
    CFDictionarySetValue(query, kSecMatchLimit, kSecMatchLimitOne);
    
    CFDictionarySetValue(query, kSecClass, kSecClassKey);
    CFDictionarySetValue(query, kSecAttrLabel, matchName);
    
    SecKeyRef key = NULL;
    OSStatus status = SecItemCopyMatching(query, (CFTypeRef *)&key);
    if ( status == noErr )
    {
        CFRelease(query);
        return ( key );
    }
    
    CFDictionarySetValue(query, kSecAttrApplicationLabel, matchName);
    CFDictionaryRemoveValue(query, kSecAttrLabel);
    
    status = SecItemCopyMatching(query, (CFTypeRef *)&key);
    if ( status == noErr )
    {
        CFRelease(query);
        return ( key );
    }
    
    CFDictionarySetValue(query, kSecClass, kSecClassCertificate);
    CFDictionarySetValue(query, kSecAttrSubject, matchName);
    CFDictionaryRemoveValue(query, kSecAttrApplicationLabel);
    
    status = SecItemCopyMatching(query, (CFTypeRef *)&key);
    if ( status == noErr )
    {
        CFRelease(query);
        return ( key );
    }
    
    CFDictionarySetValue(query, kSecAttrSerialNumber, matchName);
    CFDictionaryRemoveValue(query, kSecAttrSubject);
    
    status = SecItemCopyMatching(query, (CFTypeRef *)&key);
    if ( status == noErr )
    {
        CFRelease(query);
        return ( key );
    }
    
    CFDictionarySetValue(query, kSecMatchEmailAddressIfPresent, matchName);
    CFDictionaryRemoveValue(query, kSecAttrSerialNumber);
    
    // out of ideas
    CFRelease(query);
    return ( key );     // may be nil, may be valid...
}

- (NSDictionary *) parseEllipticCurveParameters: (AQXMLElement *) ECParameters
{
    NSMutableDictionary * ecParams = [NSMutableDictionary new];
    for ( AQXMLElement * element in [ECParameters firstChildNamed: @"FieldID"].children )
    {
        // not interested in blank text nodes
        if ( [element isKindOfClass: [AQXMLElement class]] == NO )
            continue;
        
        // found our field identifier, now determine the type
        NSString * name = element.name;
        if ( [name isEqualToString: @"Prime"] )
        {
            NSData * P = B64_CHILD(element, @"P");
            if ( P == nil )
                return ( nil );     // invalid
            
            ecParams[name] = @{@"P" : P};
        }
        else if ( [name isEqualToString: @"GnB"] )
        {
            NSData * M = B64_CHILD(element, @"M");
            if ( M == nil )
                return ( nil );     // invalid
            
            ecParams[name] = @{@"M" : M};
        }
        else if ( [name isEqualToString: @"TnB"] )
        {
            NSData * M = B64_CHILD(element, @"M");
            NSData * K = B64_CHILD(element, @"K");
            if ( M == nil || K == nil )
                return ( nil );     // invalid
            
            ecParams[name] = @{@"M" : M, @"K" : K};
        }
        else if ( [name isEqualToString: @"PnB"] )
        {
            NSData * M = B64_CHILD(element, @"M");
            NSData * K1 = B64_CHILD(element, @"K1");
            NSData * K2 = B64_CHILD(element, @"K2");
            NSData * K3 = B64_CHILD(element, @"K3");
            if ( M == nil || K1 == nil || K2 == nil || K3 == nil )
                return ( nil );     // invalid
            
            ecParams[name] = @{@"M" : M, @"K1" : K1, @"K2" : K2, @"K3" : K3};
        }
        else
        {
            NSLog(@"Unknown ECDSA FieldID element '%@'\nElement Content:\n%@", name, element.XMLString);
            return ( nil );
        }
        
        break;
    }
    
    AQXMLElement * curve = [ECParameters firstChildNamed: @"Curve"];
    if ( curve != nil )
    {
        NSData * A = B64_CHILD(curve, @"A");
        NSData * B = B64_CHILD(curve, @"B");
        if ( A == nil )
            A = [NSData new];
        if ( B == nil )
            B = [NSData new];
        
        ecParams[@"Curve"] = @{@"A" : A, @"B" : B};
    }
    
    NSData * Base = B64_CHILD(ECParameters, @"Base");
    if ( Base == nil )
        return ( nil );     // invalid
    ecParams[@"Base"] = Base;
    
    NSData * Order = B64_CHILD(ECParameters, @"Order");
    if ( Order == nil )
        return ( nil );     // invalid
    ecParams[@"Order"] = Order;
    
    // these last two may be omitted
    AQXMLElement * CoFactor = [ECParameters firstChildNamed: @"CoFactor"];
    if ( CoFactor != nil )
    {
        ecParams[@"CoFactor"] = @(CoFactor.integerValue);
    }
    
    AQXMLElement * ValidationDataType = [ECParameters firstChildNamed: @"ValidationDataType"];
    if ( ValidationDataType != nil )
    {
        NSData * Seed = B64_CHILD(ValidationDataType, @"seed");
        NSString * HashAlgorithm = [ValidationDataType attributeNamed: @"hashAlgorithm"].value;
        
        if ( Seed == nil || HashAlgorithm == nil )
            return ( nil );     // invalid
        
        ecParams[@"ValidationDataType"] = @{@"Seed" : Seed, @"HashAlgorithm" : HashAlgorithm};
    }
    
    return ( ecParams );
}

- (SecKeyRef) unpackKeyFromKeyValue: (AQXMLElement *) keyValue
                       forAlgorithm: (AQXMLSignatureAlgorithm *) algorithm
{
    AQXMLElement * dsaKeyValue = [keyValue firstChildNamed: @"DSAKeyValue"];
    AQXMLElement * rsaKeyValue = [keyValue firstChildNamed: @"RSAKeyValue"];
    AQXMLElement * ecKeyValue = [keyValue firstChildNamed: @"ECKeyValue"];
    
    if ( dsaKeyValue == nil && rsaKeyValue == nil && ecKeyValue == nil )
    {
        // key is stored as a base-64 string
        NSData * keyData = [Base64Transform decode: [keyValue.stringValue dataUsingEncoding: NSUTF8StringEncoding]];
        if ( keyData == nil )
            return ( NULL );
        
        NSDictionary * params = @{ _SEC(kSecAttrKeyType) : _SEC(algorithm.keyType) };
        return ( SecKeyCreateFromData((__bridge CFDictionaryRef)params, (__bridge CFDataRef)keyData, NULL) );
    }
    
    // read and parse key data
    if ( dsaKeyValue != nil )
    {
        // DSA key contains the following elements, all containing base64 values
        // (P Q)? G? Y J? (Seed PgenCounter)?
        
        // we can optimize this, however: Y is Required and is the public key. Yay!
        NSData * Y = B64_CHILD(dsaKeyValue, @"Y");
        if ( Y == nil )
            return ( NULL );
        
        return ( BuildDSAKey(B64_CHILD(dsaKeyValue, @"P"), B64_CHILD(dsaKeyValue, @"Q"), B64_CHILD(dsaKeyValue, @"G"), Y, B64_CHILD(dsaKeyValue, @"J"), B64_CHILD(dsaKeyValue, @"Seed"), B64_CHILD(dsaKeyValue, @"PgenCounter")) );
    }
    
    if ( rsaKeyValue != nil )
    {
        // RSA keys contain two required components: Modulus and Exponent
        NSData * Modulus = B64_CHILD(rsaKeyValue, @"Modulus");
        NSData * Exponent = B64_CHILD(rsaKeyValue, @"Exponent");
        
        if ( Modulus == nil || Exponent == nil )
            return ( NULL );
        
        return ( BuildRSAKey(Modulus, Exponent) );
    }
    
    if ( ecKeyValue != nil )
    {
        // named curve or parameters ?
        id curve = nil;
        AQXMLElement * NamedCurve = [ecKeyValue firstChildNamed: @"NamedCurve"];
        if ( NamedCurve != nil )
        {
            curve = [NamedCurve attributeNamed: @"URI"].value;
        }
        else
        {
            // Pull out any parameters
            AQXMLElement * ECParameters = [ecKeyValue firstChildNamed: @"ECParameters"];
            if ( ECParameters == nil )
                return ( NULL );        // invalid XML
            
            curve = [self parseEllipticCurveParameters: ECParameters];
        }
        
        if ( curve == nil )
            return ( NULL );        // invalid XML
        
        NSData * PublicKey = B64_CHILD(ecKeyValue, @"PublicKey");
        if ( PublicKey == nil )
            return ( NULL );        // invalid XML
        
        return ( BuildECDSAKey(curve, PublicKey, algorithm) );
    }
    
    return ( NULL );
}

- (SecKeyRef) unpackKeyFromKeyInfo: (AQXMLElement *) keyInfo
                      forAlgorithm: (AQXMLSignatureAlgorithm *) algorithm
{
    @autoreleasepool
    {
        NSMutableArray * X509KeychainQueries = [NSMutableArray new];
        NSMutableArray * X509CertificatesImported = [NSMutableArray new];
        
        for ( AQXMLElement * element in keyInfo.children )
        {
            if ( [element isKindOfClass: [AQXMLElement class]] == NO )
                continue;
            
            NSString * name = element.name;
            if ( [name isEqualToString: @"KeyName"] )
            {
                // lookup the key using the Keychain
                SecKeyRef found = [self keyWithName: element.stringValue];
                if ( found != NULL )
                    return ( found );
            }
            else if ( [name isEqualToString: @"KeyValue"] )
            {
                SecKeyRef unpacked = [self unpackKeyFromKeyValue: element
                                                    forAlgorithm: algorithm];
                if ( unpacked != NULL )
                    return ( unpacked );
            }
            else if ( [name isEqualToString: @"RetrievalMethod"] )
            {
                // directs us to another KeyInfo object somewhere else
                // contains some transforms
                NSArray * transformElements = [[element firstChildNamed: @"Transforms"] childrenNamed: @"Transform"];
                AQXMLTransform * tx = [self buildTransformFromList: transformElements];
                
                NSString * uri = [element attributeNamed: @"URI"].value;
                NSString * type = [element attributeNamed: @"Type"].value;
                if ( [type hasSuffix: @"#rawX509Certificate"] )
                {
                    // uri references binary data
                    NSData * data = [NSData dataWithContentsOfURL: [NSURL URLWithString: uri]];
                    if ( data != nil )
                    {
                        SecKeyRef key = ImportKeyData(data, @[(__bridge id)kSecAttrCanVerify]);
                        if ( key != NULL )
                            return ( key );
                    }
                    
                    continue;
                }
                
                // otherwise, it references some XML type
                AQXMLElement * newKeyInfo = ElementAtURI(uri, tx);
                if ( newKeyInfo != nil )
                {
                    SecKeyRef key = [self unpackKeyFromKeyInfo: newKeyInfo forAlgorithm: algorithm];
                    if ( key != NULL )
                        return ( key );
                }
            }
            else if ( [name isEqualToString: @"X509Data"] )
            {
                // import any certificates here
                for ( AQXMLElement * certElement in [element childrenNamed: @"X509Certificate"] )
                {
                    // contains base64 DER-encoded data
                    NSData * certData = [Base64Transform decode: [certElement.stringValue dataUsingEncoding: NSUTF8StringEncoding]];
                    SecCertificateRef cert = SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)certData);
                    if ( cert == NULL )
                        continue;
                    
                    SecCertificateAddToKeychain(cert, NULL);
                    [X509CertificatesImported addObject: (__bridge id)cert];
                }
            }
            else if ( [name isEqualToString: @"PGPData"] )
            {
                
            }
            else if ( [name isEqualToString: @"SPKIData"] )
            {
                
            }
            else if ( [name isEqualToString: @"DEREncodedKeyData"] )
            {
                NSData * data = [Base64Transform decode: [element.stringValue dataUsingEncoding: NSUTF8StringEncoding]];
                if ( data != nil )
                {
                    SecKeyRef key = ImportKeyData(data, @[(__bridge id)kSecAttrCanVerify]);
                    if ( key != NULL )
                        return ( key );
                }
            }
            else if ( [name isEqualToString: @"KeyInfoReference"] )
            {
                
            }
            else if ( [name isEqualToString: @"EncryptedKey"] )
            {
                
            }
            else if ( [name isEqualToString: @"Agreement"] )
            {
                
            }
            else
            {
                NSLog(@"Encountered unexpected child of KeyInfo: '%@'\nContent Dump:\n%@", element.name, element.XMLString);
            }
        }
    }
    
    return ( NULL );
}

- (BOOL) validateSignature: (AQXMLElement *) signatureElement
                inDocument: (AQXMLDocument *) document
{
    @autoreleasepool
    {
        AQXMLElement * signedInfo = [signatureElement firstChildNamed: @"SignedInfo"];
        if ( signedInfo == nil )
            return ( NO );
        
        //////////////////////////////////////////////////////
        // Step 1: Canonicalize the SignedInfo element
        
        AQXMLElement * canonElement = [signedInfo firstChildNamed: @"CanonicalizationMethod"];
        if ( canonElement == nil )
            return ( NO );
        
        AQXMLTransform * c14nTransform = [AQXMLTransform transformForURI: [canonElement attributeNamed: @"Algorithm"].value];
        if ( c14nTransform == nil )
            return ( NO );
        
        // the transform operates on the SignedInfo element itself
        c14nTransform.input = signedInfo;
        
        if ( [c14nTransform isKindOfClass: [C14N20Transform class]] )
        {
            // need to set an extra variable
            C14N20Transform * tmp = (C14N20Transform *)c14nTransform;
            tmp.methodElement = canonElement;
        }
        
        // run the transformation
        NSData * dataToVerify = [c14nTransform process];
        if ( dataToVerify == nil )
            return ( NO );
        
        // the spec states that the remaining steps should be performed using the
        //  canonicalized version of the SignedInfo element
        AQXMLDocument * doc NS_VALID_UNTIL_END_OF_SCOPE = [AQXMLDocument documentWithXMLData: dataToVerify error: NULL];
        if ( doc == nil )
            return ( NO );
        
        signedInfo = doc.rootElement;
        
        ////////////////////////////////////////////////////////////////
        // Step 2: Validate each Reference within the SignedInfo
        
        NSArray * references = [signedInfo childrenNamed: @"Reference"];
        if ( [references count] == 0 )
            return ( NO );
        
        for ( AQXMLElement * element in references )
        {
            if ( [self validateReferenceElement: element] == NO )
                return ( NO );
        }
        
        ///////////////////////////////////////////////////////////////
        // Step 3: Validate the signature itself
        
        AQXMLSignatureAlgorithm * signatureTransform = [AQXMLTransform transformForURI: [[signedInfo firstChildNamed: @"SignatureMethod"] attributeNamed: @"Algorithm"].value];
        if ( signatureTransform == nil )
            return ( NO );
        
        NSString * base64Signature = [signatureElement firstChildNamed: @"SignatureValue"].stringValue;
        NSData * expectedSignature = [Base64Transform decode: [base64Signature dataUsingEncoding: NSUTF8StringEncoding]];
        
        // load the key
        AQXMLElement * keyInfo = [signatureElement firstChildNamed: @"KeyInfo"];
        if ( keyInfo == nil )
            return ( NO );
        
        SecKeyRef actualKey = [self unpackKeyFromKeyInfo: keyInfo forAlgorithm: signatureTransform];
        if ( actualKey == NULL )
            return ( NO );
        
        signatureTransform.key = actualKey;
        CFRelease(actualKey);
        
        return ( [signatureTransform verifySignature: expectedSignature
                                             forData: dataToVerify
                                               error: NULL] );
    }
}

- (AQXMLDocument *) signatureForEmbeddedDocument: (AQXMLDocument *) document
{
    AQXMLCanonicalizationMethod canonMethod = (self.version == AQXMLSignatureVersion2_0 ? AQXMLCanonicalizationMethod_2_0 : AQXMLCanonicalizationMethod_1_1);
    NSData * dataToSign = [AQXMLCanonicalizer canonicalizeDocument: document usingMethod: canonMethod visibilityFilter: nil];
    
}

@end
