# Description:
#   Notify users of GitHub comment mentions, issues/PRs assignments.
#
# Dependencies:
#   "lodash": "^3.2.0"
#
# Configuration:
#   HUBOT_TEAM_URL  - (Optional) The URL of your team. (e.g.: https://my.slack.com/team/)
#   HUBOT_TEAM_PATH - (Optional) If you want to convert GitHub's `@` mention to another services's (Slack and etc.) mention, you can specify a json file to describe the conversion rule.
#      {
#        "github_user": "slack_user"
#      }
#
#   Put this url <HUBOT_URL>:<PORT>/hubot/gh-notify into your GitHub Webhooks
#   and enable 'issues', 'pull_request', 'issue_comment' and 'pull_request_review_comment' as events to receive.
#
# Author:
#   jcombes

_ = require 'lodash'
team = try require process.env.HUBOT_TEAM_PATH

# Extract all users which are mentioned in a comment
#
# comment - The comment
#
# Returns an array of the mentioned users.
extract_mentions = (comment) ->
  mentions = []
  match = comment.match /(^|\s)(@[\w\-\/]+)/g
  if match
    mentions = _.uniq(mention.trim() for mention in match)
  mentions

# Return the team user corresponding to the github user
#
# github_user - The github user
#
# Returns the team user
to_user = (github_user) ->
  # Remove @
  github_user = github_user.replace /^@/g, "" if github_user.length

  if team && team[github_user]
    user = team[github_user]
  else
    user = github_user
  user

# Send a private message to multiple users.
#
# robot - The current robot instance
# user - A User array, each one is as stored in a `respond` msg object
# message - The private message String
#
# Returns nothing.
private_messages = (robot, users, message) ->
  users.forEach (user) ->
    private_message robot, user, message

# Send a private message to a given user.
#
# robot - The current robot instance
# user - A User, as stored in a `respond` msg object
# message - The private message String
#
# Returns nothing.
private_message = (robot, user, message) ->
  # Delete the reply_to information
  delete user.reply_to
  try
    robot.send {room: to_user(user)}, message
  catch e
    robot.logger.error "Error trying to send a message to #{user}"


module.exports = (robot) ->

  # handle new comments and new issue/PR assignments
  robot.router.post '/hubot/gh-notify', (req, res) ->
    payload = req.body
    # event can be issues, issue_comment, pull_request, pull_request_review_comment
    event = req.headers['x-github-event']

    # discriminate the payload according to the action type
    if ((event is 'issues' or event is 'pull_request') and payload.action is 'opened')
      if event is 'issues'
        issue = payload.issue
        new_what = 'issue'
      else
        issue = payload.pull_request
        new_what = 'PR'
      mentioned_by = to_user(issue.user.login)
      userInfos = extract_mentions(issue.body)
      private_messages robot, userInfos, "You have been mentioned in a new #{new_what} by #{mentioned_by} in #{payload.repository.full_name}: #{issue.html_url}."
    else if ((event is 'issue_comment' or event is 'pull_request_review_comment') and payload.action is 'created')
      mentioned_by = to_user(payload.comment.user.login)
      userInfos = extract_mentions(payload.comment.body)
      private_messages robot, userInfos, "You have been mentioned in a new comment by #{mentioned_by} in #{payload.repository.full_name}: #{payload.comment.html_url}."
    else if ((event is 'issues' or event is 'pull_request') and payload.action is 'assigned')
      if event is 'issues'
        issue = payload.issue
        new_what = 'an issue'
      else
        issue = payload.pull_request
        new_what = 'a PR'
      assigned_by = to_user(payload.sender.login)
      userInfos = [ payload.assignee.login ] if payload.assignee.login
      private_messages robot, userInfos, "You have been assigned to #{new_what} by #{assigned_by} in #{payload.repository.full_name}: #{issue.html_url}."

    res.send 'HOLO YOLO'

