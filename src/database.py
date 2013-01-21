import pymongo
import praw
import time
import config
import rewriter

DATABASE_FORMAT = "0.0.1" # change when changes are made, use semver

class CommentDB:
    def __init__(self):
        self.connection = pymongo.MongoClient(config.mongo_server_address,
                                              config.mongo_server_port)
        self.database = self.connection[config.mongo_db_name]
        self.comments = self.database.comments
        self.submissions = self.database.submissions
        self.metadata = self.database.metadata
        self.comments.ensure_index([("metadata.parent_simple_body", 1),
                                    ("score", -1)])
        self.comments.ensure_index("name", unique=True)

    @staticmethod
    def __json_to_comment(reddit_session, json):
        json = dict(json)
        if "metadata" in json: del json["metadata"]
        return praw.objects.Comment(reddit_session, json)

    @staticmethod
    def __comment_to_json(comment):
        # this is possible because of our monkey-patching below
        j = dict(comment.json_dict)
        if j["replies"]:
            j["replies"]["data"]["children"] = [c.name for c in comment.replies\
                if not isinstance(c, praw.objects.MoreComments)]
        return j

    def get_comments(self, reddit_session, query, max_results=100):
        cursor = self.comments.find(query).limit(max_results)
        if max_results > 0:
            json_elements = cursor[:min(max_results, cursor.count())]
        else:
            json_elements = cursor[:]
        return [self.__json_to_comment(reddit_session, el) \
                for el in json_elements]
    
    def mark_submission(self, submission):
        """
        Mark that we've already seen this submission.
        """
        self.submissions.insert({
            "name": submission.name,
            "created_utc": submission.created_utc,
            "metadata": {
                "insert_time": time.time(),
            },
        })

    def last_seen(self, submission_or_comment):
        if isinstance(submission_or_comment, praw.objects.Submission):
            collection = self.submissions
        elif isinstance(submission_or_comment, praw.objects.Comment):
            collection = self.comments
        else:
            raise TypeError("%s is not a submission or comment." %
                            submission_or_comment)
        document = collection.find_one(
            {"name": submission_or_comment.name},
            {"metadata.insert_time": True})
        if document is None: return None
        return document["metadata"]["insert_time"]

    def insert_comments(self, *comments, fast=False):
        if not comments: return
        comments_by_name = {c.name:c for c in comments}
        documents = []
        for c in comments:
            r = c.reddit_session
            json = self.__comment_to_json(c)
            if fast or c.is_root:
                parent_simple_body = None
            else:
                try:
                    parent = comments_by_name[c.parent_id]
                except KeyError:
                    parent = r.get_info(thing_id=c.parent_id)
                parent_simple_body = rewriter.simplify_body(parent.body)
            # We insert all of our database-specific stuff in "metadata", so
            # that we can easily remove it before constructing comment objects
            json["metadata"] = {
                "parent_simple_body": parent_simple_body,
                "insert_time": time.time(),
                "database_format": DATABASE_FORMAT,
            }
            documents.append(json)
        self.comments.insert(documents)

    def drop(self):
        """
        !!!WARNING!!!
        """
        self.connection.drop_database(config.mongo_db_name)

# Monkey patch RedditContentObject so that we can extract the json without extra
# requests

_old_populate = praw.objects.RedditContentObject._populate
def _populate(self, json_dict, fetch):
    if json_dict is None:
        if fetch:
            json_dict = self._get_json_dict()
        else:
            json_dict = {}
    self.json_dict = json_dict
    return _old_populate(self, json_dict, fetch)

praw.objects.RedditContentObject._populate = \
    _populate.__get__(None, praw.objects.RedditContentObject)
