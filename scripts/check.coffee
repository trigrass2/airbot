# Description:
#   Allows to check if hubot is running
#

module.exports = (robot) ->

  robot.router.get '/hubot/check', (req, res) ->
    res.send 'OK'
