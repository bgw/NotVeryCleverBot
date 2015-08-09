import Model from './Model';
import validators from './validators';

export default class Comment extends Model {
  constructor(knex) {
    super(
      knex,
      'comment',
      Model.column()
        .string('name')
        .unique().primary().index()
        .validator(validators.commentName),
      Model.column()
        .string('parentCommentName')
        .validator(validators.commentName),
      Model.column()
        .string('articleName')
        .validator(validators.articleName)
    );
  }

  async getParentCommentName(name) {
    const result = await this.raw(
      this.sql`select * from comment where name=${{name}}`
    );
    return result[0].parentCommentName;
  }

  async set(comments) {
    await this.raw(
      this.sql`insert or replace into (key, json)
        values (${{name}}, ${{json}})`
    );
    return this;
  }
}
