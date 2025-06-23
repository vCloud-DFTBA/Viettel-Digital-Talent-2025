#!/bin/bash

# --- BƯỚC 0: NHẬN CẤU HÌNH VÀ DỌN DẸP ---
K8S_VERSION=$1
MASTER_IP=$2

if [ -z "$K8S_VERSION" ] || [ -z "$MASTER_IP" ]; then
    echo "Lỗi: K8S_VERSION hoặc MASTER_IP chưa được truyền vào từ Vagrantfile."
    exit 1
fi

echo "--- STARTING MASTER NODE SETUP (Version ${K8S_VERSION}, IP ${MASTER_IP}) ---"

echo "[TASK 1] Resetting any previous kubeadm state"
kubeadm reset -f >/dev/null 2>&1


# --- BƯỚC 1: CÀI ĐẶT CÁC THÀNH PHẦN CẦN THIẾT ---

echo "[TASK 2] General system setup"
# Tắt swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
# Tắt firewall
systemctl disable --now ufw >/dev/null 2>&1
# Cập nhật /etc/hosts
cat >>/etc/hosts<<EOF
${MASTER_IP}   k8s-master
EOF

echo "[TASK 3] Configure kernel modules and sysctl for Kubernetes"
# Kích hoạt các module kernel cần thiết
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
# Cấu hình sysctl cho networking
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1

echo "[TASK 4] Install containerd runtime"
apt-get update -qq >/dev/null 2>&1
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release >/dev/null 2>&1
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -qq >/dev/null 2>&1
apt-get install -y containerd.io >/dev/null 2>&1
# Cấu hình containerd để sử dụng systemd cgroup driver
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd >/dev/null 2>&1

echo "[TASK 5] Install Kubernetes components (version ${K8S_VERSION})"
apt-get install -y apt-transport-https ca-certificates curl gpg >/dev/null 2>&1
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
apt-get update -qq >/dev/null 2>&1
apt-get install -y kubelet=${K8S_VERSION} kubeadm=${K8S_VERSION} kubectl=${K8S_VERSION} >/dev/null 2>&1
apt-mark hold kubelet kubeadm kubectl >/dev/null 2>&1

# --- BƯỚC 2: KHỞI TẠO CỤM KUBERNETES ---

echo "[TASK 6] Initialize Kubernetes Cluster using kubeadm"
# Lấy phiên bản chính (ví dụ: 1.28.2) từ phiên bản đầy đủ (1.28.2-1.1)
K8S_MAJOR_VERSION=$(echo "${K8S_VERSION}" | cut -d- -f1)
# Tạo file cấu hình cho kubeadm
cat > kubeadm-config.yaml <<EOF
    apiVersion: kubeadm.k8s.io/v1beta3
    kind: InitConfiguration
    localAPIEndpoint:
    advertiseAddress: ${MASTER_IP}
    bindPort: 6443
    nodeRegistration:
    criSocket: "unix:///var/run/containerd/containerd.sock"
    ---
    apiVersion: kubeadm.k8s.io/v1beta3
    kind: ClusterConfiguration
    kubernetesVersion: v${K8S_MAJOR_VERSION}
    networking:
    podSubnet: "192.168.0.0/16"
    ---
    apiVersion: kubelet.config.k8s.io/v1beta1
    kind: KubeletConfiguration
    cgroupDriver: systemd
EOF
# Chạy kubeadm init với file cấu hình
kubeadm init --config kubeadm-config.yaml

echo "[TASK 7] Copy kube config for 'vagrant' user"
mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

# --- BƯỚC 3: CÀI ĐẶT MẠNG CHO CỤM (CNI) ---

echo "[TASK 8] Deploy Calico network"
# Tải file manifest của Calico về
su - vagrant -c "curl https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml -O"
# Sửa file manifest để Calico sử dụng đúng card mạng 'enp0s8'
su - vagrant -c "sed -i -e 's?# - name: IP_AUTODETECTION_METHOD?- name: IP_AUTODETECTION_METHOD?g' calico.yaml"
su - vagrant -c "sed -i -e 's?#   value: \"first-found\"?  value: \"interface=enp0s8\"?g' calico.yaml"
# Áp dụng file manifest đã được sửa
su - vagrant -c "kubectl apply -f calico.yaml"

# --- BƯỚC 4: CHUẨN BỊ CHO WORKER NODE ---

echo "[TASK 9] Waiting for Calico to be ready before generating join command..."
# Chờ 60 giây để các pod của Calico trên master có thời gian khởi động
sleep 10

echo "[TASK 10] Generate and save cluster join command"
kubeadm token create --print-join-command > /joincluster.sh
chmod +x /joincluster.sh

echo"[TASK 11] Install helm"
set -e
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "--- MASTER NODE SETUP COMPLETE ---"