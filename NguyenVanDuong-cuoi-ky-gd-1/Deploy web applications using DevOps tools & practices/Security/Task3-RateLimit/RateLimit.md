# Báo cáo triển khai Rate Limiting cho API Service

**Mục tiêu:**

- Giới hạn số lượng request đến endpoint của API service ở `10 requests/phút`.
- Khi vượt quá ngưỡng, các request tiếp theo phải nhận `HTTP 409 Conflict`.

## Bước 1: Cài đặt thư viện rate limit

1. Mở terminal vào thư mục backend của dự án.
2. Chạy lệnh cài `express-rate-limit`:

   ```bash
   npm install express-rate-limit
   ```

## Bước 2: Cấu hình Rate Limiter trong `be.js`

1. **Import** gói vào đầu file `be.js`:

   ```js
   const rateLimit = require("express-rate-limit");
   ```

2. **Khởi tạo** limiter ngay sau khi tạo `app`:

   ```js
   // Giới hạn 10 request mỗi IP trong 1 phút
   const apiLimiter = rateLimit({
     windowMs: 60 * 1000, // 1 phút
     max: 10, // tối đa 10 requests
     statusCode: 409,
     message: { message: "Too many requests – please try again in a minute." },
     standardHeaders: true,
     legacyHeaders: false,
   });
   ```

3. **Áp dụng** limiter cho các route API:

   ```js
   app.use(apiLimiter);
   ```

## Bước 3: Build và triển khai lại trên Kubernetes

## Bước 4: Test Rate Limiting

- Lần 1–10: OK
- Lần 11: **409** và body JSON `{ "message": "Too many requests – please try again in a minute." }`
- `Kết quả:`

<p align="center">
  <img src="assets\test-rate-limit.png" alt="test-rate-limit.png" width="800"/>
</p>
