# ngip - testing

[![Build Status](https://s3-ap-southeast-1.amazonaws.com/ngip-build-output/build-badge.svg)](http://build.ngip.io/jenkins/job/ngip)

This will be a hosted application which works like other uptime monitoring tools, but the ping direction is in reverse. The main purpose is to detect uptime of intranet application which doesn't expose any endpoint to the internet, but are able to access `ngip.io`. 

Typical monitoring use cases are:
- SME/SOHO Intranet Server
- internal DVR system
- IoT hub
- IoT sensors
- Presence of certain Wifi devices

*Side note:* This is also a learning project for me to solidify my knowledge in DevOps around Jenkins, Chef and various AWS services.

## Table of Contents

- [Status](#status)
- [Changelog](#changelog)
- [Background](#background)
- [Proposed Setup](#proposed-setup)
- [Project Plan](#project-plan)
- [Install](#install)
- [Usage](#usage)
- [Maintainers](#maintainers)
- [Contribute](#contribute)
- [License](#license)

## Status
LastBuildLog: 
- https://s3-ap-southeast-1.amazonaws.com/ngip-build-output/build.log

## Changelog
#### 2018-09-03
- Submit for review
  - Infra and application diagram reflecting actual working setup
#### 2018-07-15
- Updated
  - Added private subnet in infra diagram
    

## Background

I came about having this idea while developing an in-house application. It's a somewhat critical application which needs to run 24x7. There's internal monitoring tools from a different team which I could make use of, but going through the process and segregating the dashboard and notification prove too much hassle. Another common problem is power outages, which affect the internet connectivity resulting in missed alerts. 

I went looking for an existing web application or services that does what I needed and couldn't find one. Other alternatives that I've explored either requires more effort than necessary to configure or it's not flexible when needing to change configuration. Hence there's a gap to be filled here. Which need me to explore developing this and hosting it as a service.

This application will expect pings from the any application that can connect to `ngip.io`, and after the ping lapse for a predefined duration, a notification is sent. The pings can also include primitive data such as temperature, status code ...etc which will be included in the simple validation logic which send notification when the value is outside the configured range.

As for the name, initially it was *Reverse Ping* which was long and rather lame. My friend suggested *ngip* which he said sounded like the reverse of ping. The name clicked and I went with it. He did give his blessing on using the name for this project :)

So far, I've been keeping this project at the back of my head, though I did experiment with Azure Function as a possible cheap and scalable way to host this. My original plan for `ngip` was to use Azure Storage to serve a SPA built using Vue.js. Azure Function as the API endpoint for the pings, REST endpoint for the user dashboard and notification/alert sender. Redis as in memory data store and Blob Storage as persistent data store. Container or Compute as the back-end worker for periodic checking and cleanup. 

My recent interview with a company help push this idea to execution. As a win-win solution which save time and reduce risk for both party, we mutually agreed to do a take-home project to demonstrate my understanding of end to end architecture. `ngip` does fit the bill with some tweaks, mainly switching to AWS and paying more attention to IaC. I'm also using this project to learn more about DevOps and IaC.

Upon completion, this application will be hosted on AWS and free for anyone to use so long as the AWS bill remain affordable. I'll continue to fix bug and make it run more efficiently. I might also consider making this cloud agnostic or at least support another provider.

## Proposed Setup

### Platform

AWS, this is part of the requirement. It does fit my design of doing a SPA hosting it on S3 as static page. Most of the components will be orchestrated using Chef and Jenkins.

![Infra](docs/images/ngip%20-%20solution%20architecture-Infra.png)

| Technology             | Purpose                                                                                                 | Reason                                                                             |
| ---------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| AWS API Gateway        | Public facing endpoints for Lambda                                                                      | AWS' requirement to expose Lambda to public                                        |
| AWS Lambda             | Ping endpoint                                                                                           | scale-able and cost effective solution for ping endpoint                           |
| AWS ECR                | Storage for Django & Ping docker images                                                                 | Reduce traffic cost and avoid direct file transfer                                 |
| AWS ECS                | Running Django REST and Celery workers                                                                  | Ease local and cloud deployment                                                    |
| AWS ELB                | Load balance incoming REST request and SSL termination.                                                 | Connection point to Auto Scaling Group                                             |
| AWS ASG                | Self managed scaling of Django & Celery workers containers                                              | Scale automatically based on load                                                  |
| AWS CloudFront         | CDN, Edge Optimized API Endpoint                                                                        | Reduce traffic cost                                                                |
| AWS S3                 | SPA static website, private store for Lambda package & Terraform states                                 | Ease of use                                                                        |
| AWS Redis              | Application in memory caching, broker for Celery, Queue for pings from Lambda to Worker                 | Able to fullfil the needs for KeyValue store and Queue                             |
| AWS SES                | Sending email alert and notification                                                                    | Avoid reinventing the wheel, one less component to maintain                        |
| AWS RDS for PostgreSQL | Main Persistent storage                                                                                 | Works well with Django                                                             |
| AWS Route53            | DNS management                                                                                          | Tightly integrated with S3 & CDN, ease of configuration                            |
| AWS CloudWatch         | Collect and analyze logs & metrics                                                                      | Built in to AWS services                                                           |
| Chef Solo              | Instance preparation                                                                                    | Avoid having to run another server                                                 |
| Jenkins                | CI/CD                                                                                                   | Very powerful CI/CD server and tons of plugins                                     |
| Terraform              | Infrastructure Provisioning                                                                             | Easy to use, a lot of example online                                               |
| Travis-CI              | CI/CD                                                                                                   | Free hosted CI, to bring up Jenkins server only when needed to save cost           |

### Application

![Application](docs/images/ngip%20-%20solution%20architecture-Application.png)

| Technology             | Purpose                                                                                                 | Reason                                                                             |
| ---------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Vue.js                 | Front-end client-side web framework                                                                     | Easy to use and powerful                                                           |
| Django                 | Back-end framework                                                                                      | Prior experience, fast delivery                                                    |
| Celery                 | Async tasks and background worker                                                                       | Prior experience, flexible                                                         |

#### Front-end
- 3 SPA pages using Vue.js
  - Landing page
  - User Dashboard
  - Admin Dashboard
*Note: Vue.js is on the list of web framework I wanted to learn.

#### Back-end
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

#### Back-end Tasks
- Monitoring lapse ping
- Updating of last ping time
- Validation of ping data
- Deactivating expired checks
- Alert and notification

#### Monitoring
- ELK to monitor & analyze: *This is something I've wanted to learn as part of SIEM for InfoSec, though it's for DevOps here*
  - Application Logs
  - CloudWatch Logs
  - ELB Access Logs
  - CI Logs

#### CI Pipeline
- Middleware Build & Test
- Middleware Docker Test
- Push to ECR
- Setup Stage Stack
- Stage Stack App Test
- Setup Prod Stack
- Post Build Clean Up

#### Load Testing
I plan to have a separate setup for load testing, which provision a handful of EC2 instances to generate ping traffics and API call, then monitor the key metrics on the application and gauge how well the auto scaling is performing. 

## Project Plan
Below is a crude project plan outlining the tasks that will be performed, in order of execution. The plan is based on my limited knowledge of scaling using AWS and Chef. Future tasks might change as components are built and better approaches are discovered.

- [x] Setup basic working CI using Jenkins CI
- [x] Setup CloudFront for S3
- [x] Build Django + Celery working skeleton
- [x] Setup CI to create EC2 instances and deploy app
- [ ] Email based signin token
- [x] Using Django as CRUD Rest Endpoint
- [ ] Sync function for updating of last ping time
- [x] Move updating of last ping time into Celery tasks
- [ ] Isolate Celery workers into its own EC2, probably start involving Chef here
- [ ] Add more Celery tasks
  - [ ] Monitoring lapse ping 
  - [ ] Notification
  - [ ] Validation of ping data
  - [ ] Deactivating expired checks
- [ ] Add load stats
- [ ] Write a script for load testing, and deploy using Chef for CI test job
- [ ] Use AWS to monitor for Django and Celery app load to scale automatically
- [ ] Tweak Chef recipe to allow complete setup from scratch
- [x] Create SPA pages (if time permits)
  - [ ] User Dashboard
  - [ ] Admin Dashboard

## Install


## Usage
*NOTE: This project is still in design stage*

Basic:
```
$ curl api.ngip.io/ping/<your unique check token>
OK
```

With Validation Logic:
```
$ curl api.ngip.io/ping/<your unique check token>/key/value
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

