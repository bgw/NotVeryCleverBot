import {expect} from 'chai';

import normalize from '../../dist/transform/normalize';

describe('normalize', () => {
  it('is an identity function for empty strings', () => {
    expect(normalize('')).to.equal('');
  });
  it('flattens whitespace', () => {
    expect(normalize('buzzuley\t\n\r fizzuely')).to.equal('buzzuley fizzuely');
  });
  it('trims leading/trailing whitespace', () => {
    expect(normalize(' buzzuley fizzuely\n')).to.equal('buzzuley fizzuely');
  });
  it('lower-cases input', () => {
    expect(normalize('FooBarIzeIl1')).to.equal('foobarizeil1');
  });
  it('strips markdown lists', () => {
    expect(normalize('1. abc\n2. def')).to.equal('abc def');
    expect(normalize('11. abc\n12. def')).to.equal('abc def');
    expect(normalize('* abc\n* def')).to.equal('abc def');
    expect(normalize('+ abc\n+ def')).to.equal('abc def');
    expect(normalize('- abc\n- def')).to.equal('abc def');
  });
  it('strips arbitrary non-word markdown characters', () => {
    expect(normalize('*emphasisify*')).to.equal('emphasisify');
    expect(normalize('**strongemphasis**')).to.equal('strongemphasis');
    expect(normalize('_underlineify_')).to.equal('underlineify');
    expect(normalize('[abc](def)')).to.equal('abc def');
  });
  it('removes common words', () => {
    expect(normalize('the cat *and* (dog) boondoggle')).to.equal('boondoggle');
  });
  it('moves urls to the bottom', () => {
    expect(normalize('abc http://example.com def http://google.com ghi'))
      .to.equal('abc def ghi\nhttp://example.com\nhttp://google.com');
  });
  it('sorts urls alphabetically', () => {
    expect(normalize('abc http://google.com def http://example.com ghi'))
      .to.equal('abc def ghi\nhttp://example.com\nhttp://google.com');
  });
  it('deduplicates urls', () => {
    expect(normalize('abc http://google.com def http://google.com ghi'))
      .to.equal('abc def ghi\nhttp://google.com');
  });
  it('works when there is not body, only a url', () => {
    expect(normalize('http://google.com')).to.equal('http://google.com');
  });
  it('normalizes urls', () => {
    expect(normalize('https://www.google.com')).to.equal('http://google.com');
  });
});
