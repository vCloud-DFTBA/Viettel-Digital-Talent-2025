# Đề bài

<p align="center">
  <img src="assets\problem-1.png" alt="problem-1.png" width="800"/>
</p>

<p align="center">
  <img src="assets\problem-2.png" alt="problem-2.png" width="800"/>
</p>

## 1. Giới thiệu

Báo cáo này mô tả quá trình thiết lập luồng CI/CD cho ứng dụng Student App sử dụng Jenkins cho CI, Docker Hub để lưu image, ArgoCD cho CD và Kubernetes để chạy ứng dụng.

---

## 2. Kiến trúc tổng thể

- **Repo Source Code:**  
  https://github.com/duongnv3010/VDT-App (chứa frontend, backend, Jenkinsfile)

- **Repo Manifest (Helm Chart/K8s YAML):**  
  https://github.com/duongnv3010/myapp (chứa values.yaml và manifest của ứng dụng)

  (Repo này được merge file values.yaml từ repo https://github.com/duongnv3010/myapp-config để dễ dàng quản lý luồng pipeline )

- **Hệ thống:**
  - Jenkins chạy trên Kubernetes, sử dụng agent pod.
  - Docker Hub để push image.
  - ArgoCD để triển khai manifest ra cluster K8s.

=> Hệ thống tương tự với ảnh bên dưới:

<p align="center">
  <img src="assets\cicd-pipeline.png" alt="cicd-pipeline.png" width="800"/>
</p>

## 3. Các bước thiết lập chi tiết

### 3.1. Chuẩn bị Source Code và Dockerfile

- Chia thành 2 thư mục: `backend/` và `frontend/`, mỗi phần có Dockerfile riêng.
- Viết file `Jenkinsfile` ở thư mục gốc của **Repo Source Code** để khai báo pipeline CI.
- [Jenkinsfile](files/Jenkinsfile)

### 3.2. Build và Push Image lên Docker Hub

- Build image cho phần backend và frontend, sau đó push lên Dockerhub với tên lần lượt là duong3010/be-image:v1.0 và duong3010/fe-image:v1.0
- Sử dụng Kaniko để build image trực tiếp trong K8s.
- Đưa thông tin DockerHub credentials vào K8s bằng Secret:

  ```bash
  kubectl create secret generic dockerhub-credentials \
    --from-file=.dockerconfigjson=/home/youruser/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson \
    -n jenkins
  ```

### 3.3. Cấu hình Jenkins

- Cấu hình **Kubernetes Cloud** trên Jenkins, tạo podTemplate chứa container: jnlp (alpine-jdk17), kaniko, yq. (Đã config bên trong Jenkinsfile)
- Tạo ServiceAccount jenkins để connect đến **Kubernetes Cloud**

[jenkins-rbac.yaml](files/jenkins-rbac.yaml)

<p align="center">
  <img src="assets\k8s-connected.png" alt="k8s-connected.png" width="800"/>
</p>

- Tạo các credentials cho GitHub, Docker Hub.
- Gắn Jenkinsfile vào repo code.

### 3.4. Cấu hình job pipeline Jenkins

<p align="center">
  <img src="assets\job-pipeline-config.png" alt="job-pipeline-config.png" width="800"/>
</p>

- **Stages:**

  1. Checkout Source Code
  2. Build & Push Backend Image (Kaniko)
  3. Build & Push Frontend Image (Kaniko)
  4. Clone repo manifest, update `values.yaml` bằng yq
  5. Commit & push lên repo manifest

- **Trigger:**
  - Sử dụng Poll SCM để build khi có tag mới

<p align="center">
  <img src="assets\poll-scm.png" alt="poll-scm.png" width="800"/>
</p>

### 3.5. Deploy ArgoCD & tạo Application

- Tạo Application ArgoCD (sử dụng manifest):

  ```yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    name: student-app
    namespace: argocd
  spec:
    project: default
    source:
      repoURL: "https://github.com/duongnv3010/myapp"
      targetRevision: master
      path: "."
    destination:
      server: "https://kubernetes.default.svc"
      namespace: student-app-helm
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
      syncOptions:
        - CreateNamespace=true
  ```

- Apply manifest:
  ```bash
  kubectl apply -f argocd-myapp.yaml
  ```

---

## 4. Kiểm thử toàn bộ luồng

1. **Edit code, push code, tạo tag mới trên repo source.**

- Edit title ở code frontend từ `Student Management` thành `Student Management k8s`.

<p align="center">
  <img src="assets\edit-title-fe.png" alt="edit-title-fe.png" width="800"/>
</p>

- Push code và gắn tag v1.4

<p align="center">
  <img src="assets\push-and-add-tag.png" alt="push-and-add-tag.png" width="800"/>
</p>

2. **Jenkins build và push image lên Docker Hub, update tag trong manifest.**

- Jenkins Build Stage

<p align="center">
  <img src="assets\jenkins-build-stage.png" alt="jenkins-build-stage.png" width="800"/>
</p>

- push image lên Dockerhub với tag mới là v1.4

<p align="center">
  <img src="assets\dockerhub-fe-img-v1.4.png" alt="dockerhub-fe-img-v1.4.png" width="800"/>
</p>

- Update tag trong values.yaml

<p align="center">
  <img src="assets\update-values-yaml.png" alt="update-values-yaml.png" width="800"/>
</p>

3. **ArgoCD tự động detect commit mới, sync lên cụm K8s.**

<p align="center">
  <img src="assets\argocd-sync.png" alt="argocd-sync.png" width="800"/>
</p>

4. **Pod frontend/backend lên version mới.**
5. **Kiểm tra lại image version bằng:**
   ```
   kubectl describe deployment backend -n student-app-helm
   kubectl describe deployment frontend -n student-app-helm
   ```

- image version mới cho backend

<p align="center">
  <img src="assets\be-image-new-version.png" alt="be-image-new-version.png" width="800"/>
</p>

- image version mới cho frontend

<p align="center">
  <img src="assets\fe-image-new-version.png" alt="fe-image-new-version.png" width="800"/>
</p>

6. **Hình ảnh app trước và sau**

- Trước

<p align="center">
  <img src="assets\app-before.png" alt="app-before.png" width="800"/>
</p>

- Sau

<p align="center">
  <img src="assets\app-after.png" alt="app-after.png" width="800"/>
</p>
