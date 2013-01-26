================
NotVeryCleverBot
================

This is just a test of an idea. This records the top replies to the top comments
on reddit, and then plays them back to other users on reddit saying exactly the
same thing. It's just like ``Trapped_in_Reddit``, but with comments!

You can see it in action `here <http://www.reddit.com/user/NotVeryCleverBot/>`_.

Contributing
------------

Unfortunately the bot is not yet easy to run or test (the database takes days to
build, and is too large to redistribute). Because of this, **it is okay to send
me broken patches**. I'll fix them and integrate them (assuming I like them).
Right now, prefered contributions would include:

- Cleanup of code (when in doubt, follow PEP-8). This includes breaking code up
  into smaller modules or functions.
- Commenting and documentation. Try to read through the code and comment it
  while you're going along!
- Anything else you can find to do. Did I make a typo? Did I use one thing when
  I should've used another?

Dependencies
------------

- Python 3.2+
- MongoDB (Tested with 2.2.2)
- `praw <https://github.com/praw-dev/praw/>`_

Running the Bot
---------------

After configuration, execute the bot with ``./not-very-clever-bot``.
