#!/usr/bin/env python3

if __name__ != "__main__":
    raise ImportError("%s is not a library and should not be imported" %
                      __name__)

import config
import rewriter
import database
import scoring

import praw
from requests.exceptions import HTTPError, ConnectionError
import time
import pickle
import queue
import re
import traceback
import logging

logger = logging.getLogger("autothreader")

r = praw.Reddit(user_agent=config.useragent)
r.login(config.username)
db = database.CommentDB()
scorer = scoring.Scorer(r, db)

def grow_from_top(subreddit="all", timeperiod="all", limit=1000):
    """
    Read from http://reddit.com/top. We won't bother posting here, because it's
    pointless. But we can learn a lot from the posters here.

    This should only really be called when we try to build the database for the
    first time.
    """
    submission_list = getattr(r.get_subreddit(subreddit),
                              "get_top_from_%s" % timeperiod)(limit=limit)
    for submission in submission_list:
        keep_running = True
        while keep_running:
            try:
                grow_from_submission(submission)
                keep_running = False
            except HTTPError:
                logger.exception("Growing from submission failed")

def grow_from_submission(submission):
    # check that we haven't already done this one
    if db.last_seen(submission) is not None: return
    db.mark_submission(submission)
    # Iterate over all the comments
    comments = []
    q = queue.Queue()
    for c in submission.comments:
        q.put(c)
    while not q.empty():
        c = q.get()
        # Figure out if we should skip it
        if isinstance(c, praw.objects.MoreComments): continue
        if db.last_seen(c) is not None: continue
        # process it
        comments.append(c)
        if c.replies:
            for rep in c.replies:
                q.put(rep)
    db.insert_comments(*comments)

def main_loop():
    # try to learn every hour
    if time.time() - main_loop.last_learned > 60*60:
        logger.info("Learning from today's top posts")
        grow_from_top(timeperiod="day", limit=50)
        main_loop.last_learned = time.time()
    # Start writing comments
    logger.debug("Finding comments to reply to")
    comments_to_insert = []
    for c in r.get_all_comments(limit=200):
        # Keep from processing the same thing twice
        if db.last_seen(c) is not None:
            continue
        # learn it
        comments_to_insert.append(c)
        # Don't reply to yourself
        if c.author.name == config.username:
            continue
        response = scorer.get_best_response(c)
        if response is None:
            continue
        logger.info("Responding to a user")
        try:
            c.reply(rewriter.prepare_for_post(response, c))
        except HTTPError as err:
            if err.response.status_code == 403:
                logger.warning("HTTP 403. This probably means you were banned "
                               "from a subreddit.")
            else:
                logger.exception("Error responding to user")
    db.insert_comments(*comments_to_insert, fast=True)
main_loop.last_learned = 0

try:
    db.auto_update()
    if not db.comments.count():
        logger.info("Populating new database from scratch")
        grow_from_top(timeperiod="all", limit=10000)
        grow_from_top(timeperiod="month", limit=1000)
    while True:
        start_time = time.time()
        rate_limit_exceeded = False
        try:
            main_loop()
        except HTTPError:
            pass
        except ConnectionError:
            pass
        except praw.errors.RateLimitExceeded:
            logger.warning("Warning: Rate limit exceeded")
            rate_limit_exceeded = True
        time.sleep(max(0, 30 - (time.time() - start_time))) # api limitations
        if rate_limit_exceeded: time.sleep(300)
except KeyboardInterrupt:
    pass
