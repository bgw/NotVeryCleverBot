function _validate(validator, value) {
  return validator instanceof RegExp ? validator.test(value) : validator(value);
}

// TODO: consider ES7 decorator syntax
function _wrap(f) {
  f.or = function or(nextf) {
    return _wrap((value) => _validate(f, value) || _validate(nextf, value));
  }
  f.and = function and(nextf) {
    return _wrap((value) => _validate(f, value) && _validate(nextf, value));
  }
  return f;
}

export const not = new Proxy(module.exports, {
  get(receiver, name) {
    return _wrap((...args) => !_validate(module.exports[name](...args)));
  },
});

// Every reddit "thing" has a "name" (sometimes called a "fullname") associated
// with it. This has a typecode, followed by the thing's id.
export function typedName(typeNumber) {
  return _wrap(new RegExp(`t${typeNumber}_[a-z0-9]+`));
}

// Different versions of `typedName`
export const name = typedName('[0-9]+');
export const commentName = typedName(1);
export const accountName = typedName(2);
export const articleName = typedName(3);
export const linkName = typedName(3);
export const messageName = typedName(4);
export const subredditName = typedName(5);
export const awardName = typedName(6);
export const promoCampaignName = typedName(8);

export const json = _wrap(function json(str) {
  if (typeof str !== 'string') {
    return false;
  }
  try {
    JSON.parse(str);
    return true;
  } catch (err) {
    return false;
  }
});

// allow null or undefined
const isNull = _wrap(function isNull(value) {
  return value == null;
});
// rewrite the name to work around reserved name issues in ES2015 module syntax
export { isNull as null };

export const number = _wrap(function number(val) {
  return typeof val === 'number';
});

export const integer = _wrap(function integer(val) {
  return typeof val === 'number' && ~~val === val;
});

export const string = _wrap(function string(val) {
  return typeof val === 'string';
});
