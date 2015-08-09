import {expect} from 'chai';

import {knex} from './utils';
import RawComment from '../../dist/database/rawComment';

let rawComments;

beforeEach(async function() {
  rawComments = new RawComment(knex);
  await rawComments.init();
});

describe('set and get', async function() {
  it('works for a single comment', async function() {
    const comment = {foo: {bar: 5}, fizz: 'buzz'};
    await rawComments.set({t1_123abc: comment});
    expect(await rawComments.get('t1_123abc')).to.deep.equal(comment);
  });
});
