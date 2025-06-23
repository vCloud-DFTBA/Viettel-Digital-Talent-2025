# CI/CD
## Yêu cầu
    • Viết 1 luồng CI/CD cho app, khi có thay đổi từ source code, 1 tag mới được tạo ra trên trên repo này thì luồng CI/CD tương ứng của repo đó thực hiện các công việc sau:
            ▪ Sửa code trong source code
            ▪ Thực hiện build source code trên jenkin bằng docker với image tag là tag name đã được tạo ra trên gitlab/github và push docker image sau khi build xong lên Docker Hub
            ▪ Sửa giá trị Image version trong file values.yaml  trong config repo và push thay đổi lên config repo. 
            ▪ Cấu hình ArgoCD tự động triển khai lại web Deployment và api Deployment khi có sự thay đổi trên config repo.

## Output

Mỗi service có một pipeline riêng, được xây dựng gồm các stage sau:
| Stage       | Mô tả                                                                      |
| ----------- | -------------------------------------------------------------------------- |
| **Stage 1** | **Checkout** source code từ GitHub                                         |
| **Stage 2** | Trích xuất **Git commit/tag** để dùng làm image tag                        |
| **Stage 3** | **Build Docker image** bằng **Kaniko**                                     |
| **Stage 4** | **Push Docker image** lên Docker Hub                                       |
| **Stage 5** | **Cập nhật `values.yaml`** trong config repo (image version) và commit lại |
| **Stage 6** | ArgoCD phát hiện thay đổi → tự động **triển khai lại Deployment**          |

![](./images/images.png)

### Thiết lập Jenkins & Kaniko
Đã tạo sẵn Docker Hub credential dạng secret và gắn vào container Kaniko để thực hiện build và push image.

Jenkins sử dụng plugin Pipeline và Git webhook để trigger mỗi khi có tag mới.

### Thiết lập webhook trên repo github

![](./images/Screenshot%20From%202025-06-23%2015-51-10.png)

### Mẫu payload

![](./images/Screenshot%20From%202025-06-23%2015-51-59.png)

### Hình ảnh truy cập Jenkins
![](./images/Screenshot%20From%202025-06-23%2020-34-30.png)

### Cài đặt các Plugin cần thiết
![](./images/Screenshot%20From%202025-06-23%2021-45-09.png)

### Thiết lập các credentials cho jenkins

![](./images/Screenshot%20From%202025-06-14%2016-46-43.png)
![](./images/Screenshot%20From%202025-06-23%2021-55-40.png)

### Output log

![](./images/Screenshot%20From%202025-06-19%2002-32-58.png)
![](./images/Screenshot%20From%202025-06-19%2002-36-23.png)
![](./images/Screenshot%20From%202025-06-19%2004-47-32.png)

### Ảnh luồng CI/CD chạy qua các stage trên giao diện Jenkins ( sử dụng Plugin Pipeline Stage View)

![](./images/Screenshot%20From%202025-06-22%2014-34-45.png)

### Diff khi argoCD phát hiện thay đổi ở config repo

![](./images/Screenshot%20From%202025-06-20%2003-15-03.png)

### Update trên Github repo

![](./images/Screenshot%20From%202025-06-23%2015-40-39.png)

### File cấu hình

```python
pipeline {
  agent {
    kubernetes {            
      yaml """
        apiVersion: v1
        kind: Pod
        metadata:
          namespace: cicd
          name: kaniko
        spec:
          containers:                          
          - name: kaniko
            image: gcr.io/kaniko-project/executor:debug
            imagePullPolicy: Always
            command: [sleep]
            args: ["9999999"]
            resources:
              requests:
                cpu: "100m"
                memory: "128Mi"
              limits:
                cpu: "500m"
                memory: "512Mi"
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
    IMAGE = "ndbaolam/basic-auth"    
  }

  stages {
    stage('Checkout') {
      steps {
        git url: 'https://github.com/ndbaolam/IT4082-BlueMoon', branch: 'main'
      }
    }
    
    stage('Get Commit ID') {
      steps {
        script {
          def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          env.TAG = commitHash
          echo "Docker tag will fe: ${env.TAG}"
        }
      }
    }

    stage('Build & Push Docker Image') {      
      steps {
        container('kaniko') {
          sh """
            /kaniko/executor \
              --context=./auth-service \
              --dockerfile=./auth-service/Dockerfile \
              --destination=${env.IMAGE}:${env.TAG} \
              --skip-tls-verify
          """
        }
      }
    }

    stage('Update K8s Manifest Repo') {
      steps {
        script {
          def dockerImageTag = "${env.IMAGE}:${env.TAG}"
          withCredentials([
            usernamePassword(
              credentialsId: 'github_pat',
              usernameVariable: 'GIT_USERNAME',
              passwordVariable: 'GIT_TOKEN'
            )]) {
            dir('helm/app-chart') {
              sh """
                sed -i 's|^\\( *image: \\)ndbaolam/basic-auth:.*|\\1ndbaolam/basic-auth:${TAG}|' values.yaml

                git config --global user.email 'baolam782004@gmail.com'
                git config --global user.name jenkins

                git remote set-url origin https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/ndbaolam/IT4082-BlueMoon.git

                git add values.yaml
                git commit -m "Update Auth image to ${env.TAG}"
                git push origin main
              """
            }
          }
        }        
      }
    }
  }
}
```

Luồng CI/CD giúp tự động hóa hoàn toàn quá trình build, push, cập nhật config và deploy lại ứng dụng thông qua ArgoCD.
→ Đảm bảo tính liên tục, nhanh chóng, ổn định, và đồng bộ hóa giữa source code, image và cấu hình triển khai.