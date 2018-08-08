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
    stage('Web Build') {
      agent any
        steps {
          sh '''
            cd web/middleware
            docker-compose build #tag with git hash
          '''
        }
    }
    stage('Test1') {
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
    stage('Test2') {
      agent {
        docker { image 'python:3.7-alpine' }
      }
      steps {
        sh 'python --version'
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


