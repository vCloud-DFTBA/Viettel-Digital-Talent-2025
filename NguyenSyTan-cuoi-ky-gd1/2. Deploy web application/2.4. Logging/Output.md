# Output cho yêu cầu về Logging
#### Yêu cầu:
- Sử dụng ansible playbooks để triển khai stack EFK (elasticsearch, fluentd, kibana), sau đó cấu hình logging cho web service và api service, đảm bảo khi có http request gửi vào web service hoặc api service thì trong các log mà các service này sinh ra, có ít nhất 1 log có các thông tin 
    - Request Path(VD: /api1/1, /api2/3 ..) 
    - HTTP Method VD: (GET PUT POST…) 
    - Response Code: 302, 200, 202, 201… 
#### Output: 
- [Tài liệu & file setup](./Setup.md)
- Hình ảnh chụp màn hình Kibana kết quả tìm kiếm log của các service theo url path 
![](../../images/kibana-query.png)