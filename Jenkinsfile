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