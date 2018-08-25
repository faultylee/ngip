pipeline {
    agent {
        node {
            label 'master'
        }
    }
    environment {
        TF_LOG='INFO'
        TERRAFORM_CMD='docker run --rm --network host -w /app -v $(pwd):/app -v $(pwd)/../cookbooks:/cookbooks -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} -e TF_LOG=${TF_LOG} hashicorp/terraform:light'
        AWS_CMD='docker run --rm -i -u 0 --network host -v $(pwd):/data -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} faultylee/aws-cli-docker:latest'
    }
    stages {
        stage('Pre Build') {
            steps {
                withCredentials([
                        usernamePassword(credentialsId: 'DJANGO_ADMIN', passwordVariable: 'ADMIN_EMAIL', usernameVariable: 'ADMIN_NAME'),
                        string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'REDIS_PASSWORD', variable: 'REDIS_PASSWORD'),
                        usernamePassword(credentialsId: 'POSTGRES_USER', passwordVariable: 'POSTGRES_PASSWORD', usernameVariable: 'POSTGRES_USER')
                ]) {
                    sh '''
                        cd web/middleware
                        echo "DJANGO_DEBUG=false" >> .env
                        echo "ENVIRONMENT=test" >> .env
                        echo "POSTGRES_HOST=db" >> .env
                        echo "POSTGRES_PORT=5432" >> .env
                        echo "POSTGRES_DB=ngip" >> .env
                        echo "POSTGRES_USER=$POSTGRES_USER" >> .env
                        echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> .env
                        echo "REDIS_HOST=redis" >> .env
                        echo "REDIS_PORT=6379" >> .env
                        echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> .env
                        echo "MQTT_HOST=mqtt" >> .env
                        echo "MQTT_PORT=1883" >> .env
                        echo "ADMIN_NAME=$ADMIN_NAME" >> .env
                        echo "ADMIN_EMAIL=$ADMIN_EMAIL" >> .env
                    '''
                }
                sh '''
                    echo $(git log -1 --pretty=%h) > pretty-sha.txt
                    docker-compose rm -fs
                '''
                script {
                    // trim removes leading and trailing whitespace from the string
                    git_sha = readFile('pretty-sha.txt').trim()
                }
            }
        }
        stage('Middleware Test') {
            steps {
                sh '''
                    cd web/middleware
                    docker build -t ngip-middleware-web:$git_sha .
                    docker tag ngip-middleware-web:$git_sha ngip-middleware-web:latest
                    docker run --rm -it ngip-middleware python manage.py test --settings=middlware.test_settings 
                '''
            }
        }
        stage('Middleware Prepare Data') {
            steps {
                sh '''
                '''
            }
        }
        stage('Middleware Build & Up') {
            steps {
                sh '''
                    cd web/middleware
                    docker-compose rm -fs
                    docker-compose up -d
                '''
            }
        }
        stage('Middleware App Test') {
            steps {
                withCredentials([
                        usernamePassword(credentialsId: 'DJANGO_ADMIN', passwordVariable: 'ADMIN_EMAIL', usernameVariable: 'ADMIN_NAME'),
                        string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'REDIS_PASSWORD', variable: 'REDIS_PASSWORD'),
                        usernamePassword(credentialsId: 'POSTGRES_USER', passwordVariable: 'POSTGRES_PASSWORD', usernameVariable: 'POSTGRES_USER')
                ]) {
                    sh '''
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
                    docker tag ngip/ngip-middleware:$git_sha ${AWS_REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware:latest
                    docker tag ngip/ngip-middleware:$git_sha ${$AWS_REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware:$git_sha
                    
                    # need to remove the trailing \r otherwise docker login will complain
                    eval "${AWS_CMD} aws ecr get-login --no-include-email" | tr '\\r' ' ' | bash 
                    docker push ${AWS_REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware:$git_sha
                    docker push ${AWS_REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware:latest
                  '''
                }
            }
        }
        stage('Setup Test Stack') {
            steps {
                withCredentials([
                        string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY'),
                        usernamePassword(credentialsId: 'POSTGRES_USER', passwordVariable: 'POSTGRES_PASSWORD', usernameVariable: 'POSTGRES_USER')
                ]) {
                    sh '''
                    cd stack/aws
                    eval "${TERRAFORM_CMD} init"
                    eval "${TERRAFORM_CMD} apply --auto-approve -var-file='test.tfvars' -var 'pg_username=${POSTGRES_USER}' -var 'pg_password=${POSTGRES_PASSWORD}'"
                  '''
                }
            }
        }
        stage('Setup Test Infra') {
            steps {
                withCredentials([string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                    GIT_SHA=$(git log -1 --pretty=%h)
                    docker tag ngip/ngip-middleware:latest {$REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware:latest
                    docker tag ngip/ngip-middleware:latest {$REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware:$GIT_SHA
                    # need to remove the trailing \r otherwise docker login will complain
                    eval "${AWS_CMD} aws ecr get-login --no-include-email" | tr '\\r' ' ' | bash 
                  '''
                }
            }
        }
        stage('Setup Prod Stack') {
            when { tag "release-*" }
            steps {
                withCredentials([string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                    cd stack/aws
                    eval "${TERRAFORM_CMD} init"
                    eval "${TERRAFORM_CMD} apply --auto-approve -var-file='prod.tfvars'"
                  '''
                }
            }
        }
    }
    post {
        always {
            script {
                try {
                    timeout(time: 10, unit: 'MINUTES') {
                        userInput = input(id: "Stop Docker", message: "Stop Docker?", ok: 'Stop')
                    }
                } catch(err) { // timeout reached or input false
                    def user = err.getCauses()[0].getUser()
                    if('SYSTEM' == user.toString()) { // SYSTEM means timeout.
                        didTimeout = true
                    } else {
                        userInput = false
                        echo "Aborted by: [${user}]"
                    }
                }
            }
            notifyBuild("${currentBuild.currentResult}")
            sh '''
                cd web/middleware
                docker-compose rm -fs
                docker logout {$REGISTRY_ID}.dkr.ecr.ap-southeast-1.amazonaws.com
            '''
            withCredentials([string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY')]) {
              sh '''
                cd stack/aws
                eval "${TERRAFORM_CMD} destroy --auto-approve -var-file='test.tfvars'"
              '''
            }
            withCredentials([usernamePassword(credentialsId: 'JENKINS_API_TOKEN', passwordVariable: 'JENKINS_API_TOKEN', usernameVariable: 'JENKINS_API_USERNAME'), string(credentialsId: 'AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')]) {
              sh '''
                eval "${AWS_CMD} wget -O build.log --auth-no-challenge http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/job/ngip/job/$BRANCH_NAME/$BUILD_ID/consoleText"
                eval "${AWS_CMD} aws s3 cp build.log s3://ngip-build-output/build.log --acl public-read --content-type 'text/plain'"
              '''
            }
        }
    }
}

def keepThisBuild() {
    currentBuild.setKeepLog(true)
    currentBuild.setDescription("Test Description")
}

def getShortCommitHash() {
    return sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()
}

def getChangeAuthorName() {
    return sh(returnStdout: true, script: "git show -s --pretty=%an").trim()
}

def getChangeAuthorEmail() {
    return sh(returnStdout: true, script: "git show -s --pretty=%ae").trim()
}

def getChangeSet() {
    return sh(returnStdout: true, script: 'git diff-tree --no-commit-id --name-status -r HEAD').trim()
}

def getChangeLog() {
    return sh(returnStdout: true, script: "git log --date=short --pretty=format:'%ad %aN <%ae> %n%n%x09* %s%d%n%b'").trim()
}

def getCurrentBranch () {
    return sh (
            script: 'git rev-parse --abbrev-ref HEAD',
            returnStdout: true
    ).trim()
}

def isPRMergeBuild() {
    return (env.BRANCH_NAME ==~ /^PR-\d+$/)
}

//Ref: https://medium.com/@maxy_ermayank/pipeline-as-a-code-using-jenkins-2-aa872c6ecdce
def notifyBuild(String buildStatus = 'STARTED') {
    // build status of null means successful
    buildStatus = buildStatus ?: 'SUCCESS'

    def branchName = getCurrentBranch()
    def shortCommitHash = getShortCommitHash()
    def changeAuthorName = getChangeAuthorName()
    def changeAuthorEmail = getChangeAuthorEmail()
    def changeSet = getChangeSet()
    def changeLog = getChangeLog()

    // Default values
    def colorName = 'RED'
    def colorCode = '#FF0000'
    def subject = "${buildStatus}: '${env.JOB_NAME} [${env.BUILD_NUMBER}]'" + branchName + ", " + shortCommitHash
    def summary = "Started: Name:: ${env.JOB_NAME} \n " +
            "Build Number: ${env.BUILD_NUMBER} \n " +
            "Build URL: ${env.BUILD_URL} \n " +
            "Short Commit Hash: " + shortCommitHash + " \n " +
            "Branch Name: " + branchName + " \n " +
            "Change Author: " + changeAuthorName + " \n " +
            "Change Author Email: " + changeAuthorEmail + " \n " +
            "Change Set: " + changeSet

    if (buildStatus == 'STARTED') {
        color = 'YELLOW'
        colorCode = '#FFFF00'
    } else if (buildStatus == 'SUCCESS') {
        color = 'GREEN'
        colorCode = '#00FF00'
    } else {
        color = 'RED'
        colorCode = '#FF0000'
    }

    // Send notifications
//    hipchatSend(color: color, notify: true, message: summary, token: "${env.HIPCHAT_TOKEN}",
//            failOnError: true, room: "${env.HIPCHAT_ROOM}", sendAs: 'Jenkins', textFormat: true)
    if (buildStatus == 'FAILURE') {
        emailext attachLog: true, body: summary, compressLog: true, recipientProviders: [brokenTestsSuspects(), brokenBuildSuspects(), culprits()], replyTo: 'noreply@ngip.io', subject: subject, to: 'build@ngip.io'
    }
}