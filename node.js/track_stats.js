'use strict';

const StatsD = require('hot-shots'),
    pusage = require('pidusage');

const config = require('./config');

const datadog = new StatsD(config.datadog),
    interval = config.sysStatsInterval,
    pid = process.pid;

// See https://github.com/pebble/event-loop-lag, https://github.com/TabDigital/loop-lag
const lags = [],
    lagCount = 10,
    sampleInterval = interval / lagCount;
let start = process.hrtime(),
    avgLag = 0,
    sampleDataFlag = false;

// Don't use unref (https://github.com/joyent/node/issues/8364)
let timeout = setTimeout(measureLoopDelay, sampleInterval);

/**
 * Measurement of time diff in ms using `process.hrtime(time)`
 * @param {Array} time Output of `process.hrtime()`
 * @returns {Number}
 */
function msTimeDiff(time) {
    const diff = process.hrtime(time);
    return (diff[0] * 1e3) + (diff[1] / 1e6);
}

/**
 * Measure system stats and push to datadog.
 */
function measureLoopDelay() {
    // how much time has actually elapsed in the loop beyond what
    // setTimeout says is supposed to happen. we use setTimeout to
    // cover multiple iterations of the event loop, getting a larger
    // sample of what the process is working on.

    // we use Math.max to handle case where timers are running efficiently
    // and our callback executes earlier than `ms` due to how timers are
    // implemented. this is ok. it means we're healthy.
    const lag = Math.max(0, msTimeDiff(start) - sampleInterval) / sampleInterval * 1000; // Loop lag per second

    lags.push(lag);
    if (sampleDataFlag || lags.length > lagCount) {
        sampleDataFlag = true;
        const evictedLag = lags.shift();
        avgLag += (lag - evictedLag) / lagCount;
    } else {
        // Incremental averageing - http://math.stackexchange.com/questions/106700/incremental-averageing
        avgLag += (lag - avgLag) / lags.length;
    }

    start = process.hrtime();
    timeout = setTimeout(measureLoopDelay, sampleInterval);
}

/**
 * Push system stats to datadog
 */
function pushStats() {
    const memUsage = process.memoryUsage();
    datadog.gauge('process.memory.rss', memUsage.rss);
    datadog.gauge('process.memory.heapTotal', memUsage.heapTotal);
    datadog.gauge('process.memory.heapUsed', memUsage.heapUsed);
    datadog.gauge('process.uptime', process.uptime());
    datadog.gauge('process.event_loop.lag', avgLag);

    pusage.stat(pid, (err, stat) => {
        if (!err) {
            datadog.gauge('process.cpu', stat.cpu);
        }
    });
}

const pushStatsInterval = setInterval(pushStats, interval);

/**
 * Clean up resources and stop scheduled function calls.
 */
function stop() {
    clearTimeout(timeout);
    clearInterval(pushStatsInterval);
    pusage.unmonitor(pid);
    datadog.close();
}

exports.stop = stop;