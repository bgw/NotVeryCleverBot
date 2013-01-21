"""
Rewrites comments for lookup and posting. This generally means stripping and/or
reformatting a comment.
"""

import config
import re

def simplify_body(body):
    """
    Given a comment body, puts it in a standardized format that disregards
    things like punctuation that get in our way.
    """
    return re.sub(config.strip_characters, "", body.strip().lower())

def prepare_for_post(old_comment, new_parent):
    body = old_comment.body
    if not old_comment.is_root:
        old_parent = new_parent.reddit_session.get_info(
            thing_id=old_comment.parent_id).comments[0]
        old_parent_author = old_parent.author
        regex = re.compile(r"((?<=[\W_])|^)%s((?=[\W_])|$)" %
                           re.escape(old_parent_author), re.IGNORE_CASE)
        body = regex.sub(new_parent.author, body)
    return body + (config.footer % (old_comment.permalink + "?context=3"))
