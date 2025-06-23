#!/bin/bash

# --- BƯỚC 0: NHẬN CẤU HÌNH TỪ VAGRANTFILE ---
K8S_VERSION=$1
NODE_IP=$2 # <-- NHẬN IP TỪ THAM SỐ THỨ HAI

# Kiểm tra xem các tham số đã được truyền vào chưa
if [ -z "$K8S_VERSION" ] || [ -z "$NODE_IP" ]; then
    echo "Lỗi: K8S_VERSION hoặc NODE_IP chưa được truyền vào từ Vagrantfile."
    exit 1
fi

echo "--- STARTING WORKER NODE SETUP (Version ${K8S_VERSION}, IP ${NODE_IP}) ---"

# --- TASK 1: ĐẢM BẢO TRẠNG THÁI SẠCH SẼ ---
echo "[TASK 1] Resetting any previous kubeadm state"
kubeadm reset -f >/dev/null 2>&1

# --- TASK 2 -> 6: CÀI ĐẶT CÁC THÀNH PHẦN CẦN THIẾT ---
# (Phần này giữ nguyên, không cần thay đổi)
echo "[TASK 2] Disable and turn off SWAP"
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "[TASK 3] Enable and Load Kernel modules for networking"
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "[TASK 4] Add Kernel settings for Kubernetes"
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1

echo "[TASK 5] Install containerd runtime"
apt-get update -qq >/dev/null 2>&1
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release >/dev/null 2>&1
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -qq >/dev/null 2>&1
apt-get install -y containerd.io >/dev/null 2>&1
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd >/dev/null 2>&1

echo "[TASK 6] Install Kubernetes components (version ${K8S_VERSION})"
apt-get install -y apt-transport-https ca-certificates curl gpg >/dev/null 2>&1
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
apt-get update -qq >/dev/null 2>&1
# Cài đúng phiên bản đã được truyền vào
apt-get install -y kubelet=${K8S_VERSION} kubeadm=${K8S_VERSION} kubectl=${K8S_VERSION} >/dev/null 2>&1
apt-mark hold kubelet kubeadm kubectl >/dev/null 2>&1


# --- TASK 7: JOIN CLUSTER (THE CORRECT WAY) ---
echo "[TASK 7] Joining the cluster with a full configuration file"

# Đọc lệnh join gốc từ file
JOIN_COMMAND=$(cat /vagrant/joincluster.sh)

# Trích xuất các thông tin cần thiết từ lệnh join bằng shell
# (Đây là một chút "ma thuật" với các công cụ như awk, sed, tr)
MASTER_HOST_PORT=$(echo "$JOIN_COMMAND" | awk '{print $3}')
TOKEN=$(echo "$JOIN_COMMAND" | awk '{print $5}')
CA_CERT_HASH=$(echo "$JOIN_COMMAND" | awk '{print $7}')

# Tạo file cấu hình kubeadm join hoàn chỉnh
cat > kubeadm-join-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
nodeRegistration:
  name: $(hostname -f)
  kubeletExtraArgs:
    cgroup-driver: systemd
    node-ip: ${NODE_IP}
discovery:
  bootstrapToken:
    apiServerEndpoint: "${MASTER_HOST_PORT}"
    token: "${TOKEN}"
    caCertHashes:
      - "${CA_CERT_HASH}"
  tlsBootstrapToken: "${TOKEN}"
EOF

# Chạy kubeadm join CHỈ với cờ --config
kubeadm join --config kubeadm-join-config.yaml --v=5

echo "--- WORKER NODE SETUP COMPLETE ---"