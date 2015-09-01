import Table from './Table';
import * as $v from './validators';
import {getNormalizedScore} from '../transform/score';
import assert from 'assert';
import indexify from '../transform/indexify';

const __toObject = Symbol('toObject');
const __toSql = Symbol('toSql');

export default class CommentTable extends Table {
  constructor(knex) {
    super(
      knex,
      'comment',
      Table.column()
        .string('name')
        .unique().primary().index()
        .validator($v.commentName),
      Table.column()
        .string('parent_comment_name')
        .index()
        .validator($v.commentName.or($v.null)),
      Table.column()
        .string('article_name')
        .validator($v.articleName),
      Table.column()
        .text('body'),
      Table.column()
        .text('body_index')
        .index(),
      Table.column()
        .integer('score')
        .index(),
      Table.column()
        .text('json')
        .validator($v.json.or($v.null))
    );
  }

  static [__toObject](sqlObject) {
    const result = Table.camelize(sqlObject)
    result.json = result.json && JSON.parse(result.json);
    return result;
  }

  // transforms things, but doesn't decamelize: that's the job of the sql
  // template
  static [__toSql](jsObject) {
    return Object.assign({}, jsObject, {
      json: jsObject.json && (
        typeof jsObject.json === 'string' ?
          jsObject.json :
          JSON.stringify(jsObject.json)
        ),
    });
  }

  async get(name) {
    const result = await this.execSql`
      select *
      from comment
      where name=${{name}}
    `;
    assert(result.length <= 1, 'table is in an inconsistant state');
    return result.length ? CommentTable[__toObject](result[0]) : null;
  }

  async search(normalizedBody, limit=10) {
    const result = await this.execSql`
      select c.*
      from comment
        join (
          select
            name as _parent_comment_name,
            score as parent_comment_score,
            body_index as parent_body_index
          from comment
        ) as c on comment.parent_comment_name = c._parent_comment_name
      where parent_body_index=${{normalizedBody}}
      limit ${limit}
      order by score desc`;
    return result.map(CommentTable[__toObject]).sort((a, b) =>
      getNormalizedScore(a) - getNormalizedScore(b)
    )
  }

  async set(...comments) {
    await this.exec(
      [
        'insert or replace into comment values ',
        {
          code: `(
            :name,
            :parentCommentName,
            :articleName,
            :body,
            :bodyIndex,
            :score,
            :json
          )`,
          sep: ',',
        },
      ],
      ...comments.map(CommentTable[__toSql])
    );
    return this;
  }

  async setFromJson(...comments) {
    return await this.set(...comments.map((json) => ({
      name: json.name,
      parentCommentName: $v.commentName(json.parent_id) ? json.parent_id : null,
      articleName: json.link_id,
      body: json.body,
      bodyIndex: indexify(json.body),
      score: json.score_hidden ? null : json.score,
      json,
    })));
  }

  /**
   * A (slightly hackish) implementation to get and rewrite all the comments in
   * the table.
   *
   * We'd lock the table while running this, but that'd inhibit replace
   * operations, or we'd use knex's stream support, but that's currently shimmed
   * in the SQLite driver.
   */
  async transform(transformer, chunkLen=100) {
    let i = 0;
    while (true) {
      const chunk = await this.execSql`
        select *
        from comment
        limit ${chunkLen}
        offset ${chunkLen * i}
      `;
      if (chunk.length === 0) {
        break;
      }
      this.set(chunk.map(CommentTable[__toObject]).map((orig) => {
        const {name} = orig;
        const result = transformer(src);
        // check that the name didn't change: that would cause an insert instead
        // of a replace
        assert.equal(result.name, name);
        return result;
      }));
      ++i;
    }
  }
}
