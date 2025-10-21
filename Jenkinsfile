pipeline {
  agent any
  options { timestamps() }

  environment {
    // Personnalise ces 2 variables
    DOCKERHUB_NAMESPACE = 'mydockerhubuser'
    IMAGE_NAME          = 'myapp'
    // Répertoires Maven locaux pour cache
    MAVEN_REPO_LOCAL    = "${WORKSPACE}/.m2/repository"
  }

  stages {
    stage('Env') {
      steps { sh 'java -version && mvn -version && docker --version' }
    }

    stage('Build') {
      steps {
        sh 'mvn -B -U -DskipTests -Dmaven.repo.local=$MAVEN_REPO_LOCAL clean verify'
      }
    }

    stage('Tests') {
      when { expression { fileExists('pom.xml') } }
      steps {
        sh 'mvn -B -Dmaven.repo.local=$MAVEN_REPO_LOCAL test'
      }
      post {
        always {
          junit testResults: '**/target/surefire-reports/*.xml', allowEmptyResults: true
        }
      }
    }

    stage('Artifacts') {
      steps {
        archiveArtifacts artifacts: '**/target/*.jar, **/target/*.war',
                          fingerprint: true, onlyIfSuccessful: true
      }
    }

    /******************** Docker: Build, Tag, Push ********************/
    stage('Docker: Build & Push') {
      when { expression { fileExists('Dockerfile') } }
      environment {
        // Tags dynamiques
        DATE_TAG   = sh(script: "date -u +%Y%m%d%H%M", returnStdout: true).trim()
        GIT_SHA    = sh(script: "git rev-parse --short=8 HEAD", returnStdout: true).trim()
        // Récupère la version du POM (ex: 1.3.0)
        POM_VERSION = sh(
          script: "mvn -q -DforceStdout -Dmaven.repo.local=$MAVEN_REPO_LOCAL help:evaluate -Dexpression=project.version",
          returnStdout: true
        ).trim()
      }
      steps {
        script {
          def repo = "${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}"
          // Construit l’image locale avec un tag de build
          sh """
            docker build \
              --build-arg JAR_FILE=\$(ls **/target/*.jar | head -n1 || echo '') \
              -t ${repo}:build-${GIT_SHA} .
          """

          // Liste de tags à appliquer
          def tags = ["${POM_VERSION}", "${POM_VERSION}-${GIT_SHA}", "${POM_VERSION}-${DATE_TAG}", "${GIT_SHA}"]
          // Ajoute 'latest' si on est sur la branche principale
          if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') {
            tags << 'latest'
          }

          // Tagging local
          for (t in tags) {
            sh "docker tag ${repo}:build-${GIT_SHA} ${repo}:${t}"
          }

          // Login + push
          withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                            usernameVariable: 'wajih20032002',
                                            passwordVariable: 'glace 123')]) {
            sh """
              echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
              for t in ${tags.join(' ')}; do
                docker push ${repo}:\$t
              done
              docker logout
            """
          }

          // Nettoyage local optionnel
          sh """
            docker rmi ${repo}:build-${GIT_SHA} ${tags.collect { "${repo}:" + it }.join(' ')} || true
          """
        }
      }
    }
  }

  post {
    always {
      cleanWs()
    }
  }
}
