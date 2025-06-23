# Problem

<p align="center">
  <img src="assets\problem.png" alt="problem.png" width="800"/>
</p>

## 1. Cài đặt Helm

```
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh
```

## 2. Chuẩn bị Source Code

- Source code của app được chuẩn bị trong github:

```
https://github.com/duongnv3010/VDT-App
```

Đây là một app đơn giản để quản lý danh sách sinh viên. Có các chức năng CRUD đó là hiển thị danh sách sinh viên, thêm, sửa, xoá sinh viên. Ngoài ra hiện tại đã có chức năng login/signup đơn giản.

App gồm 2 phần Frontend (FE) và Backend (BE). Trong đó, FE được viết bằng HTML, CSS, Javascript, phần BE được viết bằng NodeJS.

Database được đã deploy lên cụm k8s và expose NodePort `30006` để sử dụng.

<p align="center">
  <img src="assets\database-k8s.png" alt="database-k8s.png" width="800"/>
</p>

- Tạo Dockerfile cho phần BE:

```
# backend/Dockerfile

FROM node:16-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["node", "be.js"]
```

- Tạo Dockerfile cho phần FE:

```
# frontend/Dockerfile

FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*

COPY . /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

- Build và push Docker image lên Docker Hub:

```
$ docker build -t duong3010/be-image:v1.0 .\backend\.
$ docker build -t duong3010/fe-image:v1.0 .\frontend\.
$ docker push duong3010/be-image:v1.0
$ docker push duong3010/fe-image:v1.0
```

## 3. Tạo Helm Chart

- Thư mục Helm Chart có cấu trúc như sau, đã được đẩy lên repo: https://github.com/duongnv3010/myapp.git

```
myapp/
├── charts
├── Chart.yaml
|── templates
   ├── deployment-backend.yaml
   ├── deployment-frontend.yaml
   ├── service-backend.yaml
   └── service-frontend.yaml
```

- Thư mục chứa file `values.yaml` có nội dung như sau, đã được đẩy lên repo: https://github.com/duongnv3010/myapp-config.git

```
# values.yaml

namespace: student-app-helm

frontend:
  enabled: true
  image:
    repository: duong3010/fe-image
    tag: "v1.0"
  replicaCount: 1
  containerPort: 80
  service:
    type: NodePort
    port: 80
    nodePort: 30010

backend:
  enabled: true
  image:
    repository: duong3010/be-image
    tag: "v1.0"
  replicaCount: 1
  containerPort: 3000
  service:
    type: NodePort
    port: 3000
    nodePort: 30011
  env:
    DB_HOST: "192.168.93.137"
    DB_PORT: "30006"
    DB_USER: "root"
    DB_PASSWORD: "password"
    DB_NAME: "db"
    JWT_SECRET: "secretkey"
```

Cụ thể, phần FE được expose ra NodePort 30010, phần BE được expose ra NodePort 30011 cho thuận tiện sử dụng

## 4. Tạo file manifest ArgoCD

- Tạo file manifest YAML `argocd-app.yaml` cho ArgoCD:

```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: student-app-helm
  namespace: argocd            # namespace nơi ArgoCD đã được cài đặt
spec:
  project: default

  source:
    # Repo chứa Helm Chart
    repoURL: 'https://github.com/duongnv3010/myapp.git'
    path: '.'
    targetRevision: master      # hoặc HEAD, hoặc tag/branch bạn muốn
    helm:
      # Lấy giá trị config từ repo config
      valueFiles:
        - 'https://raw.githubusercontent.com/duongnv3010/myapp-config/refs/heads/master/values.yaml'

  destination:
    server: 'https://kubernetes.default.svc'
    namespace: student-app-helm     # namespace sẽ deploy Chart vào

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true   # Tạo namespace nếu chưa tồn tại
```

- Áp dụng manifest này vào ArgoCD:

```
kubectl apply -f argocd-app.yaml
```

## 5. Kết quả đạt được

- Ảnh chụp giao diện màn hình hệ thống ArgoCD trên trình duyệt

<p align="center">
  <img src="assets\argocd-ui-student-app.png" alt="argocd-ui-student-app.png" width="800"/>
</p>

- Ảnh chụp giao diện app trên trình duyệt

<p align="center">
  <img src="assets\app-on-browser-1.png" alt="app-on-browser-1.png" width="800"/>
</p>

<p align="center">
  <img src="assets\app-on-browser-2.png" alt="app-on-browser-2.png" width="800"/>
</p>

- Test API bằng POSTMAN

<p align="center">
  <img src="assets\test-api-by-postman.png" alt="test-api-by-postman.png" width="800"/>
</p>
