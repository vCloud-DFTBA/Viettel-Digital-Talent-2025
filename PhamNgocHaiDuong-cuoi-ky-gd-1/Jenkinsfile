pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        GITHUB_CREDENTIALS = credentials('github')
        FRONTEND_IMAGE = 'shiner2/frontend'
        BACKEND_IMAGE = 'shiner2/backend-api'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout([$class: 'GitSCM', 
                    branches: [[name: 'refs/heads/master']], 
                    userRemoteConfigs: [[url: 'https://github.com/Shiner-2/CRUD-app.git', credentialsId: 'github']]
                ])
            }
        }

        stage('Check for changes') {
            steps {
                script {
                    def lastBuiltCommit = ''
                    if (fileExists('.last_build_commit')) {
                        lastBuiltCommit = readFile('.last_build_commit').trim()
                    }
                    def currentCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                    echo "Last built commit: ${lastBuiltCommit}"
                    echo "Current commit: ${currentCommit}"

                    if (lastBuiltCommit == currentCommit) {
                        echo "No new commits since last build. Skipping build."
                        currentBuild.result = 'SUCCESS'
                        error("No changes detected, aborting build.")
                    } else {
                        echo "New commit detected, proceed with build."
                    }
                }
            }
        }

        stage('Get Git Tag') {
            steps {
                script {
                    env.GIT_TAG = sh(returnStdout: true, script: "git describe --tags --abbrev=0 || echo 'latest'").trim()
                    echo "Using Git tag: ${env.GIT_TAG}"
                }
            }
        }

        stage('Get Git Tag and Increment') {
            steps {
                script {
                    // Lấy tag hiện tại, ví dụ "v1.0.0"
                    def currentTag = sh(returnStdout: true, script: "git describe --tags --abbrev=0 || echo 'v0.0.0'").trim()
                    echo "Current Tag: ${currentTag}"
        
                    // Tách phần số, giả sử tag format chuẩn "vX.Y.Z"
                    def pattern = /^v(\d+)\.(\d+)\.(\d+)$/
                    def matcher = currentTag =~ pattern
                    if (matcher) {
                        def major = matcher[0][1].toInteger()
                        def minor = matcher[0][2].toInteger()
                        def patch = matcher[0][3].toInteger()
        
                        // Tăng patch lên 1
                        patch = patch + 1
        
                        env.GIT_TAG = "v${major}.${minor}.${patch}"
                    } else {
                        // Nếu tag không đúng format, đặt version mặc định
                        env.GIT_TAG = "v0.0.1"
                    }
                    echo "New Tag: ${env.GIT_TAG}"
                }
            }
        }

        

        stage('Build and Push') {
            steps {
                sh "docker build -t ${FRONTEND_IMAGE}:${GIT_TAG} frontend"
                sh "docker build -t ${BACKEND_IMAGE}:${GIT_TAG} backend-api"

                sh "echo ${DOCKERHUB_CREDENTIALS_PSW} | docker login -u ${DOCKERHUB_CREDENTIALS_USR} --password-stdin"
                sh "docker push ${FRONTEND_IMAGE}:${GIT_TAG}"
                sh "docker push ${BACKEND_IMAGE}:${GIT_TAG}"
                sh "docker logout"
            }
        }

        stage('Update values.yaml & Push') {
            steps {
                sh """
                    sed -i '/backend-api:/,/- tag:/ s/tag: .*/tag: ${GIT_TAG}/' values.yaml
                    sed -i '/frontend:/,/- tag:/ s/tag: .*/tag: ${GIT_TAG}/' values.yaml
                    git config user.name "jenkins"
                    git config user.email "jenkins@example.com"
                    git add values.yaml
                    git commit -m "Update image tags to ${GIT_TAG}" || echo "No changes to commit"
                """
                withCredentials([usernamePassword(credentialsId: 'github', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
                    sh "git push https://${GIT_USER}:${GIT_PASS}@github.com/Shiner-2/CRUD-app.git HEAD:refs/heads/master"
                }
            }
        }


        stage('Save current commit') {
            steps {
                script {
                    def currentCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                    writeFile file: '.last_build_commit', text: currentCommit
                }
            }
        }
    }
}
