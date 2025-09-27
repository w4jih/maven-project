pipeline {
  agent any
  tools {
    jdk   'jdk-17'           // must match the name in Manage Jenkins → Tools
    maven 'maven 3.6.3'      // or whatever name you configured (not "mvn")
  }
  options {
    timestamps()
  }
  environment {
    // Use a per-workspace local repo (good hygiene)
    MAVEN_CONFIG = "-Dmaven.repo.local=${WORKSPACE}/.m2/repository"
  }

  stages {
    stage('Build') {
      steps {
        sh 'mvn -B -U -DskipTests clean verify'
      }
    }
    stage('Tests') {
      when { expression { fileExists('pom.xml') } }
      steps {
        sh 'mvn -B test'
      }
      post {
        always {
          junit testResults: '**/target/surefire-reports/*.xml', allowEmptyResults: true
        }
      }
    }
    stage('Artifacts') {
      steps {
        archiveArtifacts artifacts: 'target/*.{jar,war}', fingerprint: true, onlyIfSuccessful: true
      }
    }
  }

  post {
    always {
      cleanWs()
    }
  }
}
