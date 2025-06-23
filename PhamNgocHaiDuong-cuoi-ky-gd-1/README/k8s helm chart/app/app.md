Code của app nằm trong frontend và backend-api

Chạy lệnh 
```
helm install my-app . -n microservice --create-namespace
```
Sau đó app sẽ được triển khai trên kubernetes
![alt text](image.png)

frontend được expose ở cổng 30081 ở node worker
![alt text](image-1.png)

backend được expose ở cổng 30500 ở node worker
![alt text](image-2.png)