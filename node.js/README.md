# track stats
The script uses [`hot-shots`](https://github.com/brightcove/hot-shots) a client for StatsD
which is compatible with the customisations in [datadog](http://docs.datadoghq.com/guides/dogstatsd/)

[`pusage`](https://github.com/soyuka/pidusage) is used for getting CPU and memory stats.

## Description
A simple script which will push stats like CPU utilisation, memory and loop lag to datadog.
Rolling average isused for keeping loop lag as accurate as possible.

Just referenceing the file at the start of the app is enough:

```js
const tracker = require('src/track_stats');

// some code

// on shutdown
tracker.stop();
```

### Dashboard Screenshot
Screenshot of DataDog dashboard built using stats captured in StatsD server
![datadog dashboard](datadog_dashboard.png)

## Misc code snippet

#### encryption decryption
<details>
    <summary>Click to expand</summary>
```js
const ALGORITHM = config.crypto.algorithm, // 'aes-256-cbc'
    SHARED_SECRET_KEY = config.crypto.sharedSecretKey; // // echo "$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 32)"

const SAFE_ENCRYPTION_MAP = {'+': '-', '/': '_', '=': '.'},
    SAFE_DECRYPTION_MAP = {'-': '+', '_': '/', '.': '='}; // eslint-disable-line quote-props

// Speed up calls to hasOwnProp
const hasOwnProp = Object.prototype.hasOwnProperty;

/**
 * @param {string} str
 * @returns {string}
 */
function escapeRegExp(str) {
    return str.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, '\\$1');
}

String.prototype.replaceAll = function replaceAll(search, replacement) { // eslint-disable-line no-extend-native
    return this.replace(new RegExp(escapeRegExp(search), 'g'), replacement);
};

/**
 * @param {string} str
 * @param {Object} mapObj
 * @returns {string}
 */
function multiReplaceAll(str, mapObj) {
    let res = str;
    for (const key in mapObj) {
        if (Reflect.apply(hasOwnProp, mapObj, [key])) {
            res = res.replaceAll(key, mapObj[key]);
        }
    }
    return res;
}

/**
 *
 * @param {string} text
 * @returns {String|null}
 */
exports.encrypt = function encrypt(text) {
    if (text === null) {
        return null;
    }
    try {
        const initializationVector = crypto.randomBytes(16); // IV is always 16-bytes
        const cipher = crypto.createCipheriv(ALGORITHM, SHARED_SECRET_KEY, initializationVector);
        const encrypted = cipher.update(text, 'utf8', 'base64') + cipher.final('base64');
        const encryptedText = initializationVector.toString('base64') + encrypted;
        // http://stackoverflow.com/questions/12495746/restrict-characters-used-in-encryption
        return multiReplaceAll(encryptedText, SAFE_ENCRYPTION_MAP);
    } catch (err) {
        logger.info(`Error while trying to encrypt ${text}`, err);
        return null;
    }
};

/**
 * @param {string} safeEncrypted
 * @returns {String|null}
 */
exports.decrypt = function decrypt(safeEncrypted) {
    if (safeEncrypted === null) {
        return null;
    }
    try {
        // http://stackoverflow.com/questions/12495746/restrict-characters-used-in-encryption
        const encrypted = multiReplaceAll(safeEncrypted, SAFE_DECRYPTION_MAP);
        // console.log(`encryptedText ${encrypted}`);
        const initializationVector = new Buffer(encrypted.substring(0, 24), 'base64');
        const encryptedText = encrypted.substring(24);
        const decipher = crypto.createDecipheriv(ALGORITHM, SHARED_SECRET_KEY, initializationVector);
        return decipher.update(encryptedText, 'base64', 'utf8') + decipher.final('utf8');
    } catch (err) {
        logger.info(`Error while trying to decrypt ${safeEncrypted}`, err);
        return null;
    }
};
```
</details>