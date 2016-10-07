# PEG.js
If you haven't heard of PEG.js, you're my kinda ~guy~ person.
[PEG.js](https://github.com/pegjs/pegjs) is a javascript implementation of
[Parsing expression grammar](https://en.wikipedia.org/wiki/Parsing_expression_grammar).
Most people won't ever need this so not knowing about it is just fine.

I had a requirement of converting an expressive string into elasticsearch query.
So lets say I have a string `property["ticket_booking_date"] == "2016-01-13T07:57:53Z"`.
I somehow need to parse the property name and the value and construct an elasticsearch query.
In addition to that these `property conditions` maybe combined with `and`/`or`.

Example:
```
((property["flight_passenger_count"] > 81 and property["ticket_booking_mode"] contain "Airport") or (property["discounted_ticket"] is false))
```

When I was trying to find a way to solve this, I came across PEG.js.
I combined PEG.js and snippets from [elastic.js](https://github.com/erwanpigneul/elastic.js)
to build a parser for this purpose.

[where.pegjs](where.pegjs) contains the PEG.js definition.
[elastic.js-snippet.js](elastic.js-snippet.js) is also included but that's less important.

You can check out the demo by running `npm install && npm run demo` inside demo-pegjs.
You do need node.js and npm to be installed though.
Console output:
```
To keep it simple, I am using a hard-coded condition
Condition - ((property["flight_passenger_count"] > 81 and property["ticket_booking_mode"] contain "Airport") or (property["discounted_ticket"] is false))

Creating Parser for project id 12345
Parsing condition using PEG.js

Query -  {
  "bool": {
    "should": [
      {
        "bool": {
          "must": [
            {
              "range": {
                "$prj_12345_props.flight_passenger_count": {
                  "gt": 81
                }
              }
            },
            {
              "match": {
                "$prj_12345_props.ticket_booking_mode": {
                  "query": "Airport"
                }
              }
            }
          ]
        }
      },
      {
        "term": {
          "$prj_12345_props.discounted_ticket": {
            "term": false
          }
        }
      }
    ]
  }
}
```


## Notes
 - The parser is not battle tested and there are a few known issues
 - The PEG.js code has to be migrated to the latest release so some things are not optimal.
