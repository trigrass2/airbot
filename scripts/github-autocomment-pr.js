/**
 * Description:
 *     autocomment pull requests
 */

var _ = require("lodash");
var GitHubApi = require('github');

var token = process.env.GITHUB_TOKEN;

var airbot;

var genericChecklistComment = "Please write here the checklist to execute before merging this pull request. Here is an example:\n" +
    "- [ ] Branch is up-to-date (master merged into it)\n" +
    "- [ ] Code review done\n" +
    "- [ ] Documentation updated\n" +
    "- [ ] Describe smoke tests\n" +
    "- [ ] Smoke tests OK\n" +
    "- [ ] Describe the new non-regression tests written\n" +
    "- [ ] Describe non-regression tests done\n" +
    "- [ ] Non-regression tests OK";

var checklistComment = "Here is the checklist to complete before merging pull request:\n" +
    "- [ ] Branch is up-to-date (master merged into it)\n" +
    "- [ ] Code review done\n" +
    "- [ ] Translation done (if required)\n" +
    "- [ ] Non-regression tests updated\n" +
    "- [ ] Documentation updated (API, N&N)\n" +
    "- [ ] Performance tests done\n" +
    "- [ ] Smoke tests reviewed\n" +
    "- [ ] Feature validated\n" +
    "- [ ] Smoke tests OK\n" +
    "- [ ] Non-regression tests OK (put the list of non-regression tests done)\n" +
    "- [ ] Jasmine tests written (if required)\n" +
    "\n" +
    "Don't hesitate to modify/complete this list. We just need to trace what was done and how.";

var checklists = {};

module.exports = function(robot) {
    airbot = robot;

    airbot.router.post('/hubot/alert-twiml', function(req, res) {
        var payload = req.body;
        var event = req.headers['x-github-event']
        if (event === "pull_request" && payload.pull_request && payload.action === "opened") {
            console.log('Pull request opened');
            if (payload.repository.full_name === "AirVantage/aws-lambda-sns-twilio") {
                var github = new GitHubApi({
                    // required
                    version: "3.0.0",
                    // optional
                    debug: true,
                    protocol: "https",
                    host: "api.github.com",
                    timeout: 5000,
                    headers: {
                        "user-agent": "airvantage-pullrequestagent-app" // GitHub is happy with a unique user agent
                    }
                });
                github.authenticate({
                    type: "oauth",
                    token: token
                });

                github.issues.createComment({
                        user: payload.repository.owner.login,
                        repo: payload.repository.name,
                        number: payload.pull_request.number,
                        body: genericChecklistComment,
                    },
                    function(err, result) {
                        if (err) {
                            console.log(err);
                        } else {
                            res.send("OK");
                        }
                    }
                );
            }
        }
    });
};