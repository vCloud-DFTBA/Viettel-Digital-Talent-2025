# Báo cáo quá trình triển khai Role-Based Access

**Mục tiêu:**

- Thêm quản lý phân quyền (RBAC) cho hai role: `user` và `admin`.
- Role `user` chỉ có quyền GET (HTTP 200), nếu dùng POST/PUT/DELETE trả về HTTP 403.
- Role `admin` có toàn quyền CRUD (GET trả về 200, các hành động POST/PUT/DELETE trả về 2xx).

---

## 1. Thêm cột `role` vào bảng `user` và tạo admin user

`Note`: Ban đầu trong database, chưa phân quyền cho người dùng

<p align="center">
  <img src="assets\database-before-create-role.png" alt="database-before-create-role.png" width="800"/>
</p>

1. **Kết nối vào MySQL:**

   ```bash
   mysql -u root -h 192.168.93.137 -P 30006 -p

   USE db;
   ```

2. **Thêm trường `role`:**

   ```sql
   ALTER TABLE `user`
     ADD COLUMN `role` ENUM('user','admin') NOT NULL DEFAULT 'user';
   ```

3. **Cập nhật user cũ (nếu cần):**

   ```sql
   UPDATE `user`
     SET `role` = 'user'
     WHERE `role` IS NULL;
   ```

4. **Tạo admin mới:**

   - Sinh hash password với bcrypt:

     ```bash
     node -e "const bcrypt = require('bcrypt'); console.log(bcrypt.hashSync('admin', 10));"
     ```

   - Chèn record:

     ```sql
     INSERT INTO `user` (`username`,`password`,`role`)
     VALUES ('admin', '$2b$10$...hashed...', 'admin');
     ```

**Kết quả kiểm tra:**

```sql
SELECT id, username, role FROM `user`;
-- admin1 xuất hiện với role = 'admin'
```

<p align="center">
  <img src="assets\database-after-create-role.png" alt="database-after-create-role.png" width="800"/>
</p>

---

## 2. Cấu hình Backend (`be.js`)

1. **Signup endpoint:**

- Gán luôn `role` = "user"

  ```diff
  - INSERT INTO user (username, password)
  + INSERT INTO user (username, password, role) VALUES (?, ?, 'user')
  ```

2. **Login endpoint:** Ký JWT chứa `role`:

   ```diff
   - jwt.sign({ username }, secret)
   + jwt.sign({ username, role: user.role }, secret)
   ```

3. **Middleware `authenticate`:** Lưu cả `username` và `role`:

   ```diff
   - req.user = payload.username;
   + req.user = { username: payload.username, role: payload.role };
   ```

4. **Tạo middleware `authorize`:**

   ```js
   function authorize(allowedRoles) {
     return (req, res, next) => {
       if (!allowedRoles.includes(req.user.role)) {
         return res.status(403).json({ message: "Forbidden" });
       }
       next();
     };
   }
   ```

5. **Áp dụng phân quyền vào routes:**

   ```diff
   - app.get('/students', authenticate)
   + app.get('/students', authenticate, authorize(['user','admin']))

   - app.post('/students', authenticate)
   + app.post('/students', authenticate, authorize(['admin']))
   ```

   Tương tự cho PUT, DELETE.

---

## 3. Cấu hình Frontend (`script.js`)

1. **Decode JWT để lấy `role`:**

   ```js
   const payload = JSON.parse(atob(token.split(".")[1]));
   const role = payload.role;
   renderList(list, role);
   ```

2. **Hàm `renderList(list, role)`:**

   - Nếu `role === 'admin'`, hiển thị nút Edit/Delete.
   - Ngược lại hiển thị ký tự `—`.
   - Ẩn form thêm/sửa nếu không phải admin.

---

## 4. Kết quả

1. **Test sử dụng `curl`:**

- Với người dùng có role là `user` (duongnv)

<p align="center">
  <img src="assets\curl-role-user.png" alt="curl-role-user.png" width="800"/>
</p>

- Với người dùng có role là `admin` (admin)

<p align="center">
  <img src="assets\curl-role-admin.png" alt="curl-role-admin.png" width="800"/>
</p>

2. **Test với `browser`:**

- Với người dùng có role là `user` (duongnv)

<p align="center">
  <img src="assets\browser-role-user.png" alt="browser-role-user.png" width="800"/>
</p>

- Với người dùng có role là `admin` (admin)

<p align="center">
  <img src="assets\browser-role-admin.png" alt="browser-role-admin.png" width="800"/>
</p>
