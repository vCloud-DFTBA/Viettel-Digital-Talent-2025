# Kubernetes Lab – Deploying a 2‑Node Cluster with **Kubespray**

---

## 0. Topology

| Hostname    | Role(s)                                       | vCPU / RAM (min) | OS (tested)       |
| ----------- | --------------------------------------------- | ---------------- | ----------------- |
| **ansible** | Control node: runs Ansible, Docker, Kubespray | 2 vCPU / 4 GiB   | Ubuntu 24.04 LTS+ |
| **master1** | `kube‑control‑plane`, `etcd`                  | 2 vCPU / 4 GiB   | Ubuntu 24.04 LTS+ |
| **worker1** | `kube‑node`                                   | 2 vCPU / 4 GiB   | Ubuntu 24.04 LTS+ |

---

## 1. Chuẩn bị cho node ansible

```bash
# On the ansible host
sudo apt update
sudo apt install -y git curl python3 python3-pip
pip3 install --user ansible-core==2.15  # Kubespray ≥2.28 needs Ansible 2.15+
# Docker is only needed to enter the official Kubespray container
sudo apt install -y docker.io
```

## 2. Setup SSH key trên các node

1. Sử dụng ssh-keygen để tạo cặp khóa public/private key

```bash
ssh-keygen -t rsa
```

output:

<p align="center">
  <img src="assets\step2-1.png" alt="step2-1.png" width="800"/>
</p>

2. Copy key đến các node còn lại

```bash
ssh-copy-id user@server1
```

Thay thế `user@server1` với user và ip thực tế của các node

Output:

<p align="center">
  <img src="assets\step2-2.png" alt="step2-2.png" width="600"/>
</p>

<p align="center">
  <img src="assets\step2-3.png" alt="step2-3.png" width="800"/>
</p>

3. Test SSH

<p align="center">
  <img src="assets\step2-4.png" alt="step2-4.png" width="800"/>
</p>

<p align="center">
  <img src="assets\step2-5.png" alt="step2-5.png" width="800"/>
</p>

## 3. Get Kubespray

```bash
cd ~
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
```

Output:

<p align="center">
  <img src="assets\step3.png" alt="step3.png" width="800"/>
</p>

## 4. Chạy cài đặt Kubespray

```bash
docker run --rm -it \
 --mount type=bind,source="$(pwd)"/inventory/sample,dst=/inventory \
  --mount type=bind,source="$HOME"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
 quay.io/kubespray/kubespray:v2.28.0 bash

# We are now inside the container shell at /kubespray
```

output:

<p align="center">
  <img src="assets\step4.png" alt="step4.png" width="800"/>
</p>

## 5. Sửa inventory file

Edit `/inventory/inventory.ini`

Ví dụ `inventory.ini`:

```ini

[kube_control_plane]
master1 ansible_host=<MASTER_IP> ansible_port=<MASTER_SSH_PORT> ansible_user=<ssh_user>

[etcd:children]
kube_control_plane

[kube_node]
worker1 ansible_host=<WORKER_IP> ansible_port=<WORKER_SSH_PORT> ansible_user=<ssh_user>

[k8s_cluster:children]
kube_control_plane
kube_node

```

Output:

<p align="center">
  <img src="assets\step5.png" alt="step5.png" width="800"/>
</p>

## 6. Chạy Ansible Playbook

```
ansible-playbook -i /inventory/inventory.ini cluster.yml --become --ask-pass --ask-become-pass
```

Nhập mật khẩu SSH nếu có hoặc nhấn enter nếu đã thực hiện bước 2. Sau đó nhập mật khẩu để truy cập `sudo`

Việc triển khai đầy đủ trên hai máy ảo nhỏ thường mất 10–15 phút.
Không có tác vụ nào kết thúc bằng `FAILED`. Nếu có thấy lỗi, hãy chạy lại sau khi khắc phục nguyên nhân

Output:

<p align="center">
  <img src="assets\step6.png" alt="step6.png" width="800"/>
</p>

## 7. Cài đặt Kubectl trên Ansible Node

```bash
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Output:

<p align="center">
  <img src="assets\step7.png" alt="step7.png" width="800"/>
</p>

## 8. Kubeconfig configuration

Trên node `master1`

```bash
sudo cat /etc/kubernetes/admin.conf
```

Sao chép nội dung đó vào máy ansible, dán vào tệp có tên k8s-config.yaml. Sau đó chỉnh sửa dòng:

```bash
server: https://127.0.0.1:6443
```

thành

```bash
server: https://<ip-master1>:6443
```

Output:

<p align="center">
  <img src="assets\step8.png" alt="step8.png" width="800"/>
</p>

## 9. Kết quả

Trên node `ansible`:

```bash
export KUBECONFIG=k8s-config.yaml
```

sau đó

```bash
kubectl get nodes -o wide
```

output:

<p align="center">
  <img src="assets\step9-1.png" alt="step9-1.png" width="800"/>
</p>

và

```bash
kubectl get pods -A -o wide
```

output:

<p align="center">
  <img src="assets\step9-2.png" alt="step9-2.png" width="800"/>
</p>

# Reference

---

1. 🔗 [Kubespray](https://kubespray.io)
2. 📖 [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
3. 📄 Tài liệu cài đặt của mentor Nguyễn Ngọc Dũng
