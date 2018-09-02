def GIT_SHA_PRETTY
def DB_ADDRESS
def REDIS_ADDRESS
def WEB_PUBLIC_IP
def PING_BASE_URL
pipeline {
    agent {
        node {
            label 'master'
        }
    }
    environment {
        TERRAFORM_CMD='docker run --rm --network host -w /app -v $(pwd):/app -v $(pwd)/../../cookbooks:/cookbooks -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} -e TF_LOG=WARN hashicorp/terraform:light'
        AWS_CMD='docker run --rm -i -u 0 --network host -v $(pwd):/data -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} faultylee/aws-cli-docker:latest'
        NPM_CMD='docker run --rm -i -u 0 --network host -w /app -v $(pwd):/app node:8'
    }
    stages {
        stage('Middleware Build & Test') {
            steps {
                script {
                    def now = new Date()
                    println "CI Started at " + now.format("yyyy-MM-dd HH:mm:ss")
                    GIT_SHA_PRETTY =  sh (returnStdout: true, script: 'git log -1 --pretty=%h').trim()
                    echo "GIT SHA = ${GIT_SHA_PRETTY}"
                }
                withCredentials([
                        usernamePassword(credentialsId: 'DJANGO_ADMIN', passwordVariable: 'ADMIN_EMAIL', usernameVariable: 'ADMIN_NAME'),
                        string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'DJANGO_SECRET_KEY', variable: 'SECRET_KEY'),
                        string(credentialsId: 'AWS_NGIP_ACCESS_KEY_ID', variable: 'AWS_NGIP_ACCESS_KEY_ID'),
                        string(credentialsId: 'AWS_NGIP_SECRET_ACCESS_KEY', variable: 'AWS_NGIP_SECRET_ACCESS_KEY'),
                        usernamePassword(credentialsId: 'POSTGRES_USER', passwordVariable: 'POSTGRES_PASSWORD', usernameVariable: 'POSTGRES_USER')
                ]) {
                    sh '''
                        cd web/middleware
                        echo "DJANGO_DEBUG=false" > .env
                        echo "ENVIRONMENT=stage" >> .env
                        echo "SECRET_KEY=$DJANGO_SECRET_KEY" >> .env
                        echo "POSTGRES_HOST=db" >> .env
                        echo "POSTGRES_PORT=5432" >> .env
                        echo "POSTGRES_DB=ngip" >> .env
                        echo "POSTGRES_USER=$POSTGRES_USER" >> .env
                        echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> .env
                        echo "REDIS_HOST=redis" >> .env
                        echo "REDIS_PORT=6379" >> .env
                        echo "REDIS_DB=0" >> .env
                        echo "ADMIN_NAME=$ADMIN_NAME" >> .env
                        echo "ADMIN_EMAIL=$ADMIN_EMAIL" >> .env
                        echo "AWS_DEFAULT_REGION=ap-southeast-1" >> .env
                        echo "AWS_NGIP_ACCESS_KEY_ID=$AWS_NGIP_SECRET_ACCESS_KEY" >> .env
                        echo "AWS_NGIP_SECRET_ACCESS_KEY=$AWS_NGIP_SECRET_ACCESS_KEY" >> .env
                    '''
                }
                sh '''
                    env
                    # make sure we have the latest image
                    docker pull faultylee/aws-cli-docker:latest
                    docker pull hashicorp/terraform:light
                    docker pull node:8
                    cd web
                    docker-compose rm -fs

                    # build middleware docker
                    cd middleware
                        #
                    docker build -t ngip/ngip-middleware-web:''' + GIT_SHA_PRETTY + ''' .
                    docker tag ngip/ngip-middleware-web:''' + GIT_SHA_PRETTY + ''' ngip/ngip-middleware-web:latest

                    # build middleware static file
                    docker run --rm -w /app -v $(pwd):/app --env-file .env ngip/ngip-middleware-web:''' + GIT_SHA_PRETTY + ''' python manage.py collectstatic --no-input

                    # build fake_lambda/ping docker
                    cd ../ping
                    docker build -t ngip/ngip-middleware-ping:''' + GIT_SHA_PRETTY  + ''' .
                    docker tag ngip/ngip-middleware-ping:''' + GIT_SHA_PRETTY + ''' ngip/ngip-middleware-ping:latest

                    # build static page                    
                    cd ../frontend
                    eval "${NPM_CMD} npm install && npm run build_prod"

                    # Cannot use -it with manage.py test
                    # docker run --rm ngip/ngip-middleware-web:latest python manage.py test --settings=middlware.test_settings 
                '''
            }
        }
        stage('Middleware Docker Test') {
            steps {
                withCredentials([
                        usernamePassword(credentialsId: 'DJANGO_ADMIN', passwordVariable: 'ADMIN_EMAIL', usernameVariable: 'ADMIN_NAME'),
                        string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY'),
                        usernamePassword(credentialsId: 'POSTGRES_USER', passwordVariable: 'POSTGRES_PASSWORD', usernameVariable: 'POSTGRES_USER')
                ]) {
                    sh '''
                        cd web
                        docker-compose rm -fs
                        docker-compose up -d
                        sleep 10
                        echo $(eval "${AWS_CMD} curl -s -L  http://localhost:8000/ping/ | ${AWS_CMD} jq '.[] | .account' -r")
                        if [ -z $(eval "${AWS_CMD} curl -s -L  http://localhost:8000/ping/ | ${AWS_CMD} jq '.[] | .account' -r") ]; then
                            exit 127
                        fi
                        if [[ $(eval "${AWS_CMD} curl -s -L  http://localhost:8000/ping/ | ${AWS_CMD} jq '.[] | .account' -r") != "Account: test" ]]; then
                            exit 127
                        fi
                    '''
                }
            }
        }
        stage('Push to ECR') {
            steps {
                withCredentials([
                        string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        docker tag ngip/ngip-middleware-web:''' + GIT_SHA_PRETTY + ''' ${AWS_REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:latest
                        docker tag ngip/ngip-middleware-web:''' + GIT_SHA_PRETTY + ''' ${AWS_REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:''' + GIT_SHA_PRETTY + '''
                        # need to remove the trailing \r otherwise docker login will complain
                        eval "${AWS_CMD} aws ecr get-login --no-include-email" | tr '\\r' ' ' | bash 
                        docker push ${AWS_REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:latest
                        docker push ${AWS_REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:''' + GIT_SHA_PRETTY + '''
                     '''
                }
            }
        }
        stage('Setup Stage Stack') {
            steps {
                withCredentials([
                        string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY'),
                        usernamePassword(credentialsId: 'POSTGRES_USER', passwordVariable: 'POSTGRES_PASSWORD', usernameVariable: 'POSTGRES_USER')
                ]) {
                    echo "Bring up shared stack"
                    sh '''
                        cd stack/aws/shared
                        rm local.tf
                        cp environment/stage.tf ./local.tf
                        eval "${TERRAFORM_CMD} init"
                        eval "${TERRAFORM_CMD} apply -auto-approve -var-file='stage.tfvars' -var 'pg_username=${POSTGRES_USER}' -var 'pg_password=${POSTGRES_PASSWORD}'"
                        SHARED=$(eval "${TERRAFORM_CMD} output -json)"
                        echo "$SHARED" | jq -r '.["ngip-db-address"].value' > db_address
                        echo "$SHARED" | jq -r '.["ngip-db-address"].value' > redis_address
                     '''
                    script {
                        DB_ADDRESS = readFile('stack/aws/shared/db_address').trim()
                        echo "DB_ADDRESS = ${DB_ADDRESS}"
                        REDIS_ADDRESS = readFile('stack/aws/shared/redis_address').trim()
                        echo "REDIS_ADDRESS = ${REDIS_ADDRESS}"
                    }
                    echo "Restore latest data from prod DB"
                    sh '''
                        # if PROD DB Address not configure, then we're not ready to clone live data from PROD
                        if [ -n "$NGIP_DB_PROD_ADDRESS" ]; then
                            cd stack/aws/shared
                            DB_ADDRESS=$(eval "${TERRAFORM_CMD} output ngip-db-address" | tr -d '\\r')
                            eval "${AWS_CMD} pg_dump postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${NGIP_DB_PROD_ADDRESS}:5432/ngip" > backup.sql
                            echo "DROP DATABASE ngip;" | eval "${AWS_CMD} psql postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_ADDRESS}:5432/postgres"
                            echo "CREATE DATABASE ngip WITH OWNER ${POSTGRES_USER}" | eval "${AWS_CMD} psql postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_ADDRESS}:5432/postgres"
                            cat backup.sql | eval "${AWS_CMD} psql postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_ADDRESS}:5432/ngip"
                        fi
                    '''
                    echo "Bring up middleware stack"
                    sh '''
                        cd stack/aws/middleware
                        rm local.tf
                        cp environment/stage.tf ./local.tf
                        eval "${TERRAFORM_CMD} init"
                        eval "${TERRAFORM_CMD} apply --auto-approve -var-file='stage.tfvars' -var 'pg_username=${POSTGRES_USER}' -var 'pg_password=${POSTGRES_PASSWORD}' -var 'git_sha_pretty=''' + GIT_SHA_PRETTY + ''''"
                        MIDDLEWARE=$(eval "${TERRAFORM_CMD} output -json)"
                        echo "$MIDDLEWARE" | jq -r '.ngip_web_public_ip.value[]' > ngip_web_public_ip 
                     '''
                    script {
                        WEB_PUBLIC_IP = readFile('stack/aws/middleware/ngip_web_public_ip').trim()
                        echo "WEB_PUBLIC_IP = ${WEB_PUBLIC_IP}"
                    }
                    echo "Bring up ping stack"
                    sh '''
                        cd stack/aws/ping
                        rm local.tf
                        cp environment/stage.tf ./local.tf
                        eval "${TERRAFORM_CMD} init"
                        eval "${TERRAFORM_CMD} apply --auto-approve -var-file='stage.tfvars' -var 'git_sha_pretty=''' + GIT_SHA_PRETTY + ''''"
                        PING=$(eval "${TERRAFORM_CMD} output -json)"
                        echo "$PING" | jq -r '.base_url.value[]' > ping_base_url 
                     '''
                    script {
                        PING_BASE_URL = readFile('stack/aws/ping/ping_base_url').trim()
                        echo "PING_BASE_URL = ${PING_BASE_URL}"
                    }
                }
            }
        }
        stage('Stage Stack App Test') {
            steps {
                withCredentials([string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        if [[ $(eval "${AWS_CMD} curl -s -L  ''' + PING_BASE_URL + '''/ping/) != "missing token" ]]; then
                            exit 127
                        fi
                        if [[ $(eval "${AWS_CMD} curl -s -L  ''' + PING_BASE_URL + '''/ping/0123456789) != "invalid token" ]]; then
                            exit 127
                        fi
                        if [[ $(eval "${AWS_CMD} curl -s -L  ''' + PING_BASE_URL + '''/ping/01234567890) != "invalid token" ]]; then
                            exit 127
                        fi
                     '''
                }
            }
        }
        stage('Setup Prod Stack') {
            // tag not working https://issues.jenkins-ci.org/browse/JENKINS-52554?page=com.atlassian.jira.plugin.system.issuetabpanels%3Aall-tabpanel
            //when { tag "release-*" }
            when { expression { BRANCH_NAME == 'master' } }
            steps {
                withCredentials([
                        string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY'),
                        usernamePassword(credentialsId: 'POSTGRES_USER', passwordVariable: 'POSTGRES_PASSWORD', usernameVariable: 'POSTGRES_USER')
                ]) {
                    // PROD assumes shared stack is already provisioned
                    sh '''                    
                        cd stack/aws/middleware
                        rm local.tf
                        cp environment/prod.tf ./local.tf
                        eval "${TERRAFORM_CMD} init"
                        eval "${TERRAFORM_CMD} plan -var-file='prod.tfvars' -var 'pg_username=${POSTGRES_USER}' -var 'pg_password=${POSTGRES_PASSWORD}'"
                     '''
                }
            }
        }
    }
    post {
        always {
            script {
                sh '''
                        # reset file/dirs permission to allow next round of git cleanup
                        sudo chown -R tomcat:tomcat .
                    '''
                echo "${currentBuild.currentResult}"
                def destroy = true
                try {
                    timeout(time: 15, unit: 'MINUTES') {
                        userInput = input(id: "Destroy Stack", message: "Destroy Stack?", ok: 'Yes')
                    }
                } catch(err) { // timeout reached or input false
                    // make sure to approve these 2 signature
                    //  - method org.jenkinsci.plugins.workflow.steps.FlowInterruptedException getCauses
                    //  - method org.jenkinsci.plugins.workflow.support.steps.input.Rejection getUser
                    def user = err.getCauses()[0].getUser()
                    if('SYSTEM' == user.toString()) { // SYSTEM means timeout.
                        echo "Timeout"
                    } else {
                        destroy = false
                        userInput = false
                        echo "Aborted by: [${user}]"
                    }
                }
                if (destroy == true){
                    sh '''
                        cd web
                        docker-compose rm -fs
                        docker logout {$REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com
                    '''
                    withCredentials([string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                            cd stack/aws/middleware
                            rm local.tf
                            cp environment/stage.tf ./local.tf
                            # init is required in case earlier pipeline failed, and git cleaned the local state file, causing destroy to fail
                            eval "${TERRAFORM_CMD} init"
                            eval "${TERRAFORM_CMD} destroy --auto-approve -var-file='stage.tfvars'" | true
                          '''
                        sh '''
                            cd stack/aws/middleware
                            rm local.tf
                            cp environment/stage.tf ./local.tf
                            # init is required in case earlier pipeline failed, and git cleaned the local state file, causing destroy to fail
                            eval "${TERRAFORM_CMD} init"
                            eval "${TERRAFORM_CMD} destroy --auto-approve -var-file='stage.tfvars'" | true
                          '''
                        sh '''
                            cd stack/aws/shared
                            rm local.tf
                            cp environment/stage.tf ./local.tf
                            # init is required in case earlier pipeline failed, and git cleaned the local state file, causing destroy to fail
                            eval "${TERRAFORM_CMD} init"
                            eval "${TERRAFORM_CMD} destroy --auto-approve -var-file='stage.tfvars'" | true
                          '''
                    }
                }
                withCredentials([usernamePassword(credentialsId: 'JENKINS_API_TOKEN', passwordVariable: 'JENKINS_API_TOKEN', usernameVariable: 'JENKINS_API_USERNAME'), string(credentialsId: 'AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        eval "${AWS_CMD} wget -O build.log --auth-no-challenge http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/job/ngip/job/$BRANCH_NAME/$BUILD_ID/consoleText"
                        eval "${AWS_CMD} aws s3 cp build.log s3://ngip-build-output/build.log --acl public-read --content-type 'text/plain'"
                      '''
                }
                //publish_cloudwatch_logs(logStreamName: "ngip-" + BRANCH_NAME)
            }
        }
    }
}
