# ISO/IEC 10646 — Local Mirror

ISO/IEC 10646 *Information technology — Universal Coded Character Set (UCS)* is
the formal standard backing IDNA2008 (RFC 5892) classification tables. The
canonical PDF is paywalled at the [ISO Store](https://www.iso.org/standard/76835.html)
(CHF 199, 2 804 pages). The files below are the best publicly accessible
substitutes; together they cover the full text and its current amendments.

## Why ISO/IEC 10646 is in scope for URLBuilder

URL/URI syntax is governed by **IETF**, not ISO/IEC. The single ISO/IEC
dependency is **ISO/IEC 10646** because **RFC 3987 (IRI)** maps
internationalised URIs onto its code points, and **RFC 5892 (IDNA2008
classification)** is defined in terms of properties projected from
ISO/IEC 10646 via the Unicode Character Database. The chain is:

```
URLBuilder host label → Foundation IDNA → RFC 5891 §4 → RFC 5892 properties → ISO/IEC 10646 repertoire
```

## Documents in this folder

### Final / Committee Drafts (full text — best free substitutes for the published standard)

| File | Edition | Source | Notes |
|---|---|---|---|
| `iso-iec-10646-2020-FCD-unicode.org.pdf` | 6th ed. (2020) FCD | [unicode.org/L2/L2010/10038-fcd10646-main.pdf](http://unicode.org/L2/L2010/10038-fcd10646-main.pdf) | Full Final Committee Draft text — closest free equivalent to the published 6th edition. |
| `iso-iec-10646-2007-FCD-WG2-N3275.pdf` | 5th ed. (2007) FCD | [unicode.org/L2/L2007/07218-n3275.pdf](http://www.unicode.org/L2/L2007/07218-n3275.pdf) | WG2 N3275 — earlier-edition FCD for diff and historical reference. |

### Sample chapters from the current published edition

| File | Edition | Source |
|---|---|---|
| `iso-iec-10646-2020-iteh-sample.pdf` | 6th ed. (2020) | [iTeh sample 76835](https://cdn.standards.iteh.ai/samples/76835/9f89219dd5a04933969b8ecbe194f88f/ISO-IEC-10646-2020.pdf) |
| `iso-iec-10646-2020-amd1-2023-iteh-sample.pdf` | 6th ed. Amd 1 (2023) | [iTeh sample 83362](https://cdn.standards.iteh.ai/samples/83362/5afa721b5ede4afc84f97db157b253b8/ISO-IEC-10646-2020-Amd-1-2023.pdf) |

### Amendment work-in-progress

| File | Topic | Source |
|---|---|---|
| `iso-iec-10646-2023-amd2-chart.pdf` | 10646:2020 Amd 2 (CDAM2.3) draft chart | [unicode.org L2/23-146](https://www.unicode.org/L2/L2023/23146-n5235-cdam2-3-draft-chart.pdf) |

### Unicode bridge (functional equivalent)

ISO/IEC 10646 and the Unicode Standard share an *identical character repertoire
and code points* — see the Unicode FAQ. Unicode adds algorithms and conformance
text on top.

| File | Source | Notes |
|---|---|---|
| `unicode-iso10646-faq.html` | [unicode.org/faq/unicode_iso](https://www.unicode.org/faq/unicode_iso.html) | Authoritative FAQ on the Unicode↔ISO/IEC 10646 relationship. |
| `unicode-16.0-appendix-C-relationship-ISO-10646.html` | [Unicode 16.0 Appendix C](https://www.unicode.org/versions/Unicode16.0.0/core-spec/appendix-c/) | Formal mapping of Unicode 16.0 to ISO/IEC 10646:2020 + Amd 1 + Amd 2. |

### Unicode Character Database (referenced by RFC 5892)

These tables are the *operational* form of ISO/IEC 10646 used by Foundation
when normalising hosts:

| File | Source |
|---|---|
| `UnicodeData.txt` | [unicode.org/Public/UCD/latest/ucd/UnicodeData.txt](https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt) |
| `DerivedCoreProperties.txt` | [unicode.org/Public/UCD/latest/ucd/DerivedCoreProperties.txt](https://www.unicode.org/Public/UCD/latest/ucd/DerivedCoreProperties.txt) |
| `IdnaMappingTable.txt` | [unicode.org/Public/idna/latest/IdnaMappingTable.txt](https://www.unicode.org/Public/idna/latest/IdnaMappingTable.txt) |
| `UCD-ReadMe.txt` | [unicode.org/Public/UCD/latest/ucd/ReadMe.txt](https://www.unicode.org/Public/UCD/latest/ucd/ReadMe.txt) |

## Sources tried but not retrievable without a browser

The official free copy of ISO/IEC 10646:2014 (4th edition) is hosted on the
ISO ITTF "Publicly Available Standards" portal:

- <https://standards.iso.org/ittf/PubliclyAvailableStandards/c063182_ISO_IEC_10646_2014.zip>
- <https://standards.iso.org/ittf/PubliclyAvailableStandards/c063182_ISO_IEC_10646_2014_Electronic_Inserts.zip>

Both URLs are gated by an interactive license-acceptance form that sets a
session cookie via JS; non-browser clients receive only the interstitial HTML
(form `POST` does not establish a download-capable session). To grab the full
ZIP, open the page in a browser, click **"I accept"**, and the download will
start. Place the resulting files alongside this README.

The IEC Webstore preview at
<https://webstore.iec.ch/preview/info_isoiec10646%7Bed6.0%7Den.pdf> uses
similar bot-detection. If you have a browser session, that is another
official preview source.
