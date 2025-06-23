# Monitoring
## Yêu cầu
    Expose metric của app ra 1 http path
    Sử dụng ansible playbooks để triển khai container Prometheus server. Sau đó cấu hình prometheus add target giám sát các metrics đã expose ở trên.
## Output
Để expose metric của app ra endpoint, em sử dụng thư viện `prometheus_fastapi_instrumentator`, sau khi cài đặt sẽ tự động expose ra endpoint `\metrics`

```python
from prometheus_fastapi_instrumentator import Instrumentator
###
Instrumentator().instrument(app).expose(app)
```

    # HELP python_gc_objects_collected_total Objects collected during gc
    # TYPE python_gc_objects_collected_total counter
    python_gc_objects_collected_total{generation="0"} 391.0
    python_gc_objects_collected_total{generation="1"} 435.0
    python_gc_objects_collected_total{generation="2"} 5.0
    # HELP python_gc_objects_uncollectable_total Uncollectable objects found during GC
    # TYPE python_gc_objects_uncollectable_total counter
    python_gc_objects_uncollectable_total{generation="0"} 0.0
    python_gc_objects_uncollectable_total{generation="1"} 0.0
    python_gc_objects_uncollectable_total{generation="2"} 0.0
    # HELP python_gc_collections_total Number of times this generation was collected
    # TYPE python_gc_collections_total counter
    python_gc_collections_total{generation="0"} 222.0
    python_gc_collections_total{generation="1"} 20.0
    python_gc_collections_total{generation="2"} 1.0
    # HELP python_info Python platform information
    # TYPE python_info gauge
    python_info{implementation="CPython",major="3",minor="11",patchlevel="13",version="3.11.13"} 1.0


Em sử dụng `ansible role` để dễ dàng setup Prometheus

![](./images/Screenshot%20From%202025-06-23%2015-35-13.png)

### File playbook
```yaml
- name: Deploy Prometheus to Kubernetes
  hosts: all    
  roles:
    - prometheus
```
### Prometheus Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:latest
          args:
            - "--config.file=/etc/prometheus/prometheus.yml"
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus/
              readOnly: true
      volumes:
        - name: config
          configMap:
            name: prometheus-config
```

### Prometheus Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  selector:
    app: prometheus
  ports:
    - protocol: TCP
      port: 9090
      targetPort: 9090
      nodePort: 30169
  type: NodePort
```

### Config Prometheus
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      - job_name: 'bluemoon-be'
        static_configs:
          - targets: ['be-service.ktpm.svc.cluster.local:8000']
      - job_name: 'auth-service'
        static_configs:
          - targets: ['auth-service.ktpm.svc.cluster.local:3000']
```

- `localhost:9090`: Prometheus server.

- `be-service.ktpm.svc.cluster.local:8000`: ứng dụng backend trong namespace ktpm.

- `auth-service.ktpm.svc.cluster.local:3000`: ứng dụng auth-service.


### Hình ảnh danh sách target của App được giám sát bởi Prometheus
![](./images/Screenshot%20From%202025-06-22%2014-41-35.png)