# Description:
#   Notify users of GitHub comment mentions, issues/PRs assignments.
#
# Dependencies:
#   "lodash": "^3.2.0"
#
# Configuration:
#
#   Put this url <HUBOT_URL>:<PORT>/hubot/gh-notify into your GitHub Webhooks
#   and enable 'issues', 'pull_request', 'issue_comment' and 'pull_request_review_comment' as events to receive.
#
# Author:
#   jcombes

_ = require 'lodash'
team = require '../team.json'

default_msg_color = "#7CD197"
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

# Build a slack message
#
# msg - object containing information to be used to build the message
# {
#   text: "",
#   fallback: "",
#   title: "",
#   title_link: "",
#   repository: "",
#   mentioned_by: "",
#   assigned_by: "",
#   author: "",
#   message: "",
#   author_name: "",
#   author_link: "",
#   author_icon: "",
#   color: "",
#   thumb_url: ""
# }
#
# Returns the message with the slack format.
build_slack_message = (msg) ->
  fields = []
  if (msg.repository)
    fields.push({
      title: "Repository",
      value: msg.repository,
      short: false
    })
  if (msg.mentioned_by)
    fields.push({
      title: "Mentioned By",
      value: msg.mentioned_by,
      short: false
    })
  if (msg.assigned_by)
    fields.push({
      title: "Assigned By",
      value: msg.assigned_by,
      short: false
    })
  if (msg.author)
    fields.push({
      title: "Author",
      value: msg.author,
      short: false
    })
  if (msg.message)
    fields.push({
      title: "Message",
      value: msg.message,
      short: false
    })
  
  {
    text: msg.text
    attachments: [
      fallback: msg.fallback,
      title: msg.title,
      title_link: msg.title_link,
      fields: fields,
      author_name: msg.author_name,
      author_link: msg.author_link,
      author_icon: msg.author_icon,
      color: if msg.color then  msg.color else default_msg_color,
      thumb_url: if msg.thumb_url then  msg.thumb_url else gh_logo_url
    ]
  }

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
        text: ":octocat: - You have been *mentioned* in a new *#{event_type}*",
        fallback: "You have been mentioned in a new #{event_type} by #{mentioned_by} in #{payload.repository.full_name}: #{issue.html_url}.",
        title: "#{issue.title}",
        title_link: "#{issue.html_url}",
        repository: "#{payload.repository.full_name}",
        mentioned_by: "<@#{mentioned_by}>",
        message: issue.body,
        thumb_url: issue.user.avatar_url
      }
      private_messages robot, userInfos, build_slack_message(message)

    else if ((event is 'issue_comment' or event is 'pull_request_review_comment') and payload.action is 'created')
      if event is 'issue_comment'
        issue = payload.issue
        event_type = 'issue'
        event_type_prefix = 'an'
      else
        issue = payload.pull_request
        event_type = 'pull request'
        event_type_prefix = 'a'

      mentioned_by = to_user(payload.comment.user.login)
      userInfos = extract_mentions(payload.comment.body)
      message = {
        text: ":octocat: - You have been *mentioned* in #{event_type_prefix} *#{event_type}*",
        fallback: "You have been mentioned in #{event_type_prefix} #{event_type} by #{mentioned_by} in #{payload.repository.full_name}: #{payload.comment.html_url}.",
        title: "#{issue.title}",
        title_link: "#{payload.comment.html_url}",
        repository: "#{payload.repository.full_name}",
        mentioned_by: "<@#{mentioned_by}>",
        message: payload.comment.body,
        thumb_url: payload.comment.user.avatar_url
      }
      private_messages robot, userInfos, build_slack_message(message)

      # Notify the owner if not mentioned and if he is not the sender
      owner = issue.user.login
      if (owner != payload.comment.user.login and not _.includes(userInfos, owner))
        message = {
          text: ":octocat: - New comment in your *#{event_type}*",
          fallback: "A comment has been added in your #{event_type} by #{mentioned_by} in #{payload.repository.full_name}: #{payload.comment.html_url}.",
          title: "#{issue.title}",
          title_link: "#{payload.comment.html_url}",
          repository: "#{payload.repository.full_name}",
          author: "<@#{mentioned_by}>",
          message: payload.comment.body,
          thumb_url: payload.comment.user.avatar_url
        }
        private_messages robot, [ owner ], build_slack_message(message)

    else if ((event is 'issues' or event is 'pull_request') and payload.action is 'assigned')
      if event is 'issues'
        issue = payload.issue
        event_type = 'issue'
        event_type_prefix = 'an'
      else
        issue = payload.pull_request
        event_type = 'pull request'
        event_type_prefix = 'a'

      # Notify only if the assigned user is not the sender
      assignedUser = payload.assignee.login
      if (payload.sender.login != assignedUser)
        assigned_by = to_user(payload.sender.login)
        message = {
          text: ":octocat: - You have been *assigned* to #{event_type_prefix} *#{event_type}*",
          fallback: "You have been assigned to #{event_type_prefix} #{event_type} by #{assigned_by} in #{payload.repository.full_name}: #{issue.html_url}.",
          title: "#{issue.title}",
          title_link: "#{issue.html_url}",
          repository: "#{payload.repository.full_name}",
          assigned_by: "<@#{assigned_by}>",
          thumb_url: payload.sender.avatar_url
        }
        private_messages robot, [ assignedUser ], build_slack_message(message)

    res.send 'HOLO YOLO'
