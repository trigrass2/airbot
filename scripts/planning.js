/**
 * Description: 
 *     Get your daily planning
 */

var got = require("got-promise");
var BPromise = require("bluebird");
var _ = require("lodash");
var token = process.env.GITHUB_TOKEN;
var team = require("../team.json");

var jiraCredUser = process.env.JIRA_USER;
var jiraCredPwd = process.env.JIRA_PWD;
var auth = new Buffer(jiraCredUser + ":" + jiraCredPwd).toString('base64');

module.exports = function(robot) {

    robot.hear("planning", function(res) {
        var user = res.message.user;
        var room = {
            room: user.name
        };

        var greeting = ["Hi *<@", user.name, ">* gimme a minute to retrieve it..."].join("");
        robot.send(room, greeting);

        var ghUser = getGithubUser(user.name);
        var jiraUser = getJiraUser(user.name);

        getGithubPlanning(ghUser)
            .then(function(githubPlanning) {

                robot.adapter.customMessage({
                    channel: user.name,
                    text: "Here it is",
                    attachments: githubPlanning
                });

                return getJiraPlanning(jiraUser);
            })
            .then(function(jiraPlanning) {

                robot.adapter.customMessage({
                    channel: user.name,
                    text: "Wait... there's more!",
                    attachments: jiraPlanning
                });
            });
    });

};

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
    return got("https://api.github.com/search/issues?q=state:open+assignee:" + user, {
            json: true,
            headers: {
                "accept": "application/vnd.github.v3+json",
                "authorization": "token " + token,
                "user-agent": "https://github.com/AirVantage/airbot"
            }
        })
        .then(function(res) {
            return res.body.items;
        });
}

function github2Planning(issues) {
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
                    message += "\t ⎇ <" + issue.html_url + "|#" + issue.number + "> " + issue.title + "\n";
                });
            }

            if (issues.issues.length > 0) {
                _.each(issues.issues, function(issue) {
                    message += "\t 𐌏 <" + issue.html_url + "|#" + issue.number + "> " + issue.title + "\n";
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

    var query = "assignee=" + jiraUser + " AND status in (Open, Incomplete, Reopened) ORDER BY priority DESC";
    return got("https://issues.sierrawireless.com/rest/api/2/search?jql=" + query, {
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
                    message += "\t 𐌏 <" + getJiraIssueUrl(issue) + "|" + issue.key + "> " + issue.fields.summary + "\n";
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
