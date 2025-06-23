# Ouput yêu cầu 1
#### Yêu cầu 1:
- Dựng HAProxy Loadbalancer trên 1 VM riêng (trong trường hợp cụm lab riêng của sinh viên) với mode TCP, mở port trên LB trỏ đến NodePort của App trên K8S Cluster.
- Sử dụng giải pháp Ingress cho các deployment, đảm bảo các truy cập đến các port App sử dụng https
- Cho phép sinh viên sử dụng self-signed cert để làm bài 
#### Output 1: 
- Quy trình cấu hình: [Tài liệu](./Setup.md)
- File cấu hình của HAProxy Loadbalancer cho App 
    - File config haproxy: [haporxy.cfg](./haproxy.cfg)
- File cấu hình ingress. 
    - File config ingress: [ingress.yaml](./ingress.yaml)
- Kết quả truy cập vào App từ trình duyệt thông qua giao thức https hoặc dùng curl.   
![](../../../images/web-https.png)
