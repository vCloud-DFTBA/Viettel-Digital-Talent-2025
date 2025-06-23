# Sử dụng image Python chính thức
FROM python:3.10-slim

# Tạo thư mục app
WORKDIR /app

# Copy requirements và cài đặt
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy code Flask
COPY app.py .

# Chạy ứng dụng
CMD ["python", "app.py"]
