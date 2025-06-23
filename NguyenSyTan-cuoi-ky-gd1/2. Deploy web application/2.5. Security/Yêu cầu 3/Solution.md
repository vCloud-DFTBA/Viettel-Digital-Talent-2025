# Giải pháp cho yêu cầu 3
Các API được viết bằng ngôn ngữ Python với framework là FastAPI, giải pháp đưa ra là cấu hình một hàm utils, có nhiệm vụ thu thập số lượng request (`times`) trong một khoảng thời gian tính bằng giây (`seconds`), nếu quá số lượng request sẽ trả về lỗi với status code là `409`.  
(Ý tưởng được lấy từ thư viện [fastapi-throttle](https://github.com/AliYmn/fastapi-throttle)) 
```python
import time
from fastapi import Request, HTTPException
from typing import Dict, List


class RateLimiter:
    def __init__(self, times: int, seconds: int) -> None:
        self.times: int = times
        self.seconds: int = seconds
        self.requests: Dict[str, List[float]] = {}

    async def __call__(self, request: Request) -> None:
        client_ip: str = request.client.host
        current_time: float = time.time()

        # Initialize the client's request history if not already present
        if client_ip not in self.requests:
            self.requests[client_ip] = []

        # Filter out timestamps that are outside of the rate limit period
        self.requests[client_ip] = [
            timestamp
            for timestamp in self.requests[client_ip]
            if timestamp > current_time - self.seconds
        ]

        # Check if the number of requests exceeds the allowed limit
        if len(self.requests[client_ip]) >= self.times:
            raise HTTPException(
                status_code=409,
                detail="Too many requests, please try again later."
            )

        # Record the current request timestamp
        self.requests[client_ip].append(current_time)
```

Từ hàm utils này các api route sẽ thêm một dependencies, ví dụ đối với route liệt kê danh sách oto có trong showroom:
```python
# Rate limiter to limit requests to 10 per minute globally
global_limiter = RateLimiter(times=10, seconds=60)

# Create a router for user-related endpoints
router = APIRouter(prefix="/api/cars", tags=["cars"])

@router.get("/list", dependencies=[Depends(global_limiter)])
```

Kết quả test bằng Postman khi gọi quá 10 request trong 1 phút:
![](../../../images/ratelimit-result.png)