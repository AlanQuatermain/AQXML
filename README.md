AQXML
=====

A complete and holistic XML processing framework in Objective-C. Currently a work in progress.

The first part of this library is an object-orented framework built upon the XML tree and stream APIs provided by the GNOME project's [libxml](http://www.xmlsoft.org). The Objective-C objects are created automatically and linked to their C counterparts through some glue code in [xml_glue.m](https://github.com/AlanQuatermain/AQXML/blob/master/EPubXML/xml_glue.m), which installs creation/destruction event handlers and uses those to allocate/release the appropriate Objective-C objects, storing them in each `xmlNode`'s `_private` member.

The second part is an update to the venerable [AQXMLParser](http://blog.alanquatermain.me/2013/01/09/using-aqxmlparser-and-friends/), which is in future going to be maintained as part of this larger project. No further updates will be made to [the original repository](https://github.com/AlanQuatermain/aqtoolkit/tree/master/StreamingXMLParser).

The most interesting thing here at present is the implementation of [Canonical XML Version 2.0](http://www.w3.org/TR/xml-c14n2/), which is a W3C standard currently in Candidate Recommendation status. This project has been published in order that it serve as one of the two implementations required to move the standard from candidacy to publication.

The Canonicalization implementation [can be found here](https://github.com/AlanQuatermain/AQXML/blob/master/EPubXML/XMLWrappers/AQXMLCanonicalizer.m).

Also found within are the beginnings of implementations for [XML Encryption Version 1.1](http://www.w3.org/TR/xmlenc-core1/) and [XML Signature Version 1.1](http://www.w3.org/TR/xmldsig-core1/). You can find cryptographic algorithms defined in [AQXMLCryptoAlgorxithm.mm](https://github.com/AlanQuatermain/AQXML/blob/master/EPubXML/Algorithms/AQXMLCryptoAlgorithm.mm), with signature algorithms in [AQXMLSignatureAlgorithm.m](https://github.com/AlanQuatermain/AQXML/blob/master/EPubXML/Algorithms/AQXMLSignatureAlgorithm.m).

#### PLEASE NOTE

This repository contains a 41MB static archive containing a compiled version of the [Crypto++](http://www.cryptopp.com/) library. This proved necessary in order to get a good implementation of AES-GCM on iOS and OS X. This library will not be included verbatim in the resulting project, as only a fraction of its very template-based code will be utilized. The resulting debug build of this project on OS X amounts to 5.4MB in size, and this will very likely shrink further when compiled for release or for iOS using Thumb mode.
