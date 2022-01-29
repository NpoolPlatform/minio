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

    stage('Build minio image') {
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
        sh 'docker build -t uhub.service.ucloud.cn/entropypool/minio:RELEASE.2021-02-14T04-01-33Z .'
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
            docker push uhub.service.ucloud.cn/entropypool/minio:RELEASE.2021-02-14T04-01-33Z
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
        sh 'sed -i "s/minio.internal-devops.development.npool.top/minio.internal-devops.$TARGET_ENV.npool.top/g" 01-traefik-vpn-ingress.yaml'
        sh 'kubectl apply -f 01-traefik-vpn-ingress.yaml'
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
