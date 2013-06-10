# A set of helper functions that are used to normalize a block of text (or part
# of a block of text)

_ = require "lodash"
_s = require "underscore.string"
frequentWords = require("norvig-frequencies")[0...5000] # These are uppercase

VERSION = "0.0.1" # should get changed whenever the output might be modified

# Remove markdown and any punctuation (possibly mutilating links). This might
# result in some extra spaces, so you should call `clean` afterwards.
demarkdown = (str) ->
    str
        # Flatten numbered and bulleted lists
        .replace(/^\s*([0-9]+\.|[*+-])\s*/gm, " ")
        # Non-word characters
        .replace(/(\W|_)/gm, " ")

# We can use some tricks to speed up word frequency lookups
_frequentLongWords = _.filter frequentWords, (word) -> word.length > 3
_frequentLongWords.sort()
isCommon = (str) ->
    if str.length <= 3 then return true
    return _.indexOf(_frequentLongWords, str.toUpperCase(), true) >= 0

# Removes really common words, because they probably don't add much meaning to
# the input. You should probably run clean after this
uncommonify = (str) ->
    str.replace /\w+/gm, (word) -> if isCommon word then "" else word

clean = _.bind _s.clean, _s

# Do some stuff to minimize the variance in URLs. (`https://google.com/` should
# read the same as `http://www.google.com`)
urlNormalize = (url) ->
    url.toLowerCase()
        # Remove `#fragments` from the end of urls, but leaving Twitter-style
        # `/#/fragments/`, as they tend to have important meaning.
        .replace(/[#][^\/]*$/, "")
        # Take off any ending `index.html` (or similar) thing
        .replace(/\/index\.(html?|php|aspx?)$/, "")
        # Remove a trailing `?` if the query string is empty
        .replace(/\?$/, "")
        # Remove any trailing slash
        .replace(/\/$/, "")
        # Remove any duplicate slashes
        .replace(/([^:]\/)\//, "$1")
        # Turn `https` into `http`
        .replace(/^https/, "http")
        # Remove any `www`, `m`, or `i` prefix at the beginning of a url. `m`
        # and `i` are common on mobile versions of sites.
        .replace(/^http:\/\/(www|m|i)\./, "http://")
        # Remove image extensions from imgur links
        .replace(/(http:\/\/imgur\.com\/[a-z0-9]{3,})\.[a-z]{3}/, "$1")

# Regex from http://daringfireball.net/2010/07/improved_regex_for_matching_urls
urlRegex = ///
(                       # Capture 1: entire matched URL
    (?:
        https?://               # http or https protocol
        |                       #   or
        www\d{0,3}[.]           # "www.", "www1.", "www2." … "www999."
        |                           #   or
        [a-z0-9.\-]+[.][a-z]{2,4}/  # looks like domain name followed by a slash
    )
    (?:                       # One or more:
        [^\s()<>]+                  # Run of non-space, non-()<>
        |                           #   or
        \(([^\s()<>]+|(\([^\s()<>]+\)))*\)  # balanced parens, up to 2 levels
    )+
    (?:                       # End with:
        \(([^\s()<>]+|(\([^\s()<>]+\)))*\)  # balanced parens, up to 2 levels
        |                               #   or
        [^\s`!()\[\]{};:'".,<>?«»“”‘’] # not a space or one of these punct chars
    )
)
///ig

getUrls = (str) -> str.match urlRegex
stripUrls = (str) -> str.replace urlRegex, ""

# The core function that rewrites a comment from its given form to one that we
# can use as a search key in the database. This provides a bit of fuzziness in
# the search.
rewrite = (str) ->
    # Remove urls and save them for later
    urls = _(getUrls str)
        .map(urlNormalize)
        .sortBy(_.identity)
        .uniq(true)
        .value()
    str = stripUrls str
    # Basic string operations
    str = str.toLowerCase()
    str = demarkdown str
    str = uncommonify str
    str = clean str
    # Append normalized and sorted urls at the end
    return "#{str}#{if urls?.length then "\n" else ""}#{urls.join "\n"}"

_.extend exports,
    demarkdown: demarkdown
    isCommon: isCommon
    uncommonify: uncommonify
    clean: clean
    urlNormalize: urlNormalize
    urlRegex: urlRegex
    getUrls: getUrls
    stripUrls: stripUrls
    rewrite: rewrite
