# config
The [configuration](product_listing_template.json) I setup for elasticsearch index for products.

#### Notes
 - It is used for a template and hence all indexes matching the given pattern automatically
inherit the mapping, settings on creation.
 - DCS structure is setup using nested fields
 - Multiple analyzers are setup to satisfy search requirements
 - Configuration is optimum for 3 machine setup. Any 2 machines will have all 3 shards.
 - Some fields like `qualifiedProductName` use multiple fields(analyzed, autocomplete, raw, shingles)
 to satisfy different criteria of search.