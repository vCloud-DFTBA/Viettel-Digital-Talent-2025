# Triển khai web application sử dụng các DevOps tools & practices
## Yêu cầu 1
    Cài đặt ArgoCD lên Kubernetes Cluster, expose được ArgoCD qua NodePort
    Cài đặt Jenkins lên Kubernetes Cluster, expose được Jenkins qua NodePort
## Output 1
Để cài đặt ArgoCD, Jenkins một cách nhanh chóng và tiện lợi, em sử dụng Helm.
File cấu hình ArgoCD và Jenkins như sau
```yaml
#ArgoCD
server:
  service:
    type: NodePort
    nodePort: 30080
    servicePortHttp: 80
    servicePortHttps: 443  
configs:
  params:
    server.insecure: true
#Jenkins
controller:
  serviceType: NodePort
  servicePort: 8080
  nodePort: 30069  
```

```sh
kubectl create ns cicd
kubens cicd

helm repo add argo https://argoproj.github.io/argo-helm
helm install argo-cd argo/argo-cd --version 8.1.1 -f argo-values.yaml

helm repo add jenkinsci https://charts.jenkins.io/
helm install my-jenkins jenkinsci/jenkins --version 5.8.59 -f jenkins-values.yaml
```
Kết quả
![](./images/Screenshot%20From%202025-06-18%2019-02-16.png)
Truy cập vào ArgoCD qua Browser
![ArgoCD](./Screenshot%20From%202025-06-18%2018-39-53.png)
Truy cập vào Jenkins qua Browser
![Jenkins](./Screenshot%20From%202025-06-18%2019-06-13.png)

## Yêu cầu 2
    • Viết hoặc tìm mẫu Helm Chart cho app bất kỳ, để vào 1 folder riêng trong repo app
    • Tạo Repo Config cho app trên, trong repo này chứa các file values.yaml với nội dung của cá file values.yaml là các config cần thiết để chạy ứng dụng trên k8s bằng Helm Chart 
## Output 2
### Tổng quan về Microservices
Các service sử dụng bao gồm : `fe-service` `be-service` `auth-service` `db-service`

Trước tiên, cần phải tạo Docker Image cho từng service.
```dockerfile
#be-service
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY ./app ./app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "info"]
```

```dockerfile
#fe-service
FROM node:22-alpine AS build

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
                   
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

```dockerfile
#auth-service
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY ./app ./app

EXPOSE 3000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "3000"]
```

Sau khi build thành công image cho từng service, viết mẫu Helm chart như sau:

```yaml
fe:
  image: ndbaolam/bluemoon-fe:latest
  replicaCount: 1
  service:
    type: NodePort
    port: 80
    nodePort: 30007
  env:
    VITE_API_URL: http://be-service:8000


be:
  image: ndbaolam/bluemoon-be:f7ce5b3
  replicaCount: 1
  service:
    type: NodePort
    port: 8000
    nodePort: 30006
  env:    
    DATABASE_URL: "postgresql://ktpm:ktpm@db-service:5432/ktpm"
    SECRET_KEY: secret-key
    ALGORITHM: HS256
    ACCESS_TOKEN_EXPIRE_MINUTES: "60"

auth:
  image: ndbaolam/basic-auth:latest
  replicaCount: 1
  service:
    type: ClusterIP
    port: 3000
    nodePort: 30002
  configMap: auth-configmap

db:
  image: postgres:16-alpine
  replicaCount: 1
  service:
    type: ClusterIP
    port: 5432
  persistence:
    enabled: true
    storageClass: standard
    size: 3Gi
  env:
    POSTGRES_USER: ktpm
    POSTGRES_PASSWORD: ktpm
    POSTGRES_DB: ktpm
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-deployment
  namespace: ktpm
spec:
  replicas: {{ .Values.auth.replicaCount }}
  selector:
    matchLabels:
      app: auth
  template:
    metadata:
      labels:
        app: auth
    spec:
      containers:
      - name: auth-container
        image: {{ .Values.auth.image }}
        env:
        - name: AUTH_ADMIN
          valueFrom: 
            configMapKeyRef: 
              name: {{ .Values.auth.configMap }}
              key: AUTH_ADMIN
        - name: AUTH_USER
          valueFrom: 
            configMapKeyRef: 
              name: {{ .Values.auth.configMap }}
              key: AUTH_USER
        ports:
        - containerPort: {{ .Values.auth.service.port }}
---
apiVersion: v1
kind: Service
metadata:
  name: auth-service
  namespace: ktpm
spec:
  selector:
    app: auth
  ports:
  - port: {{ .Values.auth.service.port }}
    targetPort: {{ .Values.auth.service.port }}
  type: {{ .Values.auth.service.type }}
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: be-deployment
  namespace: ktpm
spec:
  replicas: {{ .Values.be.replicaCount }}
  selector:
    matchLabels:
      app: be
  template:
    metadata:
      labels:
        app: be
    spec:
      containers:
      - name: be-container
        image: {{ .Values.be.image }}
        env:
          - name: POSTGRES_USER
            value: {{ .Values.db.env.POSTGRES_USER }}
          - name: POSTGRES_PASSWORD
            value: {{ .Values.db.env.POSTGRES_PASSWORD }}
          - name: POSTGRES_DB
            value: {{ .Values.db.env.POSTGRES_DB }}
          - name: DATABASE_URL
            value: {{ .Values.be.env.DATABASE_URL }}
          - name: SECRET_KEY
            value: {{ .Values.be.env.SECRET_KEY }}
          - name: ALGORITHM
            value: {{ .Values.be.env.ALGORITHM }}
          - name: ACCESS_TOKEN_EXPIRE_MINUTES
            value: {{ .Values.be.env.ACCESS_TOKEN_EXPIRE_MINUTES }}
        ports:
        - containerPort: {{ .Values.be.service.port }}
---
apiVersion: v1
kind: Service
metadata:
  name: be-service
  namespace: ktpm
spec:
  selector:
    app: be
  ports:
  - port: {{ .Values.be.service.port }}
    targetPort: {{ .Values.be.service.port }}
    nodePort: {{ .Values.be.service.nodePort }}
  type: {{ .Values.be.service.type }}
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fe-deployment
  namespace: ktpm
spec:
  replicas: {{ .Values.fe.replicaCount }}
  selector:
    matchLabels:
      app: fe
  template:
    metadata:
      labels:
        app: fe
    spec:
      containers:
      - name: fe-container
        image: {{ .Values.fe.image }}
        env:
        - name: VITE_API_URL
          value: {{ .Values.fe.env.VITE_API_URL }}
        ports:
        - containerPort: {{ .Values.fe.service.port }}
---
apiVersion: v1
kind: Service
metadata:
  name: fe-service
  namespace: ktpm
spec:
  type: {{ .Values.fe.service.type }}
  selector:
    app: fe
  ports:
    - port: {{ .Values.fe.service.port }}
      targetPort: {{ .Values.fe.service.port }}
      nodePort: {{ .Values.fe.service.nodePort }}
```

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db-statefulset
  namespace: ktpm
spec:
  serviceName: db-service
  replicas: {{ .Values.db.replicaCount }}
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
        - name: db-container
          image: {{ .Values.db.image }}
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_USER
              value: {{ .Values.db.env.POSTGRES_USER }}
            - name: POSTGRES_PASSWORD
              value: {{ .Values.db.env.POSTGRES_PASSWORD }}
            - name: POSTGRES_DB
              value: {{ .Values.db.env.POSTGRES_DB }}
          volumeMounts:
            - name: db-storage
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: db-storage
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: {{ .Values.db.persistence.storageClass }}
        resources:
          requests:
            storage: {{ .Values.db.persistence.size }}
---
apiVersion: v1
kind: Service
metadata:
  name: db-service
  namespace: ktpm
spec:
  clusterIP: None
  selector:
    app: db
  ports:
    - port: {{ .Values.db.service.port }}
      targetPort: {{ .Values.db.service.port }}
```
Install release
```helm
helm install my-app app-chart/
```
Sau khi install thành công, truy cập vào ArgoCD để tạo application
![](./images/Screenshot%20From%202025-06-18%2021-28-00.png)
![](./images/Screenshot%20From%202025-06-20%2010-51-35.png)
Truy cập thông qua browser
![](./images/Screenshot%20From%202025-06-15%2019-39-55.png)
![](./images/Screenshot%20From%202025-06-18%2021-03-28.png)
