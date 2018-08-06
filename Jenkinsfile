node {
  stage ('Build') {
    sh '''
      cd web/middleware
      compose build
    '''
  }
  stage ('Test') {
    sh '''
      cd web/middleware
      compose up -d
    '''
  }
  stage ('Done') {
    sh '''
      curl $BUILD_URL/consoleText > build.log
      scripts/update-build-badge.sh
    '''
  }
}
