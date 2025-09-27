pipeline {
  agent any
  options { timestamps() }
  stages {
    stage('Env')   { steps { sh 'java -version && mvn -version' } }
    stage('Build') { steps { sh 'mvn -B -U -DskipTests -Dmaven.repo.local=$WORKSPACE/.m2/repository clean verify' } }
    stage('Tests') {
      when { expression { fileExists('pom.xml') } }
      steps { sh 'mvn -B -Dmaven.repo.local=$WORKSPACE/.m2/repository test' }
      post { always { junit testResults: '**/target/surefire-reports/*.xml', allowEmptyResults: true } }
    }
    stage('Artifacts') {
      steps { archiveArtifacts artifacts: 'target/*.{jar,war}', fingerprint: true, onlyIfSuccessful: true }
    }
  }
  post { always { cleanWs() } }
}
