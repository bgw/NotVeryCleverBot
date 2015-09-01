import {expect} from 'chai';

import {knex} from './utils';
import CommentTable from '../../dist/database/CommentTable';

const TEST_COMMENT = {
  name: 't1_cuiwy6g',
  parentCommentName: 't1_cuiwe7y',
  articleName: 't3_3iq5kd',
  body: 'These references went straight over your head. Whoosh!',
  // made up index value
  bodyIndex: '31be6e247978f0d06885039d0c5f8f66',
  score: 1,
  json: {
    subreddit_id: 't5_2qt55',
    link_title: 'Leech-infested pool.',
    banned_by: null,
    removal_reason: null,
    link_id: 't3_3iq5kd',
    link_author: 'Sippingin',
    likes: null,
    replies: '',
    user_reports: [],
    saved: false,
    id: 'cuiwy6g',
    gilded: 0,
    archived: false,
    report_reasons: null,
    author: '5xSonicx5',
    parent_id: 't1_cuiwe7y',
    score: 1,
    approved_by: null,
    over_18: false,
    controversiality: 0,
    body: 'These references went straight over your head. Whoosh!',
    edited: false,
    author_flair_css_class: null,
    downs: 0,
    body_html:
      '&lt;div class=\"md\"&gt;&lt;p&gt;These references went straight over ' +
      'your head. Whoosh!&lt;/p&gt;\n&lt;/div&gt;',
    quarantine: false,
    subreddit: 'gifs',
    score_hidden: true,
    name: 't1_cuiwy6g',
    created: 1440816058.0,
    author_flair_text: null,
    link_url: 'https://gfycat.com/UnderstatedWateryFreshwatereel',
    created_utc: 1440787258.0,
    ups: 1,
    mod_reports: [],
    num_reports: null,
    distinguished: null,
  },
};

let comments;

beforeEach(async function() {
  comments = new CommentTable(knex);
  await comments.init();
});

describe('set and get', async function() {
  it('works for a single comment', async function() {
    await comments.set(TEST_COMMENT);
    expect(await comments.get(TEST_COMMENT.name)).to.deep.equal(TEST_COMMENT);
  });
});
