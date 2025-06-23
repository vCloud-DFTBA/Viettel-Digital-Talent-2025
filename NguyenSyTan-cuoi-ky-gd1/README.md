# Báo cáo cuối kỳ VDT 2025 lĩnh vực Cloud
## Triển khai Kubernetes    
### Yêu cầu: 
Y/c 1: 
- Triển khai được Kubernetes thông qua công cụ minikube trên 1 node   
Hoặc 
- Triển khai được Kubernetes thông qua công cụ kubeadm hoặc kubespray lên 1 master node VM + 1 worker node VM
### Output:
- Tài liệu cài đặt (công cụ gì, các file config, …): [Tài liệu cài đặt](1.%20Setup%20Kubernetes/Setup.md) 
- Ảnh chụp Log của các lệnh kiểm tra hệ thống như:  `kubectl get nodes - o wide`, `kubectl get pods -A - o wide`

![](images/k8s-installation.png) 

## Triển khai web application sử dụng các DevOps tools & practices
Sinh viên chọn 1 app bất kỳ theo cấu trúc microservices (ví dụ web app và api service).  
- [Tổng quan về web app](2.%20Deploy%20web%20application/2.0.%20Tổng%20quan%20về%20app/README.md)
### K8S Helm Chart
#### Yêu cầu 1: 
- Cài đặt ArgoCD lên Kubernetes Cluster, expose được ArgoCD qua NodePort 
- Cài đặt Jenkins lên Kubernetes Cluster, expose được Jenkins qua NodePort

#### Output 1: 
- File manifests sử dụng để triển khai ArgoCD lên K8S Cluster: 
- Ảnh chụp giao diện màn hình hệ thống ArgoCD khi truy cập qua trình duyệt trình duyệt 
- File manifests sử dụng để triển khai Jenkins lên K8S Cluster:
- Ảnh chụp giao diện màn hình hệ thống Jenkins khi truy cập qua trình duyệt trình duyệt

[Kết quả yêu cầu 1](2.%20Deploy%20web%20application/2.1.%20K8s%20Helm%20Chart/Output1.md)
#### Yêu cầu 2:
- Viết hoặc tìm mẫu Helm Chart cho app bất kỳ, để vào 1 folder riêng trong repo app
- Tạo Repo Config cho app trên, trong repo này chứa các file values.yaml với nội dung của cá file values.yaml là các config cần thiết để chạy ứng dụng 
trên k8s bằng Helm Chart  
#### Output 2: 
- Các Helm Chart sử dụng để triển khai app lên K8S Cluster  
- Các file values.yaml trong config repo của app
- Ảnh chụp giao diện màn hình hệ thống ArgoCD trên trình duyệt
- Ảnh chụp giao diện màn hình trình duyệt khi truy cập vào Web URL, API URL   

[Kết quả yêu cầu 2](./2.%20Deploy%20web%20application/2.1.%20K8s%20Helm%20Chart/Output2.md)

### CI/CD
#### Yêu cầu:
- Viết 1 luồng CI/CD cho app, khi có thay đổi từ source code, 1 tag mới được tạo ra trên trên repo này thì luồng CI/CD tương ứng của repo đó 
thực hiện các công việc sau: 
- Sửa code trong source code 
- Thực hiện build source code trên jenkin bằng docker với image tag là tag name đã được tạo ra trên gitlab/github và push docker image 
sau khi build xong lên Docker Hub 
- Sửa giá trị Image version trong file values.yaml  trong config repo và push thay đổi lên config repo.  
- Cấu hình ArgoCD tự động triển khai lại web Deployment và api Deployment khi có sự thay đổi trên config repo. 
#### Output: 
- Các file setup công cụ của luồng CI/CD
- Output log của luồng CI/CD khi tạo tag mới trên repo app 
- Show log chứng minh jenkin đã chạy đúng
- Jenkinsfile cấu hình các luồng:
- Ảnh luồng CI/CD chạy qua các stage trên giao diện Jenkins ( sử dụng Plugin Pipeline Stage View)
- Hình ảnh app triển khai argoCD, hình ảnh diff khi argoCD phát hiện thay đổi ở config repo   

[Kết quả yêu cầu](./2.%20Deploy%20web%20application/2.2.%20CICD/Output.md)

### Monitoring
#### Yêu cầu:
- Expose metric của app ra 1 http path.
- Sử dụng ansible playbooks để triển khai container Prometheus server. Sau đó cấu hình prometheus add target giám sát các metrics đã expose ở trên. 
#### Output: 
- Các file setup để triển khai Prometheus
- Hình ảnh khi truy cập vào Prometheus UI thông qua trình duyệt
- Hình ảnh danh sách target của App được giám sát bởi Prometheus

[Kết quả yêu cầu](./2.%20Deploy%20web%20application/2.3.%20Monitoring/Output.md)

### Logging
#### Yêu cầu:
- Sử dụng ansible playbooks để triển khai stack EFK (elasticsearch, fluentd, kibana), sau đó cấu hình logging cho web service và api service, đảm bảo khi có http request gửi vào web service hoặc api service thì trong các log mà các service này sinh ra, có ít nhất 1 log có các thông tin 
    - Request Path(VD: /api1/1, /api2/3 ..) 
    - HTTP Method VD: (GET PUT POST…) 
    - Response Code: 302, 200, 202, 201… 
#### Output: 
- Hình ảnh chụp màn hình Kibana kết quả tìm kiếm log của các service theo url path 

[Kết quả yêu cầu](./2.%20Deploy%20web%20application/2.4.%20Logging/Output.md)

### Security
#### Yêu cầu 1:
- Dựng HAProxy Loadbalancer trên 1 VM riêng (trong trường hợp cụm lab riêng của sinh viên) với mode TCP, mở port trên LB trỏ đến NodePort của App trên K8S Cluster.
- Sử dụng giải pháp Ingress cho các deployment, đảm bảo các truy cập đến các port App sử dụng https
- Cho phép sinh viên sử dụng self-signed cert để làm bài 
#### Output 1: 
- File cấu hình của HAProxy Loadbalancer cho App 
- File cấu hình ingress. 
- Kết quả truy cập vào App từ trình duyệt thông qua giao thức https hoặc dùng curl.   

[Kết quả yêu cầu 1](./2.%20Deploy%20web%20application/2.5.%20Security/Yêu%20cầu%201/Output.md)

#### Yêu cầu 2: 
- Đảm bảo 1 số URL của api service  khi truy cập phải có xác thực thông qua 1 trong số các phương thức cookie, basic auth, token auth, nếu không sẽ trả về HTTP response code 403. 
- Thực hiện phân quyền cho 2 loại người dùng trên API:
    - Nếu người dùng có role là user thì truy cập vào GET request trả về code 200, còn truy cập vào POST/DELETE thì trả về 403 -
    -  Nếu người dùng có role là admin thì truy cập vào GET request trả về code 200, còn truy cập vào POST/DELETE thì trả về 2xx 
#### Output 2: 
- File trình bày giải pháp sử dụng để authen/authorization cho các service 
- Kết quả HTTP Response khi curl hoặc dùng postman gọi vào các URL khi truyền thêm thông tin xác thực và khi không truyền thông tin xác thực 
- Kết quả HTTP Response khi curl hoặc dùng postman vào các URL với các method GET/POST/DELETE  khi lần lượt dùng thông tin xác thực của các user có role là user và admin   

[Kết quả yêu cầu 2](./2.%20Deploy%20web%20application/2.5.%20Security/Yêu%20cầu%202/Output.md)

#### Yêu cầu 3: 
- Sử dụng 1 trong số các giải pháp để ratelimit cho Endpoint của api Service, sao cho nếu có  quá 10 request trong 1 phút gửi đến Endpoint của api service thì 
các request sau đó bị trả về HTTP Response 409  
#### Output 3: 
- File tài liệu trình bày giải pháp 
- File ghi lại kết quả thử nghiệm khi gọi quá 10 request trong 1 phút vào Endpoint của API Service.   

[Kết quả yêu cầu 3](./2.%20Deploy%20web%20application/2.5.%20Security/Yêu%20cầu%203/Output.md)