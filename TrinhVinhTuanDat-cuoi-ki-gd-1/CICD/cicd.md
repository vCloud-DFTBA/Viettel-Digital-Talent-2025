# CI/CD (1.5đ)

## Yêu cầu:

Viết 1 luồng CI/CD cho app, khi có thay đổi từ source code, 1 tag mới được tạo ra trên repo này thì luồng CI/CD tương ứng của repo đó thực hiện các công việc sau:

- Sửa code trong source code
- Thực hiện build source code trên jenkin bằng docker với image tag là tag name đã được tạo ra trên gitlab/github và push docker image sau khi build xong lên Docker Hub
- Sửa giá trị Image version trong file values.yaml trong config repo và push thay đổi lên config repo.
- Cấu hình ArgoCD tự động triển khai lại web Deployment và api Deployment khi có sự thay đổi trên config repo.

## Output:

- Các file setup công cụ của luồng CI/CD
- Output log của luồng CI/CD khi tạo tag mới trên repo app
- Show log chứng minh jenkin đã chạy đúng
- Jenkin file cấu hình các luồng
- Ảnh luồng CI/CD chạy qua các stage trên giao diện Jenkins (sử dụng Plugin Pipeline Stage View)
- Hình ảnh app triển khai argoCD, hình ảnh diff khi argoCD phát hiện thay đổi ở config repo tương tự hình ảnh sau
- Hình ảnh app trước khi sửa code và sau khi sửa code.

## Kịch bản triển khai CI/CD
1. Cấu hình webhook trên github repo chứa source code, khi có event tạo tag mới, webhook sẽ gửi một request về cho jenkins 
2. Jenkins nhận request và thực hiện chạy pipeline CI
3. Jenkins sẽ tạo image từ source code trên repo github, build image và push  images này lên docker hub
4. Jenkins thực hiện sửa tag của images trong file values-prod.yaml và push code lên repo config
5. ArgoCD mặc định cấu hình 3 phút / lần polling thay đổi trên repo config, nếu có sự khác biệt sẽ thực hiện tự động deploy lại trên cụm k8s

# 1. Cấu hình luồng CI/CD cho backend

## Thiết lập truy cập Jenkins

Do Jenkins được triển khai trên cụm Kubernetes và chỉ có thể truy cập qua NodePort, cần sử dụng một giải pháp tunneling để có thể truy cập từ bên ngoài:

**Sử dụng Ngrok để tạo public endpoint:**
- **Public URL**: `https://freely-guiding-fowl.ngrok-free.app/`
- **Forward đến**: `192.168.122.93:30999` (NodePort của Jenkins service)
- **Mục đích**: Cho phép GitHub webhook có thể gọi đến Jenkins để trigger CI/CD pipeline

**Lệnh khởi tạo Ngrok:**
```bash
nohup ngrok http --url=freely-guiding-fowl.ngrok-free.app 192.168.122.93:30999 &
```
## Cấu hình Jenkins Agent

Thực hiện tạo một Jenkins agent và cài đặt các công cụ cần thiết như Git, Docker, đồng thời tạo user Jenkins để agent có thể thực hiện pipeline.

---

### Tạo máy ảo mới

Thực hiện tạo thêm một máy ảo để làm Jenkins agent

![alt text](images/mayao.png)

Cấu hình địa chỉ IP tĩnh cho máy ảo

![alt text](images/ip.png)

---

### Tạo Jenkins Agent

- Tạo một node agent mới trong Jenkins
- Cấu hình kết nối và các thông số cần thiết

---

### Cài đặt các công cụ cần thiết

- **Git:** Để clone source code từ repository
- **Docker:** Để build và push Docker images  
- **Java:** Runtime environment cho Jenkins agent

---

### Tạo user Jenkins

- Tạo user `jenkins` trên máy agent
- Cấp quyền thực thi pipeline và truy cập Docker daemon
- Cấu hình SSH key để kết nối với Jenkins master

---

### Kiểm tra kết nối

Xác minh Jenkins agent đã được cấu hình thành công và có thể nhận job từ master

![alt text](images/jenkins_agent.png)



## 1.1 Cấu hình GitHub Webhook

### Cấu hình URL webhook GitHub

![alt text](images/webhook.png)

### Cấu hình event GitHub

![alt text](images/events.png)

Webhook URL: https://freely-guiding-fowl.ngrok-free.app/generic-webhook-trigger/invoke?token=vdt-tag-webhook-2025

---

## 1.2 Cấu hình Jenkins CI

### Thêm credentials vào Jenkins

Thực hiện thêm credetial vào Jenkins:

| Credential ID | Mô tả |
|---------------|-------|
| **dockerhub_credential** | Là thông tin tài khoản docker hub - nhằm mục đích push image lên docker hub |
| **github_token** | Là thông tin tài khoản github nhằm mục đích xác thực với github và push code lên repo config |

![alt text](images/credential.png)
### File cấu hình CI cho Jenkins: Jenkinsfile
[Jenkinsfile](https://github.com/Maybetuandat/vdt_2025_backend/blob/main/Jenkinsfile)


### Tạo Jenkins Job mới
Tạo một item và đặt tên là **vdt_backend**

![alt text](images/vdt_backend.png)

### Cấu hình Build Retention
**Discard old builds:** Giữ lại 5 bản build cuối cùng để tiết kiệm dung lượng storage

### Cấu hình GitHub Repository
Kết nối với repository GitHub chứa source code backend

![alt text](images/repogithub.png)

### Thiết lập Build Triggers
Cấu hình các tham số để tự động trigger build khi có thay đổi

![alt text](images/triger.png)

### Cấu hình Pipeline Script
Chỉ định sử dụng Jenkinsfile từ SCM (Source Code Management)

![alt text](images/jenkinsfile.png)

### Cấu hình Build khi có Tag mới
Pipeline sẽ được trigger tự động khi có tag mới được tạo trên repository

![alt text](images/tag.png)

### Chỉ định đường dẫn Jenkinsfile
Xác định vị trí file Jenkinsfile trong repository 
![alt text](images/jenkinsfile.png)

### Cấu hinh token yêu cầu gửi từ webhook
![alt text](images/token.png)

## 1.3 Thực hiện chạy luồng CI/CD

### Bước 1: Tạo và Push Tag mới
Thực hiện tạo tag **3.6** và push lên repository backend

![alt text](images/push_tag.png)

Tag được push trên repo github 
![alt text](images/tag_backend_1.png)

### Bước 2: GitHub Webhook Trigger
Webhook tự động gửi request về Jenkins server khi phát hiện tag mới

![alt text](images/webhook-3-6.png)

### Bước 3: Jenkins Pipeline Execution
Jenkins pipeline được kích hoạt và khởi chạy tự động

![alt text](images/jenkinse_pipeline.png)

**Chi tiết log Jenkins Pipeline:**

![alt text](images/log_1_jenkins.png)

![alt text](images/log2_jenkins.png)

**Log chi tiết CI Jenkins:** [Jenkins Log file](logs/backend_logs.txt)

### Bước 4: Build và Push Docker Image
Thực hiện build Docker image với tag **3.6** và push lên Docker Hub

![alt text](images/dockerhub.png)

### Bước 5: Cập nhật Config Repository
- Clone repository config
- Thay đổi image tag từ phiên bản cũ sang **3.6** trong file values
- Push thay đổi lên config repository

![alt text](images/backend_repoconfig.png)

### Bước 6: ArgoCD Detect Changes
ArgoCD phát hiện sự thay đổi trong config repository và hiển thị diff

![alt text](images/arrgocd_diff.png)

### Bước 7: ArgoCD Application
ArgoCD bắt đầu thực hiện deploy 
![alt text](images/arrgocd_deploy.png)

### Bước 8: ArgoCD Application Events
Hình ảnh event thay đổi của backend application trong ArgoCD

![alt text](images/argocd_backend_event.png)

### Bước 9: Deployment Manifest Update
Manifest mới của backend deployment đã được cập nhật lên tag **3.6**

![alt text](images/argocd_backend_deployment_3_6.png)

### Bước 10: Final Application State
Trạng thái cuối cùng của backend application sau khi hoàn thành luồng CI/CD

![alt text](images/argocd_backend.png)

# 2. Cấu hình CI/CD cho Frontend



## Trạng thái ban đầu

### Giao diện ứng dụng
Giao diện ban đầu đang được chạy trên cụm Kubernetes với đầy đủ chức năng:

![Giao diện ban đầu](images/fe1.png)


### Trạng thái Kubernetes Cluster
**Pods đang chạy trong namespace `vdt-app`:**
![Kubernetes Pods](images/1.png)
*Danh sách các pods đang hoạt động trong namespace vdt-app*

**Services được expose qua NodePort:**
![Kubernetes Services](images/2.png)


---

## Thực hiện thay đổi code

### Mục tiêu
Xóa button "Thêm sinh viên"  bằng cách comment phần code giao diện button thêm sinh viên

**Sửa trong code**

![Sửa trong code](images/fe2.png)

**Sau khi chỉnh sửa:**

![Giao diện sau khi sửa](images/fe3.png)




## Version Control

### Tạo tag và push code
Thực hiện tạo tag version `2.0` và push lên GitHub repository:

![Git tag và push](images/fe4.png)
*Tạo tag v2.0 và push lên remote repository*

Tag được push lên repo ![alt text](images/tag_fe_1.png)

## CI/CD Pipeline Execution

### 1. Webhook Trigger
GitHub webhook tự động gửi thông báo đến Jenkins server khi có thay đổi:

![Webhook notification](images/fe5.png)
*Webhook gửi POST request đến Jenkins server*

### 2. Jenkins Pipeline Execution
Jenkins server nhận trigger và bắt đầu thực thi pipeline:

![Jenkins pipeline start](images/fe6.png)
*Jenkins pipeline được kích hoạt tự động*

### 3. Build Process Logs
Chi tiết quá trình build được ghi lại trong Jenkins logs:

![Jenkins build log 1](images/fe7.png)
![Jenkins build log 2](images/fe8.png)
*Logs chi tiết của quá trình build và test*

 **[Xem full log tại đây](logs/frontend_log.txt)**

### 4. Docker Image Build & Push
Jenkins agent thực hiện build Docker image và push lên Docker Hub:

![Docker Hub push](images/fe9.png)
*Image được build thành công và push lên Docker Hub registry*

### 5. Config Repository Update
Jenkins tự động cập nhật version trong file `values-prod.yaml`:

![Config repo update](images/fe10.png)
*Cập nhật tag trong repo config*

### 6. CI Pipeline Completion
Quá trình CI hoàn thành thành công:

![CI completion](images/fe11.png)
*Jenkins pipeline hoàn thành tất cả các bước CI*

---

## Deployment với ArgoCD

### 1. ArgoCD Sync Process
Với cơ chế tự động polling sau cứ mỗi 3 phút,
ArgoCD thực hiện sync:

![ArgoCD sync](images/fe12.png)


### 2. Deployment Events
Chi tiết các event trong quá trình deployment:

![Deployment events](images/fe14.png)
*Timeline các event trong quá trình deploy frontend*

### 3. Deployment Completion
ArgoCD hoàn thành quá trình deployment:

![ArgoCD completion](images/fe13.png)
*Trạng thái "Synced" và "Healthy" cho thấy deployment thành công*

---

## Kết quả cuối cùng

### Giao diện sau deployment
Giao diện ứng dụng sau khi deploy thành công, đúng như mong đợi:

![Final result](images/fe15.png)
*Giao diện cuối cùng đã được cập nhật, không còn button "Thêm sinh viên"*




# Kết luận

Hệ thống CI/CD đã được triển khai thành công cho cả Backend (v3.6) và Frontend (v2.0) với kiến trúc GitOps hoàn chỉnh. Quy trình tự động hóa từ việc tạo Git tag đến deployment production hoạt động ổn định qua các công cụ Jenkins, ArgoCD và Kubernetes.



