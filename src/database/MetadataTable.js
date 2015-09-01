/**
 * Provide a very simple key-value table for storing information about the
 * database itself.
 */

import Table from './Table';

export default class MetadataTable extends Table {
  constructor(knex) {
    super(
      knex,
      'metadata',
      Table.column()
        .string('key')
        .unique().primary().index(),
      Table.column()
        .string('value')
    );
  }

  async get(name) {
    const result =
      await this.execSql`select value from metadata where name=${{name}}`;
    return result.length ? result[0].value : undefined;
  }

  async set(entries) {
    await this.exec(
      [
        'insert or replace into metadata (key, value) values ',
        {code: '( :key, :value )', sep: ','},
      ],
      ...Object.keys(entries).map(key => ({key, value: entries[key]}))
    );
    return this;
  }
}
