# Interview Take Home Project

## Objective
### Primary
To demonstrate my understanding of end-to-end cloud based application and ability to utilize DevOps toolset to setup and deploy to the cloud.
### Secondary
As a playground for me to learn new technology and explore different approaches to existing IT problems.

## Executive Summary
At the current stage of this project, I've made use of various DevOps toolset and able to deploy a cloud application build on top of Django, Celery and Vue.js to AWS infrasturture. Although this is my first time deploying an application which utilizes Jenkins, Terraform, Chef, EC2, ECS, Lambda, ELB, Redis, RDS all at the same time, the prior experience from on premise application architecture does help reduce my learning time. Most enterprise best practises still applies on a typical cloud application. The main take away is the need to understand the paradigm shift from going cloud and how to take advantage of DevOps to increase quality and efficiency.
 
## Detail

During the initial stage, I've spend about 1/3 of the time figuring out Jenkins and Terraform and also how to piece everything together while utilizing the key components identified. At the later stage when I gained a better understanding on the tools and what else is missing from my initial design, I start to make progress and was able to bring up the staging environment automatically using Jenkins. The later part is fine tuning and complete enough of the main application so that it's presentable.

Below are detail on how I utilized each components:

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
- Terraform - to provision AWS infrastructure, and it's also the main glue to connect each and every components together. Comparing to CloudFormation, terraform have better state management and simpler syntax.
- Jenkins - a CI/CD platform, also as a bastion host
- Travis-CI - after using Jenkins, I've learnt that Travis-CI is definately not suitable for this project. But I still use it to bring up the Jenkins instance when I push code for the first time. I've also setup scheduled pipeline in Jenkins to shutdown itself when idle to better manage the cost. 

Throughout this project, I've learn a lot about AWS Intrastructure, Jenkins and infrastucture provisioning using Terraform. Both Jenkins and Terraform are new to me but I could say now I can use them comfortably. 

Below are the area I still can't grasp them fully. I'll require trial and error to get things right. I'll need to spend more time to gain a deeper understanding before I can use them effectively.

- Chef
- API Gateway
- NAT Gateway
- ECS
- ASG
- IAM configuration,    

Below are the list of components which I've not priorotize to provision via code or script. Most of this are one time setup, though having the code is still useful for future use:

- NAT Gateway
- API Gateway Custom domain
- CloudFront
- Route53
- Jenkins
- CloudWatch & Extensive Logging
 
The Jenkins pipeline is only working up to Staging. Terrafrom code for production is working and tested without application deployment step. I'm still working out how to deploy to production properly. I also plan to learn and do blue/green deployment to production automatically.  


## Conlusion
Based on my calculation, up until today, I've spent about 150 hours on building **ngip** from scratch.
If I'm tasked to build a similar project from scratch, I expect to take between 75 to 100 hours to reach the current state.   


## Appendix
Updated diagram to reflect on what has actually been provisioned
![Infra](docs/images/ngip%20-%20solution%20architecture-Infra-Shared-v0.1.png)

![Infra](docs/images/ngip%20-%20solution%20architecture-Application-v0.1.png)