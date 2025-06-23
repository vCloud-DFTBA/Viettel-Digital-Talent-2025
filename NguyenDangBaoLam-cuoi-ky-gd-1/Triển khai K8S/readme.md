# Triển khai K8S
## Triển khai K8S sử dụng `kubeadm`.
Trước tiên, ở Master Node (Control Plane) cài đặt `kubeadm`, `kubelet`, `kubectl`, `containerd`
```sh
# Tắt swap
sudo swapoff -a
sudo sed -i '/swap.img/s/^/#/' /etc/fstab

#Cài đặt các gói cần thiết
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
  [kubernetes]
  name=Kubernetes
  baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
  enabled=1
  gpgcheck=1
  gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF
sudo dnf install -y kubelet kubeadm kubectl containerd.io
sudo systemctl enable --now kubelet

#Cấu hình quyền truy cập cho k8s master node
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#Khởi tạo 
sudo kubeadm init
```

Ngoài ra, em cài đặt `kubens`, cli giúp việc quản lý namespace trong k8s được dễ dàng hơn
```sh
sudo dnf install -y git go
git clone https://github.com/ahmetb/kubectx.git
cd kubectx
sudo cp kubens /usr/local/bin/
#Để switch qua các namespace
kubens <namespace>
```

SSH vào VM, VM đóng vai trò là worker node do vậy cần cài đặt `kubeadm`, `kubelet`, `containerd`.
```sh
sudo swapoff -a
sudo sed -i '/swap.img/s/^/#/' /etc/fstab

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
  [kubernetes]
  name=Kubernetes
  baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
  enabled=1
  gpgcheck=1
  gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

sudo apt-get update
sudo apt-get install -y kubelet kubeadm 
sudo apt-mark hold kubelet kubeadm containerd.io

sudo systemctl restart containerd
sudo systemctl enable containerd

sudo systemctl enable kubelet
sudo systemctl start kubelet
```
## Kết quả
Sau khi init trên master node, sử dụng command `sudo kubeadm join` để VM tham gia vào cluster
![Result](./images/Screenshot%20From%202025-06-21%2002-03-02.png)