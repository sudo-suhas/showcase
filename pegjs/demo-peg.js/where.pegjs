{
    const self = this;

    self.analyzedSysFields = ['$comments', '$email'];

    var
    // from underscore.js, used in utils
        ArrayProto = Array.prototype,
        ObjProto = Object.prototype,
        slice = ArrayProto.slice,
        toString = ObjProto.toString,
        hasOwnProp = ObjProto.hasOwnProperty,
        nativeForEach = ArrayProto.forEach,
        nativeIsArray = Array.isArray,
        nativeIndexOf = ArrayProto.indexOf,
        breaker = {},
        has,
        each,
        extend,
        indexOf,
        isArray,
        isObject,
        isString,
        isNumber,
        isBoolean,
        isFunction,
        isEJSObject, // checks if valid ejs object
        isQuery, // checks valid ejs Query object

    // create ejs object
        ejs = {};

    /* Utility methods, most of which are pulled from underscore.js. */

    // Shortcut function for checking if an object has a given property directly
    // on itself (in other words, not on a prototype).
    has = function(obj, key) {
        return hasOwnProp.call(obj, key);
    };

    // The cornerstone, an `each` implementation, aka `forEach`.
    // Handles objects with the built-in `forEach`, arrays, and raw objects.
    // Delegates to **ECMAScript 5**'s native `forEach` if available.
    each = function(obj, iterator, context) {
        if (obj == null) {
            return;
        }
        if (nativeForEach && obj.forEach === nativeForEach) {
            obj.forEach(iterator, context);
        } else if (obj.length === +obj.length) {
            for (var i = 0, l = obj.length; i < l; i++) {
                if (iterator.call(context, obj[i], i, obj) === breaker) {
                    return;
                }
            }
        } else {
            for (var key in obj) {
                if (has(obj, key)) {
                    if (iterator.call(context, obj[key], key, obj) === breaker) {
                        return;
                    }
                }
            }
        }
    };

    // Extend a given object with all the properties in passed-in object(s).
    extend = function(obj) {
        each(slice.call(arguments, 1), function(source) {
            for (var prop in source) {
                obj[prop] = source[prop];
            }
        });
        return obj;
    };

    // Returns the index at which value can be found in the array, or -1 if
    // value is not present in the array.
    indexOf = function(array, item) {
        if (array == null) {
            return -1;
        }

        var i = 0,
            l = array.length;
        if (nativeIndexOf && array.indexOf === nativeIndexOf) {
            return array.indexOf(item);
        }

        for (; i < l; i++) {
            if (array[i] === item) {
                return i;

            }
        }

        return -1;
    };

    // Is a given value an array?
    // Delegates to ECMA5's native Array.isArray
    // switched to ===, not sure why underscore used ==
    isArray = nativeIsArray || function(obj) {
            return toString.call(obj) === '[object Array]';
        };

    // Is a given variable an object?
    isObject = function(obj) {
        return obj === Object(obj);
    };

    // switched to ===, not sure why underscore used ==
    isString = function(obj) {
        return toString.call(obj) === '[object String]';
    };

    // switched to ===, not sure why underscore used ==
    isNumber = function(obj) {
        return toString.call(obj) === '[object Number]';
    };

    isBoolean = function(obj) {
        return obj === true || obj === false || toString.call(obj) === '[object Boolean]';
    };

    // switched to ===, not sure why underscore used ==
    if (typeof(/./) !== 'function') {
        isFunction = function(obj) {
            return typeof obj === 'function';
        };
    } else {
        isFunction = function(obj) {
            return toString.call(obj) === '[object Function]';
        };
    }

    // Is a given value an ejs object?
    // Yes if object and has "_type", "toJSON", and "toString" properties
    isEJSObject = function(obj) {
        return (isObject(obj) &&
        has(obj, '_type') &&
        has(obj, 'toJSON'));
    };

    isQuery = function(obj) {
        return (isEJSObject(obj) && obj._type() === 'query');
    };

    /**
     @mixin
     <p>The DirectSettingsMixin provides support for common options used across
     various <code>Suggester</code> implementations.  This object should not be
     used directly.</p>

     @name ejs.DirectSettingsMixin

     @param {string} settings The object to set the options on.
     */
    ejs.DirectSettingsMixin = function(settings) {

        return {

            /**
             <p>Sets the accuracy.  How similar the suggested terms at least
             need to be compared to the original suggest text.</p>

             @member ejs.DirectSettingsMixin
             @param {Double} a A positive double value between 0 and 1.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            accuracy: function(a) {
                if (a == null) {
                    return settings.accuracy;
                }

                settings.accuracy = a;
                return this;
            },

            /**
             <p>Sets the suggest mode.  Valid values are:</p>

             <dl>
             <dd><code>missing</code> - Only suggest terms in the suggest text that aren't in the index</dd>
             <dd><code>popular</code> - Only suggest suggestions that occur in more docs then the original suggest text term</dd>
             <dd><code>always</code> - Suggest any matching suggestions based on terms in the suggest text</dd>
             </dl>

             @member ejs.DirectSettingsMixin
             @param {string} m The mode of missing, popular, or always.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            suggestMode: function(m) {
                if (m == null) {
                    return settings.suggest_mode;
                }

                m = m.toLowerCase();
                if (m === 'missing' || m === 'popular' || m === 'always') {
                    settings.suggest_mode = m;
                }

                return this;
            },

            /**
             <p>Sets the sort mode.  Valid values are:</p>

             <dl>
             <dd><code>score</code> - Sort by score first, then document frequency, and then the term itself</dd>
             <dd><code>frequency</code> - Sort by document frequency first, then simlarity score and then the term itself</dd>
             </dl>

             @member ejs.DirectSettingsMixin
             @param {string} s The score type of score or frequency.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            sort: function(s) {
                if (s == null) {
                    return settings.sort;
                }

                s = s.toLowerCase();
                if (s === 'score' || s === 'frequency') {
                    settings.sort = s;
                }

                return this;
            },

            /**
             <p>Sets what string distance implementation to use for comparing
             how similar suggested terms are.  Valid values are:</p>

             <dl>
             <dd><code>internal</code> - based on damerau_levenshtein but but highly optimized for comparing string distance for terms inside the index</dd>
             <dd><code>damerau_levenshtein</code> - String distance algorithm based on Damerau-Levenshtein algorithm</dd>
             <dd><code>levenstein</code> - String distance algorithm based on Levenstein edit distance algorithm</dd>
             <dd><code>jarowinkler</code> - String distance algorithm based on Jaro-Winkler algorithm</dd>
             <dd><code>ngram</code> - String distance algorithm based on character n-grams</dd>
             </dl>

             @member ejs.DirectSettingsMixin
             @param {string} s The string distance algorithm name.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            stringDistance: function(s) {
                if (s == null) {
                    return settings.string_distance;
                }

                s = s.toLowerCase();
                if (s === 'internal' || s === 'damerau_levenshtein' ||
                    s === 'levenstein' || s === 'jarowinkler' || s === 'ngram') {
                    settings.string_distance = s;
                }

                return this;
            },

            /**
             <p>Sets the maximum edit distance candidate suggestions can have
             in order to be considered as a suggestion.</p>

             @member ejs.DirectSettingsMixin
             @param {Integer} max An integer value greater than 0.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            maxEdits: function(max) {
                if (max == null) {
                    return settings.max_edits;
                }

                settings.max_edits = max;
                return this;
            },

            /**
             <p>The factor that is used to multiply with the size in order
             to inspect more candidate suggestions.</p>

             @member ejs.DirectSettingsMixin
             @param {Integer} max A positive integer value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            maxInspections: function(max) {
                if (max == null) {
                    return settings.max_inspections;
                }

                settings.max_inspections = max;
                return this;
            },

            /**
             <p>Sets a maximum threshold in number of documents a suggest text
             token can exist in order to be corrected.</p>

             @member ejs.DirectSettingsMixin
             @param {Double} max A positive double value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            maxTermFreq: function(max) {
                if (max == null) {
                    return settings.max_term_freq;
                }

                settings.max_term_freq = max;
                return this;
            },

            /**
             <p>Sets the number of minimal prefix characters that must match in
             order be a candidate suggestion.</p>

             @member ejs.DirectSettingsMixin
             @param {Integer} len A positive integer value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            prefixLen: function(len) {
                if (len == null) {
                    return settings.prefix_len;
                }

                settings.prefix_len = len;
                return this;
            },

            /**
             <p>Sets the minimum length a suggest text term must have in order
             to be corrected.</p>

             @member ejs.DirectSettingsMixin
             @param {Integer} len A positive integer value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            minWordLen: function(len) {
                if (len == null) {
                    return settings.min_word_len;
                }

                settings.min_word_len = len;
                return this;
            },

            /**
             <p>Sets a minimal threshold of the number of documents a suggested
             term should appear in.</p>

             @member ejs.DirectSettingsMixin
             @param {Double} min A positive double value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            minDocFreq: function(min) {
                if (min == null) {
                    return settings.min_doc_freq;
                }

                settings.min_doc_freq = min;
                return this;
            }

        };
    };

    /**
     @mixin
     <p>The QueryMixin provides support for common options used across
     various <code>Query</code> implementations.  This object should not be
     used directly.</p>

     @name ejs.QueryMixin
     */
    ejs.QueryMixin = function(type) {

        var query = {};
        query[type] = {};

        return {

            /**
             Sets the boost value for documents matching the <code>Query</code>.

             @member ejs.QueryMixin
             @param {Double} boost A positive <code>double</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            boost: function(boost) {
                if (boost == null) {
                    return query[type].boost;
                }

                query[type].boost = boost;
                return this;
            },

            /**
             The type of ejs object.  For internal use only.

             @member ejs.QueryMixin
             @returns {string} the type of object
             */
            _type: function() {
                return 'query';
            },

            /**
             Retrieves the internal <code>query</code> object. This is typically used by
             internal API functions so use with caution.

             @member ejs.QueryMixin
             @returns {string} returns this object's internal <code>query</code> property.
             */
            toJSON: function() {
                return query;
            }

        };
    };

    /**
     @class
         <p>An existsFilter matches documents where the specified field is present
     and the field contains a legitimate value.</p>

     @name ejs.ExistsFilter
     @ejs filter
     @borrows ejs.FilterMixin.name as name
     @borrows ejs.FilterMixin.cache as cache
     @borrows ejs.FilterMixin.cacheKey as cacheKey
     @borrows ejs.FilterMixin._type as _type
     @borrows ejs.FilterMixin.toJSON as toJSON

     @desc
     Filters documents where a specified field exists and contains a value.

     @param {string} fieldName the field name that must exists and contain a value.
     */
    ejs.ExistsQuery = function(fieldName) {

        var
            _common = ejs.QueryMixin('exists'),
            query = _common.toJSON();

        query.exists.field = fieldName;

        return extend(_common, {

            /**
             Sets the field to check for missing values.

             @member ejs.ExistsFilter
             @param {string} name A name of the field.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            field: function(name) {
                if (name == null) {
                    return query.exists.field;
                }

                query.exists.field = name;
                return this;
            }

        });
    };

    /**
     @class
         <p>Filters documents with fields that have values within a certain numeric
     range. Similar to range filter, except that it works only with numeric
     values, and the filter execution works differently.</p>

     <p>The numeric range filter works by loading all the relevant field values
     into memory, and checking for the relevant docs if they satisfy the range
     requirements. This requires more memory since the numeric range data are
     loaded to memory, but can provide a significant increase in performance.</p>

     <p>Note, if the relevant field values have already been loaded to memory,
     for example because it was used in facets or was sorted on, then this
     filter should be used.</p>

     @name ejs.NumericRangeFilter
     @ejs filter
     @borrows ejs.FilterMixin.name as name
     @borrows ejs.FilterMixin.cache as cache
     @borrows ejs.FilterMixin.cacheKey as cacheKey
     @borrows ejs.FilterMixin._type as _type
     @borrows ejs.FilterMixin.toJSON as toJSON

     @desc
     A Filter that only accepts numeric values within a specified range.

     @param {string} fieldName The name of the field to filter on.
     */
    ejs.NumericRangeQuery = function(fieldName) {

        var
            _common = ejs.QueryMixin('numeric_range'),
            query = _common.toJSON();

        query.numeric_range[fieldName] = {};

        return extend(_common, {

            /**
             Returns the field name used to create this object.

             @member ejs.NumericRangeFilter
             @param {string} field the field name
             @returns {Object} returns <code>this</code> so that calls can be
             chained. Returns {string}, field name when field is not specified.
             */
            field: function(field) {
                var oldValue = query.numeric_range[fieldName];

                if (field == null) {
                    return fieldName;
                }

                delete query.numeric_range[fieldName];
                fieldName = field;
                query.numeric_range[fieldName] = oldValue;

                return this;
            },

            /**
             Sets the endpoint for the current range.

             @member ejs.NumericRangeFilter
             @param {number} startPoint A numeric value representing the start of the range
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            from: function(from) {
                if (from == null) {
                    return filter.numeric_range[fieldName].from;
                }

                if (!isNumber(from)) {
                    throw new TypeError('Argument must be a numeric value');
                }

                filter.numeric_range[fieldName].from = from;
                return this;
            },

            /**
             Sets the endpoint for the current range.

             @member ejs.NumericRangeFilter
             @param {number} endPoint A numeric value representing the end of the range
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            to: function(to) {
                if (to == null) {
                    return filter.numeric_range[fieldName].to;
                }

                if (!isNumber(to)) {
                    throw new TypeError('Argument must be a numeric value');
                }

                filter.numeric_range[fieldName].to = to;
                return this;
            },

            /**
             Should the first from (if set) be inclusive or not.
             Defaults to true

             @member ejs.NumericRangeFilter
             @param {Boolean} trueFalse true to include, false to exclude
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            includeLower: function(trueFalse) {
                if (trueFalse == null) {
                    return filter.numeric_range[fieldName].include_lower;
                }

                filter.numeric_range[fieldName].include_lower = trueFalse;
                return this;
            },

            /**
             Should the last to (if set) be inclusive or not. Defaults to true.

             @member ejs.NumericRangeFilter
             @param {Boolean} trueFalse true to include, false to exclude
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            includeUpper: function(trueFalse) {
                if (trueFalse == null) {
                    return filter.numeric_range[fieldName].include_upper;
                }

                filter.numeric_range[fieldName].include_upper = trueFalse;
                return this;
            },

            /**
             Greater than value.  Same as setting from to the value, and
             include_lower to false,

             @member ejs.NumericRangeFilter
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            gt: function(val) {
                if (val == null) {
                    return filter.numeric_range[fieldName].gt;
                }

                if (!isNumber(val)) {
                    throw new TypeError('Argument must be a numeric value');
                }

                filter.numeric_range[fieldName].gt = val;
                return this;
            },

            /**
             Greater than or equal to value.  Same as setting from to the value,
             and include_lower to true.

             @member ejs.NumericRangeFilter
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            gte: function(val) {
                if (val == null) {
                    return filter.numeric_range[fieldName].gte;
                }

                if (!isNumber(val)) {
                    throw new TypeError('Argument must be a numeric value');
                }

                filter.numeric_range[fieldName].gte = val;
                return this;
            },

            /**
             Less than value.  Same as setting to to the value, and include_upper
             to false.

             @member ejs.NumericRangeFilter
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            lt: function(val) {
                if (val == null) {
                    return filter.numeric_range[fieldName].lt;
                }

                if (!isNumber(val)) {
                    throw new TypeError('Argument must be a numeric value');
                }

                filter.numeric_range[fieldName].lt = val;
                return this;
            },

            /**
             Less than or equal to value.  Same as setting to to the value,
             and include_upper to true.

             @member ejs.NumericRangeFilter
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            lte: function(val) {
                if (val == null) {
                    return filter.numeric_range[fieldName].lte;
                }

                if (!isNumber(val)) {
                    throw new TypeError('Argument must be a numeric value');
                }

                filter.numeric_range[fieldName].lte = val;
                return this;
            }

        });
    };

    /**
     @class
         <p>Matches documents with fields that have terms within a certain range.</p>

     @name ejs.RangeFilter
     @ejs filter
     @borrows ejs.FilterMixin.name as name
     @borrows ejs.FilterMixin.cache as cache
     @borrows ejs.FilterMixin.cacheKey as cacheKey
     @borrows ejs.FilterMixin._type as _type
     @borrows ejs.FilterMixin.toJSON as toJSON

     @desc
     Filters documents with fields that have terms within a certain range.

     @param {string} field A valid field name.
     */
    ejs.RangeQuery = function(field) {

        var
            _common = ejs.QueryMixin('range'),
            query = _common.toJSON();

        query.range[field] = {};

        return extend(_common, {

            /**
             The field to run the filter against.

             @member ejs.RangeFilter
             @param {string} f A single field name.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            field: function(f) {
                var oldValue = query.range[field];

                if (f == null) {
                    return field;
                }

                delete query.range[field];
                field = f;
                query.range[f] = oldValue;

                return this;
            },

            /**
             The lower bound. Defaults to start from the first.

             @member ejs.RangeFilter
             @param {*} f the lower bound value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            from: function(f) {
                if (f == null) {
                    return filter.range[field].from;
                }

                filter.range[field].from = f;
                return this;
            },

            /**
             The upper bound. Defaults to unbounded.

             @member ejs.RangeFilter
             @param {*} t the upper bound value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            to: function(t) {
                if (t == null) {
                    return filter.range[field].to;
                }

                filter.range[field].to = t;
                return this;
            },

            /**
             Should the first from (if set) be inclusive or not.
             Defaults to true

             @member ejs.RangeFilter
             @param {Boolean} trueFalse true to include, false to exclude
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            includeLower: function(trueFalse) {
                if (trueFalse == null) {
                    return filter.range[field].include_lower;
                }

                filter.range[field].include_lower = trueFalse;
                return this;
            },

            /**
             Should the last to (if set) be inclusive or not. Defaults to true.

             @member ejs.RangeFilter
             @param {Boolean} trueFalse true to include, false to exclude
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            includeUpper: function(trueFalse) {
                if (trueFalse == null) {
                    return filter.range[field].include_upper;
                }

                filter.range[field].include_upper = trueFalse;
                return this;
            },

            /**
             Greater than value.  Same as setting from to the value, and
             include_lower to false,

             @member ejs.RangeFilter
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            gt: function(val) {
                if (val == null) {
                    return filter.range[field].gt;
                }

                filter.range[field].gt = val;
                return this;
            },

            /**
             Greater than or equal to value.  Same as setting from to the value,
             and include_lower to true.

             @member ejs.RangeFilter
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            gte: function(val) {
                if (val == null) {
                    return filter.range[field].gte;
                }

                filter.range[field].gte = val;
                return this;
            },

            /**
             Less than value.  Same as setting to to the value, and include_upper
             to false.

             @member ejs.RangeFilter
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            lt: function(val) {
                if (val == null) {
                    return filter.range[field].lt;
                }

                filter.range[field].lt = val;
                return this;
            },

            /**
             Less than or equal to value.  Same as setting to to the value,
             and include_upper to true.

             @member ejs.RangeFilter
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            lte: function(val) {
                if (val == null) {
                    return filter.range[field].lte;
                }

                filter.range[field].lte = val;
                return this;
            }

        });
    };

    /**
     @class
         <p>A <code>boolQuery</code> allows you to build <em>Boolean</em> query constructs
     from individual term or phrase queries. For example you might want to search
     for documents containing the terms <code>javascript</code> and <code>python</code>.</p>

     @name ejs.BoolQuery
     @ejs query
     @borrows ejs.QueryMixin.boost as boost
     @borrows ejs.QueryMixin._type as _type
     @borrows ejs.QueryMixin.toJSON as toJSON

     @desc
     A Query that matches documents matching boolean combinations of other
     queries, e.g. <code>termQuerys, phraseQuerys</code> or other <code>boolQuerys</code>.

     */
    ejs.BoolQuery = function() {

        var
            _common = ejs.QueryMixin('bool'),
            query = _common.toJSON();

        return extend(_common, {

            /**
             Adds query to boolean container. Given query "must" appear in matching documents.

             @member ejs.BoolQuery
             @param {Object} oQuery A valid <code>Query</code> object
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            must: function(oQuery) {
                var i, len;

                if (query.bool.must == null) {
                    query.bool.must = [];
                }

                if (oQuery == null) {
                    return query.bool.must;
                }

                if (isQuery(oQuery)) {
                    query.bool.must.push(oQuery.toJSON());
                } else if (isArray(oQuery)) {
                    query.bool.must = [];
                    for (i = 0, len = oQuery.length; i < len; i++) {
                        if (!isQuery(oQuery[i])) {
                            throw new TypeError('Argument must be an array of Queries');
                        }

                        query.bool.must.push(oQuery[i].toJSON());
                    }
                } else {
                    throw new TypeError('Argument must be a Query or array of Queries');
                }

                return this;
            },

            /**
             Adds query to boolean container. Given query "must not" appear in matching documents.

             @member ejs.BoolQuery
             @param {Object} oQuery A valid query object
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            mustNot: function(oQuery) {
                var i, len;

                if (query.bool.must_not == null) {
                    query.bool.must_not = [];
                }

                if (oQuery == null) {
                    return query.bool.must_not;
                }

                if (isQuery(oQuery)) {
                    query.bool.must_not.push(oQuery.toJSON());
                } else if (isArray(oQuery)) {
                    query.bool.must_not = [];
                    for (i = 0, len = oQuery.length; i < len; i++) {
                        if (!isQuery(oQuery[i])) {
                            throw new TypeError('Argument must be an array of Queries');
                        }

                        query.bool.must_not.push(oQuery[i].toJSON());
                    }
                } else {
                    throw new TypeError('Argument must be a Query or array of Queries');
                }

                return this;
            },

            /**
             Adds query to boolean container. Given query "should" appear in matching documents.

             @member ejs.BoolQuery
             @param {Object} oQuery A valid query object
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            should: function(oQuery) {
                var i, len;

                if (query.bool.should == null) {
                    query.bool.should = [];
                }

                if (oQuery == null) {
                    return query.bool.should;
                }

                if (isQuery(oQuery)) {
                    query.bool.should.push(oQuery.toJSON());
                } else if (isArray(oQuery)) {
                    query.bool.should = [];
                    for (i = 0, len = oQuery.length; i < len; i++) {
                        if (!isQuery(oQuery[i])) {
                            throw new TypeError('Argument must be an array of Queries');
                        }

                        query.bool.should.push(oQuery[i].toJSON());
                    }
                } else {
                    throw new TypeError('Argument must be a Query or array of Queries');
                }

                return this;
            },

            /**
             Sets if the <code>Query</code> should be enhanced with a
             <code>MatchAllQuery</code> in order to act as a pure exclude when
             only negative (mustNot) clauses exist. Default: true.

             @member ejs.BoolQuery
             @param {string} trueFalse A <code>true/false</code value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            adjustPureNegative: function(trueFalse) {
                if (trueFalse == null) {
                    return query.bool.adjust_pure_negative;
                }

                query.bool.adjust_pure_negative = trueFalse;
                return this;
            },

            /**
             Enables or disables similarity coordinate scoring of documents
             matching the <code>Query</code>. Default: false.

             @member ejs.BoolQuery
             @param {string} trueFalse A <code>true/false</code value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            disableCoord: function(trueFalse) {
                if (trueFalse == null) {
                    return query.bool.disable_coord;
                }

                query.bool.disable_coord = trueFalse;
                return this;
            },

            /**
             <p>Sets the number of optional clauses that must match.</p>

             <p>By default no optional clauses are necessary for a match
             (unless there are no required clauses).  If this method is used,
             then the specified number of clauses is required.</p>

             <p>Use of this method is totally independent of specifying that
             any specific clauses are required (or prohibited).  This number will
             only be compared against the number of matching optional clauses.</p>

             @member ejs.BoolQuery
             @param {Integer} minMatch A positive <code>integer</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            minimumNumberShouldMatch: function(minMatch) {
                if (minMatch == null) {
                    return query.bool.minimum_number_should_match;
                }

                query.bool.minimum_number_should_match = minMatch;
                return this;
            }

        });
    };

    /**
     @class
         <p>This query can be used to match all the documents
     in a given set of collections and/or types.</p>

     @name ejs.MatchAllQuery
     @ejs query
     @borrows ejs.QueryMixin.boost as boost
     @borrows ejs.QueryMixin._type as _type
     @borrows ejs.QueryMixin.toJSON as toJSON

     @desc
     <p>A query that returns all documents.</p>

     */
    ejs.MatchAllQuery = function() {
        return ejs.QueryMixin('match_all');
    };

    /**
     @class
         A <code>MatchQuery</code> is a type of <code>Query</code> that accepts
     text/numerics/dates, analyzes it, generates a query based on the
     <code>MatchQuery</code> type.

     @name ejs.MatchQuery
     @ejs query
     @borrows ejs.QueryMixin._type as _type
     @borrows ejs.QueryMixin.toJSON as toJSON

     @desc
     A Query that appects text, analyzes it, generates internal query based
     on the MatchQuery type.

     @param {string} field the document field/field to query against
     @param {string} qstr the query string
     */
    ejs.MatchQuery = function(field, qstr) {

        var
            _common = ejs.QueryMixin('match'),
            query = _common.toJSON();

        query.match[field] = {
            query: qstr
        };

        return extend(_common, {

            /**
             Sets the query string for the <code>Query</code>.

             @member ejs.MatchQuery
             @param {string} qstr The query string to search for.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            query: function(qstr) {
                if (qstr == null) {
                    return query.match[field].query;
                }

                query.match[field].query = qstr;
                return this;
            },

            /**
             Sets the type of the <code>MatchQuery</code>.  Valid values are
             boolean, phrase, and phrase_prefix.

             @member ejs.MatchQuery
             @param {string} type Any of boolean, phrase, phrase_prefix.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            type: function(type) {
                if (type == null) {
                    return query.match[field].type;
                }

                type = type.toLowerCase();
                if (type === 'boolean' || type === 'phrase' || type === 'phrase_prefix') {
                    query.match[field].type = type;
                }

                return this;
            },

            /**
             Sets the fuzziness value for the <code>Query</code>.

             @member ejs.MatchQuery
             @param {Double} fuzz A <code>double</code> value between 0.0 and 1.0.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fuzziness: function(fuzz) {
                if (fuzz == null) {
                    return query.match[field].fuzziness;
                }

                query.match[field].fuzziness = fuzz;
                return this;
            },

            /**
             Sets the maximum threshold/frequency to be considered a low
             frequency term in a <code>CommonTermsQuery</code>.
             Set to a value between 0 and 1.

             @member ejs.MatchQuery
             @param {number} freq A positive <code>double</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            cutoffFrequency: function(freq) {
                if (freq == null) {
                    return query.match[field].cutoff_frequency;
                }

                query.match[field].cutoff_frequency = freq;
                return this;
            },

            /**
             Sets the prefix length for a fuzzy prefix <code>MatchQuery</code>.

             @member ejs.MatchQuery
             @param {Integer} l A positive <code>integer</code> length value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            prefixLength: function(l) {
                if (l == null) {
                    return query.match[field].prefix_length;
                }

                query.match[field].prefix_length = l;
                return this;
            },

            /**
             Sets the max expansions of a fuzzy <code>MatchQuery</code>.

             @member ejs.MatchQuery
             @param {Integer} e A positive <code>integer</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            maxExpansions: function(e) {
                if (e == null) {
                    return query.match[field].max_expansions;
                }

                query.match[field].max_expansions = e;
                return this;
            },

            /**
             Sets default operator of the <code>Query</code>.  Default: or.

             @member ejs.MatchQuery
             @param {string} op Any of "and" or "or", no quote characters.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            operator: function(op) {
                if (op == null) {
                    return query.match[field].operator;
                }

                op = op.toLowerCase();
                if (op === 'and' || op === 'or') {
                    query.match[field].operator = op;
                }

                return this;
            },

            /**
             Sets the default slop for phrases. If zero, then exact phrase matches
             are required.  Default: 0.

             @member ejs.MatchQuery
             @param {Integer} slop A positive <code>integer</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            slop: function(slop) {
                if (slop == null) {
                    return query.match[field].slop;
                }

                query.match[field].slop = slop;
                return this;
            },

            /**
             Sets the analyzer name used to analyze the <code>Query</code> object.

             @member ejs.MatchQuery
             @param {string} analyzer A valid analyzer name.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            analyzer: function(analyzer) {
                if (analyzer == null) {
                    return query.match[field].analyzer;
                }

                query.match[field].analyzer = analyzer;
                return this;
            },

            /**
             Sets a percent value controlling how many "should" clauses in the
             resulting <code>Query</code> should match.

             @member ejs.MatchQuery
             @param {string} minMatch A min should match parameter.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            minimumShouldMatch: function(minMatch) {
                if (minMatch == null) {
                    return query.match[field].minimum_should_match;
                }

                query.match[field].minimum_should_match = minMatch;
                return this;
            },

            /**
             Sets rewrite method.  Valid values are:

             constant_score_auto - tries to pick the best constant-score rewrite
             method based on term and document counts from the query

             scoring_boolean - translates each term into boolean should and
             keeps the scores as computed by the query

             constant_score_boolean - same as scoring_boolean, expect no scores
             are computed.

             constant_score_filter - first creates a private Filter, by visiting
             each term in sequence and marking all docs for that term

             top_terms_boost_N - first translates each term into boolean should
             and scores are only computed as the boost using the top N
             scoring terms.  Replace N with an integer value.

             top_terms_N -   first translates each term into boolean should
             and keeps the scores as computed by the query. Only the top N
             scoring terms are used.  Replace N with an integer value.

             Default is constant_score_auto.

             This is an advanced option, use with care.

             @member ejs.MatchQuery
             @param {string} m The rewrite method as a string.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            rewrite: function(m) {
                if (m == null) {
                    return query.match[field].rewrite;
                }

                m = m.toLowerCase();
                if (m === 'constant_score_auto' || m === 'scoring_boolean' ||
                    m === 'constant_score_boolean' || m === 'constant_score_filter' ||
                    m.indexOf('top_terms_boost_') === 0 ||
                    m.indexOf('top_terms_') === 0) {

                    query.match[field].rewrite = m;
                }

                return this;
            },

            /**
             Sets fuzzy rewrite method.  Valid values are:

             constant_score_auto - tries to pick the best constant-score rewrite
             method based on term and document counts from the query

             scoring_boolean - translates each term into boolean should and
             keeps the scores as computed by the query

             constant_score_boolean - same as scoring_boolean, expect no scores
             are computed.

             constant_score_filter - first creates a private Filter, by visiting
             each term in sequence and marking all docs for that term

             top_terms_boost_N - first translates each term into boolean should
             and scores are only computed as the boost using the top N
             scoring terms.  Replace N with an integer value.

             top_terms_N -   first translates each term into boolean should
             and keeps the scores as computed by the query. Only the top N
             scoring terms are used.  Replace N with an integer value.

             Default is constant_score_auto.

             This is an advanced option, use with care.

             @member ejs.MatchQuery
             @param {string} m The rewrite method as a string.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fuzzyRewrite: function(m) {
                if (m == null) {
                    return query.match[field].fuzzy_rewrite;
                }

                m = m.toLowerCase();
                if (m === 'constant_score_auto' || m === 'scoring_boolean' ||
                    m === 'constant_score_boolean' || m === 'constant_score_filter' ||
                    m.indexOf('top_terms_boost_') === 0 ||
                    m.indexOf('top_terms_') === 0) {

                    query.match[field].fuzzy_rewrite = m;
                }

                return this;
            },

            /**
             Set to false to use classic Levenshtein edit distance in the
             fuzzy query.

             @member ejs.MatchQuery
             @param {Boolean} trueFalse A boolean value
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fuzzyTranspositions: function(trueFalse) {
                if (trueFalse == null) {
                    return query.match[field].fuzzy_transpositions;
                }

                query.match[field].fuzzy_transpositions = trueFalse;
                return this;
            },

            /**
             Enables lenient parsing of the query string.

             @member ejs.MatchQuery
             @param {Boolean} trueFalse A boolean value
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            lenient: function(trueFalse) {
                if (trueFalse == null) {
                    return query.match[field].lenient;
                }

                query.match[field].lenient = trueFalse;
                return this;
            },

            /**
             Sets what happens when no terms match.  Valid values are
             "all" or "none".

             @member ejs.MatchQuery
             @param {string} q A no match action, "all" or "none".
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            zeroTermsQuery: function(q) {
                if (q == null) {
                    return query.match[field].zero_terms_query;
                }

                q = q.toLowerCase();
                if (q === 'all' || q === 'none') {
                    query.match[field].zero_terms_query = q;
                }

                return this;
            },

            /**
             Sets the boost value for documents matching the <code>Query</code>.

             @member ejs.MatchQuery
             @param {number} boost A positive <code>double</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            boost: function(boost) {
                if (boost == null) {
                    return query.match[field].boost;
                }

                query.match[field].boost = boost;
                return this;
            },

        });
    };

    /**
     @class
         A <code>MultiMatchQuery</code> query builds further on top of the
     <code>MatchQuery</code> by allowing multiple fields to be specified.
     The idea here is to allow to more easily build a concise match type query
     over multiple fields instead of using a relatively more expressive query
     by using multiple match queries within a bool query.

     @name ejs.MultiMatchQuery
     @ejs query
     @borrows ejs.QueryMixin.boost as boost
     @borrows ejs.QueryMixin._type as _type
     @borrows ejs.QueryMixin.toJSON as toJSON

     @desc
     A Query that allow to more easily build a MatchQuery
     over multiple fields

     @param {(String|String[])} fields the single field or array of fields to search across
     @param {string} qstr the query string
     */
    ejs.MultiMatchQuery = function(fields, qstr) {

        var
            _common = ejs.QueryMixin('multi_match'),
            query = _common.toJSON();

        query.multi_match.query = qstr;
        query.multi_match.fields = [];

        if (isString(fields)) {
            query.multi_match.fields.push(fields);
        } else if (isArray(fields)) {
            query.multi_match.fields = fields;
        } else {
            throw new TypeError('Argument must be string or array');
        }

        return extend(_common, {

            /**
             Sets the fields to search across.  If passed a single value it is
             added to the existing list of fields.  If passed an array of
             values, they overwite all existing values.

             @member ejs.MultiMatchQuery
             @param {(String|String[])} f A single field or list of fields names to
             search across.
             @returns {Object} returns <code>this</code> so that calls can be
             chained. Returns {Array} current value if `f` not specified.
             */
            fields: function(f) {
                if (f == null) {
                    return query.multi_match.fields;
                }

                if (isString(f)) {
                    query.multi_match.fields.push(f);
                } else if (isArray(f)) {
                    query.multi_match.fields = f;
                } else {
                    throw new TypeError('Argument must be string or array');
                }

                return this;
            },

            /**
             Sets whether or not queries against multiple fields should be combined using Lucene's
             <a href="http://lucene.apache.org/java/3_0_0/api/core/org/apache/lucene/search/DisjunctionMaxQuery.html">
             DisjunctionMaxQuery</a>

             @member ejs.MultiMatchQuery
             @param {string} trueFalse A <code>true/false</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            useDisMax: function(trueFalse) {
                if (trueFalse == null) {
                    return query.multi_match.use_dis_max;
                }

                query.multi_match.use_dis_max = trueFalse;
                return this;
            },

            /**
             The tie breaker value.  The tie breaker capability allows results
             that include the same term in multiple fields to be judged better than
             results that include this term in only the best of those multiple
             fields, without confusing this with the better case of two different
             terms in the multiple fields.  Default: 0.0.

             @member ejs.MultiMatchQuery
             @param {Double} tieBreaker A positive <code>double</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            tieBreaker: function(tieBreaker) {
                if (tieBreaker == null) {
                    return query.multi_match.tie_breaker;
                }

                query.multi_match.tie_breaker = tieBreaker;
                return this;
            },

            /**
             Sets the maximum threshold/frequency to be considered a low
             frequency term in a <code>CommonTermsQuery</code>.
             Set to a value between 0 and 1.

             @member ejs.MultiMatchQuery
             @param {number} freq A positive <code>double</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            cutoffFrequency: function(freq) {
                if (freq == null) {
                    return query.multi_match.cutoff_frequency;
                }

                query.multi_match.cutoff_frequency = freq;
                return this;
            },

            /**
             Sets a percent value controlling how many "should" clauses in the
             resulting <code>Query</code> should match.

             @member ejs.MultiMatchQuery
             @param {string} minMatch A min should match parameter.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            minimumShouldMatch: function(minMatch) {
                if (minMatch == null) {
                    return query.multi_match.minimum_should_match;
                }

                query.multi_match.minimum_should_match = minMatch;
                return this;
            },

            /**
             Sets rewrite method.  Valid values are:

             constant_score_auto - tries to pick the best constant-score rewrite
             method based on term and document counts from the query

             scoring_boolean - translates each term into boolean should and
             keeps the scores as computed by the query

             constant_score_boolean - same as scoring_boolean, expect no scores
             are computed.

             constant_score_filter - first creates a private Filter, by visiting
             each term in sequence and marking all docs for that term

             top_terms_boost_N - first translates each term into boolean should
             and scores are only computed as the boost using the top N
             scoring terms.  Replace N with an integer value.

             top_terms_N -   first translates each term into boolean should
             and keeps the scores as computed by the query. Only the top N
             scoring terms are used.  Replace N with an integer value.

             Default is constant_score_auto.

             This is an advanced option, use with care.

             @member ejs.MultiMatchQuery
             @param {string} m The rewrite method as a string.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            rewrite: function(m) {
                if (m == null) {
                    return query.multi_match.rewrite;
                }

                m = m.toLowerCase();
                if (m === 'constant_score_auto' || m === 'scoring_boolean' ||
                    m === 'constant_score_boolean' || m === 'constant_score_filter' ||
                    m.indexOf('top_terms_boost_') === 0 ||
                    m.indexOf('top_terms_') === 0) {

                    query.multi_match.rewrite = m;
                }

                return this;
            },

            /**
             Sets fuzzy rewrite method.  Valid values are:

             constant_score_auto - tries to pick the best constant-score rewrite
             method based on term and document counts from the query

             scoring_boolean - translates each term into boolean should and
             keeps the scores as computed by the query

             constant_score_boolean - same as scoring_boolean, expect no scores
             are computed.

             constant_score_filter - first creates a private Filter, by visiting
             each term in sequence and marking all docs for that term

             top_terms_boost_N - first translates each term into boolean should
             and scores are only computed as the boost using the top N
             scoring terms.  Replace N with an integer value.

             top_terms_N -   first translates each term into boolean should
             and keeps the scores as computed by the query. Only the top N
             scoring terms are used.  Replace N with an integer value.

             Default is constant_score_auto.

             This is an advanced option, use with care.

             @member ejs.MultiMatchQuery
             @param {string} m The rewrite method as a string.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fuzzyRewrite: function(m) {
                if (m == null) {
                    return query.multi_match.fuzzy_rewrite;
                }

                m = m.toLowerCase();
                if (m === 'constant_score_auto' || m === 'scoring_boolean' ||
                    m === 'constant_score_boolean' || m === 'constant_score_filter' ||
                    m.indexOf('top_terms_boost_') === 0 ||
                    m.indexOf('top_terms_') === 0) {

                    query.multi_match.fuzzy_rewrite = m;
                }

                return this;
            },

            /**
             Enables lenient parsing of the query string.

             @member ejs.MultiMatchQuery
             @param {Boolean} trueFalse A boolean value
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            lenient: function(trueFalse) {
                if (trueFalse == null) {
                    return query.multi_match.lenient;
                }

                query.multi_match.lenient = trueFalse;
                return this;
            },

            /**
             Sets the query string for the <code>Query</code>.

             @member ejs.MultiMatchQuery
             @param {string} qstr The query string to search for.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            query: function(qstr) {
                if (qstr == null) {
                    return query.multi_match.query;
                }

                query.multi_match.query = qstr;
                return this;
            },

            /**
             Sets the type of the <code>MultiMatchQuery</code>.  Valid values are
             boolean, phrase, and phrase_prefix or phrasePrefix.

             @member ejs.MultiMatchQuery
             @param {string} type Any of boolean, phrase, phrase_prefix or phrasePrefix.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            type: function(type) {
                if (type == null) {
                    return query.multi_match.type;
                }

                type = type.toLowerCase();
                if (type === 'best_fields' || type === 'most_fields' || type === 'cross_fields' || type === 'phrase' || type === 'phrase_prefix') {
                    query.multi_match.type = type;
                }

                return this;
            },

            /**
             Sets the fuzziness value for the <code>Query</code>.

             @member ejs.MultiMatchQuery
             @param {Double} fuzz A <code>double</code> value between 0.0 and 1.0.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fuzziness: function(fuzz) {
                if (fuzz == null) {
                    return query.multi_match.fuzziness;
                }

                query.multi_match.fuzziness = fuzz;
                return this;
            },

            /**
             Sets the prefix length for a fuzzy prefix <code>Query</code>.

             @member ejs.MultiMatchQuery
             @param {Integer} l A positive <code>integer</code> length value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            prefixLength: function(l) {
                if (l == null) {
                    return query.multi_match.prefix_length;
                }

                query.multi_match.prefix_length = l;
                return this;
            },

            /**
             Sets the max expansions of a fuzzy <code>Query</code>.

             @member ejs.MultiMatchQuery
             @param {Integer} e A positive <code>integer</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            maxExpansions: function(e) {
                if (e == null) {
                    return query.multi_match.max_expansions;
                }

                query.multi_match.max_expansions = e;
                return this;
            },

            /**
             Sets default operator of the <code>Query</code>.  Default: or.

             @member ejs.MultiMatchQuery
             @param {string} op Any of "and" or "or", no quote characters.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            operator: function(op) {
                if (op == null) {
                    return query.multi_match.operator;
                }

                op = op.toLowerCase();
                if (op === 'and' || op === 'or') {
                    query.multi_match.operator = op;
                }

                return this;
            },

            /**
             Sets the default slop for phrases. If zero, then exact phrase matches
             are required.  Default: 0.

             @member ejs.MultiMatchQuery
             @param {Integer} slop A positive <code>integer</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            slop: function(slop) {
                if (slop == null) {
                    return query.multi_match.slop;
                }

                query.multi_match.slop = slop;
                return this;
            },

            /**
             Sets the analyzer name used to analyze the <code>Query</code> object.

             @member ejs.MultiMatchQuery
             @param {string} analyzer A valid analyzer name.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            analyzer: function(analyzer) {
                if (analyzer == null) {
                    return query.multi_match.analyzer;
                }

                query.multi_match.analyzer = analyzer;
                return this;
            },

            /**
             Sets what happens when no terms match.  Valid values are
             "all" or "none".

             @member ejs.MultiMatchQuery
             @param {string} q A no match action, "all" or "none".
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            zeroTermsQuery: function(q) {
                if (q == null) {
                    return query.multi_match.zero_terms_query;
                }

                q = q.toLowerCase();
                if (q === 'all' || q === 'none') {
                    query.multi_match.zero_terms_query = q;
                }

                return this;
            }

        });
    };

    /**
     @class
         <p>Matches documents that have fields containing terms with a specified
     prefix (not analyzed). The prefix query maps to Lucene PrefixQuery.</p>

     @name ejs.PrefixQuery
     @ejs query
     @borrows ejs.QueryMixin._type as _type
     @borrows ejs.QueryMixin.toJSON as toJSON

     @desc
     Matches documents containing the specified un-analyzed prefix.

     @param {string} field A valid field name.
     @param {string} value A string prefix.
     */
    ejs.PrefixQuery = function(field, value) {

        var
            _common = ejs.QueryMixin('prefix'),
            query = _common.toJSON();

        query.prefix[field] = {
            value: value
        };

        return extend(_common, {

            /**
             The field to run the query against.

             @member ejs.PrefixQuery
             @param {string} f A single field name.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            field: function(f) {
                var oldValue = query.prefix[field];

                if (f == null) {
                    return field;
                }

                delete query.prefix[field];
                field = f;
                query.prefix[f] = oldValue;

                return this;
            },

            /**
             The prefix value.

             @member ejs.PrefixQuery
             @param {string} p A string prefix
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            value: function(p) {
                if (p == null) {
                    return query.prefix[field].value;
                }

                query.prefix[field].value = p;
                return this;
            },

            /**
             Sets rewrite method.  Valid values are:

             constant_score_auto - tries to pick the best constant-score rewrite
             method based on term and document counts from the query

             scoring_boolean - translates each term into boolean should and
             keeps the scores as computed by the query

             constant_score_boolean - same as scoring_boolean, expect no scores
             are computed.

             constant_score_filter - first creates a private Filter, by visiting
             each term in sequence and marking all docs for that term

             top_terms_boost_N - first translates each term into boolean should
             and scores are only computed as the boost using the top N
             scoring terms.  Replace N with an integer value.

             top_terms_N -   first translates each term into boolean should
             and keeps the scores as computed by the query. Only the top N
             scoring terms are used.  Replace N with an integer value.

             Default is constant_score_auto.

             This is an advanced option, use with care.

             @member ejs.PrefixQuery
             @param {string} m The rewrite method as a string.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            rewrite: function(m) {
                if (m == null) {
                    return query.prefix[field].rewrite;
                }

                m = m.toLowerCase();
                if (m === 'constant_score_auto' || m === 'scoring_boolean' ||
                    m === 'constant_score_boolean' || m === 'constant_score_filter' ||
                    m.indexOf('top_terms_boost_') === 0 ||
                    m.indexOf('top_terms_') === 0) {

                    query.prefix[field].rewrite = m;
                }

                return this;
            },

            /**
             Sets the boost value of the <code>Query</code>.

             @member ejs.PrefixQuery
             @param {Double} boost A positive <code>double</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            boost: function(boost) {
                if (boost == null) {
                    return query.prefix[field].boost;
                }

                query.prefix[field].boost = boost;
                return this;
            }

        });
    };

    /**
     @class
         <p>A query that is parsed using Lucene's default query parser. Although Lucene provides the
     ability to create your own queries through its API, it also provides a rich query language
     through the Query Parser, a lexer which interprets a string into a Lucene Query.</p>

     </p>See the Lucene <a href="http://lucene.apache.org/java/2_9_1/queryparsersyntax.html">Query Parser Syntax</a>
     for more information.</p>

     @name ejs.QueryStringQuery
     @ejs query
     @borrows ejs.QueryMixin.boost as boost
     @borrows ejs.QueryMixin._type as _type
     @borrows ejs.QueryMixin.toJSON as toJSON

     @desc
     A query that is parsed using Lucene's default query parser.

     @param {string} qstr A valid Lucene query string.
     */
    ejs.QueryStringQuery = function(qstr) {

        var
            _common = ejs.QueryMixin('query_string'),
            query = _common.toJSON();

        query.query_string.query = qstr;

        return extend(_common, {

            /**
             Sets the query string on this <code>Query</code> object.

             @member ejs.QueryStringQuery
             @param {string} qstr A valid Lucene query string.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            query: function(qstr) {
                if (qstr == null) {
                    return query.query_string.query;
                }

                query.query_string.query = qstr;
                return this;
            },

            /**
             Sets the default field/property this query should execute against.

             @member ejs.QueryStringQuery
             @param {string} fieldName The name of document field/property.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            defaultField: function(fieldName) {
                if (fieldName == null) {
                    return query.query_string.default_field;
                }

                query.query_string.default_field = fieldName;
                return this;
            },

            /**
             A set of fields/properties this query should execute against.
             Pass a single value to add to the existing list of fields and
             pass an array to overwrite all existing fields.  For each field,
             you can apply a field specific boost by appending a ^boost to the
             field name.  For example, title^10, to give the title field a
             boost of 10.

             @member ejs.QueryStringQuery
             @param {Array} fieldNames A list of document fields/properties.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fields: function(fieldNames) {
                if (query.query_string.fields == null) {
                    query.query_string.fields = [];
                }

                if (fieldNames == null) {
                    return query.query_string.fields;
                }

                if (isString(fieldNames)) {
                    query.query_string.fields.push(fieldNames);
                } else if (isArray(fieldNames)) {
                    query.query_string.fields = fieldNames;
                } else {
                    throw new TypeError('Argument must be a string or array');
                }

                return this;
            },

            /**
             Sets whether or not queries against multiple fields should be combined using Lucene's
             <a href="http://lucene.apache.org/java/3_0_0/api/core/org/apache/lucene/search/DisjunctionMaxQuery.html">
             DisjunctionMaxQuery</a>

             @member ejs.QueryStringQuery
             @param {string} trueFalse A <code>true/false</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            useDisMax: function(trueFalse) {
                if (trueFalse == null) {
                    return query.query_string.use_dis_max;
                }

                query.query_string.use_dis_max = trueFalse;
                return this;
            },

            /**
             Set the default <em>Boolean</em> operator. This operator is used to join individual query
             terms when no operator is explicity used in the query string (i.e., <code>this AND that</code>).
             Defaults to <code>OR</code>.

             @member ejs.QueryStringQuery
             @param {string} op The operator to use, AND or OR.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            defaultOperator: function(op) {
                if (op == null) {
                    return query.query_string.default_operator;
                }

                op = op.toUpperCase();
                if (op === 'AND' || op === 'OR') {
                    query.query_string.default_operator = op;
                }

                return this;
            },

            /**
             Sets the analyzer name used to analyze the <code>Query</code> object.

             @member ejs.QueryStringQuery
             @param {string} analyzer A valid analyzer name.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            analyzer: function(analyzer) {
                if (analyzer == null) {
                    return query.query_string.analyzer;
                }

                query.query_string.analyzer = analyzer;
                return this;
            },

            /**
             Sets the quote analyzer name used to analyze the <code>query</code>
             when in quoted text.

             @member ejs.QueryStringQuery
             @param {string} analyzer A valid analyzer name.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            quoteAnalyzer: function(analyzer) {
                if (analyzer == null) {
                    return query.query_string.quote_analyzer;
                }

                query.query_string.quote_analyzer = analyzer;
                return this;
            },

            /**
             Sets whether or not wildcard characters (* and ?) are allowed as the
             first character of the <code>Query</code>.  Default: true.

             @member ejs.QueryStringQuery
             @param {Boolean} trueFalse A <code>true/false</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            allowLeadingWildcard: function(trueFalse) {
                if (trueFalse == null) {
                    return query.query_string.allow_leading_wildcard;
                }

                query.query_string.allow_leading_wildcard = trueFalse;
                return this;
            },

            /**
             Sets whether or not terms from wildcard, prefix, fuzzy, and
             range queries should automatically be lowercased in the <code>Query</code>
             since they are not analyzed.  Default: true.

             @member ejs.QueryStringQuery
             @param {Boolean} trueFalse A <code>true/false</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            lowercaseExpandedTerms: function(trueFalse) {
                if (trueFalse == null) {
                    return query.query_string.lowercase_expanded_terms;
                }

                query.query_string.lowercase_expanded_terms = trueFalse;
                return this;
            },

            /**
             Sets whether or not position increments will be used in the
             <code>Query</code>. Default: true.

             @member ejs.QueryStringQuery
             @param {Boolean} trueFalse A <code>true/false</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            enablePositionIncrements: function(trueFalse) {
                if (trueFalse == null) {
                    return query.query_string.enable_position_increments;
                }

                query.query_string.enable_position_increments = trueFalse;
                return this;
            },


            /**
             Sets the prefix length for fuzzy queries.  Default: 0.

             @member ejs.QueryStringQuery
             @param {Integer} fuzzLen A positive <code>integer</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fuzzyPrefixLength: function(fuzzLen) {
                if (fuzzLen == null) {
                    return query.query_string.fuzzy_prefix_length;
                }

                query.query_string.fuzzy_prefix_length = fuzzLen;
                return this;
            },

            /**
             Set the minimum similarity for fuzzy queries.  Default: 0.5.

             @member ejs.QueryStringQuery
             @param {Double} minSim A <code>double</code> value between 0 and 1.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fuzzyMinSim: function(minSim) {
                if (minSim == null) {
                    return query.query_string.fuzzy_min_sim;
                }

                query.query_string.fuzzy_min_sim = minSim;
                return this;
            },

            /**
             Sets the default slop for phrases. If zero, then exact phrase matches
             are required.  Default: 0.

             @member ejs.QueryStringQuery
             @param {Integer} slop A positive <code>integer</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            phraseSlop: function(slop) {
                if (slop == null) {
                    return query.query_string.phrase_slop;
                }

                query.query_string.phrase_slop = slop;
                return this;
            },

            /**
             Sets whether or not we should attempt to analyzed wilcard terms in the
             <code>Query</code>. By default, wildcard terms are not analyzed.
             Analysis of wildcard characters is not perfect.  Default: false.

             @member ejs.QueryStringQuery
             @param {Boolean} trueFalse A <code>true/false</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            analyzeWildcard: function(trueFalse) {
                if (trueFalse == null) {
                    return query.query_string.analyze_wildcard;
                }

                query.query_string.analyze_wildcard = trueFalse;
                return this;
            },

            /**
             Sets whether or not we should auto generate phrase queries *if* the
             analyzer returns more than one term. Default: false.

             @member ejs.QueryStringQuery
             @param {Boolean} trueFalse A <code>true/false</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            autoGeneratePhraseQueries: function(trueFalse) {
                if (trueFalse == null) {
                    return query.query_string.auto_generate_phrase_queries;
                }

                query.query_string.auto_generate_phrase_queries = trueFalse;
                return this;
            },

            /**
             Sets a percent value controlling how many "should" clauses in the
             resulting <code>Query</code> should match.

             @member ejs.QueryStringQuery
             @param {string} minMatch A min should match parameter.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            minimumShouldMatch: function(minMatch) {
                if (minMatch == null) {
                    return query.query_string.minimum_should_match;
                }

                query.query_string.minimum_should_match = minMatch;
                return this;
            },

            /**
             Sets the tie breaker value for a <code>Query</code> using
             <code>DisMax</code>.  The tie breaker capability allows results
             that include the same term in multiple fields to be judged better than
             results that include this term in only the best of those multiple
             fields, without confusing this with the better case of two different
             terms in the multiple fields.  Default: 0.0.

             @member ejs.QueryStringQuery
             @param {Double} tieBreaker A positive <code>double</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            tieBreaker: function(tieBreaker) {
                if (tieBreaker == null) {
                    return query.query_string.tie_breaker;
                }

                query.query_string.tie_breaker = tieBreaker;
                return this;
            },

            /**
             If they query string should be escaped or not.

             @member ejs.QueryStringQuery
             @param {Boolean} trueFalse A <code>true/false</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            escape: function(trueFalse) {
                if (trueFalse == null) {
                    return query.query_string.escape;
                }

                query.query_string.escape = trueFalse;
                return this;
            },

            /**
             Sets the max number of term expansions for fuzzy queries.

             @member ejs.QueryStringQuery
             @param {Integer} max A positive <code>integer</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fuzzyMaxExpansions: function(max) {
                if (max == null) {
                    return query.query_string.fuzzy_max_expansions;
                }

                query.query_string.fuzzy_max_expansions = max;
                return this;
            },

            /**
             Sets fuzzy rewrite method.  Valid values are:

             constant_score_auto - tries to pick the best constant-score rewrite
             method based on term and document counts from the query

             scoring_boolean - translates each term into boolean should and
             keeps the scores as computed by the query

             constant_score_boolean - same as scoring_boolean, expect no scores
             are computed.

             constant_score_filter - first creates a private Filter, by visiting
             each term in sequence and marking all docs for that term

             top_terms_boost_N - first translates each term into boolean should
             and scores are only computed as the boost using the top N
             scoring terms.  Replace N with an integer value.

             top_terms_N -   first translates each term into boolean should
             and keeps the scores as computed by the query. Only the top N
             scoring terms are used.  Replace N with an integer value.

             Default is constant_score_auto.

             This is an advanced option, use with care.

             @member ejs.QueryStringQuery
             @param {string} m The rewrite method as a string.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fuzzyRewrite: function(m) {
                if (m == null) {
                    return query.query_string.fuzzy_rewrite;
                }

                m = m.toLowerCase();
                if (m === 'constant_score_auto' || m === 'scoring_boolean' ||
                    m === 'constant_score_boolean' || m === 'constant_score_filter' ||
                    m.indexOf('top_terms_boost_') === 0 ||
                    m.indexOf('top_terms_') === 0) {

                    query.query_string.fuzzy_rewrite = m;
                }

                return this;
            },

            /**
             Sets rewrite method.  Valid values are:

             constant_score_auto - tries to pick the best constant-score rewrite
             method based on term and document counts from the query

             scoring_boolean - translates each term into boolean should and
             keeps the scores as computed by the query

             constant_score_boolean - same as scoring_boolean, expect no scores
             are computed.

             constant_score_filter - first creates a private Filter, by visiting
             each term in sequence and marking all docs for that term

             top_terms_boost_N - first translates each term into boolean should
             and scores are only computed as the boost using the top N
             scoring terms.  Replace N with an integer value.

             top_terms_N -   first translates each term into boolean should
             and keeps the scores as computed by the query. Only the top N
             scoring terms are used.  Replace N with an integer value.

             Default is constant_score_auto.

             This is an advanced option, use with care.

             @member ejs.QueryStringQuery
             @param {string} m The rewrite method as a string.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            rewrite: function(m) {
                if (m == null) {
                    return query.query_string.rewrite;
                }

                m = m.toLowerCase();
                if (m === 'constant_score_auto' || m === 'scoring_boolean' ||
                    m === 'constant_score_boolean' || m === 'constant_score_filter' ||
                    m.indexOf('top_terms_boost_') === 0 ||
                    m.indexOf('top_terms_') === 0) {

                    query.query_string.rewrite = m;
                }

                return this;
            },

            /**
             Sets the suffix to automatically add to the field name when
             performing a quoted search.

             @member ejs.QueryStringQuery
             @param {string} s The suffix as a string.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            quoteFieldSuffix: function(s) {
                if (s == null) {
                    return query.query_string.quote_field_suffix;
                }

                query.query_string.quote_field_suffix = s;
                return this;
            },

            /**
             Enables lenient parsing of the query string.

             @member ejs.QueryStringQuery
             @param {Boolean} trueFalse A boolean value
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            lenient: function(trueFalse) {
                if (trueFalse == null) {
                    return query.query_string.lenient;
                }

                query.query_string.lenient = trueFalse;
                return this;
            }

        });
    };

    /**
     @class
         <p>Matches documents with fields that have terms within a certain range.
     The type of the Lucene query depends on the field type, for string fields,
     the TermRangeQuery, while for number/date fields, the query is a
     NumericRangeQuery.</p>

     @name ejs.RangeQuery
     @ejs query
     @borrows ejs.QueryMixin._type as _type
     @borrows ejs.QueryMixin.toJSON as toJSON

     @desc
     Matches documents with fields that have terms within a certain range.

     @param {string} field A valid field name.
     */
    ejs.RangeQuery = function(field) {

        var
            _common = ejs.QueryMixin('range'),
            query = _common.toJSON();

        query.range[field] = {};

        return extend(_common, {

            /**
             The field to run the query against.

             @member ejs.RangeQuery
             @param {string} f A single field name.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            field: function(f) {
                var oldValue = query.range[field];

                if (f == null) {
                    return field;
                }

                delete query.range[field];
                field = f;
                query.range[f] = oldValue;

                return this;
            },

            /**
             The lower bound. Defaults to start from the first.

             @member ejs.RangeQuery
             @param {*} f the lower bound value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            from: function(f) {
                if (f == null) {
                    return query.range[field].from;
                }

                query.range[field].from = f;
                return this;
            },

            /**
             The upper bound. Defaults to unbounded.

             @member ejs.RangeQuery
             @param {*} t the upper bound value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            to: function(t) {
                if (t == null) {
                    return query.range[field].to;
                }

                query.range[field].to = t;
                return this;
            },

            /**
             Should the first from (if set) be inclusive or not.
             Defaults to true

             @member ejs.RangeQuery
             @param {Boolean} trueFalse true to include, false to exclude
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            includeLower: function(trueFalse) {
                if (trueFalse == null) {
                    return query.range[field].include_lower;
                }

                query.range[field].include_lower = trueFalse;
                return this;
            },

            /**
             Should the last to (if set) be inclusive or not. Defaults to true.

             @member ejs.RangeQuery
             @param {Boolean} trueFalse true to include, false to exclude
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            includeUpper: function(trueFalse) {
                if (trueFalse == null) {
                    return query.range[field].include_upper;
                }

                query.range[field].include_upper = trueFalse;
                return this;
            },

            /**
             Greater than value.  Same as setting from to the value, and
             include_lower to false,

             @member ejs.RangeQuery
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            gt: function(val) {
                if (val == null) {
                    return query.range[field].gt;
                }

                query.range[field].gt = val;
                return this;
            },

            /**
             Greater than or equal to value.  Same as setting from to the value,
             and include_lower to true.

             @member ejs.RangeQuery
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            gte: function(val) {
                if (val == null) {
                    return query.range[field].gte;
                }

                query.range[field].gte = val;
                return this;
            },

            /**
             Less than value.  Same as setting to to the value, and include_upper
             to false.

             @member ejs.RangeQuery
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            lt: function(val) {
                if (val == null) {
                    return query.range[field].lt;
                }

                query.range[field].lt = val;
                return this;
            },

            /**
             Less than or equal to value.  Same as setting to to the value,
             and include_upper to true.

             @member ejs.RangeQuery
             @param {*} val the value, type depends on field type
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            lte: function(val) {
                if (val == null) {
                    return query.range[field].lte;
                }

                query.range[field].lte = val;
                return this;
            },

            /**
             Sets the boost value of the <code>Query</code>.

             @member ejs.RangeQuery
             @param {Double} boost A positive <code>double</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            boost: function(boost) {
                if (boost == null) {
                    return query.range[field].boost;
                }

                query.range[field].boost = boost;
                return this;
            }

        });
    };

    /**
     @class
         <p>A <code>TermQuery</code> can be used to return documents containing a given
     keyword or <em>term</em>. For instance, you might want to retieve all the
     documents/objects that contain the term <code>Javascript</code>. Term filters
     often serve as the basis for more complex queries such as <em>Boolean</em> queries.</p>

     @name ejs.TermQuery
     @ejs query
     @borrows ejs.QueryMixin._type as _type
     @borrows ejs.QueryMixin.toJSON as toJSON

     @desc
     A Query that matches documents containing a term. This may be
     combined with other terms with a BooleanQuery.

     @param {string} field the document field/key to query against
     @param {string} term the literal value to be matched
     */
    ejs.TermQuery = function(field, term) {

        var
            _common = ejs.QueryMixin('term'),
            query = _common.toJSON();

        query.term[field] = {
            term: term
        };

        return extend(_common, {

            /**
             Sets the fields to query against.

             @member ejs.TermQuery
             @param {string} f A valid field name.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            field: function(f) {
                var oldValue = query.term[field];

                if (f == null) {
                    return field;
                }

                delete query.term[field];
                field = f;
                query.term[f] = oldValue;

                return this;
            },

            /**
             Sets the term.

             @member ejs.TermQuery
             @param {string} t A single term.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            term: function(t) {
                if (t == null) {
                    return query.term[field].term;
                }

                query.term[field].term = t;
                return this;
            },

            /**
             Sets the boost value for documents matching the <code>Query</code>.

             @member ejs.TermQuery
             @param {number} boost A positive <code>double</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            boost: function(boost) {
                if (boost == null) {
                    return query.term[field].boost;
                }

                query.term[field].boost = boost;
                return this;
            }

        });
    };

    /**
     @class
         <p>A query that match on any (configurable) of the provided terms. This is
     a simpler syntax query for using a bool query with several term queries
     in the should clauses.</p>

     @name ejs.TermsQuery
     @ejs query
     @borrows ejs.QueryMixin.boost as boost
     @borrows ejs.QueryMixin._type as _type
     @borrows ejs.QueryMixin.toJSON as toJSON

     @desc
     A Query that matches documents containing provided terms.

     @param {string} field the document field/key to query against
     @param {(String|String[])} terms a single term or array of "terms" to match
     */
    ejs.TermsQuery = function(field, terms) {

        var
            _common = ejs.QueryMixin('terms'),
            query = _common.toJSON();

        if (isString(terms)) {
            query.terms[field] = [terms];
        } else if (isArray(terms)) {
            query.terms[field] = terms;
        } else {
            throw new TypeError('Argument must be string or array');
        }

        return extend(_common, {

            /**
             Sets the fields to query against.

             @member ejs.TermsQuery
             @param {string} f A valid field name.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            field: function(f) {
                var oldValue = query.terms[field];

                if (f == null) {
                    return field;
                }

                delete query.terms[field];
                field = f;
                query.terms[f] = oldValue;

                return this;
            },

            /**
             Sets the terms.  If you t is a String, it is added to the existing
             list of terms.  If t is an array, the list of terms replaces the
             existing terms.

             @member ejs.TermsQuery
             @param {(String|String[])} t A single term or an array or terms.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            terms: function(t) {
                if (t == null) {
                    return query.terms[field];
                }

                if (isString(t)) {
                    query.terms[field].push(t);
                } else if (isArray(t)) {
                    query.terms[field] = t;
                } else {
                    throw new TypeError('Argument must be string or array');
                }

                return this;
            },

            /**
             Sets the minimum number of terms that need to match in a document
             before that document is returned in the results.

             @member ejs.TermsQuery
             @param {string} minMatch A min should match parameter.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            minimumShouldMatch: function(minMatch) {
                if (minMatch == null) {
                    return query.terms.minimum_should_match;
                }

                query.terms.minimum_should_match = minMatch;
                return this;
            },

            /**
             Enables or disables similarity coordinate scoring of documents
             matching the <code>Query</code>. Default: false.

             @member ejs.TermsQuery
             @param {string} trueFalse A <code>true/false</code value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            disableCoord: function(trueFalse) {
                if (trueFalse == null) {
                    return query.terms.disable_coord;
                }

                query.terms.disable_coord = trueFalse;
                return this;
            }

        });
    };
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