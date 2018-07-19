pipeline {
    agent none
    stages {
        stage('Build') {
            agent any
            steps {
                sh '''
                    docker -v
                    env
                    ls -lah
                '''
            }
        }
        stage('Test') {
            agent {
                docker { image 'python:3.7-alpine' }
            }
            steps {
                sh 'python --version'
            }
        }
        post {
            always {
                sh '''
                    curl $BUILD_URL/consoleText > build.log
                    scripts/update-build-badge.sh
                '''
            }
        }
    }
}
