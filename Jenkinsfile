pipeline {
    agent {
        node {
            label 'master'
        }
    }
    environment {
      TERRAFORM_CMD='$(which docker) run --rm --network host -w /app -v $(pwd):/app -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} hashicorp/terraform:light'
      AWS_CMD='$(which docker) run --rm -i -u 0 --network host -v $(pwd):/data -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} faulty/aws-cli-docker:latest'
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
                        echo $(eval "{$AWS_CMD} curl -s -L  http://localhost:8000/ping/ | ${AWS_CMD} jq '.[] | .account' -r")
                        if [ -z $(eval "{$AWS_CMD} curl -s -L  http://localhost:8000/ping/ | ${AWS_CMD} jq '.[] | .account' -r") ]; then
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
    }
    post {
        always {
            script {
                timeout(time: 10, unit: 'MINUTES') {
                    input(id: "Stop Docker", message: "Stop Docker?", ok: 'Stop')
                }
            }
            sh '''
                cd web/middleware
                docker-compose rm -fs
            '''
            build job: 'ngip-post-build', parameters: [string(name: 'NGIP_BUILD_ID', value: env.BUILD_ID), string(name: 'NGIP_BRANCH_NAME', value: env.BRANCH_NAME)], wait: false
            withCredentials([usernamePassword(credentialsId: 'JENKINS_API_TOKEN', passwordVariable: 'JENKINS_API_TOKEN', usernameVariable: 'JENKINS_API_USERNAME'), string(credentialsId: 'AWS_ACCESS_KEY_ID_EC2', variable: 'AWS_ACCESS_KEY_ID'), string(credentialsId: 'AWS_SECRET_ACCESS_KEY_EC2', variable: 'AWS_SECRET_ACCESS_KEY')]) {
              sh '''
                eval "${AWS_CMD} wget -O build.log --auth-no-challenge http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/job/ngip/job/$BRANCH_NAME/$BUILD_ID/consoleText"
                eval "${AWS_CMD} aws s3 cp build.log s3://ngip-build-output/build.log --acl public-read --content-type 'text/plain'"
              '''
            }
        }
    }
}


