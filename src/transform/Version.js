// Used to version the transform pipeline. Body indices need to match exactly in
// the database for lookups to happen, so when the transform format changes, the
// index needs to be rebuilt.

// JSON.stringify doesn't guarantee an order, this does
import jsonStringify from 'json-stable-stringify';

const __data = Symbol('data');

export default class Version {
  constructor(custom, ...dependencies) {
    this[__data] = Object.freeze(Object.assign({}, custom,
      ...dependencies.map((d) => d[__data])
    ));
    Object.assign(this, this[__data]);
    Object.freeze(this);
  }

  toString() {
    return jsonStringify(this[__data]);
  }

  equals(other) {
    return '' + this === '' + other;
  }
}
