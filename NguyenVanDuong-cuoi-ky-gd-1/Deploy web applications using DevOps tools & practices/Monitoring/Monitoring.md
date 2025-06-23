# Triển khai Prometheus giám sát metrics ứng dụng bằng Ansible & Kubernetes

## 1. Yêu cầu & Mục tiêu

- Expose metric của app ra 1 HTTP path (ví dụ `/metrics`).
- Sử dụng **Ansible Playbook** để triển khai Prometheus server **dưới dạng Pod trong Kubernetes**.
- Cấu hình Prometheus scrape các metric của ứng dụng vừa expose.
- Output gồm:
  - Các file setup để triển khai Prometheus.
  - Hình ảnh giao diện Prometheus khi truy cập qua trình duyệt.
  - Hình ảnh danh sách target App được Prometheus giám sát.

---

## 2. Expose metrics trên App

- Cài đặt các gói cần thiết

```bash
npm install prom-client express-prom-bundle
```

- Thêm code sau vào file be.js trong repo Source code

```js
// --- PROMETHEUS METRICS ---
const client = require("prom-client");
const promBundle = require("express-prom-bundle");

// 2.1. Default resource metrics (memory, cpu, eventloop...)
client.collectDefaultMetrics();

// 2.2. HTTP request metrics tự động cho Express
const metricsMiddleware = promBundle({
  includeMethod: true,
  includePath: true,
  includeStatusCode: true,
  promClient: { collectDefaultMetrics: false },
});
app.use(metricsMiddleware);

// 2.3. Custom DB query metrics
const dbQueryCounter = new client.Counter({
  name: "db_query_total",
  help: "Số lần query tới database",
  labelNames: ["operation", "table"],
});

// 2.4. Custom business metric: đăng ký user
const userRegisterCounter = new client.Counter({
  name: "user_register_total",
  help: "Số user đã đăng ký thành công",
});

// 2.5. Custom business metric: student created
const studentCreatedCounter = new client.Counter({
  name: "student_created_total",
  help: "Số student đã tạo thành công",
});
```

- Chèn các custom metric vào code (Đếm số lần query Database (CRUD):)

  - Trong endpoint **/signup**

  ```js
  // Đếm query vào bảng user khi đăng ký
  await pool.query("INSERT INTO user (username, password) VALUES (?, ?)", [
    username,
    hashed,
  ]);
  dbQueryCounter.inc({ operation: "insert", table: "user" });
  userRegisterCounter.inc(); // đếm số user đăng ký thành công
  ```

  - Trong endpoint **get students**

  ```js
  const [rows] = await pool.query("SELECT id, name, dob, school FROM student");
  dbQueryCounter.inc({ operation: "select", table: "student" });
  ```

  - Trong endpoint **create students**

  ```js
  const [result] = await pool.query(
    "INSERT INTO student (name, dob, school) VALUES (?, ?, ?)",
    [name, dob, school]
  );
  dbQueryCounter.inc({ operation: "insert", table: "student" });
  studentCreatedCounter.inc();
  ```

  - Trong endpoint **delete students**

  ```js
  const [result] = await pool.query("DELETE FROM student WHERE id = ?", [id]);
  dbQueryCounter.inc({ operation: "delete", table: "student" });
  ```

- Thêm counter cho các endpoint khác, ví dụ đếm số lần đăng nhập lỗi:

```js
const loginFailCounter = new client.Counter({
  name: "login_failed_total",
  help: "Số lần đăng nhập thất bại",
});
```

Và trong login:

```js
if (!match) {
  loginFailCounter.inc();
  return res.status(401).json({ message: "Invalid credentials" });
}
```

- Thêm endpoint expose metrics cho Prometheus (ở cuối file, trước app.listen)

```js
app.get("/metrics", async (req, res) => {
  res.set("Content-Type", client.register.contentType);
  res.end(await client.register.metrics());
});
```

## 3. Build lại Image

- Commit code đã thay đổi lên repo Source Code (https://github.com/duongnv3010/VDT-App)
- Add một tag mới và push.
- Pipeline CI/CD sẽ thực hiện các việc còn lại

## 4. Kiểm tra endpoint metrics

- Truy cập: 192.168.93.137:30011/metrics

<p align="center">
  <img src="assets\endpoint-metrics.png" alt="endpoint-metrics.png" width="800"/>
</p>

## 5. Triển khai Prometheus lên K8s bằng Ansible

- Cấu trúc thư mục monitoring:

```bash
monitoring/
├── prometheus-configmap.yaml
├── prometheus-deployment.yaml
├── prometheus-service.yaml
└── prometheus-k8s-playbook.yaml

```

- file prometheus-configmap.yaml

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
      - job_name: 'student-backend'
        metrics_path: /metrics
        static_configs:
          - targets: ['192.168.93.137:30011']
```

- file prometheus-deployment.yaml

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
          image: prom/prometheus:v2.52.0
          args:
            - "--config.file=/etc/prometheus/prometheus.yml"
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus/
      volumes:
        - name: config
          configMap:
            name: prometheus-config
```

- file prometheus-service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: NodePort
  ports:
    - port: 9090
      targetPort: 9090
      nodePort: 30900
  selector:
    app: prometheus
```

- file prometheus-k8s-playbook.yaml

```yaml
- name: Deploy Prometheus to Kubernetes cluster
  hosts: localhost
  connection: local
  gather_facts: no

  tasks:
    - name: Ensure namespace monitoring exists
      kubernetes.core.k8s:
        api_version: v1
        kind: Namespace
        name: monitoring
        state: present

    - name: Apply Prometheus configmap
      kubernetes.core.k8s:
        state: present
        src: prometheus-configmap.yaml

    - name: Apply Prometheus deployment
      kubernetes.core.k8s:
        state: present
        src: prometheus-deployment.yaml

    - name: Apply Prometheus service
      kubernetes.core.k8s:
        state: present
        src: prometheus-service.yaml
```

- Cài thêm một số gói cần thiết:

```bash
sudo apt update
sudo apt install python3-kubernetes python3-openshift -y
```

- Chạy lại playbook

```bash
ansible-playbook prometheus-k8s-playbook.yaml
```

- Hỉnh ảnh prometheus trên browser:

<p align="center">
  <img src="assets\prometheus-ui.png" alt="prometheus-ui.png" width="800"/>
</p>

- Hình ảnh danh sách target trên UI

<p align="center">
  <img src="assets\target-ui.png" alt="target-ui.png" width="800"/>
</p>
