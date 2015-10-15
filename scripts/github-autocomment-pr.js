/**
 * Description:
 *     autocomment pull requests
 */

var _ = require("lodash");
var GitHubApi = require('github');

var token = process.env.GITHUB_TOKEN;

var airbot;

var defaultChecklistComment = "Please write here the checklist to execute before merging this pull request. Here is an example:\n" +
    "- [ ] Branch is up-to-date (master merged into it)\n" +
    "- [ ] Code review done\n" +
    "- [ ] Documentation updated\n" +
    "- [ ] Describe smoke tests\n" +
    "- [ ] Smoke tests OK\n" +
    "- [ ] Describe the new non-regression tests written\n" +
    "- [ ] Describe non-regression tests done\n" +
    "- [ ] Non-regression tests OK";

var checklists = {};
// Customize the checklist per GitHub repo here
checklists["AirVantage/aws-lambda-sns-twilio"] = "My custom checklist:\n" +
    "- [ ] Branch is up-to-date (master merged into it)\n" +
    "- [ ] Describe the tests done\n";

module.exports = function(robot) {
    airbot = robot;

    airbot.router.post('/hubot/gh-autocomment-pr', function(req, res) {
        var payload = req.body;
        var event = req.headers['x-github-event'];
        if (event === "pull_request" && payload.pull_request && payload.action === "opened") {
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

            var comment = defaultChecklistComment;
            if (event.repository.full_name in checklists) {
                comment = checklists[event.repository.full_name];
            }
            github.issues.createComment({
                    user: payload.repository.owner.login,
                    repo: payload.repository.name,
                    number: payload.pull_request.number,
                    body: comment,
                },
                function(err, result) {
                    if (err) {
                        console.log(err);
                        res.send("NOK");
                    } else {
                        res.send("OK");
                    }
                }
            );
        }
    });
};