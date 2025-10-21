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
      sh 'mvn -B -U -DskipTests -Dmaven.repo.local=$MAVEN_REPO_LOCAL clean package'
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
  steps {
    // Compute tags in one bash block
    script {
      // if you want POM version:
      def pomVersion = sh(script: 'mvn -q -DforceStdout help:evaluate -Dexpression=project.version', returnStdout: true).trim()
      env.POM_VERSION = pomVersion
      env.GIT_SHA     = sh(script: 'git rev-parse --short=8 HEAD', returnStdout: true).trim()
      env.DATE_TAG    = sh(script: 'date -u +%Y%m%d%H%M', returnStdout: true).trim()
    }

    // Locate artifact (jar/war) with bash, fail if missing
    sh label: 'Detect artifact', script: '''
      bash -eo pipefail -c '
        echo "[INFO] Looking for Maven binary (jar/war)…"
        ARTIFACT="$(find . -type f \\( -path "*/target/*.jar" -o -path "*/target/*.war" \\) \
          ! -name "*-sources.jar" ! -name "*-javadoc.jar" | head -n1 || true)"
        if [ -z "${ARTIFACT:-}" ]; then
          echo "[ERROR] No artifact found under */target/. Ensure `mvn package` produced a jar/war."
          echo "[DEBUG] Listing target directories:"
          find . -type d -name target -maxdepth 3 -print -exec ls -l {} \\; || true
          exit 1
        fi
        echo "[INFO] Artifact: $ARTIFACT"
        printf "ARTIFACT=%s\n" "$ARTIFACT" > .docker-env
      '
    '''

    script {
      def repo = "${env.DOCKERHUB_NAMESPACE}/${env.IMAGE_NAME}"
      // Build image using ARG
      sh label: 'Docker build', script: """
        bash -eo pipefail -c '
          source .docker-env
          docker build --build-arg JAR_FILE="\$ARTIFACT" -t ${repo}:build-${env.GIT_SHA} .
        '
      """

      // Prepare tags
      def tags = ["${env.POM_VERSION}", "${env.POM_VERSION}-${env.GIT_SHA}", "${env.POM_VERSION}-${env.DATE_TAG}", "${env.GIT_SHA}"]
      if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') { tags << 'latest' }

      // Tag locally
      for (t in tags) {
        sh "docker tag ${repo}:build-${env.GIT_SHA} ${repo}:${t}"
      }

      // Push using proper credentials vars
      withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                        usernameVariable: 'DH_USER',
                                        passwordVariable: 'DH_PASS')]) {
        sh label: 'Docker push', script: """
          bash -eo pipefail -c '
            echo "\$DH_PASS" | docker login -u "\$DH_USER" --password-stdin
            for t in ${tags.join(' ')}; do
              docker push ${repo}:\$t
            done
            docker logout
          '
        """
      }

      // Optional cleanup
      sh "docker rmi ${repo}:build-${env.GIT_SHA} ${tags.collect { "${repo}:" + it }.join(' ')} || true"
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
