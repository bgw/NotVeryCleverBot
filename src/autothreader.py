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

r = praw.Reddit(user_agent="NotVeryCleverBot thread response predictor by "
                           "/u/pipeep")
username = "NotVeryCleverBot"
footer = "\n\n---\n^I'm ^a ^new ^bot ^in ^testing. ^Let ^me ^know ^how ^I'm " \
         "^doing."
r.login(username)
try:
    with open("comments.db", "rb") as f:
        response_db, already_done = pickle.load(f)
        print("loaded %d comments" % len(already_done))
except IOError:
    response_db = {}
    already_done = set()

def grow_from_top():
    """
    Read from http://reddit.com/top. We won't bother posting here, because it's
    pointless. But we can learn a lot from the posters here.

    This should only really be called when we try to build the database for the
    first time.
    """
    for submission in r.get_top(limit=500):
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
            for r in comment.replies: q.put(r)
            response_db[comment.body] = comment.score, comment.replies[0].body

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
            response = response_db[c.body]
            print("Someone said:\n    %s\nSo I should say:\n    %s" %
                  (c.body, response[1]))
            c.reply(response[1] + footer)

try:
    if not response_db:
        print("Building new database from scratch")
        grow_from_top()
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
    print("dumping database")
    with open("comments.db", "wb") as f:
        pickle.dump((response_db, already_done), f)
