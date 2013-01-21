# sys.path manipulation
import sys
sys.path += ["../lib/praw"]

# General Settings
username = "NotVeryCleverBot"
useragent = "NotVeryCleverBot thread response predictor by /u/pipeep"
footer = "\n\n---\n*^^I'm ^^a ^^thread ^^response ^^predicting ^^bot ^^in " \
         "^^testing. ^^Let ^^me ^^know ^^how ^^I'm ^^doing. " \
         "[^^Original ^^Thread.](%s)*"
ignore_phrases = {"thank you", "wat", "what", "yes", "no", "this", "yo dawg"}
strip_characters = r"""[._'"`?!()]"""

# MongoDB Settings
mongo_server_address = "localhost"
mongo_server_port = 27017
mongo_db_name="not-very-clever-bot"
