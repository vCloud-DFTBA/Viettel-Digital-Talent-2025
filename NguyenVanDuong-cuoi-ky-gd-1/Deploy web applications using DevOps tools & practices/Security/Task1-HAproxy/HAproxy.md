# Báo Cáo Quá Trình Triển Khai Hệ Thống Kubernetes với HAProxy & Ingress-NGINX

## Thành phần hạ tầng

- **Control Node (Ansible)**: 192.168.93.141
- **Master Node (kube-control-plane, etcd)**: 192.168.93.132
- **Worker Node (kube-node)**: 192.168.93.137
- **Load Balancer (HAProxy)**: 192.168.93.142

---

## Bước 1: Cài đặt & cấu hình HAProxy TCP LB

1. **Cài HAProxy** trên VM LB:
   ```bash
   sudo apt-get update
   sudo apt-get install -y haproxy
   ```
2. **Sao lưu cấu hình gốc**:
   ```bash
   cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup
   ```
3. **Cấu hình `/etc/haproxy/haproxy.cfg`**:

   ```cfg
    global
        log /dev/log    local0
        log /dev/log    local1 notice
        daemon
        maxconn 2000

    defaults
        log     global
        mode    tcp
        option  tcplog
        timeout connect 10s
        timeout client  30s
        timeout server  30s

    frontend fe-frontend
        bind *:80
        mode tcp
        default_backend be-frontend

    backend be-frontend
        mode tcp
        balance roundrobin
        server master1 192.168.93.132:30010 check
        server worker1 192.168.93.137:30010 check

    frontend fe-backend
        bind *:3000
        mode tcp
        default_backend be-backend

    backend be-backend
        mode tcp
        balance roundrobin
        server master1 192.168.93.132:30011 check
        server worker1 192.168.93.137:30011 check

    frontend fe-ingress-http
        bind *:32100
        mode tcp
        default_backend be-ingress-http

    backend be-ingress-http
        mode tcp
        balance roundrobin
        server master1 192.168.93.132:32100 check
        server worker1 192.168.93.137:32100 check

    frontend fe-ingress-https
        bind *:443
        mode tcp
        default_backend be-ingress-https

    backend be-ingress-https
        mode tcp
        balance roundrobin
        server master1 192.168.93.132:32443 check
        server worker1 192.168.93.137:32443 check
   ```

4. **Khởi động lại và bật HAProxy**:
   ```bash
   sudo systemctl restart haproxy
   sudo systemctl enable haproxy
   ```

## Bước 2: Triển khai Ingress-NGINX

1. **Tạo namespace**:
   ```bash
   kubectl create namespace ingress-nginx
   ```
2. **Apply manifest chính thức**:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml
   ```
3. **Patch Service thành NodePort**:
   ```bash
   kubectl -n ingress-nginx patch svc ingress-nginx-controller        --type='json' -p='[
         {"op":"replace","path":"/spec/type","value":"NodePort"},
         {"op":"add","path":"/spec/ports/0/nodePort","value":32100},
         {"op":"add","path":"/spec/ports/1/nodePort","value":32443}
       ]'
   ```

## Bước 3: Tạo Self-Signed TLS Secret

1. **Tạo file cấu hình OpenSSL** `tls.conf` với SAN:

   ```bash
   cat > tls.conf <<EOF
   [req]
   req_extensions = v3_req
   distinguished_name = req_distinguished_name

   [req_distinguished_name]

   [v3_req]
   basicConstraints = CA:FALSE
   keyUsage = digitalSignature, keyEncipherment
   subjectAltName = @alt_names

   [alt_names]
   DNS.1 = frontend.student-app.local
   DNS.2 = backend.student-app.local
   EOF
   ```

2. **Sinh khóa và chứng chỉ**:
   ```bash
   openssl req -x509 -nodes -days 365      -newkey rsa:2048      -keyout tls.key      -out tls.crt      -subj "/CN=frontend.student-app.local"      -extensions v3_req      -config tls.conf
   ```
3. **Tạo Secret** trong Kubernetes:
   ```bash
   kubectl create secret tls student-app-tls      --key tls.key --cert tls.crt      -n student-app-helm
   ```

## Bước 4: Tạo Ingress Resource

1. **Tạo file** `ingress-student-app.yaml`:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: student-app-ingress
     namespace: student-app-helm
     annotations:
       kubernetes.io/ingress.class: "nginx"
   spec:
     tls:
       - hosts:
           - frontend.student-app.local
         secretName: student-app-tls
     rules:
       - host: frontend.student-app.local
         http:
           paths:
             - path: /login
               pathType: Prefix
               backend:
                 service:
                   name: backend-service
                   port: { number: 3000 }
             - path: /signup
               pathType: Prefix
               backend:
                 service:
                   name: backend-service
                   port: { number: 3000 }
             - path: /students
               pathType: Prefix
               backend:
                 service:
                   name: backend-service
                   port: { number: 3000 }
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: frontend-service
                   port: { number: 80 }
       - host: backend.student-app.local
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: backend-service
                   port: { number: 3000 }
   ```
2. **Áp dụng**:
   ```bash
   kubectl apply -f ingress-student-app.yaml
   ```

## Bước 5: Cấu hình DNS/hosts và kiểm thử

1. **Trên máy client**, sửa `/etc/hosts`:
   ```
   192.168.93.142 frontend.student-app.local backend.student-app.local
   ```
2. **Kiểm tra**:
   ```bash
   curl -Ik https://frontend.student-app.local/
   curl -Ik https://frontend.student-app.local/login      -H "Content-Type: application/json"      -d '{"username":"duongnv","password":"duongnv"}'
   ```
3. **Mở trình duyệt** qua `https://frontend.student-app.local` → Accept self-signed certificate.

- `Kết quả`:

<p align="center">
  <img src="assets\path-default.png" alt="path-default.png" width="800"/>
</p>

<p align="center">
  <img src="assets\path-login.png" alt="path-login.png" width="800"/>
</p>

<p align="center">
  <img src="assets\path-signup.png" alt="path-signup.png" width="800"/>
</p>
