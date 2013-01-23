# sys.path manipulation
import sys
sys.path += ["../lib/praw"]

# General Settings
username = "NotVeryCleverBot"
useragent = "NotVeryCleverBot thread response predictor by /u/pipeep"
footer = "\n\n---\n*^^I'm ^^a ^^thread ^^response ^^predicting ^^bot ^^in " \
         "^^testing. ^^Let ^^me ^^know ^^how ^^I'm ^^doing. " \
         "[^^Original ^^Thread.](%s) ^^Here's ^^my " \
         "[^^source ^^code](https://github.com/PiPeep/NotVeryCleverBot)*"
# Don't respond when someone says one of these phrases
ignore_phrases = {"thank you", "wat", "what", "yes", "no", "this", "yo dawg",
                  "source", "original", "pics didnt happen",
                  "where this from"}
# These words are useless... remove them
strip_words = {"the", "and", "you", "it", "is", "isnt", "like", "of", "i", "a",
               "has", "will", "in", "thats", "what", "so", "at", "for", "do",
               "to", "ill", "but", "of", "id", "was", "wasnt", "them", "also",
               "an", "its", "are", "on", "be", "too", "very", "or", "now"}
strip_characters = r"""[.,;_'"`?!()\-&^]"""

# MongoDB Settings
mongo_server_address = "localhost"
mongo_server_port = 27017
mongo_db_name="not-very-clever-bot"
