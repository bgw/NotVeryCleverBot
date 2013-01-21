#!/usr/bin/env python3

if __name__ != "__main__":
    raise ImportError("%s is not a library and should not be imported" %
                      __name__)

import config
import rewriter
import database

import praw
from requests.exceptions import HTTPError, ConnectionError
import time
import pickle
import queue
import re
import random

r = praw.Reddit(user_agent=config.useragent)
r.login(config.username)
db = database.CommentDB()

def score_response(comment, response):
    """
    This function can be modified to give a good internal scoring for a
    response. If negative, we won't post.
    """
    if response.score < 5: return -1
    return (response.score - 20 + len(comment.body)) * random.gauss(1, .1)

def get_best_response(comment):
    simple_body = rewriter.simplify_body(comment.body)
    if simple_body in config.ignore_phrases: return None
    if len(comment.body) < 5 or " " not in comment.body: return None
    responses = db.get_comments(r, {
        "$orderby": "score",
        "metadata.parent_simple_body": simple_body,
    })
    if not responses: return None
    best_response = max(zip(map(score_response, responses), responses))
    if best_response[0] < 0: return None
    return best_response[1]

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
        grow_from_submission(submission)

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
        print("Learning from today's top posts")
        grow_from_top(timeperiod="day", limit=50)
        main_loop.last_learned = time.time()
    # Start writing comments
    print("Fetching more comments")
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
        response = get_best_response(c)
        if response is None:
            continue
        print("Someone said:\n    %s\nSo I should say:\n    %s" %
              (c.body, response.body))
        c.reply(rewriter.prepare_for_post(response, c))
    db.insert_comments(*comments_to_insert, fast=True)
main_loop.last_learned = 0

try:
    if not db.comments.count():
        print("Populating new database from scratch")
        grow_from_top(timeperiod="all", limit=5000)
        grow_from_top(timeperiod="month")
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
            print("Warning: Rate limit exceeded")
            rate_limit_exceeded = True
        time.sleep(max(0, 30 - (time.time() - start_time))) # api limitations
        if rate_limit_exceeded: time.sleep(300)
except KeyboardInterrupt:
    pass
