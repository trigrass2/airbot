# Description:
#   Inspired by https://github.com/github/hubot-scripts/blob/master/src/scripts/remind.coffee
#   Updated to allow user to add a reminder to another user
#
#
# Dependencies:
#   "chrono-node": "^0.1.10"
#   "moment": "^2.8.1"
#   "lodash": "^2.4.1"
#
# Configuration:
#   None
#
# Commands:
#   hubot remind <target> in <time> to <action> - Set a reminder in <time> to do an <action> <time> is in the format 1 day, 2 hours, 5 minutes etc. Time segments are optional, as are commas
#   hubot delete reminder <action> - Delete reminder matching <action> (exact match required)
#   hubot show reminders
#
# Author:
#   whitman
#   jtwalters
#   arenoux

_ = require('lodash')
moment = require('moment')
chrono = require('chrono-node')
timeoutIds = {}

class Reminders
  constructor: (@robot) ->
    @cache = []
    @currentTimeout = null

    # Load reminders from brain, on loaded event
    @robot.brain.on('loaded', =>
      if @robot.brain.data.reminders
        @cache = _.map(@robot.brain.data.reminders, (item) ->
          new Reminder(item)
        )
        console.log("loaded #{@cache.length} reminders")
        @queue()
    )

    # Persist reminders to the brain, on save event
    @robot.brain.on('save', =>
      @robot.brain.data.reminders = @cache
    )

  add: (reminder) ->
    @cache.push(reminder)
    @cache.sort((a, b) -> a.due - b.due)
    @queue()

  removeFirst: ->
    reminder = @cache.shift()
    return reminder

  queue: ->
    return if @cache.length is 0
    now = (new Date).getTime()
    trigger = =>
      reminder = @removeFirst()
      target= 
        room: reminder.msg_envelope.user.name
      sender=
        room: reminder.msg_envelope.message.user.name 
      console.log reminder.msg_envelope
      @robot.send(target, reminder.msg_envelope.message.user.name + ' asked me to remind you to ' + reminder.action)
      @robot.send(sender, 'I just remind ' + reminder.msg_envelope.user.name + ' to ' + reminder.action)

      @queue()
    # setTimeout uses a 32-bit INT
    extendTimeout = (timeout, callback) ->
      if timeout > 0x7FFFFFFF
        setTimeout(->
          extendTimeout(timeout - 0x7FFFFFFF, callback)
        , 0x7FFFFFFF)
      else
        setTimeout(callback, timeout)
    reminder = @cache[0]
    duration = reminder.due - now
    duration = 0 if duration < 0
    clearTimeout(timeoutIds[reminder])
    timeoutIds[reminder] = extendTimeout(reminder.due - now, trigger)
    console.log("reminder set with duration of #{duration}")

class Reminder
  constructor: (data) ->
    {@msg_envelope, @action, @time, @due} = data

    if @time and !@due
      @time.replace(/^\s+|\s+$/g, '')

      periods =
        weeks:
          value: 0
          regex: "weeks?"
        days:
          value: 0
          regex: "days?"
        hours:
          value: 0
          regex: "hours?|hrs?"
        minutes:
          value: 0
          regex: "minutes?|mins?"
        seconds:
          value: 0
          regex: "seconds?|secs?"

      for period of periods
        pattern = new RegExp('^.*?([\\d\\.]+)\\s*(?:(?:' + periods[period].regex + ')).*$', 'i')
        matches = pattern.exec(@time)
        periods[period].value = parseInt(matches[1]) if matches

      @due = (new Date).getTime()
      @due += (
        (periods.weeks.value * 604800) +
        (periods.days.value * 86400) +
        (periods.hours.value * 3600) +
        (periods.minutes.value * 60) +
        periods.seconds.value
      ) * 1000

  formatDue: ->
    dueDate = new Date(@due)
    duration = dueDate - new Date
    if duration > 0 and duration < 86400000
      'in ' + moment.duration(duration).humanize()
    else
      'on ' + moment(dueDate).format("dddd, MMMM Do YYYY, h:mm:ss a")

module.exports = (robot) ->
  reminders = new Reminders(robot)

  getAmbiguousUserText = (users) ->
    "Be more specific, I know #{users.length} people named like that: #{(user.name for user in users).join(", ")}"

  robot.respond(/show reminders$/i, (msg) ->
    text = ''
    for reminder in reminders.cache
      text += "#{reminder.action} #{reminder.formatDue()}\n"
    msg.send(text)
  )

  robot.respond(/delete reminder (.+)$/i, (msg) ->
    query = msg.match[1]
    prevLength = reminders.cache.length
    reminders.cache = _.reject(reminders.cache, {action: query})
    reminders.queue()
    msg.send("Deleted reminder #{query}") if reminders.cache.length isnt prevLength
  )

  # robot.respond(/remind me (in|on) (.+?) to (.*)/i, (msg) ->
  #   type = msg.match[1]
  #   time = msg.match[2]
  #   action = msg.match[3]
  #   options =
  #     msg_envelope: msg.envelope,
  #     action: action
  #     time: time
  #   if type is 'on'
  #     # parse the date (convert to timestamp)
  #     due = chrono.parseDate(time).getTime()
  #     if due.toString() isnt 'Invalid Date'
  #       options.due = due
  #   reminder = new Reminder(options)
  #   reminders.add(reminder)
  #   msg.send "I'll remind you to #{action} #{reminder.formatDue()}"
  # )

  robot.respond /remind (.+) in ((?:(?:\d+) (?:weeks?|days?|hours?|hrs?|minutes?|mins?|seconds?|secs?)[ ,]*(?:and)? +)+)to (.*)/i, (msg) ->
    who = msg.match[1]
    time = msg.match[2]
    action = msg.match[3]
    users = robot.brain.usersForFuzzyName(who)
    if users.length is 1
      user = users[0]
      msg.envelope.user = user
      msg.envelope.message.room = user.name
      options =
        msg_envelope: msg.envelope,
        action: action
        time: time
      reminder = new Reminder(options)
      reminders.add reminder
      msg.send "I'll remind #{user.name} to #{action} #{reminder.formatDue()}"
    else if users.length > 1
      msg.send getAmbiguousUserText users
      return
    else
      msg.send "Cannot find user #{who}"
