### Kỹ thuật sử dụng
- FastAPI Middleware: sử dụng `BaseHTTPMiddleware` để chèn middleware vào pipeline xử lý request.
- Thư viện `aiocache`: dùng `SimpleMemoryCache` để lưu trữ số lượng request theo từng IP (in-memory).
- Xác định IP: kiểm tra lần lượt các header `X-Forwarded-For`, `X-Real-IP`, hoặc fallback về `request.client.host`.

### Cấu trúc Middleware
#### Cấu hình `aiocache`
```python
caches.set_config({
    'default': {
        'cache': "aiocache.SimpleMemoryCache",
        'ttl': 60  
    }
})
```

### Hàm dispatch
Đây là hàm chính xử lý từng request. Các bước chính:

a. Xác định IP của client: `ip = self._get_client_ip(request)`
b. Truy vấn số lượng request đã gửi trong 60s:
- `rate_limit_key = f"api_rate_limit:{ip}"`
- `current_count = await self.cache.get(rate_limit_key)`

c. Kiểm tra giới hạn:
- Nếu chưa có IP trong cache → set count = 1.
- Nếu IP đã tồn tại và vượt quá giới hạn → trả về 409.
- Nếu chưa vượt → tăng count và cho phép request đi tiếp.

## Kết quả
![](./Screenshot%20From%202025-06-23%2023-23-06.png)