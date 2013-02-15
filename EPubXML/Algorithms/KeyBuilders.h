//
//  KeyBuilders.h
//  EPubXML
//
//  Created by Jim Dovey on 2012-10-04.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/SecKey.h>

@class AQXMLSignatureAlgorithm;

__BEGIN_DECLS

extern SecKeyRef ImportKeyData(NSData * data, NSArray * usage);
extern SecCertificateRef ImportCertificateData(NSData * data);

extern SecKeyRef BuildRSAKey(NSData * modulus, NSData * exponent);
extern SecKeyRef BuildDSAKey(NSData * P, NSData * Q, NSData * G, NSData * Y, NSData * J,
                             NSData * Seed, NSData * PGenCounter);
extern SecKeyRef BuildECDSAKey(id curveNameOrParameters, NSData * publicKey, AQXMLSignatureAlgorithm * alg);

__END_DECLS
