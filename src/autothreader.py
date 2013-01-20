#!/usr/bin/env python3

if __name__ != "__main__":
    raise ImportError("%s is not a library and should not be imported" %
                      __name__)

import sys
sys.path += ["../lib/praw"]

import praw
from requests.exceptions import HTTPError
from time import sleep
import pickle

r = praw.Reddit(user_agent="Thread response predictor by /u/pipeep")
try:
    with open("comments.db", "r") as f:
        comment_db, already_done = pickle.load("comments.db")
        print("loaded %d comments" % len(already_done))
except:
    comment_db = {}
    already_done = set()

def find_best_response(body):
    parent_urls = comment_db[body]
    best = (1, None) # require a score of at least 1 to consider it good enough
    for purl in parent_urls:
        try:
            candidate = r.get_submission(url=purl) \
                         .comments[0].replies[0]
        except HTTPError:
            print("error")
            continue
        if candidate.score > best[0]:
            best = (candidate.score, candidate)
    return best[1]

def main_loop():
    print("Fetching more comments")
    for c in r.get_all_comments(limit=500):
        # Keep from processing the same thing twice
        url = c.permalink
        if url in already_done:
            continue
        else:
            already_done.add(url)
        # Add to database, and respond if we have a response
        if c.body not in comment_db:
            comment_db[c.body] = set()
        else:
            response = find_best_response(c.body)
            if response is not None:
                print("Someone said:\n    %s\nSo I should say:\n    %s" %
                      (c.body, response.body))
        comment_db[c.body].add(url)

try:
    while True:
        try:
            main_loop()
        except HTTPError:
            pass
        sleep(30.1) # Reddit api limitations
except KeyboardInterrupt:
    print("dumping database")
    with open("comments.db", "w") as f:
        pickle.dump((comment_db, already_done), f)
