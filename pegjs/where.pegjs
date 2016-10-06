{
  // elastic.js-snippet.js gets included here
}
/*
 * Core PEG
 */
ProjectDocType "Project doc type"
    = (projectType:ProjectType { self.projectType = projectType; } ) expr:Expression  { return expr; }
    / Expression

Expression "Where Expression"
    = '(' head:Expression tail:(And expr:Expression { return expr; })+ ')'
    {
        var conditions = tail;
        conditions.unshift(head);
        return ejs.BoolQuery().must(conditions);
    }
    / '(' head:Expression tail:(Or expr:Expression { return expr; })+ ')'
    {
        var conditions = tail;
        conditions.unshift(head);
        return ejs.BoolQuery().should(conditions);
    }
    / '(' expr:Expression ')' { return expr; }
    / head:PropertyCondition
    torso:(And cond:PropertyCondition { return cond; })+
    tail:(And expr:Expression { return expr;})*
    {
        var conditions = torso.concat(tail);
        conditions.unshift(head);
        return ejs.BoolQuery().must(conditions);
    }
    / head:PropertyCondition
    torso:(And cond:PropertyCondition { return cond; })*
    tail:(And expr:Expression { return expr;})+
    {
        var conditions = torso.concat(tail);
        conditions.unshift(head);
        return ejs.BoolQuery().must(conditions);
    }
    / head:PropertyCondition
    torso:(Or cond:PropertyCondition { return cond; })+
    tail:(Or expr:Expression { return expr;})*
    {
        var conditions = torso.concat(tail);
        conditions.unshift(head);
        return ejs.BoolQuery().should(conditions);
    }
    / head:PropertyCondition
    torso:(Or cond:PropertyCondition { return cond; })*
    tail:(Or expr:Expression { return expr;})+
    {
        var conditions = torso.concat(tail);
        conditions.unshift(head);
        return ejs.BoolQuery().should(conditions);
    }
    / PropertyCondition

PropertyCondition "Property Condition"
    = _ '(' _ cond:PropertyCondition _ ')' _ { return cond; }
    / NumBetweenCondition
    / NumLtCondition
    / NumGtCondition
    / NumLteCondition
    / NumGteCondition
    / NumEqCondition
    / NumNeCondition
    / NumSetContainCondition
    / DateBetweenCondition
    / DateLtCondition
    / DateGtCondition
    / DateLteCondition
    / DateGteCondition
    / DateEqCondition
    / StrContainsCondition
    / StrNotContainsCondition
    / StrEqCondition
    / StrNeCondition
    / StrIsSetCondition
    / StrIsNotSetCondition
    / StrSetContainCondition
    / BooleanCondition

/*
 * Numeric property conditions
 */
NumBetweenCondition "Number property in between condition"
    = lte:NumLteCondition And gte:NumGteCondition { return ejs.BoolQuery().must([lte, gte]); }
    / gte:NumGteCondition And lte:NumLteCondition { return ejs.BoolQuery().must([lte, gte]); }

NumLteCondition "Number property less than or equal to condition"
    = key:PropertyKey LteOperand value:NumericValue { return ejs.RangeQuery(key).lte(value); }

NumGteCondition "Number property greater than or equal to condition"
    = key:PropertyKey GteOperand value:NumericValue { return ejs.RangeQuery(key).gte(value); }

NumLtCondition "Number property less than condition"
    = key:PropertyKey LtOperand value:NumericValue { return ejs.RangeQuery(key).lt(value); }

NumGtCondition "Number property greater than condition"
    = key:PropertyKey GtOperand value:NumericValue { return ejs.RangeQuery(key).gt(value); }

NumEqCondition "Number property equality condition"
    = key:PropertyKey EqOperand value:NumericValue { return ejs.TermQuery(key, value); }

NumNeCondition "Number property inequality condition"
    = key:PropertyKey NeOperand value:NumericValue
    {
      return ejs.BoolQuery()
        .must(ejs.ExistsQuery(key))
        .mustNot(ejs.TermQuery(key, value));
    }

NumSetContainCondition "Number set contains condition"
    = key:PropertyKey SetContainOperand value:NumericValue { return ejs.TermQuery(key, value); }

/*
 * Date property condition
 */
DateBetweenCondition "Date property in between condition"
    = lte:DateLteCondition And gte:DateGteCondition { return ejs.BoolQuery().must([lte, gte]); }
    / gte:DateGteCondition And lte:DateLteCondition { return ejs.BoolQuery().must([lte, gte]); }

DateLteCondition "Date property less than or equal to condition"
    = key:PropertyKey LteOperand value:DateValue { return ejs.RangeQuery(key).lte(value.getTime()); }

DateGteCondition "Date property greater than or equal to condition"
    = key:PropertyKey GteOperand value:DateValue { return ejs.RangeQuery(key).gte(value.getTime()); }

DateLtCondition "Date property less than condition"
    = key:PropertyKey LtOperand value:DateValue { return ejs.RangeQuery(key).lt(value.getTime()); }

DateGtCondition "Date property greater than condition"
    = key:PropertyKey GtOperand value:DateValue { return ejs.RangeQuery(key).gt(value.getTime()); }

DateEqCondition "Date property equality condition"
    = key:PropertyKey EqOperand value:DateValue { return ejs.TermQuery(key, value.getTime()); }

/*
 * String property conditions
 */
StrContainsCondition "String property contains condition"
    = key:PropertyKey ContainOperand value:StringValue { return ejs.MatchQuery(key, value); }

StrNotContainsCondition "String property does not contains condition"
    = key:PropertyKey NotContainOperand value:StringValue
    { return ejs.BoolQuery()
        .must(ejs.ExistsQuery(key))
        .mustNot(ejs.MatchQuery(key, value)); }

StrEqCondition "String property equality condition"
    = key:PropertyKey EqOperand value:StringValue
    {
      let fieldName;

      // TODO: Move logic to function searchableField
      if (key.startsWith(self.projectType) || self.analyzedSysFields.indexOf(key) >= 0) {
        // Not a System field, not analyzed fields(comments or email)
        fieldName = key + '.raw';
      } else {
        // System string fields are not analyzed
        fieldName = key;
      }

      return ejs.TermQuery(fieldName, value);
    }

StrNeCondition "String property inequality condition"
    = key:PropertyKey NeOperand value:StringValue
    {
      let fieldName;

      if (key.startsWith(self.projectType) || self.analyzedSysFields.indexOf(key) >= 0) {
        // Not a System field, not analyzed fields(comments or email)
        fieldName = key + '.raw';
      } else {
        // System string fields are not analyzed
        fieldName = key;
      }

      return ejs.BoolQuery()
        .must(ejs.ExistsQuery(key))
        .mustNot(ejs.TermQuery(fieldName, value));
    }

StrIsSetCondition "String property is set"
    = key:PropertyKey IsSetOperand { return ejs.ExistsQuery(key); }

StrIsNotSetCondition "String property is not set"
    = key:PropertyKey IsNotSetOperand { return ejs.BoolQuery().mustNot(ejs.ExistsQuery(key)); }

StrSetContainCondition "String set contains condition"
    = key:PropertyKey SetContainOperand value:StringValue
    {

      let fieldName;

      if (key.startsWith(self.projectType) || self.analyzedSysFields.indexOf(key) >= 0) {
        // Not a System field, not analyzed fields(comments or email)
        fieldName = key + '.raw';
      } else {
        // System string fields are not analyzed
        fieldName = key;
      }

      return ejs.TermQuery(fieldName, value);
    }

/*
 * Boolean property condition
 */
BooleanCondition "Boolean condition"
    = key:PropertyKey BooleanOperand value:BooleanValue { return ejs.TermQuery(key, value); }

/*
 * Property Keys, operands and property values
 */
ProjectType "project type"
    = begin_project chars:char+ end_project { return chars.join(''); }

PropertyKey "Property key"
    = begin_property chars:char+ end_property { return chars[0] !== '$' ? self.projectType + '.' + chars.join('') : chars.join(''); }

EqOperand "Equal operand"
    = _ "==" _

NeOperand "Not equal operand"
    = _ "!=" _

LtOperand "Less than operand"
    = _ "<" _

GtOperand "Greater than operand"
    = _ ">" _

LteOperand "Less than or equal to operand"
    = _ "<=" _

GteOperand "Greater than or equal to operand"
    = _ ">=" _

SetContainOperand "Set contains operand"
    = _ "setcontain" _

ContainOperand "Contains operand"
    = _ "contain" _

NotContainOperand "Contains operand"
    = _ "notcontain" _

IsSetOperand "Is set operand"
    = _ "isset" _

IsNotSetOperand "Is not set operand"
    = _ "isnotset" _

BooleanOperand "Boolean(is) operand"
    = _ "is" _

NumericValue "Numeric Value"
    = quotation_mark val:NumericValue quotation_mark { return val; }
    / minus? int frac? exp? { return parseFloat(text()); }

DateValue "Date Value"
    = quotation_mark val:DateValue quotation_mark { return val; }
    / _ iso_date_time _ { return new Date(text().trim()); }

StringValue "String value"
    = quotation_mark chars:char* quotation_mark { return chars.join(""); }

BooleanValue "Boolean Value"
    = quotation_mark val:BooleanValue quotation_mark { return val; }
    / _ val:("true"/"false") _ { return val === 'true'; }

/*
 * Supporting identifiers
 */
Or "or condition"
    = _ "or" _

And "and condition"
    = _ "and" _

begin_project = _ 'project["'
end_project = '"]' _

begin_property = _ 'property["'
end_property = '"]' _


/* ----- Numbers ----- */
decimal_point = "."
digit1_9      = [1-9]
e             = [eE]
exp           = e (minus / plus)? DIGIT+
frac          = decimal_point DIGIT+
int           = zero / (digit1_9 DIGIT*)
minus         = "-"
plus          = "+"
zero = "0"

/* ----- Strings ----- */
char
    = unescaped
  / escape
    sequence:(
        '"'
      / "\\"
      / "/"
      / "b" { return "\b"; }
      / "f" { return "\f"; }
      / "n" { return "\n"; }
      / "r" { return "\r"; }
      / "t" { return "\t"; }
      / "u" digits:$(HEXDIG HEXDIG HEXDIG HEXDIG) {
          return String.fromCharCode(parseInt(digits, 16));
        }
    )
    { return sequence; }

escape         = "\\"
quotation_mark = '"'
unescaped = [^\0-\x1F\x22\x5C]

DIGIT  = [0-9]
HEXDIG = [0-9a-f]i

/* Date */
iso_date_time
    = date ("T" time)?  { return text(); }

date_century
    // 00-99
    = $(DIGIT DIGIT) { return text(); }

date_decade
    // 0-9
    = DIGIT  { return text(); }

date_subdecade
    // 0-9
    = DIGIT  { return text(); }

date_year
    = date_decade date_subdecade  { return text(); }

date_fullyear
    = date_century date_year  { return text(); }

date_month
    // 01-12
    = $(DIGIT DIGIT)  { return text(); }

date_wday
    // 1-7
    // 1 is Monday, 7 is Sunday
    = DIGIT  { return text(); }

date_mday
    // 01-28, 01-29, 01-30, 01-31 based on
    // month/year
    = $(DIGIT DIGIT)  { return text(); }

date_yday
    // 001-365, 001-366 based on year
    = $(DIGIT DIGIT DIGIT)  { return text(); }

date_week
    // 01-52, 01-53 based on year
    = $(DIGIT DIGIT)  { return text(); }

datepart_fullyear
    = date_century? date_year "-"?  { return text(); }

datepart_ptyear
    = "-" (date_subdecade "-"?)?  { return text(); }

datepart_wkyear
    = datepart_ptyear
    / datepart_fullyear

dateopt_century
    = "-"
    / date_century

dateopt_fullyear
    = "-"
    / datepart_fullyear

dateopt_year
    = "-"
    / date_year "-"?

dateopt_month
    = "-"
    / date_month "-"?

dateopt_week
    = "-"
    / date_week "-"?

datespec_full
    = datepart_fullyear date_month "-"? date_mday  { return text(); }

datespec_year
    = date_century
    / dateopt_century date_year

datespec_month
    = "-" dateopt_year date_month ("-"? date_mday)  { return text(); }

datespec_mday
    = "--" dateopt_month date_mday  { return text(); }

datespec_week
    = datepart_wkyear "W" (date_week / dateopt_week date_wday)  { return text(); }

datespec_wday
    = "---" date_wday  { return text(); }

datespec_yday
    = dateopt_fullyear date_yday  { return text(); }

date
    = datespec_full
    / datespec_year
    / datespec_month
    / datespec_mday
    / datespec_week
    / datespec_wday
    / datespec_yday


/* Time */
time_hour
    // 00-24
    = $(DIGIT DIGIT)  { return text(); }

time_minute
    // 00-59
    = $(DIGIT DIGIT)  { return text(); }

time_second
    // 00-58, 00-59, 00-60 based on
    // leap-second rules
    = $(DIGIT DIGIT)  { return text(); }

time_fraction
    = ("," / ".") $(DIGIT+)  { return text(); }

time_numoffset
    = ("+" / "-") time_hour (":"? time_minute)?  { return text(); }

time_zone
    = "Z"
    / time_numoffset

timeopt_hour
    = "-"
    / time_hour ":"?

timeopt_minute
    = "-"
    / time_minute ":"?

timespec_hour
    = time_hour (":"? time_minute (":"? time_second)?)?  { return text(); }

timespec_minute
    = timeopt_hour time_minute (":"? time_second)?  { return text(); }

timespec_second
    = "-" timeopt_minute time_second  { return text(); }

timespec_base
    = timespec_hour
    / timespec_minute
    / timespec_second

time
    = timespec_base time_fraction? time_zone?  { return text(); }

_ "whitespace"
    = [ \t\n\r]*