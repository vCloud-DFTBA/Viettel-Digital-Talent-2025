# Viettel-Digital-Talent-2025
Creator: Nguyễn Tuấn Anh

# Triển khai kubernetes
Yêu cầu: Cài đặt ansible v2.16.6, docker
Công cụ sử dụng: Kubespray
Cách cài đặt:
git clone https://github.com/kubernetes-sigs/kubespray
cd kubespray

docker run --rm -it \
  --mount type=bind,source="$(pwd)"/inventory/sample,dst=/inventory \
  --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
  quay.io/kubespray/kubespray:v2.28.0 bash

[Cấu hình inventory](script/kubespray/inventory.ini)

Chạy cài đặt K8s:
ansible-playbook -i /inventory/inventory.ini cluster.yml --become --ask-pass --ask-become-pass
●	Nhập mật khẩu SSH + mật khẩu sudo.
●	Nếu không có node nào failed, là thành công.

Cài đặt kubectl:
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

[Cấu hình kubeconfig](script/kubespray/config)

[Ảnh chụp log](images/kubespray/log.png)

#K8S Helm Chart

Cách cài đặt ArgoCD lên k8s cluster:
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml # manifest chính thức từ Argo CD

Forward port để truy cập giao diện:
kubectl port-forward svc/argocd-server -n argocd 32335:443

Cách lấy mật khẩu ArgoCD:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

[File manifest ArgoCD](https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml)

[Ảnh chụp giao diện ArgoCD](images/argocd/UI.png)

Cách cài đặt Helm:
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

Cách cài đặt Jenkins:
helm repo add jenkins https://charts.jenkins.io
helm repo update

kubectl create namespace jenkins

helm install jenkins jenkins/jenkins -f values.yaml -n jenkins

[File manifest Jenkins](script/jenkins/values.yaml)
File này đã được bổ sung pod templates và các plugin phục vụ cho phần sau

[Ảnh chụp giao diện Jenkins](images/jenkins/UI.png)

Url git app
[Frontend](https://github.com/ntacsharp/my-app-frontend)
[Backend](https://github.com/ntacsharp/my-app-backend)
[Config/Deploy](https://github.com/ntacsharp/my-app-deploy)

Cách cài đặt helm chart app
Vào folder config
kubectl create namespace my-app
helm install my-app . -n my-app

[File manifest ArgoCD Application](script/argocd/argo-application.yaml)

Cách apply:
kubectl apply -f argo-application.yaml -n argocd

[Ảnh chụp giao diện ArgoCD App](images/argocd/app.png)

[Ảnh chụp giao diện App](images/web-app.png)

# CICD
Thục hiện build image và push lên dockerhub.
[Dockerfile backend](https://github.com/ntacsharp/my-app-backend/blob/master/Dockerfile)
[Dockerfile frontend](https://github.com/ntacsharp/my-app-frontend/blob/master/Dockerfile)
[Dockerhub image backend](https://hub.docker.com/repository/docker/tuanasanh/my-app-frontend-image/general)
[Dockerhub image frontend](https://hub.docker.com/repository/docker/tuanasanh/my-app-frontend-image/general)
Các lệnh:
Build image(ví dụ): docker build -t tuanasanh/my-app-backend-image:1.0
Push image lên dockerhub (ví dụ): docker push tuanasanh/my-app-backend-image:1.0

Các plugin cần thiết trong jenkins: Generic Webhook Trigger, Github, Workspace Cleanup, Pipeline View Stage, vv (đã được liệt kê trong file manifest jenkins)

Thêm các credential cần thiết: Github và Dockerhub
[Ảnh credential](images/jenkins/cre.png)

Các bước tạo job:
New item => Chọn tên => Pipeline => Set up như trong ảnh
[Ảnh 1](images/jenkins/1.png)
[Ảnh 2](images/jenkins/2.png)
[Ảnh 3](images/jenkins/3.png)
[Ảnh 4](images/jenkins/4.png)

[Cấu hình webhook trên git repo](images/jenkins/webhook.png)

[Tag mới trên repo](images/jenkins/tag.png)

[Log của pipeline](script/jenkins/#36.txt)

[Cấu hình Jenkinsfile](https://github.com/ntacsharp/my-app-backend/blob/master/Jenkinsfile)

[Ảnh chụp Jenkins Stage view](images/jenkins/stages.png)

[Anh chụp argo diff](images/argocd/diff.png)
Ảnh này em chụp bên git do em không tìm được chỗ hiện diff trên ArgoCD :v

[Ảnh chụp app triển khai Argo](images/argocd/sync.png)

# Monitoring
Expose metric của app ra 1 http path
Bước 1: Tải dependency: npm i prom-client
Bước 2: Viết [middleware](https://github.com/ntacsharp/my-app-frontend/blob/master/middleware.ts) và [Path /api/metrics](https://github.com/ntacsharp/my-app-frontend/blob/master/src/app/api/metrics/route.ts)

Cấu trúc:
├── [ansible.cfg](script/prometheus/ansible.cfg)
├── inventories
│   └── [hosts.ini](script/prometheus/inventories/hosts.ini)
├── playbooks
│   └── [deploy_prometheus.yml](script/prometheus/playbooks/deploy-prometheus.yml)
└── roles── prometheus
            ├── files
            │   └── [prometheus.yml](script/prometheus/files/prometheus.yml)
            └── tasks
                └── [main.yml](script/prometheus/tasks/main.yml)

Cách triển khai: Chạy lệnh ansible-playbook -i inventories/hosts.ini playbooks/deploy-prometheus.yml --become --ask-pass --ask-become-pass

# Logging
Tạo namespace logging: kubectl create namespace logging

Cấu trúc:
├── [install-elasticsearch.yaml](script/efk/install-elasticsearch.yaml)
├── [inventory.ini](script/efk/inventory.ini)
│── roles
│   ├── kibana── files── [kibana.yaml](script/efk/roles/kibana/files/kibana.yaml)
│   └── fluentd── files
│                 ├── [fluentd-sa.yaml](script/efk/roles/fluentd/files/fluentd-sa.yaml)
│                 ├── [fluentd-configmap.yaml](script/efk/roles/fluentd/files/fluentd-configmap.yaml)
│                 ├── [fluentd-daemonset.yaml](script/efk/roles/fluentd/files/fluentd-daemonset.yaml)
└── playbooks
    ├── [deploy-kibana.yaml](script/efk/playbooks/deploy-kibana.yaml)
    └── [deploy-fluentd.yaml](script/efk/playbooks/deploy-fluentd.yaml)

Lần lượt chạy 
ansible-playbook -i inventory.ini install-elasticsearch.yaml --become --ask-pass --ask-become-pass
ansible-playbook -i inventory.ini playbooks/deploy-kibana.yaml --become --ask-pass --ask-become-pass
ansible-playbook -i inventory.ini playbooks/deploy-fluentd.yaml--become --ask-pass --ask-become-pass

Do vấn đề về cpu mà em không cài elasticsearch vào trong cụm cluster k8s được, nên em chọn giải pháp cài ra ngoài.

[Ảnh chụp giao diện Kibana](images/efk/kibana.png)

# Security
Yêu cầu 1:
Tạo self-signed cert bằng openssl:
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=lab.local"
kubectl create secret tls lab-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n default

Cài NGINX Ingress Controller bằng Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=31221 \
  --set controller.service.nodePorts.https=31222 \
  --set controller.publishService.enabled=false

[File ingress.yaml](script/sec/ingress.yaml)

Apply manifest ingress: kubectl apply -f ingress.yaml

Thêm lab.local vào hosts
sudo nano /etc/hosts
Thêm dòng 192.168.122.82   lab.local

Cài đặt haproxy
sudo apt install haproxy -y

[File haproxy config](script/sec/haproxy.cfg)

Khởi động lại haProxy
sudo systemctl restart haproxy
sudo systemctl enable haproxy

Kiểm tra bằng lệnh curl từ 1 máy khác (máy thật)
curl -vk https://lab.local/
[Ảnh chụp kết quả curl](images/sec/curl.png)

Yêu cầu 2:
Giải pháp xác thực và phân quyền.
Để đảm bảo tính thuận tiện cho việc demo, thông tin tài khoản và mật khẩu sẽ được lưu trực tiếp ở backend, không mã hóa và không sử dụng cơ sở dữ liệu.

[Source code backend](https://github.com/ntacsharp/my-app-backend)

Trong ví dụ này, em sẽ sử dụng Bearer token. Bearer token là một loại token được sử dụng trong các hệ thống xác thực và ủy quyền API web. Token này thường được gửi kèm trong tiêu đề HTTP như sau:
Authorization: Bearer <token>
Khi server nhận được yêu cầu chứa Bearer token, nó sẽ kiểm tra token để xác định xem yêu cầu có hợp lệ không và có quyền truy cập tài nguyên hay không.

Tuy nhiên, bearer token không được mã hóa, nên nếu bị lộ, ai có token là có quyền. Vì vậy cần sử dụng phương thức https để bảo vệ token này.

Cả hai yêu cầu là xác thực và phân quyền đều được em tự triển khai trong source code mà không sử dụng các bên thứ ba, cụ thể:
[Hàm xác thực token](script/sec/code/authenticateToken.js)
[Hàm phân quyền](script/sec/code/requireRole.js)
Hai hàm này sẽ được đặt vào trước quá trình xử lý dữ liệu như middleware để đảm bảo yêu cầu xác thực và phân quyền, [ví dụ](images/sec/example.png)

Quy trình hoạt động:
Đầu tiên, người dùng cần thực hiện đăng nhập với tài khoản và mật khẩu (Gửi 1 Post request tới /api/login). Nếu như đúng tài khoản và mật khẩu thì client sẽ nhận lại một chuỗi token.
[Minh chứng](images/sec/login_proof.png)
Khi gửi các yêu cầu tới backend, client sẽ gửi kèm token này trong header. Backend sẽ nhận token, giải mã, xác thực và kiểm tra quyền. 
Nếu như thiếu token, backend sẽ trả lại {"message":"Forbidden - no token"}
[Minh chứng](images/sec/no_token_proof.png)
Nếu như có token nhưng không có quyền, backend sẽ trả lại {"message":"Forbidden - insufficient role"}
[Minh chứng](images/sec/sufficient_role_proof.png)

Minh chứng cho request hợp lệ: 
[Minh chứng User](images/sec/200%20user.png)
[Minh chứng Admin](images/sec/200%20admin.png)

Yêu cầu 3:
Công cụ sử dụng: express-rate-limit
Đây là một công cụ phổ biến cho backend sử dụng express dùng để hạn chế rate của các request.
Cách cài đặt: npm install express-rate-limit

Cách tích hợp vào backend:
[Source code backend](https://github.com/ntacsharp/my-app-backend)
import rateLimit từ express-rate-limit
Đặt biến:
const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  keyGenerator: req => req.user?.username || req.ip,
  handler: (req, res) => {
    res.status(409).json({ message: 'Too many requests - please wait.' });
  }
});
sử dụng biến cho mọi api: app.use('/api', apiLimiter);

Tuy cách sử dụng ratelimit ở backend này sẽ đem lại nhiều điểm yếu như hiệu năng thấp, tiêu thụ tài nguyên nhiều hơn. Nhưng nó là cách đơn giản nhất, phù hợp với người mới làm quen như em.

Cách test:  for i in {1..50}; do curl -k -s -o /dev/null -w "%{http_code}\n" https://lab.local/api/hello; done
[Kết quả](images/sec/rate-limit.png)