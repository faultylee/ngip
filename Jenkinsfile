pipeline {
  agent {
    node {
      label 'master'
      }
  }
  stages {
    stage('Pre Web Build') {
      agent any
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
      agent any
        steps {
          sh '''
            cd web/middleware
            docker-compose rm -fs
            docker-compose build #tag with git hash
          '''
        }
    }
    stage('Web Up') {
      agent any
        steps {
          sh '''
            cd web/middleware
            #generate env file
            docker-compose up -d
            #sleep
            #check http
            # curl -s -L  http://localhost:8000/ping | jq ".[] | .account" -r
            # Account: test
          '''
        }
    }
    stage('Web Test') {
      agent {
        docker { image 'faulty/aws-cli-docker:latest' }
      }
      steps {
        sh '''
          test=$(curl -s -L  http://localhost:8000/ping | jq ".[] | .account" -r)
          if [[ "$test" == "Account: test" ]]; then
            exit 127
          fi
        '''
        script {
          timeout(time: 10, unit: 'MINUTES') {
            input(id: "Stop Docker", message: "Stop Docker?", ok: 'Stop')
          }
        }
      }
    }
  }
  post {
    always {
      node('master') {
        build job: 'ngip-post-build', parameters: [string(name: 'NGIP_BUILD_ID', value: env.BUILD_ID), string(name: 'NGIP_BRANCH_NAME', value: env.BRANCH_NAME)], wait: false
        sh '''
            cd web/middleware
            docker-compose stop
            #curl $BUILD_URL/consoleText > build.log
            #scripts/update-build-badge.sh
        '''
      }
    }
  }
}


