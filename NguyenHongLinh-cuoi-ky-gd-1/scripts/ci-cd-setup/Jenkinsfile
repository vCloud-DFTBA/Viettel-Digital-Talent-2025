pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      imagePullPolicy: Always
      command: [sleep]
      args: ["9999999"]
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent
        - name: docker-config
          mountPath: /kaniko/.docker/
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
        DOCKER_HUB_USERNAME = 'linhx021' 
        DOCKER_HUB_REPO = 'linhx021' 
        CONFIG_REPO_URL = 'https://github.com/honglinh0812/CD-VDT.git' // Thay thế bằng URL config repo của bạn
        CONFIG_REPO_BRANCH = 'main' 
        FRONTEND_SOURCE_PATH = 'microservices-frontend'
        BACKEND_SOURCE_PATH = 'microservices-backend' 
        FRONTEND_HELM_CHART_PATH = 'config/frontend-chart' 
        BACKEND_HELM_CHART_PATH = 'config/backend-chart' 
        VALUES_FILE = 'values.yaml'
        }
    stages {
        stage('Checkout source code') {
            steps {
                script {
                    def currentCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                    echo "Current commit hash: ${currentCommit}"
                    def tagName = sh(returnStdout: true, script: "git describe --tags --exact-match ${currentCommit}").trim()
                    if (!tagName) {
                        error 'Không thể xác định tag. Đảm bảo job được kích hoạt bởi một Git tag và repository có tag.'
                    }
                    echo "Đang build cho tag: ${tagName}"
                }
            }
        }

        stage('Build and push images with Kaniko') {
            steps {
                script {
                    def currentCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                    def tagName = sh(returnStdout: true, script: "git describe --tags --exact-match ${currentCommit}").trim()
                    def dockerImageTagFrontend = "microservice-frontend:${tagName}"
                    def dockerImageTagBackend = "microservice-backend:${tagName}"
                    container('kaniko') {
                        echo "Đang build và push image với Kaniko: ${dockerImageTagFrontend}"
                        sh """
                        /kaniko/executor \
                            --context `pwd`/microservices-frontend \
                            --dockerfile `pwd`/microservices-frontend/Dockerfile \
                            --destination docker.io/${DOCKER_HUB_REPO}/${dockerImageTagFrontend} &&
                        /kaniko/executor \
                            --dockerfile `pwd`/microservices-backend/Dockerfile \
                            --context `pwd`/microservices-backend \
                            --destination=docker.io/${DOCKER_HUB_REPO}/${dockerImageTagBackend}
                        """
                    }
                }
            }
        }

        stage('Update config repository') {
            steps {
                script {
                    def currentCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                    def tagName  = sh(returnStdout: true, script: "git describe --tags --exact-match ${currentCommit}").trim()
                    def configRepoDir = "config-repo"

                    withCredentials([usernamePassword(credentialsId: 'git-config-repo-credentials', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                        sh "git config --global user.email 'honglinh0812uet@gmail.com'"
                        sh "git config --global user.name 'honglinh0812'"
                        sh "git clone ${CONFIG_REPO_URL} ${configRepoDir}"
                        dir(configRepoDir) {
                            sh "git checkout ${CONFIG_REPO_BRANCH}"
                            // Thêm dòng này để cấu hình Git sử dụng username và password (PAT) cho việc push
                            sh "git remote set-url origin https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/honglinh0812/CD-VDT.git"

                            def frontendValuesFilePath = "${FRONTEND_HELM_CHART_PATH}/${VALUES_FILE}"
                            sh "sed -i 's|^\\(\\s*tag:\\s*\\).*|\\1${tagName}|' ${frontendValuesFilePath}"
                            echo "Updated ${frontendValuesFilePath} with image tag: ${tagName}"

                            def backendValuesFilePath = "${BACKEND_HELM_CHART_PATH}/${VALUES_FILE}"
                            sh "sed -i 's|^\\(\\s*tag:\\s*\\).*|\\1${tagName}|' ${backendValuesFilePath}"
                            echo "Updated ${backendValuesFilePath} with image tag: ${tagName}"
                            sh "git add ${frontendValuesFilePath}"
                            sh "git add ${backendValuesFilePath}"
                            
                            def hasChanges = sh(script: "git diff --cached --quiet || echo 'yes'", returnStdout: true).trim()

                            if (hasChanges == 'yes') {
                                sh "git commit -m 'CI: Update image tag to ${tagName}'"
                                sh "git push origin ${CONFIG_REPO_BRANCH}"
                                echo "Image tag updated and pushed"
                            } else {
                                echo "No changes to commit"
                            }
                        }
                    }
                    echo "Config repository updated successfully."
                }
            }
        }
    }

    post {
        always {
            script {
                node {
                    cleanWs()
                }
            }
        }
    }
}
