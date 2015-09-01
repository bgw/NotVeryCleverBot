import {expect} from 'chai';

import {knex} from './utils';
import Table from '../../dist/database/Table';

let Foo;

beforeEach(async function() {
  Foo = new Table(
    knex,
    'Foo',
    Table.column()
      .string('foo'),
    Table.column()
      .float('bar')
      .unique()
  );
});

describe('column definition', () => {
  it('is fully lazy', () => {
    Table.column()
      .string('foobar')
      .charset('non-existant')
      .methodDoesNotExist();
  });
});

describe('init', () => {
  it('returns a promise', async function() {
    await Foo.init();
  });
  it('creates the table', async function() {
    expect(await knex.schema.hasTable('Foo')).to.be.false;
    await Foo.init();
    expect(await knex.schema.hasTable('Foo')).to.be.true;
  });
  it('creates all the columns', async function() {
    await Foo.init();
    expect(await knex.schema.hasColumn('Foo', 'foo')).to.be.true;
    expect(await knex.schema.hasColumn('Foo', 'bar')).to.be.true;
  });
});

describe('sql', () => {
  beforeEach(() => Foo.init());
  it('should transform into an object', () => {
    const bar = 5.3;
    expect(Foo.sql`fizzbuzz`).to.be.an('object');
    expect(Foo.sql`fizzbuzz ${bar}`).to.be.an('object');
    expect(Foo.sql`fizzbuzz ${{bar}}`).to.be.an('object');
  });
});

describe('exec/execSql', () => {
  beforeEach(() => Foo.init());

  it('bubbles errors', async function() {
    await expect(Foo.exec('fizzbuzz')).to.eventually.be.rejected;
    await expect(Foo.execSql`fizzbuzz`).to.eventually.be.rejected;
  });

  it('accepts a sql object', async function() {
    await Foo.execSql`insert into Foo (foo, bar) values (${'abc'}, ${5.3})`;
    expect(await Foo.execSql`select * from Foo where foo=${'abc'}`)
      .to.deep.equal([{foo: 'abc', bar: 5.3}]);
  });

  it('works on batch operations', async function() {
    await Foo.exec(
      ['insert into Foo (foo, bar) values ', ['(?, ?)', ', ']],
      ['fizz', 1], ['buzz', 2]
    );
    await Foo.exec(
      // long format for code/sep
      ['insert into Foo (foo, bar) values ', {code: '(?, ?)', sep: ', '}],
      // columns
      'foo', 'bar',
      ['fizz', 3], ['buzz', 4]
    );
    await Foo.exec(
      ['insert into Foo (foo, bar) values ', ['( :foo, :bar )', ', ']],
      {foo: 'dog', bar: 5}, {bar: 6, foo: 'cat'}
    );
    expect(await Foo.execSql`select * from Foo order by bar`)
      .to.deep.equal([
        {foo: 'fizz', bar: 1}, {foo: 'buzz', bar: 2},
        {foo: 'fizz', bar: 3}, {foo: 'buzz', bar: 4},
        {foo: 'dog',  bar: 5}, {foo: 'cat', bar: 6},
      ]);
  });
});

describe('validation', () => {
  beforeEach(() => Foo.init());
  it('is run upon insertion');
});
