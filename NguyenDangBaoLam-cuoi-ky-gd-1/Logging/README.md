# Logging
    • Sử dụng ansible playbooks để triển khai stack EFK (elasticsearch, fluentd, kibana), sau đó cấu hình logging cho web service và api service, đảm bảo khi có http request gửi vào web service hoặc api service thì trong các log mà các service này sinh ra, có ít nhất 1 log có các thông tin:
        ◦ Request Path(VD: /api1/1, /api2/3 ..)
        ◦ HTTP Method VD: (GET PUT POST…)
        ◦ Response Code: 302, 200, 202, 201…

## Output
Để có thể log ra theo đúng yêu cầu, ta cần phải format lại log của các service

```python
@app.middleware("http")
async def log_requests(request: Request, call_next):
    response = await call_next(request)
    log_data = {
        "request_path": request.url.path,
        "http_method": request.method,
        "response_code": response.status_code,
    }
    logger.info(json.dumps(log_data))
    return response
```

## Tổng quan về EFK
EFK là một hệ thống logging bao gồm 3 thành phần chính:
| Thành phần        | Mô tả                                                                              |
| ----------------- | ---------------------------------------------------------------------------------- |
| **Elasticsearch** | Nơi **lưu trữ** và **tìm kiếm** log — là một công cụ tìm kiếm mạnh mẽ, dạng NoSQL. |
| **Fluentd**       | **Agent thu thập log** từ ứng dụng, file, container và gửi đến Elasticsearch.      |
| **Kibana**        | **Giao diện trực quan** để truy vấn và hiển thị log từ Elasticsearch.              |

## Elastícearch
Elasticsearch là một cơ sở dữ liệu tìm kiếm phân tán, được thiết kế để lưu trữ và truy vấn các tập dữ liệu lớn theo thời gian thực. Đây là thành phần trung tâm của EFK stack, chịu trách nhiệm lưu trữ, phân tích và tìm kiếm log.

Ta cần tạo DNS Headless `elasticsearch.kube-logging.svc.cluster.local` (K8S service không được gán IP), cần thiết khi dùng StatefulSet để các pod có thể truy cập lẫn nhau qua DNS riêng
`es-cluster-0.elasticsearch.kube-logging.svc.cluster.local`

Elasticsearch yêu cầu Persistent Volume để lưu trữ dữ liệu log.

```yaml
kind: Service
apiVersion: v1
metadata:
  name: elasticsearch
  namespace: kube-logging
  labels:
    app: elasticsearch
spec:
  selector:
    app: elasticsearch
  clusterIP: None
  ports:
    - port: 9200
      name: rest
    - port: 9300
      name: inter-node
```

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-cluster
  namespace: kube-logging
spec:
  serviceName: elasticsearch
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:7.2.0
        resources:
            limits:
              cpu: 1000m
            requests:
              cpu: 100m
        ports:
        - containerPort: 9200
          name: rest
          protocol: TCP
        - containerPort: 9300
          name: inter-node
          protocol: TCP
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
        env:
          - name: cluster.name
            value: k8s-logs
          - name: node.name
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: discovery.type
            value: single-node
          - name: ES_JAVA_OPTS
            value: "-Xms512m -Xmx512m"
      initContainers:
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
      - name: increase-vm-max-map
        image: busybox
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
      - name: increase-fd-ulimit
        image: busybox
        command: ["sh", "-c", "ulimit -n 65536"]
        securityContext:
          privileged: true
  volumeClaimTemplates:
  - metadata:
      name: data
      labels:
        app: elasticsearch
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: standard
      resources:
        requests:
          storage: 5Gi
```
### Kibana
Kibana cho phép:
- Truy vấn dữ liệu log
- Tạo biểu đồ trực quan
- Phân tích log theo thời gian thực

```yaml
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: kube-logging
  labels:
    app: kibana
spec:
  type: NodePort
  ports:
  - port: 5601  
    nodePort: 30111
  selector:
    app: kibana
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: kube-logging
  labels:
    app: kibana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana:7.2.0
        resources:
          limits:
            cpu: 1000m
          requests:
            cpu: 100m
        env:
          - name: ELASTICSEARCH_URL
            value: http://elasticsearch:9200
        ports:
        - containerPort: 5601
```

### Fluentd
Fluentd là thành phần quan trọng trong stack EFK, chịu trách nhiệm thu thập log từ các Pod đang chạy trong cluster Kubernetes và gửi đến Elasticsearch để lưu trữ và truy vấn.

Ta sẽ triển khai Fluentd như một `DaemonSet`, nghĩa là mỗi Node trong cluster sẽ chạy một Pod Fluentd riêng biệt. Đảm bảo Fluentd có thể thu thập log từ tất cả các container trên Node đó.

Fluentd sẽ:
- Đọc log từ các file log do container tạo ra (thường nằm trong /var/log/containers)
- Phân tích định dạng log
- Gửi log đến Elasticsearch qua giao thức HTTP (cổng 9200)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: kube-logging
  labels:
    app: fluentd
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluentd
  labels:
    app: fluentd
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - namespaces
  verbs:
  - get
  - list
  - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: fluentd
roleRef:
  kind: ClusterRole
  name: fluentd
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: fluentd
  namespace: kube-logging
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-logging
  labels:
    app: fluentd
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      serviceAccount: fluentd
      serviceAccountName: fluentd
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1.4.2-debian-elasticsearch-1.1
        env:
          - name:  FLUENT_ELASTICSEARCH_HOST
            value: "elasticsearch.kube-logging.svc.cluster.local"
          - name:  FLUENT_ELASTICSEARCH_PORT
            value: "9200"
          - name: FLUENT_ELASTICSEARCH_SCHEME
            value: "http"
          - name: FLUENTD_SYSTEMD_CONF
            value: disable
        resources:
          limits:
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

### Output
![](./images/Screenshot%20From%202025-06-23%2003-10-13.png)
![](./images/Screenshot%20From%202025-06-23%2003-18-39.png)