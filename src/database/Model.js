import _ from 'lodash';
import assert from 'assert';

// TODO: temporary workaround --- V8's old proxy implementation doesn't trap
// symbols, though the ES6 spec does, and we can't polyfill around it
const __define = '@@define';
const __name = '@@name';
const __type = '@@type';
const __validator = '@@validator';

const __transformSqlKeyBindings = Symbol('transformSqlKeyBindings');
const __transformSqlKeyBindingsObject = Symbol('transformSqlKeyBindingsObject');
const __transformQueryTemplate = Symbol('transformQueryTemplate');
const __validate = Symbol('validate');
const __validateArray = Symbol('validateArray');
const __validateObject = Symbol('validateObject');
const __validators = Symbol('validators');

/**
 * A poor-man's Model implementation. We can't use bookshelf for perf reasons,
 * as we need better control of batching and upsert (INSERT OR REPLACE) support
 * (which knex doesn't even technically support).
 *
 * We use knex to generate the table, and generally use raw queries for
 * everything else.
 */
export default class Model {
  constructor(knex, tableName, ...schema) {
    if (typeof knex === 'string') {
      if (arguments.length > 1) {
        schema.unshift(tableName);
      }
      tableName = knex;
      knex = null;
    }
    this.knex = knex || require('knex');
    this.tableName = tableName;
    this.schema = schema;
    this[__validators] = {};
  }

  /**
   * Call this after the constructor to write the schema to the database.
   *
   * @returns {Promise} Unwraps to this, so you can chain, for example
   * `let m = await new Model(foo, bar).init()`
   */
  async init() {
    await this.knex.schema.createTable(this.tableName, (table) => {
      for (const column of this.schema) {
        assert.notEqual(column[__name], undefined,
                        'the column should have a name');
        column[__define](table);
        assert.equal(this[__validators][column[__name]], undefined,
                     "a validator for the column shouldn't already exist");

        if (column[__validator]) {
          this[__validators][column[__name]] = column[__validator];
        } else {
          this[__validators][column[__name]] = () => true;
        }
      }
    });
    return this;
  }

  /**
   * Like knex.raw, but takes a query template and a spread of arg arrays or
   * objects to pass through. May also take the result of `this.sql`, though
   * there's a shortcut `execSql` function for chaining that.
   *
   * There's a large number of ways to call `exec`. Some execute a single
   * command, while others allow bulk operations by specifying multiple arrays
   * or objects of parameters.
   *
   * 1. With `this.sql`:
   *    
   *    ```js
   *    foos = await Foo.exec(Foo.sql`select * from Foo where bar=${{bar}}`);
   *    // or
   *    foos = await Foo.execSql`select * from Foo where bar=${{bar}}`;
   *    ```
   *
   * 2. With only a raw sql string:
   *    
   *    ```js
   *    foos = await Foo.exec('select * from Foo');
   *    ```
   *
   * 3. With a spread of arrays for bulk operations:
   *
   *    ```js
   *    foos = await Foo.exec('select * from Foo where foo=? and bar=?`,
   *                          [1, 'fizz'], [2, 'buzz']);
   *    // or optionally provide column names to allow for column validation
   *    foos = await Foo.exec('select * from Foo where foo=? and bar=?`,
   *                          'foo', 'bar',
   *                          [1, 'fizz'], [2, 'buzz']);
   *    ```
   *
   *    This will batch operations by repeating and joining the provided
   *    template with a semicolon. This reduces the amount of context switches
   *    and/or network overhead.
   *
   * 4. With a spread of objects for bulk operations:
   *
   *    ```js
   *    foos = await Foo.exec('select * from Foo where foo=:foo and bar=:bar`,
   *                          {foo: 1, bar: 'fizz'}, {foo: 2, bar: 'buzz'});
   *    ```
   *
   *    Entries don't need to be in-order, and extra entries are ignored. A
   *    spread of columns doesn't need to be specified, because column names can
   *    be derived from the object keys.
   * 
   * @returns {Promise.<array.<object>>}
   */
  async exec(queryTemplate, ...args) {
    // simple operation: `exec(this.sql`select * from Foo where bar=${{bar}}`)`
    if (_.isPlainObject(queryTemplate)) {
      assert.equal(args.length, 0);
      // we're using a template-string generated with Model.sql
      return await this.knex.raw(queryTemplate.expression,
                                 queryTemplate.values);
    }

    // simple operation: `exec('select * from Foo')`
    if (args.length === 0) {
      return await this.knex.raw(queryTemplate);
    }
    
    // expand `...args` into `exec(queryTemplate, ...columns, ...args)`
    const columns = [];
    if (typeof args[0] === 'string') {
      for (const c of args) {
        if (typeof c !== 'string') {
          break;
        }
        columns.push(c);
      }
      args.splice(0, columns.length);
    }

    // handle batch operations
    if (Array.isArray(args[0])) {
      if (columns.length) {
        args.forEach(this[__validateArray].bind(this, columns));
      }
      return await this.knex.raw(
        Model[__transformQueryTemplate](null, queryTemplate, args.length),
        [].concat(...args)
      );
    } else {
      if (columns.length) {
        throw new Error(
          "Don't specify column names with objects, instead use " +
          ":namedParameters in your sql template"
        );
      }
      args.forEach(this[__validateObject], this);
      // use __transformSqlKeyBindings and string concatenation to allow bulk
      // operations on objects
      return await this.knex.raw(
        Model[__transformQueryTemplate](
          Model[__transformSqlKeyBindings], queryTemplate, args.length
        ),
        Object.assign({}, ...args.map(Model[__transformSqlKeyBindingsObject]))
      );
    }
  }

  /**
   * Knex supports keyed bindings using a `:colon` syntax. However, batching
   * involves repeating the template. If we simply repeated the template without
   * modification, we could have multiple template keys with the same name.
   *
   * This helper transforms a sql template to a version containing unique keys,
   * based on the supplied index.
   *
   * This works with transformSqlKeyBindingsObject, which generates a matching
   * object by transforming keys.
   */
  static [__transformSqlKeyBindings](expression, index) {
    index = index || 0; // may be passed null for non-repeated components
    // regex is derived from knex's code: http://git.io/vY1GK
    return expression.replace(/(\s)\:(\w+\:?)/g, `$1:__bind_${index}_$2`);
  }

  /**
   * Creates a new object with unique keys based on the original object's keys
   * and a supplied index. Intended to be used with transformSqlKeyBindings.
   */
  static [__transformSqlKeyBindingsObject](obj, index) {
    return _.mapKeys(obj, (v, k) => `__bind_${index}_${k}`);
  }

  static [__transformQueryTemplate](componentTransformer, template, len) {
    let result = '';
    for (const component of template) {
      if (typeof component === 'string') {
        result += (componentTransformer || _.identity)(component, null);
      } else if (_.isPlainObject(component) || Array.isArray(component)) {
        // extract and verify component
        let code, sep;
        if (Array.isArray(component)) {
          // shorthand
          [code, sep] = component;
        } else {
          ({code, sep} = component);
        }
        if (typeof code !== 'string' || typeof sep !== 'string') {
          throw new SyntaxError('expected code and sep values to be strings');
        }
        // transform and repeat component
        if (componentTransformer) {
          result = result.concat(..._.range(len).map(
            (i) => componentTransformer(code, i) + sep
          )).slice(0, -sep.length);
        } else {
          // faster code-path
          result += _.repeat(code + sep, len).slice(0, -sep.length);
        }
      } else {
        throw new SyntaxError('invalid template component type');
      }
    }
    return result;
  }

  /**
   * Allows you to declaratively and lazily define columns using knex methods.
   *
   * `Model.column().string('name').primary()` gets turned into
   * `table.column().string('name').primary()` inside init().
   *
   * The structure then allows us to extend the syntax and introspect various
   * components, which we use to add validation support.
   */
  static column() {
    const proxy = new Proxy(
      {
        /**
         * Gets wrapped over by the proxy when knex properties are requested, so
         * that later you can call column[__define](table), and it'll evaluate
         * all the stuff that was passed to it before.
         */
        [__define](table) { return table; },
        validator(v) {
          this[__validator] = v;
          return proxy;
        }
      },
      {
        get(target, key) {
          // passthrough internal or explicitly defined functions/props
          if (typeof key === 'symbol' ||
              // TODO: temporary workaround --- V8's old proxy implementation
              // doesn't trap symbols, though the ES6 spec does
              key.startsWith('@@') ||
              ({}).hasOwnProperty.call(target, key)) {
            return target[key];
          }

          // this is the function that'll get evaluated immediately when we
          // return it, and it'll set the prop on the column lazily.
          return (...args) => {
            // try to guess the name and type based upon the first function call
            // eg. Model.column.string('foobar') tells us the column is a
            // string, and the column name is foobar.
            if (target[__name] === undefined) {
              target[__name] = args[0];
              target[__type] = key;
            }
            // wrap the old __define call, so when it's actually called in
            // init(), the lazily evaluated function is called.
            const oldDefine = target[__define];
            target[__define] = table => oldDefine(table)[key](...args);
            // allow chaining
            return proxy;
          };
        }
      }
    );
    return proxy;
  }

  /**
   * Validates all the key-value pairs of an object.
   *
   * @param {object} obj Keys should be column names to validate the values
   * against.
   * @throws {Error} If validation fails or if the column doesn't exist.
   * @returns {object} The passed object, useful for chaining.
   */
  [__validateObject](obj) {
    assert(_.isPlainObject(obj), 'expected plain object');
    for (const column of Object.keys(obj)) {
      this[__validate](column, obj[column]);
    }
    return obj;
  }

  [__validateArray](columns, values) {
    assert(Array.isArray(values), 'expected array');
    assert.equal(columns.length, values.length, 'value-column length mismatch');
    for (let i = 0; i < columns.length; ++i) {
      this[__validate](columns[i], values[i]);
    }
    return values;
  }

  [__validate](column, value) {
    const validator = this[__validators][column];
    if (validator === undefined) {
      throw new Error(`Column '${column}' doesn't exist`);
    }
    if (!validator(value)) {
      throw new Error(
        `Value '${value}' for '${column}' could not be validated.`
      );
    }
  }

  /**
   * A tag for template strings. This allows you to write:
   *
   *   this.exec(this.sql`select * from foo where bar=${bar} baz=${baz}`)
   *   // or, pass objects (double curly braces) to perform validation...
   *   this.execSql`select * from foo where bar=${{bar}} and baz=${{baz}}`
   *
   * It's important to tag your template strings this way, and that you avoid
   * using string concatenation, as this sanitizes your SQL.
   */
  sql(strings, ...values) {
    return {
      expression: strings.join('?'),
      values: values.map(value => {
        if (!_.isPlainObject(value)) {
          return value;
        }

        const keys = Object.keys(value);
        if (keys.length !== 1) {
          throw new Error(
            'Got object with multiple or zero keys, expected one'
          );
        }

        this[__validateObject](value);
        return value[keys[0]];
      }),
    };
  }

  /**
   * A collapsed version of `this.exec(this.sql`foobar`)`.
   */
  execSql(strings, ...values) {
    return this.exec(this.sql(strings, ...values));
  }
}
