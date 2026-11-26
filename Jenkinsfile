// =============================================================================
//  Jenkinsfile — oan-service-helm. Packages the shared charts and adds them to the develop
//  channel of oan-helm, like the Publish develop charts GitHub workflow, but with the Jenkins
//  credential oan-helm-fork-token, so it does not need the OAN_HELM_TOKEN repository secret.
//
//  Every branch: lint the charts that changed (all of them on a first build).
//  main:         package those charts as 0.0.0-develop.<commits on main> and add each archive to
//                repository/develop/ of oan-helm with scripts/ci/publish_chart.py (taken from
//                oan-helm). A version already published is skipped, not an error; oan-helm's
//                publish-channels workflow then updates the index, checksums and CHANGELOG.
//
//  Agent needs: helm, git, python3. Credential: oan-helm-fork-token (username + token with push
//  access to oan-helm). Only one of this Jenkinsfile and the GitHub workflow should publish.
// =============================================================================
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '30'))
    timeout(time: 20, unit: 'MINUTES')
  }

  environment {
    OAN_HELM = 'https://github.com/Centre-for-Open-Societal-Systems/oan-helm.git'
    ALL_CHARTS = 'frappe-common frappe-service ui-service'
  }

  stages {
    stage('Resolve') {
      steps {
        script {
          // The version counts commits, so the checkout must be complete.
          sh 'git fetch --quiet --unshallow || true'
          env.CHART_VERSION = '0.0.0-develop.' + sh(returnStdout: true, script: 'git rev-list --count HEAD').trim()
          def base = env.GIT_PREVIOUS_SUCCESSFUL_COMMIT ?: ''
          def changed = []
          for (chart in env.ALL_CHARTS.split(' ')) {
            // No previous build, or a base git no longer has: take every chart.
            def unchanged = base && sh(returnStatus: true, script: "git diff --quiet ${base} HEAD -- ${chart}") == 0
            if (!unchanged) { changed << chart }
          }
          env.CHARTS = changed.join(' ')
          echo "branch=${env.BRANCH_NAME}  version=${env.CHART_VERSION}  charts=${env.CHARTS ?: 'none'}"
        }
      }
    }

    stage('Lint') {
      when { expression { env.CHARTS } }
      steps {
        sh '''
          set -euo pipefail
          for chart in $CHARTS; do
            # helm dependency build refuses a repository it does not know by URL.
            grep -hE '^ *repository: *"?http' "$chart/Chart.yaml" | sed -E 's/^ *repository: *"?([^"]*)"?.*/\\1/' | sort -u |
              while read -r url; do helm repo add "r-$(echo "$url" | md5sum | cut -c1-8)" "$url" > /dev/null; done
            helm dependency build "$chart"
            helm lint "$chart"
          done
        '''
      }
    }

    stage('Package') {
      when { allOf { branch 'main'; expression { env.CHARTS } } }
      steps {
        sh '''
          set -euo pipefail
          rm -rf dist && mkdir -p dist
          for chart in $CHARTS; do
            helm package "$chart" --version "$CHART_VERSION" --destination dist
          done
          ls -l dist
        '''
        stash name: 'dist', includes: 'dist/*.tgz'
      }
    }

    stage('Publish') {
      when { allOf { branch 'main'; expression { env.CHARTS } } }
      steps {
        unstash 'dist'
        withCredentials([usernamePassword(credentialsId: 'oan-helm-fork-token', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
          sh '''
            set -euo pipefail
            work="$(mktemp -d)"
            trap 'rm -rf "$work"' EXIT
            # The publisher only: scripts/ci of oan-helm main, without its repository/ archives.
            git clone --quiet --depth 1 --filter=blob:none --sparse "$OAN_HELM" "$work/oan-helm"
            git -C "$work/oan-helm" sparse-checkout set scripts/ci
            for archive in dist/*.tgz; do
              set +e
              python3 "$work/oan-helm/scripts/ci/publish_chart.py" "$archive"
              status=$?
              set -e
              # 4: this version is already published from the same commit, so a re-run is not an error.
              if [ "$status" -ne 0 ] && [ "$status" -ne 4 ]; then exit "$status"; fi
            done
          '''
        }
      }
    }
  }

  post {
    success { echo "OK  ${env.BRANCH_NAME} #${env.BUILD_NUMBER} -> ${env.CHART_VERSION} (${env.CHARTS ?: 'no chart changed'})" }
    failure { echo "FAIL ${env.BRANCH_NAME} #${env.BUILD_NUMBER}" }
  }
}
