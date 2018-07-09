# ngip

[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)

This will be a hosted application which works like other uptime monitoring tools, but the ping direction is in reverse. The main purpose is to detect uptime of intranet application which doesn't expose any endpoint to the internet, but are able to access `ngip.io`. 

Typical monitoring use cases are:
- SME/SOHO Intranet Server
- internal DVR system
- IoT hub
- IoT sensors
- Presence of certain Wifi devices

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

I came about having this idea while developing an in-house application. It's a somewhat critical application which needs to run 24x7. There's internal monitoring tools from a different team which I could make use of, but going through the process and segregating the dashboard and notification proof too much hassle. Another common problem is power outages, which affect the internet connectivity resulting in missed alerts. 

This application will expect pings from the any application that can connect to `ngip.io`, and after the ping lapse for a pre-defined duration, a notification is sent. The pings can also include primitive data such as temperature, status code ...etc which will be included in the simple validation logic which send notification when the value is outside the configured range.

As for the name, initially it was *Reverse Ping* which was long and rather lame. My friend suggested *ngip* which he said sounded like the reverse of ping. The name clicked and I went with it. He did give his blessing on using the name for this project :)

So far I've been keeping this project at the back of my head, though I did experiment with Azure Function as a possible cheap and scalable way to host this. My original plan for `ngip` was to use Azure Storage to serve a SPA built using Vue.js. Azure Function as the API endpoint for the pings, REST endpoint for the user dashboard and notification/alert sender. Redis as in memory data store and Blob Storage as persistent data store. Container or Compute as the backend worker for periodic checking and cleanup. 

My recent interview with a company help push this idea to execution. As a win-win solution which save time and reduce risk for both party, we mutually agreed to do a take-home project to demonstrate my understanding of end to end architecture. `ngip` does fit the bill with some tweaks, mainly switching to AWS and paying more attention to IaC. I'm also using this project to learn more about DevOps and IaC.

Upon completion, this application will be hosted on AWS and free for anyone to use so long as the AWS bill remain affordable. I'll continue to fix bug and make it run more efficiently. I might also consider making this cloud agnostic or at least support another provider.

## Proposed Setup

### Platform

AWS, this is part of the requirement. It does fit my design of doing a SPA hosting it on S3 as static page. Most of the components will be orchestrated using Chef and Jenkins.

| Technology             | Purpose                                                                                                 | Reason                                                                |
| ---------------------- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| AWS EC2                | Running Django REST and Celery workers                                                                  | As per requirement                                                    |
| AWS Lambda             | Ping endpoint                                                                                           | scale-able and cost effective                                         |
| AWS ELB                | Load balance incoming request and SSL termination. Need to figure out how to scale EC2 as load goes up. | As per requirement, to utilize auto scaling                           |
| AWS S3                 | SPA static website                                                                                      | scale-able and cost effective                                         |
| AWS Redis              | Application in memory caching, broker for Celery                                                        | Prior experience                                                      |
| AWS SQS                | Message queue for async tasks, using queue length to judge scaling behavior or overall health           | Prior experience in using MQTT to scale async tasks                   |
| AWS SES                | Sending email alert and notification                                                                    | Avoid reinventing the wheel, one less component to maintain           |
| AWS RDS for PostgreSQL | Persistent storage                                                                                      | Prior experience                                                      |
| AWS Route53            | DNS management                                                                                          | Possible future multi-region failover                                 |
| AWS ECS or Docker      | Possibly to host Celery workers                                                                         | As per requirement                                                    |
| AWS Opsworks Chef      | Overall solution orchestration                                                                          | Currently learning and would like to gain experience in               |
| AWS CloudFormation     | Template for production, staging and test environment                                                   | Easier than using script to setup environment                         |
| Jenkins                | CI/CD                                                                                                   | As per requirement, similar to Gitlab CI which I have experience with |

### Application

| Technology             | Purpose                                                                                                 | Reason                                                                             |
| ---------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Vue.js                 | Front-end client side web framework                                                                     | A web framework in my to-learn list. Small, easier to learn, and good performance. |
| Django                 | Back-end framework                                                                                      | Prior experience, fast delivery                                                    |
| Celery                 | Async tasks and background worker                                                                       | Prior experience                                                                   |
| ELK                    | Collect and analyze logs                                                                                | A technology stack in my to-learn list, especially useful for SIEM in InfoSec      |

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
- Alert and notification

#### Monitoring
- ELK to monitor & analyze: *This is something I've wanted to learn as part of SIEM for InfoSec, though it's for DevOps here*
  - Application Logs
  - CloudWatch Logs
  - ELB Access Logs
  - CI Logs

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

