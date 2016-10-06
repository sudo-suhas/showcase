'use strict';

const WhereParser = require('./where_parser');

// Sorry about this
const hardCodedCondition = '((property["flight_passenger_count"] > 81 ' +
  'and property["ticket_booking_mode"] contain "Airport") ' +
  'or (property["discounted_ticket"] is false))';

console.log('To keep it simple, I am using a hard-coded condition');
console.log('Condition -', hardCodedCondition);
console.log();

console.log('Creating Parser for project id 12345')
const parser = new WhereParser('12345');

console.log('Parsing condition using PEG.js');
const query = parser.parseExpression(hardCodedCondition);
console.log();

console.log('Query - ', JSON.stringify(query.toJSON(), null, 2));