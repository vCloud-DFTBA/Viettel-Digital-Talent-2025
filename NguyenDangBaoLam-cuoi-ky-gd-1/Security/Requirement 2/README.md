# Yêu cầu
    • Đảm bảo 1 số URL của api service  khi truy cập phải có xác thực thông qua 1 trong số các phương thức cookie, basic auth, token auth, nếu không sẽ trả về HTTP response code 403. (0.5)
    • Thực hiện phân quyền cho 2 loại người dùng trên API:
        ◦ Nếu người dùng có role là user thì truy cập vào GET request trả về code 200, còn truy cập vào POST/DELETE thì trả về 403
        ◦ Nếu người dùng có role là admin thì truy cập vào GET request trả về code 200, còn truy cập vào POST/DELETE thì trả về 2xx

## Giải pháp xác thực và phân quyền
Để xử lý xác thực và phân quyền một cách linh hoạt giữa các service, em triển khai một `auth-service` chuyên trách xử lý xác thực đầu vào và quyết định quyền truy cập theo role.

Cách hoạt động:
- `auth-service` được triển khai như một API xác thực độc lập, cung cấp một endpoint /auth.
- Ingress Controller sẽ gửi mọi request đến /auth của `auth-service` để kiểm tra.
- `auth-service` kiểm tra:
    - Thông tin đăng nhập (qua Basic Auth)
    - Role của user
    - Loại HTTP method (GET, POST, DELETE...)

Mã nguồn `auth-service`
```python
@app.api_route("/auth", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"])
async def auth(request: Request):
    try:
        credentials: HTTPBasicCredentials = await security(request)
    except Exception:
        return JSONResponse(status_code=403, content={"detail": "Missing or invalid auth"})

    username = credentials.username
    password = credentials.password

    if not htpasswd.check_password(username, password):
        return JSONResponse(status_code=403, content={"detail": "Invalid credentials"})

    role = roles.get(username, "user")
    method = request.headers.get("X-Original-Method", request.method).upper()

    if role == "user" and method in ["POST", "DELETE"]:
        return JSONResponse(status_code=403, content={"detail": "Insufficient permission"})

    return Response(status_code=200)
```
Sử dụng annotation
```yaml
nginx.ingress.kubernetes.io/auth-url: "http://auth-service.ktpm.svc.cluster.local:3000/auth"
```

Khi đó:
- Nginx sẽ gửi request phụ (subrequest) đến /auth
- Nếu /auth trả về 200 → cho phép truy cập API
- Nếu /auth trả về 403 → chặn lại

## Kết quả
### Khi không xác thực
![](../images/Screenshot%20From%202025-06-22%2011-24-40.png)
### Khi sử dụng credential của user
![](../images/Screenshot%20From%202025-06-22%2011-25-40.png)
![](../images/Screenshot%20From%202025-06-22%2011-37-12.png)
![](../images/Screenshot%20From%202025-06-22%2011-26-44.png)
### Khi sử dụng credential của admin
![](../images/Screenshot%20From%202025-06-22%2011-34-53.png)
![](../images/Screenshot%20From%202025-06-22%2011-36-38.png)