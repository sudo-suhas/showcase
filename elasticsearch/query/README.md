# Elasticsearch Query

This is generated as part of an application which accepts a JSON
describing the type of search to be made against elasticsearch.

This payload is run through `query_builder.js`(not included here) which uses
[`elastic.js`](https://github.com/erwanpigneul/elastic.js) for building the query object.
Check out the [example query](elastic_query.json) for the following search payload:

```json
{
	"docType": "products",
	"brands": ["Oye", "Zero"],
	"department": "Clothes",
	"ageGroups": ["newborn", "3-12 months"],
	"genders": ["Boys"],
	"priceRanges": [{
		"min": 0,
		"max": 500
	}, {
		"min": 500,
		"max": 1000
	}],
	"searchParameter": "pants"
}
```

### Notes
 - Only required fields are fetched from the document
 - Products in stock are scored higher
 - Recently introduced products are scored higher
 - Popularity, brand boost and general boost factors are also used for calculating score
 - [Search query](#search-query) is used if it is a keyword search.
 - Filters for various fields in the request payload are used for generating term filters etc.
 However, care is taken so that application of such a filter, say for a brand, does not filter the list of brands returned.
 - Special care has to be taken for filtering DCS as it is defined as `nested` field
 - Aggregations for DCS, brands, discount percent etc are specified
 - Special [top hits aggregation](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-metrics-top-hits-aggregation.html)
 is applied for getting results grouped by the virtual id and color.
 - Dynamic aggregations are applied depending upon the Department/Category specified using a mapping file.

## Extras

#### [`joi`](https://github.com/hapijs/joi) object schema definition

<details>
    <summary>Click to expand</summary>
```js
Joi.object({
    docType: Joi.string().valid('products').required(),
    brands: Joi.array().items(Joi.string()),
    department: Joi.string(),
    categories: Joi.array().items(Joi.string()),
    subCategories: Joi.array().items(Joi.string()),
    customCategory: Joi.string(),
    searchParameter: Joi.string(),
    ageGroups: Joi.array().items(Joi.string()),
    diaperSizes: Joi.array().items(Joi.string()),
    genders: Joi.array().items(Joi.string()),
    priceRanges: Joi.array().items(Joi.object({
        min: Joi.number().min(0).required(),
        max: Joi.number().greater(Joi.ref('min')).required()
    })),
    discountPercentage: Joi.number().min(1).max(99),
    discountRange: Joi.object({
        min: Joi.number().min(0).required(),
        max: Joi.number().max(100).greater(Joi.ref('min')).required()
    }),
    colours: Joi.array().items(Joi.string()),
    collections: Joi.array().items(Joi.string()),
    materials: Joi.array().items(Joi.string()),
    packQuantities: Joi.array().items(Joi.string()),
    maternitySizes: Joi.array().items(Joi.string()),
    availability: Joi.boolean().default(false),
    page: Joi.number().integer().min(1).default(1),
    size: Joi.number().integer().min(8).default(12),
    sort: Joi.string().valid([
        'most-relevant', 'newest', 'lowest-price', 'highest-price', 'discountpercent'
    ]).default('most-relevant'),
    filterSource: Joi.boolean().default(true),
    cache: Joi.boolean().default(false)
});
```
</details>

#### Search Query

<details>
    <summary>Click to expand</summary>
```js
const SEARCH_QUERY = ejs.BoolQuery()
    .should(ejs.MultiMatchQuery(['qualifiedProductName^1.5', 'qualifiedProductName.shingles'])
        .query('{{query_string}}')
        .type('most_fields')
        .minimumShouldMatch('3<65%')
        .cutoffFrequency(0.01)
        .lenient(true)
        .boost(24))
    .should(ejs.NestedQuery('dcs')
        .query(ejs.MultiMatchQuery(['dcs.departmentName^8', 'dcs.categoryName^2', 'dcs.subCategoryName'])
            .query('{{query_string}}')
            .type('best_fields')
            .minimumShouldMatch('3<75%')
            .tieBreaker(0.3)
            .lenient(true)
            .boost(4)))
    .should(ejs.MultiMatchQuery([
        'collectionsFeature^3.5', 'colourFeature^3.5', 'materialFeature^3.5',
        'genderFeature^4', 'sizeDiapersFeature^2', 'longDesc'
    ])
        .query('{{query_string}}')
        .type('most_fields')
        .minimumShouldMatch('3<20%')
        .lenient(true)
        .boost(2))
    .should(ejs.BoolQuery()
        .should(ejs.MultiMatchQuery(['qualifiedProductName^1.5', 'qualifiedProductName.shingles'])
            .query('{{query_string}}')
            .type('most_fields')
            .minimumShouldMatch('3<75%')
            .fuzziness('AUTO')
            .cutoffFrequency(0.01)
            .lenient(true)
            .boost(18))
        .should(ejs.NestedQuery('dcs')
            .query(ejs.MultiMatchQuery(['dcs.departmentName^8', 'dcs.categoryName^4', 'dcs.subCategoryName^2'])
                .query('{{query_string}}')
                .type('best_fields')
                .minimumShouldMatch('3<80%')
                .tieBreaker(0.3)
                .cutoffFrequency(0.1)
                .fuzziness('AUTO')
                .lenient(true)
                .boost(8)))
        .should(ejs.MultiMatchQuery([
            'collectionsFeature^1.5', 'colourFeature^1.5', 'materialFeature^1.5',
            'genderFeature^2', 'sizeDiapersFeature^2', 'longDesc'
        ])
            .query('{{query_string}}')
            .type('most_fields')
            .minimumShouldMatch('3<40%')
            .cutoffFrequency(0.1)
            .fuzziness('AUTO')
            .lenient(true)
            .boost(3))
        .boost(0.1))
    .should(ejs.MatchQuery('productId', '{{query_string}}'));
```
</details>