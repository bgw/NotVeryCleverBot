import config
import rewriter

import itertools
import random

class Scorer:
    def __init__(self, reddit_session, database):
        self.reddit_session = reddit_session
        self.database = database

    def score_response(self, comment, response):
        """
        This function can be modified to give a good internal scoring for a
        response. If negative, we won't post.
        """
        if response.body.strip() == "[deleted]": return -1
        simple_body = rewriter.simplify_body(comment.body)
        if response.score < 10: return -1
        return (response.score - 40 + len(simple_body)) * random.gauss(1, .2)

    def get_best_response(self, comment):
        simple_body = rewriter.simplify_body(comment.body)
        if simple_body in config.ignore_phrases: return None
        if len(simple_body) < 10 or simple_body.count(" ") < 3: return None
        responses = self.database.get_comments(self.reddit_session, {
            "$query": {"metadata.parent_simple_body": simple_body},
            "$orderby": {"metadata.score": -1},
        })
        if not responses: return None
        best_response = max(
            zip(
                map(self.score_response, itertools.repeat(comment), responses),
                responses
            ), key=lambda v:v[0]
        )
        if best_response[0] < 0: return None
        return best_response[1]
