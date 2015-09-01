import './polyfill';

import _ from 'lodash';
import config from './config';
import logger from './logger';
import Rockets from 'rockets';
import CommentTable from './database/CommentTable';

let commentTable;
let commentBuffer = {};

async function main() {
  await config.init();
  // TODO: improve how DB code is initialized
  commentTable = new CommentTable(config.knex);
  await commentTable.init();

  // configure and connect rockets client
  const rocketsClient = new Rockets();
  rocketsClient.on('connect', () => {
    rocketsClient.subscribe('comments');
  });
  rocketsClient.on('disconnect', () => {
    logger.warn('disconnected from rockets server, reconnecting');
    rocketsClient.reconnect();
  });
  rocketsClient.on('error', (err) => logger.error(err));
  rocketsClient.on('comment', ({data}) => {
    const comment = data;
    logger.info(`r/${comment.subreddit}`, comment.author);
    commentBuffer[comment.name] = comment;
    // will happen asynchronously sometime later
    throttledFlushComments();
  });
  rocketsClient.connect();
}

async function flushComments() {
  const oldBuffer = commentBuffer;
  commentBuffer = {};
  // may take some time
  logger.info(`starting flush of ${oldBuffer.length} items to disk`);
  await commentTable.set(_.values(oldBuffer));
  logger.info(`finished flushing ${oldBuffer.length} items to disk`);
}

// don't write to the db more than once a second
const throttledFlushComments = _.throttle(() => flushComments().done(), 1000);

main().done();
