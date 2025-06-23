pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:alpine-jdk17
    args: ['\$(JENKINS_SECRET)', '\$(JENKINS_NAME)']
    workingDir: /home/jenkins/agent
    volumeMounts:
    - name: workspace-volume
      mountPath: /home/jenkins/agent

  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: [sleep]
    args: [9999999]
    volumeMounts:
    - name: workspace-volume
      mountPath: /home/jenkins/agent
    - name: docker-config
      mountPath: /kaniko/.docker/

  - name: yq
    image: mikefarah/yq:4.43.1
    command: [sleep]
    args: [9999999]
    volumeMounts:
    - name: workspace-volume
      mountPath: /home/jenkins/agent

  volumes:
  - name: workspace-volume
    emptyDir: {}
  - name: docker-config
    secret:
      secretName: dockerhub-credentials
      items:
        - key: .dockerconfigjson
          path: config.json
"""
        }
    }

    environment {
        BACKEND_IMAGE = 'duong3010/be-image'
        FRONTEND_IMAGE = 'duong3010/fe-image'
        MANIFEST_REPO = 'https://github.com/duongnv3010/myapp.git'
        MANIFEST_CRED_ID = 'github-credentials'
    }

    stages {
        stage('Checkout Source Code') {
            steps {
                checkout scm
            }
        }

        stage('Build & Push Backend Image') {
            steps {
                script {
                    def tagName = env.GIT_TAG_NAME ?: sh(returnStdout: true, script: "git describe --tags").trim()
                    container('kaniko') {
                        sh """
                        /kaniko/executor --context `pwd`/backend \
                                         --dockerfile `pwd`/backend/Dockerfile \
                                         --destination ${BACKEND_IMAGE}:${tagName}
                        """
                    }
                }
            }
        }

        stage('Build & Push Frontend Image') {
            steps {
                script {
                    def tagName = env.GIT_TAG_NAME ?: sh(returnStdout: true, script: "git describe --tags").trim()
                    container('kaniko') {
                        sh """
                        /kaniko/executor --context `pwd`/frontend \
                                         --dockerfile `pwd`/frontend/Dockerfile \
                                         --destination ${FRONTEND_IMAGE}:${tagName}
                        """
                    }
                }
            }
        }

        stage('Update values.yaml in Manifest Repo') {
        steps {
            script {
                def tagName = env.GIT_TAG_NAME ?: sh(returnStdout: true, script: "git describe --tags").trim()
                withCredentials([usernamePassword(credentialsId: MANIFEST_CRED_ID, usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
                    sh """
                    git clone https://${GIT_USER}:${GIT_PASS}@github.com/duongnv3010/myapp.git manifest-repo
                    """
                    container('yq') {
                        sh """
                        cd manifest-repo
                        /usr/bin/yq e '.backend.image.tag = "${tagName}"' -i values.yaml
                        /usr/bin/yq e '.frontend.image.tag = "${tagName}"' -i values.yaml
                        """
                    }
                    sh """
                    cd manifest-repo
                    git config user.email "nguyenduong20053010@gmail.com"
                    git config user.name "duongnv3010"
                    git add values.yaml
                    git commit -m "ci: update backend/frontend image tag to ${tagName}"
                    git push origin master
                    """
                }
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
