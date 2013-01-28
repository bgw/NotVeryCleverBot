import config
import rewriter

import pymongo
import bson
import praw
import time
import logging

logger = logging.getLogger("database")

DATABASE_FORMAT = "0.0.6" # change when changes are made, use semver

class CommentDB:
    def __init__(self):
        self.connection = pymongo.MongoClient(config.mongo_server_address,
                                              config.mongo_server_port)
        self.database = self.connection[config.mongo_db_name]
        # The main collection. Every comment we've ever seen on reddit. Format
        # matches the API's JSON format.
        self.comments = self.database.comments
        # Submissions we've already seen. Only enough information is stored so
        # that we can know not to scan it again.
        self.submissions = self.database.submissions
        # A smaller database with only high scoring comments (uses DBRef)
        self.good_comments = self.database.good_comments
        # Store information about the database itself (database version, last
        # update, etc)
        self.metadata_collection = self.database.metadata
        if self.metadata is None:
            self.metadata = {
                "database_format": DATABASE_FORMAT,
                "last_update": time.time(),
            }
        self.ensure_indexes()
    
    def ensure_indexes(self):
        """
        Build indexes. We can then search by any of these named keys quickly.
        (Usually O(1) time)
        """
        self.good_comments.ensure_index([("metadata.parent_simple_body", 1),
                                         ("metadata.score", -1)])
        self.comments.ensure_index("name", unique=True)
        self.submissions.ensure_index("name", unique=True)

    def get_metadata(self, describing="database"):
        return self.metadata_collection.find_one({"describing": describing})

    def set_metadata(self, document, describing="database"):
        if "_id" in document:
            del document["_id"] # update on _id not allowed
        self.metadata_collection.update({"describing": describing},
                                        {"$set": document}, upsert=True)

    metadata = property(get_metadata, set_metadata)

    def auto_update(self):
        if self.metadata["database_format"] != DATABASE_FORMAT:
            logger.warning("Database format out-of-date. (%s -> %s)" %
                (self.metadata["database_format"], DATABASE_FORMAT))
            self.update()

    def update(self):
        """
        Try to update the database format to the latest version.
        """
        logger.warning("Updating database. This will probably take a while. "
                       "(%s -> %s)" %
                       (self.metadata["database_format"], DATABASE_FORMAT))
        # Rebuild supplimental collection data
        #self.rebuild_comments_metadata()
        self.rebuild_good_comments()
        # update the full database metadata
        dbmd = self.metadata
        dbmd["database_format"] = DATABASE_FORMAT
        dbmd["last_update"] = time.time()
        self.metadata = dbmd
        #self.compact_all()

    def compact_all(self):
        logger.info("Compacting all database collections")
        collections = "comments", "submissions", "good_comments", "metadata"
        for c in collections: self.database.command("compact", c)

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

    def get_comments(self, reddit_session, query,
                     sort_by=[("metadata.score", -1)], good_only=False,
                     limit=100):
        if good_only:
            cursor = self.good_comments.find(query).sort(sort_by)
        else:
            cursor = self.comments.find(query).sort(sort_by)
        if limit > 0: cursor = cursor.limit(limit)
        # define a helper
        g = lambda doc: self.comments.find_one({"name":doc["base_ref"]}) \
                        if good_only else doc
        # convert to comment objects
        return [self.__json_to_comment(reddit_session, g(el)) for el in cursor]
    
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

    def insert_comments(self, *comments, fast=True):
        if not comments: return
        comments_by_id = {c.name: c for c in comments}
        documents = []
        for c in comments:
            r = c.reddit_session
            json = self.__comment_to_json(c)
            json["metadata"] = self.generate_comment_metadata(
                json, comments_by_id, None if fast else c.reddit_session)
            documents.append(json)
        self.comments.insert(documents)

    def generate_comment_metadata(self, comment_json, comments_by_id={},
                                  reddit_session=None):
        parent_body = parent_simple_body = None
        # find the parent body
        # Comments are of type t1, submissions are t3
        if comment_json["parent_id"][:2] != "t3":
            # lookup in local table
            parent_id = comment_json["parent_id"]
            try:
                parent = comments_by_id[parent_id]
                if isinstance(parent, praw.objects.Comment):
                    parent = parent.json_dict
            except KeyError:
                # lookup in database
                parent = self.comments.find_one({"name": parent_id},
                                                {"body": True})
                if parent is None and reddit_session is not None:
                    # fall back to looking it up with the API
                    parent = r.get_info(thing_id=comment.parent_id).json_dict
            # Pull out what we want for later
            if parent is not None:
                parent_body = parent["body"]
                parent_simple_body = rewriter.simplify_body(parent_body)
        # We shouldn't overwrite insert time if we can avoid it
        try: insert_time = comment_json["metadata"]["insert_time"]
        except KeyError: insert_time = time.time()
        # Put it all together
        return {
            "parent_simple_body": parent_simple_body,
            "parent_body": parent_body,
            "score": comment_json["ups"] - comment_json["downs"],
            "insert_time": insert_time,
            "database_format": DATABASE_FORMAT,
        }

    def rebuild_comments_metadata(self, query={}):
        """
        Used when upgrading the database, or dealing with a changed
        configuration. This is very slow.
        """
        logger.info("Rebuilding comment metadata")
        for document in self.comments.find(query):
            comment_metadata = self.generate_comment_metadata(document)
            self.comments.update({"_id": document["_id"]},
                                 {"$set": {"metadata": comment_metadata}},
                                 upsert=True)
    
    def rebuild_good_comments(self):
        """
        This assumes the comments metadata is sane
        """
        logger.info("Rebuilding 'good comments' collection")
        self.good_comments.drop()
        cursor = self.comments.find(
            {"$and": [
                {"metadata.score": {"$gte": config.good_comment_threshold}},
                {"metadata.parent_simple_body": {"$ne": None}},
                {"metadata.parent_simple_body": {"$ne": ""}},
            ]},
            {
                "metadata.score": True, "metadata.parent_simple_body": True,
                "name": True
            })
        for document in cursor:
            self.good_comments.insert({
                "base_ref": document["name"],
                "metadata": {
                    "score": document["metadata"]["score"],
                    "parent_simple_body":
                        document["metadata"]["parent_simple_body"],
                },
            })

    def drop(self):
        """
        !!!WARNING!!!
        """
        logger.warning("Dropping *entire* MongoDB database!")
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
