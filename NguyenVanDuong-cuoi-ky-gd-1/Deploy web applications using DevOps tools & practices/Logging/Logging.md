# Báo cáo quá trình triển khai EFK Stack trên Kubernetes bằng Ansible

## 1. Mục tiêu

- Cài đặt và cấu hình EFK Stack (Elasticsearch, Fluentd, Kibana) trên cụm Kubernetes do Kubespray quản lý.
- Namespace: `logging`
- Chạy cả 3 thành phần trên node `master1`
- Expose Kibana qua NodePort `30020`
- Tự động hóa toàn bộ quá trình bằng Ansible
- Chỉ thu thập log JSON từ Pod backend (student-app-helm) và parse ra các field: `method`, `path`, `status`, `time`

**_Note_**: Ban đầu em cài đặt trên `worker1` thì gặp 2 vấn đề:

- Xung đột Runtime: Containerd và docker
- Máy của em có cấu hình không được khỏe, mà các thành phần trước em cài khá nhiều dịch vụ lên `worker1` rồi nên bị quá tải RAM và CPU, gây crash cả cụm k8s

=> Em quyết định cài trên `master1`

## 2. Kiến trúc thư mục logging

```
root@ansible:~/logging# tree
.
├── files
│   ├── elasticsearch-deployment.yaml
│   ├── es-pvc.yaml
│   ├── es-pv.yaml
│   ├── fluentd-configmap.yaml
│   ├── fluentd-daemonset.yaml
│   └── kibana-deployment.yaml
├── hosts
└── playbook.yaml
```

## 3. Chuẩn bị persistent storage cho Elasticsearch

1. Tạo thư mục lưu data trên master1:

   ```bash
   mkdir -p /mnt/data/esdata
   chown 1000:1000 /mnt/data/esdata   # UID Elasticsearch container
   ```

2. Định nghĩa PersistentVolume (PV) và PersistentVolumeClaim (PVC):

   - **es-pv.yaml**: PV dùng hostPath `/mnt/data/esdata`, `storageClassName: manual`, 5Gi.
   - **es-pvc.yaml**: PVC trong namespace `logging`, request 5Gi.

3. Áp dụng PV/PVC:

   ```bash
   kubectl apply -f es-pv.yaml
   kubectl apply -f es-pvc.yaml -n logging
   ```

## 4. Triển khai Elasticsearch

- **elasticsearch-deployment.yaml**:

```
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: logging
spec:
  ports:
    - port: 9200
      name: http
  selector:
    app: elasticsearch
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elasticsearch
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      nodeSelector:
        kubernetes.io/hostname: master1
      tolerations:
        - key: "node-role.kubernetes.io/master"
          operator: "Exists"
          effect: "NoSchedule"
        - key: "node-role.kubernetes.io/control-plane"
          operator: "Exists"
          effect: "NoSchedule"
      containers:
        - name: elasticsearch
          image: docker.elastic.co/elasticsearch/elasticsearch:7.17.0
          env:
            - name: discovery.type
              value: single-node
            - name: ES_JAVA_OPTS
              value: -Xms512m -Xmx512m
          ports:
            - containerPort: 9200
          volumeMounts:
            - name: data
              mountPath: /usr/share/elasticsearch/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: es-pvc

```

## 5. Triển khai Kibana

- **kibana-deployment.yaml**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: logging
spec:
  type: NodePort
  selector:
    app: kibana
  ports:
    - port: 5601
      targetPort: 5601
      nodePort: 30020
      name: http
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: logging
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
      nodeSelector:
        kubernetes.io/hostname: master1
      tolerations:
        - key: "node-role.kubernetes.io/master"
          operator: "Exists"
          effect: "NoSchedule"
        - key: "node-role.kubernetes.io/control-plane"
          operator: "Exists"
          effect: "NoSchedule"
      containers:
        - name: kibana
          image: docker.elastic.co/kibana/kibana:7.17.0
          env:
            - name: ELASTICSEARCH_HOSTS
              value: http://elasticsearch.logging.svc.cluster.local:9200
          ports:
            - containerPort: 5601
```

## 6. Cấu hình Fluentd

- ConfigMap `fluentd-configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: logging
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/backend-deployment-*_student-app-helm_*.log
      pos_file /fluentd/pos/backend-containers.log.pos
      tag app.backend
      read_from_head true
      refresh_interval 5

      <parse>
        @type multi_format
        <pattern>
          format json
        </pattern>
        <pattern>
          format regexp
          expression /^(?:[^ ]*Z) (?:stdout|stderr) [FP] (?<log>\{.*\})$/
        </pattern>
      </parse>
    </source>

    <filter app.backend>
      @type parser
      key_name log
      reserve_data true
      remove_key_name_field true

      <parse>
        @type json
      </parse>
    </filter>

    <match app.backend>
      @type elasticsearch
      host elasticsearch.logging.svc.cluster.local
      port 9200
      logstash_format    true
      include_tag_key    true
      type_name          _doc
      reload_connections false
    </match>
```

- DaemonSet `fluentd-daemonset.yaml`:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: logging
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      nodeSelector:
        kubernetes.io/hostname: master1
      tolerations:
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule

      containers:
        - name: fluentd
          image: fluent/fluentd-kubernetes-daemonset:v1-debian-elasticsearch
          volumeMounts:
            - name: config
              mountPath: /fluentd/etc/fluent.conf
              subPath: fluent.conf

            - name: varlog
              mountPath: /var/log
              readOnly: true

            - name: fluentd-pos
              mountPath: /fluentd/pos

      volumes:
        - name: config
          configMap:
            name: fluentd-config
        - name: varlog
          hostPath:
            path: /var/log
        - name: fluentd-pos
          emptyDir: {}
```

## 7. Tự động hóa bằng Ansible

- files `hosts`:

```ini
[control]
master1 ansible_host=192.168.93.132 ansible_user=duongnv
```

- Sử dụng playbook `logging.yml` và module `kubernetes.core.k8s`, sequence:

```yaml
---
- name: Deploy EFK Stack
  hosts: control
  gather_facts: false
  collections:
    - kubernetes.core

  vars:
    kubeconfig: /etc/kubernetes/admin.conf
    namespace: logging

  tasks:
    - name: Ensure namespace exists
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        definition:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: "{{ namespace }}"

    - name: Create PersistentVolume for Elasticsearch
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        src: ../files/es-pv.yaml

    - name: Create PersistentVolumeClaim for Elasticsearch
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        src: ../files/es-pvc.yaml
        namespace: "{{ namespace }}"

    - name: Deploy Elasticsearch Service + Deployment
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        src: ../files/elasticsearch-deployment.yaml
        namespace: "{{ namespace }}"

    - name: Deploy Kibana Service + Deployment
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        src: ../files/kibana-deployment.yaml
        namespace: "{{ namespace }}"

    - name: Create ConfigMap for Fluentd
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        src: ../files/fluentd-configmap.yaml
        namespace: "{{ namespace }}"

    - name: Deploy Fluentd DaemonSet
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig }}"
        state: present
        src: ../files/fluentd-daemonset.yaml
        namespace: "{{ namespace }}"

    - name: Wait for Elasticsearch to be Ready
      kubernetes.core.k8s_info:
        kubeconfig: "{{ kubeconfig }}"
        kind: Pod
        namespace: "{{ namespace }}"
        label_selectors:
          - "app=elasticsearch"
      register: es_pods

    - name: Wait for Elasticsearch pod status=Running
      wait_for:
        host: 127.0.0.1
        port: 9200
        delay: 5
        timeout: 120

    - name: Pause 20s to let pods spin up
      pause:
        seconds: 20

    - name: Check all pods are Running
      kubernetes.core.k8s_info:
        kubeconfig: "{{ kubeconfig }}"
        kind: Pod
        namespace: "{{ namespace }}"
      register: all_pods

    - name: Fail if any pod is not Running
      fail:
        msg: "Not all pods are Running yet: {{ all_pods.resources|map(attribute='status.phase')|list }}"
      when: "'Running' not in all_pods.resources|map(attribute='status.phase')|list"
```

- Trạng thái các pods EFK:

<p align="center">
  <img src="assets\pods-status.png" alt="pods-status.png" width="800"/>
</p>

## 8. Test

1. Sinh traffic cho backend:

   ```bash
   curl -X POST http://<NODE_IP>:<NODEPORT>/login -d '{"username":"duongnv","password":"duongnv"}'
   curl http://<NODE_IP>:<NODEPORT>/students -H "Authorization: Bearer $TOKEN"
   ```

2. Kiểm tra index:

   ```bash
   kubectl port-forward svc/elasticsearch 9200:9200 -n logging
   curl localhost:9200/_cat/indices?v
   ```

<p align="center">
  <img src="assets\test-index.png" alt="test-index.png" width="800"/>
</p>

3. Tạo **Index Pattern** `logstash-*` (Time field = @timestamp) trong Kibana → Stack Management.

<p align="center">
  <img src="assets\create-index-pattern.png" alt="create-index-pattern.png" width="800"/>
</p>

4. Vào **Discover** để xem log với các field: `method`, `path`, `status`, `time`.

---

### Kết quả

- Kibana truy cập qua `http://<NodeIP>:30020` hiển thị dashboard Discover.
- Log backend đã được parse thành JSON, filter theo `path.keyword`, `status` dễ dàng.

<p align="center">
  <img src="assets\discover-kibana.png" alt="discover-kibana.png" width="800"/>
</p>
