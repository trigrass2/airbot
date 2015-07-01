/**
 * Description:
 *     Get your daily planning
 */

var _ = require("lodash");
var got = require("got-promise");
var schedule = require('node-schedule');
var BPromise = require("bluebird");

var token = process.env.GITHUB_TOKEN;
var team = require("../team.json");

var jiraCredUser = process.env.JIRA_USER;
var jiraCredPwd = process.env.JIRA_PWD;
var auth = new Buffer(jiraCredUser + ":" + jiraCredPwd).toString('base64');
var blacklist = ["airbot", "air2d2", "slackbot"];
var airbot;
var debug = process.env.AIRBOT_PLANNING_DEBUG;

module.exports = function(robot) {
    airbot = robot;

    // Monday => Friday at 8am.
    var rule = new schedule.RecurrenceRule();
    rule.dayOfWeek = [new schedule.Range(1, 5)];
    rule.hour = 7;
    rule.minute = 0;

    // Daily planning
    airbot.logger.debug("Scheduling daily planning");
    schedule.scheduleJob(rule, sendPlanningToEachUser);

    // On demand planning
    airbot.respond("/planning/i", function(res) {
        var username = res.message.user.name;

        var greeting = ["Hi *<@", username,
            ">* gimme a minute to retrieve it..."
        ].join("");
        sendMessage(username, greeting);

        getFullPlanning(username);
    });

};

function sendPlanningToEachUser() {
    var allUsers = getDailyPlanningSubscribers();

    var planningTasks = _.map(allUsers, function(user) {
        var username = user.name;
        airbot.logger.debug("Build planning task for:", username);
        if (_.contains(blacklist, username)) {
            return function() {
                airbot.logger.debug("Nothing to build for:", username);
                return BPromise.resolve();
            };
        }

        return function() {
            var greeting = [":alarm_clock: Good morning *<@", username,
                ">*, I'm just finishing to compile your planning..."
            ].join("");
            return greetUser(username, greeting)
                .then(function() {
                    return getFullPlanning(username);
                })
                .then(function() {
                    airbot.logger.debug("Wait for 1sec..");
                    return new BPromise(function(resolve) {
                        setTimeout(function() {
                            resolve();
                        }, 1000);
                    });
                })
                .catch(function(e) {
                    console.error("Error sending message to", username, "=>", e);
                });
        };
    });

    BPromise.resolve(planningTasks).each(function(task) {
            return task();
        })
        .then(function() {
            airbot.logger.debug("All done");
        });
}

function greetUser(username, message) {
    return new BPromise(function(resolve, reject) {
        try {
            sendMessage(username, message);
        } catch (e) {
            reject(e);
            return;
        }
        resolve();
    });
}

function getDailyPlanningSubscribers() {
    // Get all Slack users
    return airbot.brain.usersForFuzzyName("");
}

function getFullPlanning(username) {
    var ghUser = getGithubUser(username);
    var jiraUser = getJiraUser(username);

    return getGithubPlanning(ghUser)
        .then(function(githubPlanning) {
            sendCustomMessage(username, "Here it is", githubPlanning);
            return getJiraPlanning(jiraUser);
        })
        .then(function(jiraPlanning) {
            sendCustomMessage(username, "Wait... there's more!", jiraPlanning);
        });
}

function getGithubUser(slackUser) {
    var result = slackUser;

    _.each(team, function(slack, github) {
        if (slack === slackUser) {
            result = github;
            return;
        }
    });

    return result;
}

function getGithubPlanning(ghUser) {
    return getGithubIssues(ghUser)
        .then(github2Planning);
}

function getGithubIssues(user) {
    return got("https://api.github.com/search/issues?q=state:open+assignee:" +
            user, {
                json: true,
                headers: {
                    "accept": "application/vnd.github.v3+json",
                    "authorization": "token " + token,
                    "user-agent": "https://github.com/AirVantage/airbot"
                }
            })
        .then(function(res) {
            return res.body.items;
        })
        .catch(function(err) {
            airbot.logger.debug("No github planning for '", user, "'");
        });
}

function github2Planning(issues) {

    if (!issues) {
        return BPromise.resolve();
    }

    return new BPromise(function(resolve) {
        var message = "";
        var repositories = {};
        _.each(issues, function(issue) {
            var repoName = getGithubRepository(issue);
            if (!repositories[repoName]) {
                repositories[repoName] = {
                    prs: [],
                    issues: []
                };
            }
            if (issue.pull_request) {
                repositories[repoName].prs.push(issue);
            } else {
                repositories[repoName].issues.push(issue);
            }
        });

        _.each(repositories, function(issues, repo) {
            message += " _" + repo + "_\n";

            if (issues.prs.length > 0) {
                _.each(issues.prs, function(issue) {
                    message += "\t ⎇ <" + issue.html_url +
                        "|#" + issue.number + "> " +
                        issue.title + "\n";
                });
            }

            if (issues.issues.length > 0) {
                _.each(issues.issues, function(issue) {
                    message += "\t 𐌏 <" + issue.html_url +
                        "|#" + issue.number + "> " +
                        issue.title + "\n";
                });
            }

        });

        resolve([{
            fallback: "https://github.com/issues/assigned",
            title: "Github",
            text: message,
            color: "#666666",
            mrkdwn_in: ["text"]
        }]);

    });
}

function getGithubRepository(issueUrl) {
    var split = issueUrl.html_url.split("/");
    var repository = "unknown";

    if (split.length > 5) {
        repository = split[4];
    }

    return repository;
}

function getJiraUser(slackUser) {
    var result = slackUser;

    if (team.jira[slackUser]) {
        result = team.jira[slackUser];
    }

    return result;
}

function getJiraPlanning(jiraUser) {
    return getJiraIssues(jiraUser)
        .then(jira2Planning);
}

function getJiraIssues(jiraUser) {

    var query = "assignee=" + jiraUser +
        " AND status in (Open, Incomplete, Reopened, \"In Progress\") ORDER BY priority DESC";
    return got("https://issues.sierrawireless.com/rest/api/2/search?jql=" +
            query, {
                json: true,
                headers: {
                    "Authorization": "Basic " + auth,
                    "user-agent": "https://github.com/AirVantage/airbot"
                }
            })
        .then(function(res) {
            return res.body.issues;
        });
}

function jira2Planning(issues) {
    return new BPromise(function(resolve) {
        var message = "";
        var projects = {};
        _.each(issues, function(issue) {
            var projectName = getJiraProject(issue);
            if (!projects[projectName]) {
                projects[projectName] = [];
            }
            projects[projectName].push(issue);
        });

        _.each(projects, function(issues, project) {
            message += " _" + project + "_\n";
            if (issues.length > 0) {
                _.each(issues, function(issue) {
                    message += "\t 𐌏 <" +
                        getJiraIssueUrl(issue) + "|" +
                        issue.key + "> " + issue.fields
                        .summary + "\n";
                });
            }
        });

        resolve([{
            fallback: "https://issues.sierrawireless.com/issues/?filter=-1",
            title: "JIRA",
            text: message,
            color: "#e43a2f",
            mrkdwn_in: ["text"]
        }]);

    });
}


function getJiraProject(issue) {
    var split = issue.key.split("-");
    var repository = "unknown";

    if (split.length > 1) {
        repository = split[0];
    }

    return repository;
}

function getJiraIssueUrl(issue) {
    return "https://issues.sierrawireless.com/browse/" + issue.key;
}

function sendMessage(username, message) {
    if (debug) {
        airbot.logger.debug("@" + username, ":", message);
    } else {
        airbot.send({
            room: username
        }, message);
    }
}

function sendCustomMessage(username, title, content) {
    if (debug) {
        airbot.logger.debug("@" + username, "->", title);
    } else {
        airbot.adapter.customMessage({
            channel: username,
            text: title,
            attachments: content
        });
    }
}
