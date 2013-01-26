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
    return " ".join(get_words(body))

def get_words(body):
    stripped = re.sub(config.strip_characters, "", body.strip().lower())
    words = [i for i in re.split("\s", stripped) if i]
    words = [i for i in words if i not in config.strip_words]
    return words

def prepare_for_post(old_comment, new_parent):
    body = old_comment.body
    if not old_comment.is_root:
        old_parent = new_parent.reddit_session.get_info(
            thing_id=old_comment.parent_id)
        if old_parent.author:
            old_parent_author = old_parent.author.name
            regex = re.compile(r"((?<=[\W_])|^)%s((?=[\W_])|$)" %
                               re.escape(old_parent_author), re.IGNORECASE)
            body = regex.sub(new_parent.author.name, body)
    return body + (config.footer % (old_comment.permalink + "?context=3"))
