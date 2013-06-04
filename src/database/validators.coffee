# Additional validators for our fields that sequelize doesn't have built-in

# Every reddit "thing" has a "name" (sometimes called a "fullname") associated
# with it. This has a typecode, followed by the thing's id.
nameTyped = (typeNumber) ->
    is: new RegExp "t#{typeNumber}_[a-z0-9]+"

# Different versions of `nameTyped`
name = nameTyped "[0-9]+"
nameComment = nameTyped 1
nameAccount = nameTyped 2
nameArticle = nameLink = nameTyped 3
nameMessage = nameTyped 4
nameSubreddit = nameTyped 5
nameAward = nameTyped 6
namePromoCampaign = nameTyped 8

module.exports = {
    nameTyped,
    name,
    nameComment,
    nameAccount,
    nameArticle,
    nameLink,
    nameMessage,
    nameSubreddit,
    nameAward,
    namePromoCampaign
}
