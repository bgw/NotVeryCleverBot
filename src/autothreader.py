#!/usr/bin/env python3

if __name__ != "__main__":
    raise ImportError("%s is not a library and should not be imported" %
                      __name__)

import sys
sys.path += ["../lib/praw"]

import praw
from requests.exceptions import HTTPError
import time
import pickle
import queue
import re

r = praw.Reddit(user_agent="NotVeryCleverBot thread response predictor by "
                           "/u/pipeep")
username = "NotVeryCleverBot"
footer = "\n\n---\n*^^I'm ^^a ^^new ^^bot ^^in ^^testing. ^^Let ^^me ^^know " \
         "^^how ^^I'm ^^doing. [^^Original ^^Thread.](%s)*"
r.login(username)
try:
    with open("comments.db", "rb") as f:
        response_db, already_done = pickle.load(f)
        print("loaded %d comments" % len(already_done))
except IOError:
    response_db = {}
    already_done = set()

def strip_formatting(comment_body):
    return re.sub(r"""[._'"?!]""", "", comment_body.lower())

def score_response(comment):
    """
    This function can be modified to give a good internal scoring for a
    response. If negative, we won't post.
    """
    original_score, body, permalink = \
        response_db[strip_formatting(comment.body)]
    if len(comment.body) < 5: return -1
    return original_score - 20

def grow_from_top():
    """
    Read from http://reddit.com/top. We won't bother posting here, because it's
    pointless. But we can learn a lot from the posters here.

    This should only really be called when we try to build the database for the
    first time.
    """
    for submission in r.get_top(limit=900):
        q = queue.Queue()
        for c in submission.comments:
            q.put(c)
        while not q.empty():
            comment = q.get()
            already_done.add(comment.id)
            if isinstance(comment, praw.objects.MoreComments):
                continue
            if not comment.replies:
                continue
            if isinstance(comment.replies[0], praw.objects.MoreComments):
                continue
            if comment.body in response_db and \
                                   comment.score < response_db[comment.body][0]:
                continue
            for rep in comment.replies: q.put(rep)
            response_db[strip_formatting(comment.body)] = (
                comment.score, comment.replies[0].body, comment.permalink
            )

def main_loop():
    print("Fetching more comments")
    for c in r.get_all_comments(limit=200):
        # Keep from processing the same thing twice
        if c.id in already_done:
            continue
        else:
            already_done.add(c.id)
        if c.author.name == username:
            continue
        if c.body in response_db:
            response = response_db[strip_formatting(c.body)]
            print("lookup of score %d" % score_response(c))
            if score_response(c) < 0:
                continue
            print("Someone said:\n    %s\nSo I should say:\n    %s" %
                  (c.body, response[1]))
            c.reply(response[1] + (footer % response[2]))

try:
    if not response_db:
        print("Building new database from scratch")
        grow_from_top()
        print("dumping database")
        with open("comments.db.initial", "wb") as f:
            pickle.dump((response_db, already_done), f)
    while True:
        start_time = time.time()
        rate_limit_exceeded = False
        try:
            main_loop()
        except HTTPError:
            pass
        except praw.errors.RateLimitExceeded:
            print("Warning: Rate limit exceeded")
            rate_limit_exceeded = True
        time.sleep(30 - (time.time() - start_time)) # Reddit api limitations
        if rate_limit_exceeded: time.sleep(300)
except KeyboardInterrupt:
    pass
finally:
    print("dumping database")
    with open("comments.db", "wb") as f:
        pickle.dump((response_db, already_done), f)
