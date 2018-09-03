# Interview Take Home Project

## Objective
### Primary
To demonstrate my understanding of end-to-end cloud based application and ability to utilize DevOps tool set to set up and deploy to the cloud.
### Secondary
As a playground for me to learn new technology and explore different approaches to existing IT problems.

## Executive Summary
At the current stage of this project, I've made use of various DevOps tool set and able to deploy a cloud application build on top of Django, Celery and Vue.js to AWS infrastructure. Although this is my first time deploying an application which utilizes Jenkins, Terra form, Chef, EC2, ECS, Lambda, ELB, Redis, RDS all at the same time, the prior experience from one premise application architecture does help reduce my learning time. Most enterprise best practices still applies on a typical cloud application. 
 
## Detail

During the initial stage, I've spent about 1/3 of the time figuring out Jenkins and Terraform and also how to piece everything together while utilizing the key components identified. At the later stage when I gained a better understanding on the tools and what else is missing from my initial design, I start to make progress and was able to bring up the staging environment automatically using Jenkins. The later part is fine-tuning and complete enough of the main application so that it's presentable.

Below are detail on how I utilized each component:

- Lambda - this is a readonly endpoint which collect GET request and check for a valid token from the URI, and push an item to Redis' List
- API Gateway - manage custom domain and path to connect to Lambda
- Django - REST endpoint to perform CRUD on Ping and Token stored in RDS
- Celery - Async worker to allow endpoints to offload tasks and improve response time. One of the task is to pop item from Redis' List and add the record into RDS
- ASG - to self manage ECR or EC2 to allow automatic scaling based on predefined parameters
- ELB - actual public end point for REST, and to be connected to ASG as listener group
- ECR - to host Django and Celery Worker, both from the same image but with different command to excute.
- Docker - along with compose, to host all the containers when running test, which provide faster feedback on test result. 
- EC2 - to host Jenkins and also a single instance of docker to host Django, Celery Camara and Celery Beat, which doesn't require auto scaling
- RDS - main data store, used by Django and Celery
- Redis - as key value store and queue for Django and Lambda, as the broker for Celery
- Chef Solo - initially I chose to use Chef server, but after considering license, configuration drift and having all instances provision from scratch on every build, Chef Solo is clearly a better choice for this project. Chef Solo is used to bootstrap and prepare the EC2 instances.   
- Terraform - to provision AWS infrastructure, and it's also the main glue to connect each and every component together. Comparing to CloudFormation, terraform have better state management and simpler syntax.
- Jenkins - a CI/CD platform, also as a bastion host
- Travis-CI - after using Jenkins, I've learnt that Travis-CI is definitely not suitable for this project. But I still use it to bring up the Jenkins instance when I push code for the first time. I've also setup scheduled pipeline in Jenkins to shutdown itself when idle to better manage the cost. 

Throughout this project, I've learn a lot about AWS Infrastructure, Jenkins and infrastructure provisioning using Terraform. Both Jenkins and Terraform are new to me but I could say now I can use them comfortably. 

Below are the area I've yet to grasp them fully. I'll require trial and error to get things right. I'll need to spend more time to gain a deeper understanding before I can use them effectively.

- Chef
- API Gateway
- NAT Gateway
- ECS
- ASG
- IAM configuration   

Below are the list of components which I've not prioritized to provision via code or script. Most of this are one time setup, though having the code is still useful for future use:

- IAM configuration   
- NAT Gateway
- API Gateway Custom domain
- CloudFront
- Route53
- Jenkins
- CloudWatch & Extensive Logging
 
The Jenkins pipeline is only working up to Staging. Terrafrom code for production is working and tested without application deployment step. I'm still working out how to deploy to production properly. I also plan to learn and do blue/green deployment to production automatically.  

The application itself still need more work, such as authentication, unit testing and logging. I'll continue working on this at my free time.

Based on my calculation, up until today, I've spent about 150 hours on building **ngip** from scratch.
If I'm tasked to build a similar project again, I expect to take between 75 and 100 hours to reach the current state. Possibly shorter after a few iterations.  

## Conclusion
The key take away from this project is that hands on play big role in terms of learning new technology. Secondly is the need to understand the paradigm shift from going to cloud. With the increasing pace of technology progression, we need to work smarter and not harder to keep up, such as using DevOps to increase quality and efficiency of delivery. 



## Appendix
Updated diagram to reflect on what has actually been provisioned
![Infra](docs/images/ngip%20-%20solution%20architecture-Infra-Shared-v0.1.png)

![Infra](docs/images/ngip%20-%20solution%20architecture-Application-v0.1.png)

## Project file structure

#### Overview 

```
├── docs                # reference documents
├── scripts             # helper scripts, not related to application directly
├── stack               # infrastructure code based on Chef and Terraform
│   ├── aws          
│   │   ├── jenkins     # infra code for Jenkins instance, for state tracking only
│   │   ├── middleware  # infra code for middleware - django, ecs
│   │   ├── ping        # infra code for lambda
│   │   └── shared      # shared infra code - vpc, subnet, elb, peering
│   └── cookbooks       # code for Chef
└── web                 # main application code, docker-compose's root
    ├── frontend        # Vue.js code for static SPA
    ├── middleware      # code for REST endpoint, Django & Clery
    └── ping            # code for lambda - ping api

```

#### Infrasture 

```
NOTE: Terraform will always load all *.tf files, and state storage cannot have variable
hence it must be place in a separate folder. During CI/CD each environment.tf file will
be copy out and replace local.tf

├── environment         # Environment specific S3 state storage config
│   ├── prod.tf         
│   └── stage.tf
├── local.tf            # S3 state storage config
├── main.tf             # main infra code file
├── prod.tfvars         # prod specific variables     * require -var-files
├── stage.tfvars        # staging specific variables  * require -var-files
└── terraform.tfvars    # local testing variables     * load by default

```

#### Jenkins CI/CD

Jenkinsfile at the root of this project is the main source for the pipeline. Only 2 addtional script which run on outside of the Jenkinsfile.

```
scripts/start-jenkins-ci.sh                       # Script used at Travis-CI to bring up Jenkins Server
scripts/check-for-idle-and-shutdown-jenkins.sh    # Scheduled script which shutdown Jenkins server when idle 

```
Following are the pipelines described by the Jenkinsfile
- Middleware Build & Test - docker build
- Middleware Docker Test - docker-compose up and check endpoint is working 
- Push to ECR & Upload files to S3 - push docker image to ECR, lambda packge and static files to S3
- Setup Stage Stack - Provision staging infrastructure
- Stage Stack App Test - endpoint testing
- Setup Prod Stack (skip unless commit from `master`) - only a placeholder
- Post Build Clean Up - delete containers, prompt to destroy infrastructure

#### Docker-Compose

docker-compose.yml file in the `web` folder will load a locally testable stack consisting of:
- PostgreSQL
- Redis 
- Django with Gunicorn, REST Endpoint & Admin UI
- Celery Worker - background async worker
- Celery Camera - to capture tasks results
- Celery Beat - to handle scheduling
- Ping - Simulated lambda using Flask - API endpoint
- Nginx - reverse proxy and static file server