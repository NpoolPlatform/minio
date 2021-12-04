pipeline {
  agent any
  tools {
    go 'go'
  }
  environment {
    GOPROXY = 'https://goproxy.cn,direct'
  }
  stages {
    stage('Clone minio cluster') {
      steps {
        git(url: scm.userRemoteConfigs[0].url, branch: '$BRANCH_NAME', changelog: true, credentialsId: 'KK-github-key', poll: true)
      }
    }

    stage('Check deps tools') {
      steps {
        script {
          if (!fileExists("/usr/bin/helm")) {
            sh 'mkdir -p $HOME/.helm'
            if (!fileExists("$HOME/.helm/.helm-src")) {
              sh 'git clone https://github.com/helm/helm.git $HOME/.helm/.helm-src'
            }
            sh 'cd $HOME/.helm/.helm-src; git checkout release-3.7; make; cp bin/helm /usr/bin/helm'
            sh 'helm version'
          }
        }
      }
    }

    stage('Switch to current cluster') {
      steps {
        sh 'cd /etc/kubeasz; ./ezctl checkout $TARGET_ENV'
      }
    }

    stage('Build minio image for developement') {
      when {
        expression { BUILD_TARGET == 'true' }
      }
      steps {
        sh 'mkdir -p .docker-tmp; cp /usr/bin/consul .docker-tmp'
        sh(returnStdout: true, script: '''
          set +e
          images=`docker images | grep entropypool | grep minio | awk '{ print $3 }' | grep latest`
          for image in $images; do
            docker rmi $image
          done
          set -e
        '''.stripIndent())
        sh 'docker build -t entropypool/minio:latest .'
      }
    }

    stage('Tag minio') {
      when {
        expression { TAG_TYPE != null }
      }
      steps {
        sh(returnStdout: true, script: '''
          tag_version="0.1.0"
          set +e
          tag_rev_list=`git rev-list --tags --max-count=1`
          if [ 0 -eq $? ]; then
            cur_tag=`git describe --tags $tag_rev_list`
            major_version=`echo $cur_tag | awk -F '.' '{ print $1 }'`
            minor_version=`echo $cur_tag | awk -F '.' '{ print $2 }'`
            mininus_version=`echo $cur_tag | awk -F '.' '{ print $3 }'`
            if [ "$TAG_TYPE" == "major" ]; then
              major_version=`expr $major_version + 1`
              tag_version="$major_version.$minor_version.$mininus_version"
            elif [ "$TAG_TYPE" == "major" ]; then
              minor_version=`expr $minor_version + 1`
              tag_version="$major_version.$minor_version.$mininus_version"
            elif [ "$TAG_TYPE" == "mininus" ]; then
              mininus_version=`expr $mininus_version + 1`
              flag=`expr $mininus_version % 2`
              [[ 0 -eq $flag && $TARGET_ENV ~= testing ]] && mininus_version=`expr $mininus_version + 1`
              [[ ! 0 -eq $flag && $TARGET_ENV ~= production ]] && mininus_version=`expr $mininus_version + 1`
              tag_version="$major_version.$minor_version.$mininus_version"
            fi
          fi

          git tag -a $tag_version -m "add tag $tag_version for test"
          set -e
        '''.stripIndent())

        withCredentials([gitUsernamePassword(credentialsId: 'KK-github-key', gitToolName: 'git-tool')]) {
          sh 'git push --tag'
        }

      }
    }

    stage('Build minio image for testing or production') {
      when {
        expression { BUILD_TARGET == 'true' }
        expression { TAG_TYPE != null }
      }
      steps {
        sh 'mkdir -p .docker-tmp; cp /usr/bin/consul .docker-tmp'
        sh(returnStdout: true, script: '''
          set +e
          images=`docker images | grep entropypool | grep minio | awk '{ print $3 }' | grep -v latest`
          for image in $images; do
            docker rmi $image
          done
          set -e
          tag_rev_list=`git rev-list --tags --max-count=1`
          tag_version=`git describe --tags $tag_rev_list`
          docker build -t entropypool/minio:$tag_version .
        '''.stripIndent())
      }
    }

    stage('Release minio image') {
      when {
        expression { RELEASE_TARGET == 'true' }
      }
      steps {
        sh(returnStdout: true, script: '''
          set +e
          while true; do
            docker push entropypool/minio:RELEASE.2021-02-14T04-01-33Z
            if [ $? -eq 0 ]; then
              break
            fi
          done
          set -e
        '''.stripIndent())
      }
    }

    stage('Deploy minio') {
      when {
        expression { DEPLOY_TARGET == 'true' }
      }
      steps {
        sh 'helm repo add minio https://helm.min.io/'
        sh 'helm upgrade minio --namespace kube-system -f values.service.yaml ./minio || helm install minio --namespace kube-system -f values.service.yaml ./minio'
      }
    }

    stage('Deploy ingress to target') {
      when {
        expression { DEPLOY_TARGET == 'true' }
      }
      steps {
        sh 'sed -i "s/minio.internal-devops.development.npool.top/minio.internal-devops.$TARGET_ENV.npool.top/g" 01-ingress.yaml'
        sh 'kubectl apply -f 01-ingress.yaml'
      }
    }

    stage('Config apollo') {
      when {
        expression { CONFIG_TARGET == 'true' }
      }
      steps {
        sh 'rm .apollo-base-config -rf'
        sh 'git clone https://github.com/NpoolPlatform/apollo-base-config.git .apollo-base-config'
        sh 'cd .apollo-base-config; ./apollo-base-config.sh $APP_ID $TARGET_ENV minio-npool-top'
        sh 'cd .apollo-base-config; ./apollo-item-config.sh $APP_ID $TARGET_ENV minio-npool-top accesskey root'
        sh 'cd .apollo-base-config; ./apollo-item-config.sh $APP_ID $TARGET_ENV minio-npool-top secretkey 12345679'
      }
    }
  }

  post('Report') {
    fixed {
      script {
        sh(script: 'bash $JENKINS_HOME/wechat-templates/send_wxmsg.sh fixed')
     }
      script {
        // env.ForEmailPlugin = env.WORKSPACE
        emailext attachmentsPattern: 'TestResults\\*.trx',
        body: '${FILE,path="$JENKINS_HOME/email-templates/success_email_tmp.html"}',
        mimeType: 'text/html',
        subject: currentBuild.currentResult + " : " + env.JOB_NAME,
        to: '$DEFAULT_RECIPIENTS'
      }
     }
    success {
      script {
        sh(script: 'bash $JENKINS_HOME/wechat-templates/send_wxmsg.sh successful')
     }
      script {
        // env.ForEmailPlugin = env.WORKSPACE
        emailext attachmentsPattern: 'TestResults\\*.trx',
        body: '${FILE,path="$JENKINS_HOME/email-templates/success_email_tmp.html"}',
        mimeType: 'text/html',
        subject: currentBuild.currentResult + " : " + env.JOB_NAME,
        to: '$DEFAULT_RECIPIENTS'
      }
     }
    failure {
      script {
        sh(script: 'bash $JENKINS_HOME/wechat-templates/send_wxmsg.sh failure')
     }
      script {
        // env.ForEmailPlugin = env.WORKSPACE
        emailext attachmentsPattern: 'TestResults\\*.trx',
        body: '${FILE,path="$JENKINS_HOME/email-templates/fail_email_tmp.html"}',
        mimeType: 'text/html',
        subject: currentBuild.currentResult + " : " + env.JOB_NAME,
        to: '$DEFAULT_RECIPIENTS'
      }
     }
    aborted {
      script {
        sh(script: 'bash $JENKINS_HOME/wechat-templates/send_wxmsg.sh aborted')
     }
      script {
        // env.ForEmailPlugin = env.WORKSPACE
        emailext attachmentsPattern: 'TestResults\\*.trx',
        body: '${FILE,path="$JENKINS_HOME/email-templates/fail_email_tmp.html"}',
        mimeType: 'text/html',
        subject: currentBuild.currentResult + " : " + env.JOB_NAME,
        to: '$DEFAULT_RECIPIENTS'
      }
     }
  }
}
