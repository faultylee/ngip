pipeline {
  agent {
    node {
      label 'master'
      }
  }
  stages {
    stage('Web Build') {
      agent any
        steps {
          sh '''
            cd web/middleware
            ls -lah
            env
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
        build job: 'ngip-post-build', parameters: [string(name: 'NGIP_BUILD_URL', value: '')], wait: false
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


