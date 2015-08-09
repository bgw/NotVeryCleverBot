import _ from 'lodash';

import Model from './Model';

export default class RawComment extends Model {
  constructor(knex) {
    super(
      knex,
      'RawComment',
      Model.column()
        .string('name')
        .unique()
        .primary()
        .index(),
      Model.column()
        .text('json')
    );
  }

  async get(name) {
    const result =
      await this.execSql`select json from RawComment where name=${{name}}`;
    return result.length ? JSON.parse(result[0].json) : undefined;
  }

  /**
   * @param {object} rawComments Comments as `{name: json}` pairs, where the
   * json value is a string or object.
   * @returns {RawComment} `this`, to assist with chaining.
   */
  async set(rawComments) {
    await this.exec(
      [
        'insert or replace into RawComment (name, json) values ',
        {code: '( :name, :json )', sep: ','},
      ],
      ...Object.keys(rawComments).map((name) => {
        let json = rawComments[name];
        return {
          name,
          json: typeof json === 'string' ? json : JSON.stringify(json)
        };
      })
    );
    return this;
  }
}
