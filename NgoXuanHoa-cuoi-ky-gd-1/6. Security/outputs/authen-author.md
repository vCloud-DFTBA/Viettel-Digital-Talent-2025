# Giải pháp
- Em đã triển khai sử dụng JWT - JSON Web Token và Authorization để tiến hành xác thực và phân quyền người dùng
### Các bước triển khai
Đầu tiên cấu hình JWT trong FastAPI với OAuth2 và Bcrypt<br>
Ở đây em có dùng CustomOAuth2PasswordBearer nhằm trả ra `HTTP_STATUS_403_FORBIDDEN` trong trường hợp `JWT_TOKEN` truyền lên sai định dạng, hoặc người dùng cố tình không truyền lên vì mặc định OAuth2 sẽ trả ra `HTTP_STATUS_401_UNAUTHORIZED`
```
import os
from typing import Annotated

from dotenv import load_dotenv
from fastapi import Depends, HTTPException, Request
from fastapi.security import OAuth2PasswordBearer
from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from starlette import status
from starlette.status import HTTP_403_FORBIDDEN, HTTP_401_UNAUTHORIZED
from datetime import timedelta, datetime, timezone
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from starlette.status import HTTP_201_CREATED, HTTP_404_NOT_FOUND, HTTP_200_OK, HTTP_401_UNAUTHORIZED
from passlib.context import CryptContext
from fastapi.security import OAuth2PasswordRequestForm, OAuth2PasswordBearer
from jose import jwt, JWTError

load_dotenv()

SECRET_KEY = os.getenv("PRIVATE_KEY")
ALGORITHM = os.getenv("ALGORITHM")
ACCESS_TOKEN_EXPIRE_MINUTES = os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES")

password_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

class CustomOAuth2PasswordBearer(OAuth2PasswordBearer):
    async def __call__(self, request: Request):
        from fastapi.security.utils import get_authorization_scheme_param
        authorization = request.headers.get("Authorization")
        scheme, param = get_authorization_scheme_param(authorization)
        if not authorization or scheme.lower() != "bearer":
            raise HTTPException(
                status_code=HTTP_403_FORBIDDEN,
                detail="Not authenticated",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return param

# Sử dụng custom oauth2 scheme
custom_oauth2_scheme = CustomOAuth2PasswordBearer(tokenUrl="/api/auth/login")

def verify_password(plain_password, hashed_password):
    return password_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return password_context.hash(password)


def create_access_token(username: str, user_id: int, user_role:str ,expires_delta: timedelta):
    encode = {'sub' : username, 'id' : user_id, 'role' : user_role}
    expire = datetime.now(timezone.utc) + expires_delta
    encode.update({'exp' : expire})
    return jwt.encode(encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: Annotated[str, Depends(custom_oauth2_scheme)]):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get('sub')
        user_id: int = payload.get('id')
        user_role : str = payload.get('role')
        if username is None or user_id is None:
            raise HTTPException(status_code=HTTP_403_FORBIDDEN, detail= 'Cannot validate user!')
        return {'username': username, 'user_id': user_id, 'user_role': user_role}
    except JWTError:
        raise HTTPException(status_code=HTTP_403_FORBIDDEN, detail= 'Cannot validate user!')
```
Tiếp theo ở Frontend cần lưu lại JWT sau khi login và truyền đến FastAPI qua mỗi request vì JWT là trạng thái Stateless, ở đây em sẽ lưu vào LocalStorage và truyền cùng với Header mỗi lần request
```
export const login = async (username, password) => {
  try {
    const params = new URLSearchParams();
    params.append('username', username);
    params.append('password', password);

    const response = await api.post('/api/auth/login', params, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });
    
    if (response.data.access_token) {
      saveToken(response.data.access_token);
    }
    
    return response.data;
  } catch (error) {
    throw error.response?.data || error.message;
  }
};
```
Ở FastAPI, mỗi lần có 1 request truyền tới em sẽ extract JWT và lấy các thông tin để xác định user và role của user đó nhằm phân quyền cho user đó<br>
Ở đây em đang cấu hình: <br>
user: chỉ method GET <br>
admin: POST/PUT/DELETE
```
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from starlette.status import HTTP_200_OK, HTTP_201_CREATED, HTTP_403_FORBIDDEN, HTTP_404_NOT_FOUND, HTTP_204_NO_CONTENT

from configs.database import get_db
from configs.authentication import get_current_user
from services.student_services import get_student_service, StudentService
from schemas.student import StudentCreate, StudentUpdate, StudentResponse

router = APIRouter(
    prefix="/api/students",
    tags=["students"],
)


def check_admin_permission(current_user: dict = Depends(get_current_user)):
    """Kiểm tra quyền admin cho các thao tác POST/PUT/DELETE"""
    if current_user.get("user_role") != "admin":
        raise HTTPException(
            status_code=HTTP_403_FORBIDDEN,
            detail="Chỉ admin mới có quyền thực hiện thao tác này"
        )
    return current_user


@router.get("", status_code=HTTP_200_OK, response_model=List[StudentResponse])
async def get_all_students(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    student_service: StudentService = Depends(get_student_service),
    current_user: dict = Depends(get_current_user)
):
    students = student_service.get_all_students(db, skip=skip, limit=limit)
    return students


@router.get("/{student_id}", status_code=HTTP_200_OK, response_model=StudentResponse)
async def get_student(
    student_id: int,
    db: Session = Depends(get_db),
    student_service: StudentService = Depends(get_student_service),
    current_user: dict = Depends(get_current_user)
):
    student = student_service.get_student_by_id(student_id, db)
    if not student:
        raise HTTPException(status_code=HTTP_404_NOT_FOUND, detail="Không tìm thấy student")
    return student


@router.post("", status_code=HTTP_201_CREATED, response_model=StudentResponse)
async def create_student(
    student_data: StudentCreate,
    db: Session = Depends(get_db),
    student_service: StudentService = Depends(get_student_service),
    current_user: dict = Depends(check_admin_permission)
):
    student = student_service.create_student(student_data, db)
    return student


@router.put("/{student_id}", status_code=HTTP_200_OK, response_model=StudentResponse)
async def update_student(
    student_id: int,
    student_data: StudentUpdate,
    db: Session = Depends(get_db),
    student_service: StudentService = Depends(get_student_service),
    current_user: dict = Depends(check_admin_permission)
):
    student = student_service.update_student(student_id, student_data, db)
    if not student:
        raise HTTPException(status_code=HTTP_404_NOT_FOUND, detail="Không tìm thấy student")
    return student


@router.delete("/{student_id}", status_code=HTTP_204_NO_CONTENT)
async def delete_student(
    student_id: int,
    db: Session = Depends(get_db),
    student_service: StudentService = Depends(get_student_service),
    current_user: dict = Depends(check_admin_permission)
):
    success = student_service.delete_student(student_id, db)
    if not success:
        raise HTTPException(status_code=HTTP_404_NOT_FOUND, detail="Không tìm thấy student")
    return {"message": "Xóa student thành công"}
```
