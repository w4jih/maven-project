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
    DATE_TAG   = sh(script: "date -u +%Y%m%d%H%M", returnStdout: true).trim()
    GIT_SHA    = sh(script: "git rev-parse --short=8 HEAD", returnStdout: true).trim()
    POM_VERSION = sh(
      script: "mvn -q -DforceStdout -Dmaven.repo.local=$MAVEN_REPO_LOCAL help:evaluate -Dexpression=project.version",
      returnStdout: true
    ).trim()
  }
  steps {
    sh '''
      set -euo pipefail
      echo "[INFO] Recherche du binaire Maven (jar/war)…"
      ARTIFACT="$(find . -type f \\( -path "*/target/*.jar" -o -path "*/target/*.war" \\) \
        ! -name "*-sources.jar" ! -name "*-javadoc.jar" | head -n1 || true)"
      if [ -z "${ARTIFACT:-}" ]; then
        echo "[ERROR] Aucun artefact trouvé sous */target/. Vérifie que 'mvn package' produit bien un jar/war."
        echo "[DEBUG] Arborescence target:"
        find . -type d -name target -maxdepth 3 -print -exec ls -l {} \\; || true
        exit 1
      fi
      echo "[INFO] Artefact détecté: $ARTIFACT"
      echo "ARTIFACT=$ARTIFACT" > .docker-env
    '''
    script {
      def repo = "${env.DOCKERHUB_NAMESPACE}/${env.IMAGE_NAME}"
      // Build avec ARG propre
      sh """
        set -euo pipefail
        source .docker-env
        docker build --build-arg JAR_FILE="\$ARTIFACT" -t ${repo}:build-${GIT_SHA} .
      """
      def tags = ["${POM_VERSION}", "${POM_VERSION}-${GIT_SHA}", "${POM_VERSION}-${DATE_TAG}", "${GIT_SHA}"]
      if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') { tags << 'latest' }
      for (t in tags) { sh "docker tag ${repo}:build-${GIT_SHA} ${repo}:${t}" }
      withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'wajih20032002', passwordVariable: 'glace 123')]) {
        sh """
          echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
          for t in ${tags.join(' ')}; do docker push ${repo}:\$t; done
          docker logout
        """
      }
      sh "docker rmi ${repo}:build-${GIT_SHA} ${tags.collect { "${repo}:" + it }.join(' ')} || true"
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
