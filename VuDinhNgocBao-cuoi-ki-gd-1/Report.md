# **Báo cáo Đồ án cuối kỳ VDT 2025 - Cloud GĐ 1**

*   **Họ và tên:** Vũ Đình Ngọc Bảo
*   **Lớp:** Cloud
*   **Mentor:** *
*   **Repo Source Code:** [`https://github.com/chuitrai/my_app`](https://github.com/chuitrai/my_app)
*   **Repo Cấu hình:** [`https://github.com/chuitrai/my_app_config`](https://github.com/chuitrai/my_app_config)

## **I. Giới thiệu tổng quan**

Báo cáo này ghi lại quá trình thực hiện, tìm tòi và gỡ lỗi trong suốt quá trình hoàn thành bài tập lớn cuối kỳ GĐ1. Hướng tiếp cận tập trung vào việc xây dựng một hệ thống hoàn chỉnh từ hạ tầng, CI/CD đến giám sát, đồng thời ghi nhận lại các sự cố thường gặp và cách khắc phục để có được một hệ thống hoạt động ổn định.

## **II. Phần 1: Triển khai Hạ tầng Kubernetes**

Em đã chọn triển khai Kubernetes bằng `kubeadm` để hiểu sâu về cấu trúc của cụm, đồng thời tự động hóa toàn bộ quá trình bằng Vagrant và VirtualBox để tăng tốc độ thử nghiệm và sửa lỗi. Quá trình ban đầu gặp nhiều sự cố liên quan đến kết nối mạng giữa các node và cấu hình CNI. Sau nhiều lần thử nghiệm, em đã ổn định kịch bản cài đặt, trong đó quan trọng nhất là việc đồng bộ `cgroup driver` giữa `containerd` và `kubelet` thành `systemd`, và tùy chỉnh cấu hình Calico để nhận diện đúng interface mạng private. Một bài học quan trọng là phải đảm bảo mạng trên master node ổn định trước khi cho worker node gia nhập để tránh các lỗi `timeout` trong quá trình TLS Bootstrap.

## **III. Phần 2: Triển khai DevOps Tools & Practices**

### **3.1. K8S Helm Chart & Triển khai Ứng dụng**

Em đã đóng gói toàn bộ ứng dụng 3-tier vào một Helm Chart duy nhất và áp dụng mô hình GitOps với 2 repository riêng biệt. Việc triển khai được thực hiện qua ArgoCD. Thách thức lớn nhất trong phần này là việc cấu hình ArgoCD để có thể lấy Chart nguồn từ repo ứng dụng và file `values.yaml` từ repo cấu hình. Ban đầu, quá trình render manifest của ArgoCD liên tục thất bại do các lỗi cú pháp nhỏ trong file `argocd-application.yaml` và các lỗi `nil pointer` trong template do thiếu giá trị trong `values.yaml`. Sau khi debug bằng ArgoCD CLI để xem manifest được render, em đã sửa lại các đường dẫn và đảm bảo tất cả các biến đều có giá trị, giúp ArgoCD triển khai thành công toàn bộ ứng dụng.


### **3.2. CI/CD - Tự động hóa quy trình triển khai**

Em đã xây dựng một luồng CI/CD hoàn chỉnh bằng Jenkins Multibranch Pipeline, được kích hoạt khi có Git Tag mới được tạo. Quá trình này gặp nhiều thử thách nhất, từ lỗi cú pháp `Jenkinsfile` đến các vấn đề về môi trường thực thi. Ban đầu, pipeline liên tục thất bại với lỗi `docker: not found` và `Cannot connect to the Docker daemon`. Nguyên nhân được xác định là do agent Jenkins mặc định không có Docker và không thể giao tiếp với Docker daemon trên node. Giải pháp cuối cùng là định nghĩa một Pod Agent tùy chỉnh ngay trong `Jenkinsfile` bằng cú pháp YAML, trong đó mount trực tiếp `docker.sock` từ host node vào container build, đồng thời cài đặt các công cụ cần thiết như `git` và `sed` một cách tự động. Sau Sau đó em chuyên sang dùng `kaniko` thì chạy ổn hơn.


### **3.3. Monitoring**

Để giám sát ứng dụng, em đã sửa code Go để expose các metrics tùy chỉnh qua endpoint `/metrics` bằng thư viện của Prometheus. Thay vì triển khai Prometheus Stack phức tạp, em đã bám sát yêu cầu đề bài là sử dụng Ansible để deploy một container Prometheus độc lập trên master node. Quá trình ban đầu gặp lỗi do máy ảo chưa cài đặt Python Docker SDK, sau khi cài đặt thư viện cần thiết bằng `pip`, playbook đã chạy thành công. File cấu hình `prometheus.yml` được thiết lập để "cào" metrics từ địa chỉ `ClusterIP` của service backend, đảm bảo kết nối nội bộ ổn định.


### **3.4. Logging**

Em đã triển khai EFK Stack (Elasticsearch, Fluentd, Kibana) bằng Ansible Playbook. Thách thức lớn nhất là việc cấu hình Fluentd để có thể phân tích đúng các dòng log JSON do ứng dụng Go tạo ra (vấn đề "JSON trong JSON"). Ban đầu, Kibana không hiển thị các trường dữ liệu như `path` hay `method`. Sau khi debug log của Fluentd, em đã xác định được cần phải thêm một bộ lọc (`filter`) `parser` vào `fluent.conf` để "mở gói" chuỗi JSON nằm trong trường `log` mặc định của Docker. Sau khi deploy lại Fluentd với cấu hình mới và refresh Index Pattern trên Kibana, dữ liệu đã được phân tích chính xác, cho phép tìm kiếm và lọc log theo các trường nghiệp vụ theo đúng yêu cầu đề bài.