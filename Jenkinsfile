node {
  stage ('Build') {
    sh '''
      cd web/middleware
      ls -la
      env
      docker-compose build
    '''
  }
  stage ('Test') {
    sh '''
      cd web/middleware
      docker-compose up -d
    '''
  }
  stage ('Done') {
    sh '''
      curl $BUILD_URL/consoleText > build.log
      scripts/update-build-badge.sh
    '''
  }
}
