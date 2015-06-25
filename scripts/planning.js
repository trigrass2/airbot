/**
 * Description: 
 *     Get your daily planning
 */

var got = require("got-promise");
var BPromise = require("bluebird");
var _ = require("lodash");
var token = "1304013ce1783926ba2b702c3bc481a3cc6a89aa";
var team = require("../team.json");

module.exports = function(robot) {

    robot.hear("planning", function(res) {
        var user = res.message.user;
        var room = {
            room: user.name
        };

        var greeting = ["Hi *<@", user.name, ">* gimme a minute to retrieve it."].join("");
        robot.send(room, greeting);

        var ghUser = getGithubUser(user.name);
        getPlanning(ghUser)
            .then(function(planningAttachment) {
                robot.adapter.customMessage({
                    channel: user.name,
                    text: "Your planning",
                    attachments: planningAttachment
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


function getPlanning(ghUser) {
    return getGithubIssues(ghUser)
        .then(issues2Planning);
}

function getGithubIssues(user) {
    return got("https://api.github.com/search/issues?q=state:open+assignee:" + user, {
            json: true,
            headers: {
                "accept": "application/vnd.github.v3+json",
                "authorization": "token " + token
            }
        })
        .then(function(res) {
            return res.body.items;
        });
}

function issues2Planning(issues) {
    return new BPromise(function(resolve) {
        var message = "";
        var repositories = {};
        _.each(issues, function(issue) {
            var repoName = getRepository(issue);
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
                    message += "\t ⎇ <" + issue.html_url + "|#" + issue.number + "-" + issue.title + ">\n";
                });
            }

            if (issues.issues.length > 0) {
                _.each(issues.issues, function(issue) {
                    message += "\t 𐌏 <" + issue.html_url + "|#" + issue.number + "-" + issue.title + ">\n";
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

function getRepository(issueUrl) {
    var split = issueUrl.html_url.split("/");
    var repository = "unknown";

    if (split.length > 5) {
        repository = split[4];
    }

    return repository;
}
