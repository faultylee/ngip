pipeline {
    agent {
        node {
            label 'master'
        }
    }
    environment {
        TF_LOG='INFO'
        TERRAFORM_CMD='docker run --rm --network host -w /app -v $(pwd):/app -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} -e TF_LOG=${TF_LOG} hashicorp/terraform:light'
        AWS_CMD='docker run --rm -i -u 0 --network host -v $(pwd):/data -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} faulty/aws-cli-docker:latest'
        DOCKER_LOGIN=''
    }
    stages {
        stage('Pre Web Build') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'DJANGO_ADMIN', passwordVariable: 'ADMIN_EMAIL', usernameVariable: 'ADMIN_NAME'), string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY'), string(credentialsId: 'REDIS_PASSWORD', variable: 'REDIS_PASSWORD'), usernamePassword(credentialsId: 'POSTGRES_USER', passwordVariable: 'POSTGRES_PASSWORD', usernameVariable: 'POSTGRES_USER')]) {
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
            }
        }
        stage('Setup Stack') {
            steps {
                withCredentials([string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                  sh '''
                    cd stack/aws
                    eval "${TERRAFORM_CMD} init"
                    eval "${TERRAFORM_CMD} apply --auto-approve"
                  '''
                }
            }
        }
        stage('Web Build') {
            steps {
                sh '''
                    cd web/middleware
                    docker-compose rm -fs
                    docker-compose build
                '''
            }
        }
        stage('Web Up') {
            steps {
                sh '''
                  cd web/middleware
                  docker-compose up -d
                '''
            }
        }
        stage('Web Test') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'DJANGO_ADMIN', passwordVariable: 'ADMIN_EMAIL', usernameVariable: 'ADMIN_NAME'), string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY'), string(credentialsId: 'REDIS_PASSWORD', variable: 'REDIS_PASSWORD'), usernamePassword(credentialsId: 'POSTGRES_USER', passwordVariable: 'POSTGRES_PASSWORD', usernameVariable: 'POSTGRES_USER')]) {
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
                sh '''
                    GIT_SHA=$(git log -1 --pretty=%h)
                    docker tag faulty/ngip-middleware-web:latest faulty/ngip-middleware-web:$GIT_SHA
          
                '''
            }
        }
        stage('Push to ECR') {
            steps {
                withCredentials([string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                    GIT_SHA=$(git log -1 --pretty=%h)
                    docker tag ngip/ngip-middleware:latest 288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware:latest
                    docker tag ngip/ngip-middleware:latest 288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware:$GIT_SHA
                    # need to remove the trailing \r otherwise docker login will complain
                    eval "${AWS_CMD} aws ecr get-login --no-include-email" | tr '\\r' ' ' | bash 
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
            sh '''
                cd web/middleware
                docker-compose rm -fs
                docker logout 288211158144.dkr.ecr.ap-southeast-1.amazonaws.com
            '''
            //build job: 'ngip-post-build', parameters: [string(name: 'NGIP_BUILD_ID', value: env.BUILD_ID), string(name: 'NGIP_BRANCH_NAME', value: env.BRANCH_NAME)], wait: false
            withCredentials([string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY')]) {
              sh '''
                cd stack/aws
                eval "${TERRAFORM_CMD} destroy --auto-approve"
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


