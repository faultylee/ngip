# ngip

[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)

This will be an hosted application which works like other uptime monitoring tools, but the ping direction is in reverse. The main purpose is to detect uptime of intranet application which doesn't expose any end point to the internet, but are able to access `ngip.io`. 

Typical monitoring use cases are:
- SME/SOHO Intranet Server
- internal DVR system
- IoT hub
- IoT sensors
- Presense of certain Wifi devices

## Table of Contents

- [Background](#background)
- [Proposed Setup](#proposed-setup)
- [Project Plan](#project-plan)
- [Install](#install)
- [Usage](#usage)
- [Maintainers](#maintainers)
- [Contribute](#contribute)
- [License](#license)

## Background

I came about having this idea while developing an in-house application. It's a somewhat critical application which needs to run 24x7. There's internal monitoring tools from a different team which I could make use of, but going through the process and also segregating the dashboard and notification proof too much hassle. Another common problem is power outages, which affect the internet connectivity resulting in missed alerts. 

This application will expect pings from the any application that can connect to `ngip.io`, and after the ping lapse for a pre-defined duration, a notification is sent. The pings can also include primitive data such as temperature, status code ...etc which will be included in the simple validation logic which send notification when the value is outside the configured range.

As for the name, initially it was *Reverse Ping* which was long and rather lame. My friend suggested *ngip* which he said sounded like the reverse of ping. The name clicked and I went with it. He did give his blessing on using the name for this project :)

So far I've been keeping this project at the back of my head, though I did experiement with Azure Function as a possible cheap and scalable way to host this. My recent interview with a company help push this idea to execution. As a win-win solution which save time and reduce risk for both party, we mutually agreed to do a take-home project to prove my technical capability. `ngip` does fit the bill with some tweaks from my original plan.

Upon completion, this application will be hosted on AWS and free for anyone to use so long as the AWS bill is affordable. I'll continue to fix bug and make it run more effeciently. Since it is opensourced, anyone can host this on their own.

## Proposed Setup

### Platform

AWS, this is part of the requirement. It does fit my design of doing a SPA hosting it on S3 as static page. Static website hosting on Azure Storage only recently in public preview, as of June 2018.

- AWS EC2 to host background worker and service end point. Will be orchestrated using Chef Automate and Jenkins.
- AWS ELB to load balance incoming request and SSL termination. Need to figure out how to scale EC2 as load goes up.
- AWS S3 to host SPA static website.
- AWS SQS for Celery backend and to allow scaling of backend async tasks.
- AWS SES for emailing of signin token and notification.
- AWS RDS as persistant storage.
- Debian due to my familiarity.
- Docker to isolate Django and Celery Workers.
- Jenkins for CI.
- Chef for Orchestration.
- Let's Encrypt for SSL.
- Gunicorn as wsgi for Django.

### Application

#### Front-end
- 3 SPA pages using Vue.js
  - Landing page
  - User Dashboard
  - Admin Dashboard
*Note: Vue.js is on the list of web framework I wanted to learn.

#### Backend
- Django + Celery
- REST endpoint for SPA
  - Landing Page stats
  - User Dashboard
    - Checks summary
    - Add/Modify/Remove checks
  - Admin Dashboard
    - User stats
    - Tasks queue
    - Load stats

#### Backend Tasks
- Monitoring lapse ping
- Updating of last ping time
- Validation of ping data
- Deactiving expired checks
- Notification

#### CI Pipeline
- Build
- Test
- Deploy to testing environment
- Load test
- Prompt to deploy to production

## Project Plan
Below is a crude project plan outlining the tasks that will be performed, in order of execution. The plan is based on my limited knowledge of scaling using AWS and Chef. Future tasks might change as compoments are built and better approaches are discovered.

- [ ] Build Django + Celery working skeleton
- [ ] Setup CI to create EC2 instances and deploy app
- [ ] Email based signin token
- [ ] Using Django as front-end to add/modify/remove checks
- [ ] Sync function for updating of last ping time
- [ ] Move updating of last ping time into Celery tasks
- [ ] Isolate Celery workers into it's own EC2, probably start involving Chef here
- [ ] Add more Celery tasks
  - [ ] Monitoring lapse ping 
  - [ ] Notification
  - [ ] Validation of ping data
  - [ ] Deactivating expired checks
- [ ] Add load stats
- [ ] Write a script for load testing, and deploy using Chef for CI test job
- [ ] Use AWS to monitor for Django and Celery app load to scale automatically
- [ ] Tweak Chef recipe to allow complete setup from scratch
- [ ] Create SPA pages (if time permits)
  - [ ] User Dashboard
  - [ ] Admin Dashbord

## Install


## Usage
*NO
TE: This project is still in design stage*

Basic:
```
$ curl ngip.io/<your unique check token>
OK
```

With Validation Logic:
```
$ curl ngip.io/<your unique check token>/key/value
OK

$ curl -d "param1=value1&param2=value2" -H "Content-Type: application/x-www-form-urlencoded" -X POST  ngip.io/<your unique check token>
OK

$ curl -d '{"key1":"value1", "key2":"value2"}' -H "Content-Type: application/json" -X POST ngip.io/<your unique check token>
OK

```

## Credit

- Chandana N. Athauda - [@inzeek](https://twitter.com/inzeek) for his guidance on my personal career and review on this project.
- Yazid Azahari - [@yazidazahari](http://www.yazidazahari.com/), [@yazid](https://github.com/yazid) for his mentorship throughout my career and using `ngip` for this project.

## Maintainers

[@faultylee](https://github.com/faultylee).

## Contribute

Feel free to dive in! [Open an issue](https://github.com/faultylee/ngip/issues/new) or submit PRs.

ngip follows the [Contributor Covenant](http://contributor-covenant.org/version/1/3/0/) Code of Conduct.

## License

[GNU General Public License v3.0](LICENSE) © Mohd Lee

