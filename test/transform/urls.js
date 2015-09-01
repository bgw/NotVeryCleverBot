import {expect} from 'chai';

import {getUrls, stripUrls, normalizeUrl} from '../../dist/transform/urls';

describe('getUrls', () => {
  it('gives an empty array on an empty string', () => {
    expect(getUrls('')).to.deep.equal([]);
  });
  it('ignores emails', () => {
    expect(getUrls('foo@example.com')).to.deep.equal([]);
  });
  it('ignores #hashtags', () => {
    expect(getUrls('#yolo')).to.deep.equal([]);
  });
  it('ignores @mentions', () => {
    expect(getUrls('@bgw')).to.deep.equal([]);
  });
  it('finds urls', () => {
    expect(getUrls('[link](https://www.youtube.com/watch?v=dQw4w9WgXcQ)'))
      .to.deep.equal(['https://www.youtube.com/watch?v=dQw4w9WgXcQ']);
    expect(getUrls('[link](http://en.wikipedia.org/wiki/Saw_(film))'))
      .to.deep.equal(['http://en.wikipedia.org/wiki/Saw_(film)']);
  });
  it('finds multiple urls', () => {
    expect(getUrls('http://example.com http://example.com'))
      .to.deep.equal(['http://example.com', 'http://example.com']);
  });
});

describe('stripUrls', () => {
  it('is an identity function for empty strings', () => {
    expect(stripUrls('')).to.equal('');
  });
  it('ignores emails', () => {
    expect(stripUrls('foo@example.com')).to.equal('foo@example.com');
  });
  it('ignores #hashtags', () => {
    expect(stripUrls('#yolo')).to.equal('#yolo');
  });
  it('ignores @mentions', () => {
    expect(stripUrls('@bgw')).to.equal('@bgw');
  });
  it('finds urls', () => {
    expect(stripUrls('[link](https://www.youtube.com/watch?v=dQw4w9WgXcQ)'))
      .to.equal('[link]()');
    expect(stripUrls('[link](http://en.wikipedia.org/wiki/Saw_(film))'))
      .to.equal('[link]()');
  });
  it('finds multiple urls', () => {
    expect(stripUrls('http://example.com example.com'))
      .to.equal(' ');
  });
});

describe('normalizeUrl', () => {
  it('prepends http:// to non-protocol urls', () => {
    expect(normalizeUrl('example.com'))
      .to.equal('http://example.com');
  });
  it('collapses twitter-style url fragments', () => {
    expect(normalizeUrl('http://twitter.com/#!/_bgwoodruff'))
      .to.equal('http://twitter.com/_bgwoodruff');
  });
  it('removes fragments', () => {
    expect(normalizeUrl('http://example.com/foo#fragment'))
      .to.equal('http://example.com/foo');
  });
  it('removes trailing ? on an empty query string', () => {
    expect(normalizeUrl('http://example.com/search?'))
      .to.equal('http://example.com/search');
  });
  it('removes common extensions', () => {
    expect(normalizeUrl('http://example.com/search.html'))
      .to.equal('http://example.com/search');
    expect(normalizeUrl('http://example.com/search.php'))
      .to.equal('http://example.com/search');
  });
  it('removes index.html', () => {
    expect(normalizeUrl('http://example.com/index.html'))
      .to.equal('http://example.com');
  });
  it('removes trailing slashes', () => {
    expect(normalizeUrl('http://example.com/'))
      .to.equal('http://example.com');
  });
  it('removes duplicate slashes', () => {
    expect(normalizeUrl('http://example.com//my/page/////here'))
      .to.equal('http://example.com/my/page/here');
  });
  it('removes duplicate slashes', () => {
    expect(normalizeUrl('http://example.com//my/page///.//here'))
      .to.equal('http://example.com/my/page/here');
  });
  it('converts https to http', () => {
    expect(normalizeUrl('https://example.com'))
      .to.equal('http://example.com');
  });
  it('removes www, m, or i prefixes', () => {
    expect(normalizeUrl('https://www.example.com'))
      .to.equal('http://example.com');
    expect(normalizeUrl('https://m.example.com'))
      .to.equal('http://example.com');
    expect(normalizeUrl('https://i.example.com'))
      .to.equal('http://example.com');
  });
  it('removes www, m, or i prefixes', () => {
    expect(normalizeUrl('http://www.example.com'))
      .to.equal('http://example.com');
    expect(normalizeUrl('http://m.example.com'))
      .to.equal('http://example.com');
    expect(normalizeUrl('http://i.example.com'))
      .to.equal('http://example.com');
  });
  it('removes extensions from imgur links', () => {
    // FYI: this is one case where normalization doesn't preserve correctness,
    // as imgur URLs are case-sensitive
    expect(normalizeUrl('https://i.imgur.com/3cpq2uY.jpg'))
      .to.equal('http://imgur.com/3cpq2uy');
  });
  it('works on cascades', () => {
    expect(normalizeUrl('https://m.example.com/index.html/?#section=foo'))
      .to.equal('http://example.com');
  });
});
