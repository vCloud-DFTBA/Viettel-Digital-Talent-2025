# Yêu cầu
    • Dựng HAProxy Loadbalancer trên 1 VM riêng (trong trường hợp cụm lab riêng của sinh viên) với mode TCP, mở port trên LB trỏ đến NodePort của App trên K8S Cluster. (0.5)
    • Sử dụng giải pháp Ingress cho các deployment, đảm bảo các truy cập đến các port App sử dụng https (0.5)
    • Cho phép sinh viên sử dụng self-signed cert để làm bài
# Output
## Sử dụng giải pháp Ingress cho các deployment, đảm bảo các truy cập đến các port App sử dụng https

Ingress là một object trong Kubernetes:
- Định nghĩa quy tắc điều hướng (routing) HTTP/HTTPS
- Cho phép nhiều domain/subdomain chia sẻ một địa chỉ IP công cộng
- Kết nối các URL đến các dịch vụ trong cluster

Ingress Controller là phần mềm đứng phía trước (proxy) thực thi các quy tắc định nghĩa trong Ingress, chịu trách nhiệm nhận request từ ngoài vào và định tuyến theo Ingress rules.

Ở đây, em sử dụng `NGINX Ingress Controller`

### Cài đặt Nginx-Ingress
```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm install my-ingress-nginx ingress-nginx/ingress-nginx --version 4.12.3 -n ingress-nginx --create-namespace

kubectl patch svc ingress-nginx-controller -n ingress-nginx \
  -p '{"spec": {"externalIPs":["<NODE_IP>"]}}'
```

### Tạo self-signed cert
Tạo chứng chỉ TLS self-signed có chứa SAN (Subject Alternative Names) bằng file cấu hình san.cnf
```sh
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -config san.cnf -extensions req_ext
```

Trong đó:
| |                                                                                                |
| --------------------- | ---------------------------------------------------------------------------------------------------------- |
| `openssl req`         | Tạo một certificate request (CSR) hoặc certificate.                                                        |
| `-x509`               | Tạo chứng chỉ **self-signed** (không cần CA).                                                              |
| `-nodes`              | Không mã hóa private key (tức không cần mật khẩu khi sử dụng key).                                         |
| `-days 365`           | Chứng chỉ có hiệu lực trong 365 ngày.                                                                      |
| `-newkey rsa:2048`    | Tạo cặp key mới (public/private) với thuật toán RSA, độ dài 2048 bit.                                      |
| `-keyout tls.key`     | Ghi private key ra file `tls.key`.                                                                         |
| `-out tls.crt`        | Ghi certificate (chứng chỉ) ra file `tls.crt`.                                                             |
| `-config san.cnf`     | Sử dụng file cấu hình `san.cnf` để chỉ định thông tin certificate.                                         |
| `-extensions req_ext` | Kích hoạt extension có tên `req_ext` được định nghĩa trong `san.cnf`, chứa phần cấu hình `subjectAltName`. |

Với file `san.cnf` có nội dung như sau
```yaml
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = VN
ST = Hanoi
L = Hanoi
O = ktpm
CN = minikube.app1

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = minikube.app1
DNS.2 = minikube.app2
```

### Tạo Ingress Rule 

#### Rule cho Frontend
``` yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fe-ingress
  namespace: ktpm
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    meta.helm.sh/release-name: my-app
    meta.helm.sh/release-namespace: ktpm
spec:
  ingressClassName: {{ .Values.ingress.className | quote }}
  tls:
    - hosts:
        - {{ .Values.ingress.feHost }}
      secretName: {{ .Values.ingress.tlsSecret }}
  rules:
    - host: {{ .Values.ingress.feHost }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fe-service
                port:
                  number: {{ .Values.fe.service.port }}
```
#### Rule cho Backend
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: be-ingress
  namespace: ktpm
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /        
    meta.helm.sh/release-name: my-app
    meta.helm.sh/release-namespace: ktpm
spec:
  ingressClassName: {{ .Values.ingress.className | quote }}
  tls:
    - hosts:
        - {{ .Values.ingress.beHost }}
      secretName: {{ .Values.ingress.tlsSecret }}
  rules:
    - host: {{ .Values.ingress.beHost }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: be-service
                port:
                  number: {{ .Values.be.service.port }}
```
#### Tạo secret
Gắn nhãn và chú thích (annotations) để Helm có thể quản lý Secret này.
Cho biết Secret này được Helm quản lý, thuộc release my-app.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Values.ingress.tlsSecret }}
  namespace: ktpm
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: my-app
    meta.helm.sh/release-namespace: ktpm
type: kubernetes.io/tls    
data:
  tls.crt: 'base64 -w 0 tls.crt'
  tls.key: 'base64 -w 0 tls.key'
```

Với `values.yaml` như sau:
```yaml
ingress:
  enabled: true
  className: nginx
  feHost: minikube.app1
  beHost: minikube.app2
  tlsSecret: app-tls
  authSecret: basic-auth
```

### Output
#### Truy cập https thông qua `curl`
![](../images/Screenshot%20From%202025-06-20%2003-09-50.png)