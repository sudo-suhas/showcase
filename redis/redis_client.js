'use strict';
// eslint-disable-next-line no-shadow
const Promise = require('bluebird');
const redis = Promise.promisifyAll(require('redis'));

const config = require('../config'),
  ee = require('./event_emitter'),
  logger = require('../logger');

// https://github.com/sudo-suhas/showcase/blob/master/redis/README.md#utilasync
const async = require('./util').async;

const client = redis.createClient(config.redis),
  subscriber = redis.createClient(config.redis),
  datadog = global.statsd;

const SEPERATOR = ':|$|:',
  RELOAD_CACHE_KEY = 'reloadCacheKey';

let clientReady, downTime;

client.on('ready', () => {
  logger.info('Redis client now ready.');
  if (clientReady === false) {
    // It means redis came online and crashed after some time.
    downTime = Math.floor((Date.now() - downTime) / 1000);
    const msgText = `Redis was down for ${downTime} seconds`;
    datadog.event('Redis client ready', msgText);
  }
  clientReady = true;
});

subscriber.on('ready', () => {
  logger.info('Redis subscriber client now ready.');
  // Subscribe To Expired Events
  subscriber.psubscribe('__keyevent@*__:*');
});

/**
 * Logs the error and sets a flag to denote redis client is not ready
 *
 * @param {Error} err
 */
function onRedisError(err) {
  logger.error(err);
  if (clientReady === true) {
    datadog.event('Redis error', err.message, {
      alert_type: 'error'
    });
    downTime = Date.now();
  }
  clientReady = false;
}

client.on('error', onRedisError);

subscriber.on('error', () => {
  // do nothing
});

/**
 * Emits appropriate event caught on expiry of value in redis or when value is set in redis.
 * Expired event is only fired in specific cases.
 *
 * @param {any} pattern
 * @param {any} channel
 * @param {any} key
 */
function* onPmessage(pattern, channel, key) {
  try {
    if (key.indexOf(SEPERATOR) === -1) {
      if (config.reloadExpired && channel.indexOf(':expired') !== -1) {
        const tags = [];
        let reloadExpired = false;
        const timesGot = yield client.getAsync(`${key}${SEPERATOR}timesGot`);
        if (timesGot && timesGot > config.cacheTimesGot) {
          tags.push('reload_type:times_got');
          reloadExpired = true;
          ee.emit('expired', key);
        } else {
          const reloadCache = yield client.sismemberAsync(RELOAD_CACHE_KEY, key);
          if (reloadCache) {
            tags.push('reload_type:cache_key');
            reloadExpired = true;
            ee.emit('expired', key);
          }
        }
        if (reloadExpired === true) {
          datadog.increment('reload_expired', 1, tags);
        }
      } else if (channel.indexOf(':set') !== -1) {
        ee.emit(`${key}set`);
      }
    }
  } catch (err) {
    logger.error(err);
  }
}

subscriber.on('pmessage', async(onPmessage));

/**
 * @param {string} payloadStr
 * @param {string} key
 * @returns {string} Concatenated key with payload string and separator
 */
function genKey(payloadStr, key) {
  return payloadStr + SEPERATOR + key;
}

/**
 * Checks if response is present in redis for given page and size, and returns a promise
 *
 * @param {string} payloadStr
 * @param {number} page
 * @param {number} size
 * @returns {Object} If found, a promise which resolves to the expected response for payload
 */
exports.getCachedAsync = async(function* getCached(payloadStr, page, size, tags) {
  if (!clientReady) {
    logger.warn('Redis Client not ready, returning null in get');
    return null;
  }
  try {
    const exists = yield client.existsAsync(payloadStr);
    if (!exists) {
      return null;
    }

    const totalFetched = yield client.getAsync(genKey(payloadStr, 'totalFetched'));
    const fromIdx = (page - 1) * size;
    const toIdx = fromIdx + size - 1;

    if (toIdx >= totalFetched) {
      return null;
    }

    const start = Date.now();
    return Promise.all([
      client.lrangeAsync(genKey(payloadStr, 'hits'), fromIdx, toIdx),
      client.getAsync(genKey(payloadStr, 'total')),
      client.getAsync(genKey(payloadStr, 'facets'))
    ]).then((resArray) => {
      const respTime = Date.now() - start;
      datadog.timing('redis.response_time', respTime, 1, tags);

      client.incr(genKey(payloadStr, 'timesGot'));
      return {
        hits: resArray[0].map(JSON.parse),
        total: resArray[1],
        facets: JSON.parse(resArray[2])
      };
    });
  } catch (err) {
    tags.push('error_src:redis');
    logger.error(`Got error while executing getCached in redis_client for payload ${payloadStr}`);
    throw err;
  }
});

/**
 * Sets up objects in redis using elasticsearch response.
 * Objects are saved with expiry.
 *
 * @param {string} payloadStr
 * @param {Object} esRes
 * @param {number} bigPage
 * @param {boolean} cache
 * @returns {void}
 */
exports.set = function set(payloadStr, esRes, bigPage, cache) {
  if (!clientReady) {
    logger.warn('Redis Client not ready, skipping setex and rpush statements in set()');
    client.del(genKey(payloadStr, 'sentinel') + bigPage);
    return;
  }
  const multi = client.multi();
  const otherExpiry = config.cacheExpiry + 60;
  multi.setex(genKey(payloadStr, 'timesGot'), otherExpiry, 0);
  multi.setex(genKey(payloadStr, 'total'), otherExpiry, esRes.total);
  multi.setex(genKey(payloadStr, 'totalFetched'), otherExpiry, esRes.hits.length);
  // hits start
  const hitsKey = genKey(payloadStr, 'hits');
  multi.del(hitsKey);
  esRes.hits.map(JSON.stringify)
    .forEach((val) => {
      multi.rpush(hitsKey, val);
    });
  multi.expire(hitsKey, otherExpiry);
  // hits end
  multi.setex(genKey(payloadStr, 'facets'), otherExpiry, JSON.stringify(esRes.facets));
  multi.del(genKey(payloadStr, 'sentinel') + bigPage);
  multi.setex(payloadStr, config.cacheExpiry, 1);

  if (cache) {
    multi.sadd(RELOAD_CACHE_KEY, payloadStr);
  }

  multi.exec();
};

/**
 * Closes the redis client and subscriber client
 */
exports.close = function close() {
  client.end(true);
  client.unref();
  subscriber.end(true);
  subscriber.unref();
};