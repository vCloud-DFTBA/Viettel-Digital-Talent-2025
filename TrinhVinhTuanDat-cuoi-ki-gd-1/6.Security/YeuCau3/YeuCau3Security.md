# Yêu cầu 3 (1đ): Rate Limiting

## Yêu cầu
Sử dụng 1 trong số các giải pháp để rate limit cho Endpoint của API Service, sao cho nếu có quá **10 request trong 1 phút** gửi đến Endpoint của API service thì các request sau đó bị trả về **HTTP Response 409**.

---

## Giải pháp đề xuất

Giải pháp được đưa ra: **Rate limit ở HAProxy**


## 1. Rate Limit ở HAProxy

### Mô tả luồng hoạt động
Sau khi thành công dựng lên HAProxy, luồng hoạt động khi thực hiện một request sẽ là:

```
Browser -> HAProxy -> Ingress Controller -> Backend
                                         -> Frontend
```

Do đó có thể đưa ra giải pháp cho việc rate limit sẽ xử lý ngay ở HAProxy. Khi trong một phút có request > 10 sẽ thực hiện trả về mã lỗi 409. Đây cũng là một trong những giải pháp hiện nay đối với các hệ thống để phòng chống DDOS.

### Cấu hình HAProxy

Thực hiện sửa file `haproxy.cfg`:

```bash
global
    daemon
    maxconn 4096
    log stdout local0

defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    option tcplog
    log global
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
frontend frontend_http
    bind *:80
    mode http
    redirect scheme https

frontend frontend_https
    bind *:443
    mode tcp
    default_backend backend_ingress_https

frontend api_proxy
    bind *:8080
    mode http
    option httplog
    
    
    stick-table type ipv6 size 100k expire 60s store http_req_rate(60s)
    
    
    http-request track-sc0 src
    
    
    http-request return status 409 content-type "application/json" string '{"error":"Rate limit exceeded","message":"Maximum 10 requests per minute allowed","code":429}' if { sc_http_req_rate(0) gt 10 }
    
    default_backend api_backend

backend api_backend
    mode http
    balance roundrobin
    option httpchk GET /actuator/health
    
    server api1 192.168.122.93:30002 check inter 5s fall 3 rise 2

backend backend_ingress_https
    mode tcp
    balance roundrobin
    server k8s-node1 192.168.122.93:32368 check
```

### Tài liệu tham khảo
Dựa trên trang tài liệu chính thức của HAProxy:
1. [Four Examples of HAProxy Rate Limiting](https://www.haproxy.com/blog/four-examples-of-haproxy-rate-limiting)
2. [Traffic Policing](https://www.haproxy.com/documentation/haproxy-configuration-tutorials/security/traffic-policing/)

## 2. Kiểm thử Rate Limiting

### Script test
Câu lệnh thực hiện test và log khi thực hiện curl:

```bash
LOG_FILE="rate_test_$(date '+%Y%m%d_%H%M%S').txt"
LOG_ID="TEST_$(date '+%Y%m%d%H%M%S')"

{
    echo "=== Rate Limiting Test - ID: $LOG_ID ==="
    echo "Time: $(date)"
    echo ""
    
    for i in {1..12}; do
        echo "Request $i: [$(date '+%H:%M:%S')]"
        curl -s -w "HTTP Code: %{http_code}\n" http://192.168.122.121:8080/api/students
        echo "---"
        sleep 2
    done
    
    echo ""
    echo "Test completed: $(date)"
} | tee $LOG_FILE

echo "Log saved to: $LOG_FILE"
```

### Kết quả kiểm thử

**File thực thi lệnh test rate limit:** [Script.sh](Logs/ratelimitwithHAProxy.sh)

**Hình ảnh khi test rate limit:**
![Rate limit test result](image.png)

**File logs khi thực hiện curl:** [Log rate limit with HAProxy](Logs/rate_test_20250623_103856.txt)

**Hình ảnh thống kê ở HAProxy**
![alt text](image-1.png)
### Phân tích kết quả

Từ kết quả kiểm thử có thể thấy:
- 10 request đầu tiên được xử lý bình thường (HTTP 200)
- Từ request thứ 11 trở đi, HAProxy trả về HTTP 409 với message rate limit exceeded
- Cơ chế rate limiting hoạt động chính xác theo yêu cầu đề bài





## Kết luận

Giải pháp rate limiting sử dụng HAProxy đã được triển khai thành công và hoạt động đúng như yêu cầu. HAProxy có khả năng theo dõi số lượng request theo IP address trong khoảng thời gian 1 phút và tự động từ chối các request vượt quá ngưỡng cho phép.

Ưu điểm của giải pháp:
- Xử lý tại tầng load balancer, bảo vệ toàn bộ backend
- Cấu hình đơn giản và hiệu quả
- Có thể tùy chỉnh response message và status code
- Hỗ trợ monitoring qua HAProxy stats

Giải pháp này phù hợp cho môi trường production để bảo vệ API khỏi các cuộc tấn công DDOS hoặc việc sử dụng tài nguyên quá mức.

