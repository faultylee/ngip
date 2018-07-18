pipeline {
    agent {
        docker { image 'python:3.7-alpine' }
    }
    stages {
        stage('Test') {
            steps {
                sh 'python --version'
            }
        }
    }
}
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh '''
                    docker -v
                    env
                    ls -lah
                '''
            }
        }
    }
}