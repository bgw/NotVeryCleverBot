import _ from 'lodash';

import {
  getUrls,
  stripUrls,
  normalizeUrl,
  VERSION as URLS_VERSION,
} from './urls';
import frequentWords from 'norvig-frequencies';
import Version from './Version';

// should get changed whenever the output might be modified
export const VERSION = new Version(
  {normalize: 0},
  URLS_VERSION
);

function demarkdown(str) {
  return str
    // Flatten numbered and bulleted lists
    .replace(/^\s*([0-9]+\.|[*+-])\s*/gm, ' ')
    // Quotes
    .replace(/['"]/gm, ' ')
    // Non-word characters
    .replace(/(\W|_)/gm, ' ');
}

// only pick the 5000 most common words, and then rewrite things as an object
// for O(1) lookups.
const _isCommonLookup = {};
for (const word of frequentWords.slice(0, 5000)) {
  _isCommonLookup[word.toLowerCase()] = true;
}
function isCommon(word) {
  return _isCommonLookup.hasOwnProperty(word.toLowerCase());
}

function uncommonify(str) {
  return str.replace(/\w+/gm, (word) => isCommon(word) ? '' : word);
}

export default function normalize(str) {
  const urls = Array.from(new Set(getUrls(str).map(normalizeUrl))).sort();
  str = stripUrls(str);
  str = str.toLowerCase();
  str = demarkdown(str);
  str = uncommonify(str);
  str = str.replace(/\s+/g, ' ');
  str = str + (urls.length ? `\n${urls.join('\n')}` : '');
  str = _.trim(str);
  return str;
}
