'use strict';
const fs = require('fs'),
  path = require('path');

const PEG = require('pegjs');

const pegjsPath = path.resolve(__dirname, 'where.pegjs');

const options = {
  cache: false,
  output: 'parser',
  optimize: 'speed',
  trace: false,
  plugins: []
};

const parser = PEG.generate(fs.readFileSync(pegjsPath, 'utf8'), options);

/**
 * Construct where parser for given project
 * @param {string} projectId
 * @constructor
 */
function WhereParser(projectId) {
  if (!new.target) {
    throw new Error('WhereParser() is a constructor and must be invoked with the \'new\' keyword!');
  }
  this.projectId = projectId;
}

/**
 * Parse given expression and return a boolean elasticsearch query
 * @param {string} expression
 * @returns {Object} Bool Query constructed using elastic.js
 */
WhereParser.prototype.parseExpression = function parseExpression(expression) {
  return parser.parse(`project["$prj_${this.projectId}_props"](${expression})`);
};

module.exports = WhereParser;