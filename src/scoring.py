import config
import rewriter

import itertools
import collections
import random
import math

class Scorer:
    def __init__(self, reddit_session, database):
        self.reddit_session = reddit_session
        self.database = database

    def score_response(self, comment, response):
        """
        This function can be modified to give a good internal scoring for a
        response. If negative, we won't post. This is useful when there is more
        than one possible response in our database.
        """
        # Discard the obviously bad responses
        if response.body.strip() == "[deleted]": return -1
        simple_body = rewriter.simplify_body(comment.body)
        if response.score < config.good_comment_threshold: return -1
        # Derive our base score. We use a logarithm, because reddit scores are
        # roughly logrithmic <http://amix.dk/blog/post/19588>
        base_score = math.log10(response.score)
        # A raw pentalty to subtract for the comment being in a different
        # context from it's parent
        response_parent = self.__get_parent(response)
        if response_parent is not None:
            similarity = self._get_parent_similarity_ratio(comment,
                                                           response_parent)
            difference_penalty = math.log10(10000) * (1 - similarity)**10
        else:
            difference_penalty = math.log10(10000)
        # give it some points for length
        length_reward = math.log10(len(simple_body))
        # throw in some randomness for good luck
        fuzz_multiplier = random.gauss(mu=1, sigma=.05)
        # put it all together
        final_score = (base_score - difference_penalty + length_reward) * \
                      fuzz_multiplier
        return final_score
    
    def _get_parent_similarity_ratio(self, comment, response):
        count_a, count_b = \
            self.__get_parent_words(comment), self.__get_parent_words(response)
        total_count_a, total_count_b = \
            sum(count_a.values()), sum(count_b.values())
        if not total_count_a or not total_count_b:
            return 0
        same_words = total_count_a - sum(count_a.subtract(count_b).values())
        return same_words / min(total_count_a, total_count_b)

    def __get_parent_words(self, *args, **kwargs):
        """
        Gets a Counter of all the words in all the parents. (given a comment)
        """
        word_counter = collections.Counter()
        parents = self.__get_parents(*args, **kwargs)
        for p in parents:
            word_counter.update(rewriter.get_words(p.body))
        return word_counter

    def __get_parents(self, comment, limit=3):
        """
        Gets a list of all the parents of a comment.
        """
        parents = []
        while not comment.is_root and len(parents) < limit:
            r = self.__get_parent(comment)
            if not r: break
            comment = r[0]
            parents.append(comment)
        return parents

    def __get_parent(self, comment):
        """
        Gets the parent of a comment. TODO: move this somewhere where it makes
        more sense.
        """
        r = self.database.get_comments(self.reddit_session,
                                       {"name": comment.parent_id})

    def get_best_response(self, comment):
        simple_body = rewriter.simplify_body(comment.body)
        if simple_body in config.ignore_phrases: return None
        if len(simple_body) < 10 or simple_body.count(" ") < 2: return None
        responses = self.database.get_comments(
            self.reddit_session, 
            {"metadata.parent_simple_body": simple_body},
            good_only=True,
            limit=100)
        if not responses: return None
        best_response = max(
            zip(
                map(self.score_response, itertools.repeat(comment), responses),
                responses
            ), key=lambda v:v[0]
        )
        if best_response[0] < 0: return None
        return best_response[1]
