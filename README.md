AQXML
=====

A complete and holistic XML processing framework in Objective-C. Currently a work in progress.

The first part of this library is an object-orented framework built upon the XML tree and stream APIs provided by the GNOME project's [libxml](http://www.xmlsoft.org). The Objective-C objects are created automatically and linked to their C counterparts through some glue code in [xml_glue.m](#), which installs creation/destruction event handlers and uses those to allocate/release the appropriate Objective-C objects, storing them in each `xmlNode`'s `_private` member.

The most interesting thing here at present is the implementation of [Canonical XML Version 2.0](http://www.w3.org/TR/xml-c14n2/), which is a W3C standard currently in Candidate Recommendation status. This project has been published in order that it serve as one of the two implementations required to move the standard from candidacy to publication.

The Canonicalization implementation can be found [here](#).

Also found within are the beginnings of implementations for [XML Encryption Version 1.1](http://www.w3.org/TR/xmlenc-core1/) and [XML Signature Version 1.1](http://www.w3.org/TR/xmldsig-core1/).
