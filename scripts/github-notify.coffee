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
msg_color = "#7CD197"
gh_logo_url = "http://static.airvantage.io/img/gitHub-octocat-200x166.png"

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
# robot - the current robot instance
# user - the array of github users
# message - the message with attachment object
#
# Returns nothing.
private_messages = (robot, users, message) ->
  users.forEach (user) ->
    private_message robot, user, message

# Send a private message to a given user.
#
# robot - the current robot instance
# user - the github user
# message - the message with attachment object
#
# Returns nothing.
private_message = (robot, user, message) ->
  try
    message.channel = to_user(user)
    robot.adapter.customMessage message
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
        event_type = 'issue'
      else
        issue = payload.pull_request
        event_type = 'pull request'
      mentioned_by = to_user(issue.user.login)
      userInfos = extract_mentions(issue.body)
      message = {
        text: ":octocat: - You have been *mentioned* in a new *#{event_type}*"
        attachments: [
          {
            fallback: "You have been mentioned in a new #{event_type} by #{mentioned_by} in #{payload.repository.full_name}: #{issue.html_url}.",
            title: "#{issue.title}",
            title_link: "#{issue.html_url}",
            fields: [
                {
                    title: "Repository",
                    value: "#{payload.repository.full_name}",
                    short: false
                },
                {
                    title: "Mentioned by",
                    value: "<@#{mentioned_by}>",
                    short: false
                },
                {
                    title: "Message",
                    value: issue.body,
                    short: false
                }
            ],
            "color": msg_color,
            "thumb_url": gh_logo_url
          }
        ]
      }
      private_messages robot, userInfos, message

    else if ((event is 'issue_comment' or event is 'pull_request_review_comment') and payload.action is 'created')
      if event is 'issue_comment'
        issue = payload.issue
        event_type = 'an *issue*'
        event_type_raw = 'an issue'
      else
        issue = payload.pull_request
        event_type = 'a *pull request*'
        event_type_raw = 'a pull request'
      mentioned_by = to_user(payload.comment.user.login)
      userInfos = extract_mentions(payload.comment.body)
      message = {
        text: ":octocat: - You have been *mentioned* in #{event_type}"
        attachments: [
          {
            fallback: "You have been mentioned in #{event_type_raw} by #{mentioned_by} in #{payload.repository.full_name}: #{payload.comment.html_url}.",
            title: "#{issue.title}",
            title_link: "#{payload.comment.html_url}",
            fields: [
                {
                    title: "Repository",
                    value: "#{payload.repository.full_name}",
                    short: false
                },
                {
                    title: "Mentioned by",
                    value: "<@#{mentioned_by}>",
                    short: false
                },
                {
                    title: "Message",
                    value: payload.comment.body,
                    short: false
                }
            ],
            "color": msg_color,
            "thumb_url": gh_logo_url
          }
        ]
      }
      private_messages robot, userInfos, message

    else if ((event is 'issues' or event is 'pull_request') and payload.action is 'assigned')
      if event is 'issues'
        issue = payload.issue
        event_type = 'an *issue*'
        event_type_raw = 'an issue'
      else
        issue = payload.pull_request
        event_type = 'a pull *request*'
        event_type_raw = 'a pull request'
      assigned_by = to_user(payload.sender.login)
      userInfos = [ payload.assignee.login ] if payload.assignee.login
      message = {
        text: ":octocat: - You have been *assigned* to #{event_type}"
        attachments: [
          {
            fallback: "You have been assigned to #{event_type_raw} by #{assigned_by} in #{payload.repository.full_name}: #{issue.html_url}.",
            title: "#{issue.title}",
            title_link: "#{issue.html_url}",
            fields: [
                {
                    title: "Repository",
                    value: "#{payload.repository.full_name}",
                    short: false
                },
                {
                    title: "Assigned by",
                    value: "<@#{assigned_by}>",
                    short: false
                }
            ],
            "color": msg_color,
            "thumb_url": gh_logo_url
          }
        ]
      }
      private_messages robot, userInfos, message

    res.send 'HOLO YOLO'
