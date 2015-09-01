// Provides various URL-in-text mainipulation utilities.
//
// Much of the functionality is currently implemented using the excellent
// twitter-text library, which appears to do the "right thing" on most free-form
// markdown or markdown-like text blocks.

import * as twitterText from 'twitter-text';
import Version from './Version';

// should get changed whenever the output might be modified
export const VERSION = new Version({
  urls: 0,
  twitterText: require('twitter-text/package.json').version,
});

export function getUrls(str) {
  return twitterText.extractUrls(str);
}

export function stripUrls(str) {
  return twitterText.extractUrlsWithIndices(str)
    .reduce(({fragments, prevEnd}, {indices: [start, end]}) => {
      fragments.splice(
        // remove the last element from the fragments list
        -1, 1,
        // and add two more
        str.slice(prevEnd, start),
        str.slice(end, str.length)
      );
      return {fragments, prevEnd: end};
    }, {fragments: [str], prevEnd: 0})
    .fragments.join('');
}

// Do some stuff to minimize the variance in URLs. (`https://google.com/` should
// read the same as `http://www.google.com`)
//
// This does not guarantee correctness, but that also doesn't generally matter.
export function normalizeUrl(url) {
  if (!twitterText.regexen.urlHasProtocol.test(url)) {
    url = 'http://' + url;
  }
  return url.toLowerCase()
    // collapse routing style fragments, eg /#/foo or /#!/bar
    // deosn't worry about duplicate slashes, those will be removed later
    .replace(/#!?\//, '/')
    // remove `#fragments` from the end of urls
    .replace(/#.*$/, '')
    // remove a trailing `?` if the query string is empty
    .replace(/\?$/, '')
    // remove any duplicate slashes
    .replace(/([^:]\/)(\.?\/)+/g, '$1')
    // remove any trailing slash, prior to index.html removal
    .replace(/\/$/, '')
    // removes common extensions
    .replace(/\.(s?html?|php|aspx?|jsp|cgi)$/, '')
    // take off any ending `index.html` (or similar) thing
    .replace(/\/index$/, '')
    // remove any trailing slash, after index.html removal
    .replace(/\/$/, '')
    // turn `https` into `http`
    .replace(/^https:/, 'http:')
    // remove any `www`, `m`, or `i` prefix at the beginning of a url. `m`
    // and `i` are common on mobile versions of sites.
    .replace(/^http:\/\/(www|m|i)\./, 'http://')
    // remove image extensions from imgur links
    .replace(/^(http:\/\/imgur\.com\/[a-z0-9]{3,})\.[a-z]{3}/, '$1');
}
