# Redis
This is probably not the best demonstration for Redis.
But it does show that I can use the basics of Redis at least.

Redis is used as a cache for elasticsearch responses.
The reason for doing this is that elasticsearch cannot paginate aggregated response.
So I have a payload which the REST app received. This was used to build an elasticsearch query.
I use the payload for constructing a key which ties together related data.
 - How many times was this search requested in a given time period
 - What is the total number of documents in the response
 - How much of this total has been fetched and saved in redis
 - The actual documents
 - The aggregations or facets


## Highlights
 - Subscriber for processing expired entries and tracking set events
 - Use of bluebird to promisify the redis API
 - Use of `multi` command to execute multiple redis commands
 - Use of redis commands `rpush` and `lrange` on [list](http://redis.io/commands#list) datatype

## Description
- [*Subscriber*](redis_client.js#L69-L98) - The subscriber does 2 tasks.
  + On expiry of a key, it emits an event for reloading the data from elasticsearch into redis
  if it satisfies any of the following criteria:
    * The 'search result' was queried from redis multiple times and crosses a threshold
    * The key is member of a special [set](http://redis.io/commands#set)
    stored in redis which tracks keys which need to be reloaded
  + On a set event, it emits an event which is tracked elsewhere
- *Fetch search result* - The function [`getCachedAsync`](redis_client.js#L119-L59) uses the payload key, page number
and size for fetching the search result. `Promise.All` is used for fetching multiple values from redis concurrently
- *Store search result* - The function [`set`](redis_client.js#L171-L200) uses the
elasticsearch response to store all relevant data. `client.multi` is used for executing all commands in single call.

## Other helper code

#### util.async
<details>
  <summary>Click to expand</summary>
```js
/**
 * Enables async flow using yield and generators
 *
 * @param {Function} makeGenerator
 * @returns {any}
 */
exports.async = function async(makeGenerator) {
    return function asyncFunc(...args) {
        const generator = makeGenerator(...args);

        /**
         *
         * @param {Promise} result
         * @returns {Promise}
         */
        function handle(result) {
            // result => { done: [Boolean], value: [Object] }
            if (result.done) {
                return Promise.resolve(result.value);
            }

            return Promise.resolve(result.value)
                .then((res) => {
                    return handle(generator.next(res));
                }).catch((err) => {
                    return handle(generator.throw(err));
                });
        }

        try {
            return handle(generator.next());
        } catch (ex) {
            return Promise.reject(ex);
        }
    };
};
```
</details>