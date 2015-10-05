/**
 * Description:
 *     Send alert notifications to the different channels (Slack, SMS, Email, Voice call)
 */

var _ = require("lodash");
var GitHubApi = require('github');
var twilio = require('twilio')(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

var token = process.env.GITHUB_TOKEN;

var airbot;

module.exports = function(robot) {
    airbot = robot;

    airbot.router.post('/hubot/alert-twiml', function(req, res) {
        res.send("<Response>" +
            "<Say>AirVantage alert!</Say>" +
            "<Pause length=\"2\"/>" +
            "<Say>AirVantage alert!</Say>" +
            "<Pause length=\"2\"/>" +
            "<Say>AirVantage alert!</Say>" +
            "<Pause length=\"2\"/>" +
            "<Say>AirVantage alert!</Say>" +
            "<Pause length=\"2\"/>" +
            "<Say>AirVantage alert!</Say>" +
            "<Pause length=\"30\"/>" +
        "</Response>");
    });

    airbot.router.post('/hubot/alert-handler', function(req, res) {
        // Send message to Operation channel
        /* TODO restore Slack notification
        airbot.send({
            room: "operations"
        }, "@channel Alert!");*/

        // Voice call to duty phone
        twilio.makeCall({
                to: process.env.DUTY_PHONE,
                from: process.env.TWILIO_PHONE_NUMBER,
                url:'https://hubot.airvantage.io/hubot/alert-twiml'
        }, function(err, data) {
            if (err) {
                console.log('Error: ' + err);
            } else {
                console.log('Data: ' + data);
            }
        });
        res.send("OK");
    });
};