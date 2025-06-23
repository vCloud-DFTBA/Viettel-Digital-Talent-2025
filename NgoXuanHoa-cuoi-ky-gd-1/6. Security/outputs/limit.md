# Giải pháp
- FastAPI hỗ trợ trực tiếp 1 thư viện `slowapi` cho việc ratelimits<br>
Thực hiện cài và import thư viện
```
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
```
Khai báo limiter
```
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, rate_limit_handler)
```
Khai báo ratelimits và endpoint muốn ratelimit <br>
Ở đây em sẽ limit endpoint `/` tối đa 10 request/minute
```
@app.get("/")
@limiter.limit("10/minute")
async def root(request: Request):
    return {"message": "Hello Viettel Digital Talent 2025!"}
```
