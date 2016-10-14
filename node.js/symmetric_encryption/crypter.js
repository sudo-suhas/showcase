'use strict';
const crypto = require('crypto');

// Ideally, fetch these from config.crypto
const ALGORITHM = 'aes-256-cbc', // config.crypto.algorithm
  // Can be generated using echo "$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 32)"
  SHARED_SECRET_KEY = 'LlGiq9X589Owe9emgS88E818gYN0hvrt'; // config.crypto.sharedSecretKey

const SAFE_ENCRYPTION_MAP = {
    '+': '-',
    '/': '_',
    '=': '.'
  },
  SAFE_DECRYPTION_MAP = {
    '-': '+',
    '_': '/',
    '.': '='
  }; // eslint-disable-line quote-props

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
    const initVector = crypto.randomBytes(16); // IV is always 16-bytes
    const cipher = crypto.createCipheriv(ALGORITHM, SHARED_SECRET_KEY, initVector);
    const encrypted = cipher.update(text, 'utf8', 'base64') + cipher.final('base64');
    const encryptedText = initVector.toString('base64') + encrypted;
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
    const initVector = new Buffer(encrypted.substring(0, 24), 'base64');
    const encryptedText = encrypted.substring(24);
    const decipher = crypto.createDecipheriv(ALGORITHM, SHARED_SECRET_KEY, initVector);
    return decipher.update(encryptedText, 'base64', 'utf8') + decipher.final('utf8');
  } catch (err) {
    logger.info(`Error while trying to decrypt ${safeEncrypted}`, err);
    return null;
  }
};