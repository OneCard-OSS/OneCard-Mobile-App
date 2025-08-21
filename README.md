# onecard_client

OneCard authenticator application.


# OneCard Flutter Client

NFC 카드 기반 인증 시스템과 푸시 알림을 지원하는 Flutter 애플리케이션입니다.

## 🌟 주요 기능

### 1. 🔐 보안 인증 시스템
- **NFC 카드 기반 로그인**: 사번과 NFC 카드를 이용한 2단계 인증
- **자동 로그인**: 저장된 토큰을 이용한 자동 로그인 시도
- **토큰 갱신**: Refresh Token을 이용한 자동 액세스 토큰 갱신
- **보안 저장소**: Flutter Secure Storage를 이용한 안전한 토큰 관리

### 2. 📱 푸시 알림 시스템
- **실시간 푸시 알림**: Socket.IO 기반 실시간 알림 수신
- **백그라운드 서비스**: 앱이 백그라운드에 있어도 알림 수신 가능
- **시스템 재시작 시 자동 실행**: 부팅 시 백그라운드 서비스 자동 시작
- **Deep Link 지원**: onecard:// scheme을 통한 앱 내 네비게이션

### 3. 🔗 Deep Link 기능
- **onecard:// URL scheme 지원**
- **푸시 알림에서 Deep Link 실행**
- **URL 파라미터 파싱 및 표시**

## 🛠️ 설치 및 설정

### 1. 환경 변수 설정

프로젝트 루트의 `.env` 파일을 수정하여 서버 설정을 변경할 수 있습니다:

```env
# 로그인 및 API 서버 설정
API_BASE_URL=https://your-api-server.com
LOGIN_INITIATE_ENDPOINT=/app/api/initiate
LOGIN_VERIFY_ENDPOINT=/app/api/verify
TOKEN_REFRESH_ENDPOINT=/app/api/token
LOGOUT_ENDPOINT=/app/api/logout

# 푸시 알림 서버 설정
PUSH_SERVER_URL=http://your-push-server:5000
JWT_SECRET=your_jwt_secret_key

# 백그라운드 서비스 설정
BACKGROUND_SERVICE_INTERVAL_MINUTES=15
AUTO_RECONNECT_ATTEMPTS=3

# 개발/디버그 설정
DEBUG_MODE=true
LOG_LEVEL=debug
```


## 📋 API 엔드포인트

### 로그인 시작
```
POST /app/api/initiate
Content-Type: application/json

{
  "emp_no": "사번"
}

Response:
{
  "attempt_id": "시도ID",
  "response": "base64_encoded_challenge_data"
}
```

### 로그인 검증
```
POST /app/api/verify
Content-Type: application/json

{
  "attempt_id": "시도ID",
  "pubkey": "카드_공개키",
  "encrypted_data": {
    "ciphertext": "암호화된_데이터"
  }
}

Response:
{
  "access_token": "액세스_토큰",
  "refresh_token": "리프레시_토큰",
  "token_type": "bearer",
  "expires_in": 3600
}
```

### 토큰 갱신
```
POST /app/api/token
Content-Type: application/json

{
  "refresh_token": "리프레시_토큰"
}

Response:
{
  "access_token": "새_액세스_토큰",
  "refresh_token": "새_리프레시_토큰",
  "token_type": "bearer",
  "expires_in": 3600
}
```

### 로그아웃
```
POST /app/api/logout
Authorization: Bearer 액세스_토큰

Response:
{
  "message": "Logout Successful"
}
```

## 🚀 사용법

### 1. 최초 로그인
1. 앱 실행 시 로그인 화면이 표시됩니다
2. 사번을 입력하고 "NFC 카드로 로그인" 버튼을 클릭합니다
3. NFC 카드를 휴대폰 뒷면에 가까이 대고 기다립니다
4. 인증이 완료되면 메인 화면으로 이동합니다

### 2. 자동 로그인
- 한 번 로그인하면 다음 앱 실행 시 자동으로 로그인됩니다
- 토큰이 만료된 경우 자동으로 갱신을 시도합니다
- 갱신에 실패하면 다시 로그인해야 합니다

### 3. 푸시 알림
- 로그인 성공 시 자동으로 푸시 서버에 연결됩니다
- 백그라운드에서도 알림을 수신할 수 있습니다
- 알림을 터치하면 Deep Link가 있는 경우 해당 페이지로 이동합니다

### 4. Deep Link 테스트
- 메인 화면의 "Deep Link 테스트" 버튼을 클릭하여 기능을 확인할 수 있습니다
- 외부에서 `onecard://test?param1=value1&param2=value2` 형태로 앱을 실행할 수 있습니다

## 🔧 개발자 가이드

### 파일 구조
```
lib/
├── config/
│   └── app_config.dart          # 환경 변수 관리
├── services/
│   ├── auth_service.dart        # 인증 서비스
│   ├── background_service.dart  # 백그라운드 서비스
│   └── secure_storage_service.dart # 보안 저장소
├── screens/
│   └── login_page.dart          # 로그인 화면
├── assets/
│   └── NFCCommands.dart         # NFC 명령어 유틸리티
├── nfc_operation.dart            # NFC 카드 통신
├── socket_service.dart          # Socket.IO 서비스
├── push_notification_service.dart # 로컬 알림 서비스
├── deeplink_page.dart           # Deep Link 페이지
└── main.dart                    # 메인 앱
```

### 주요 클래스

#### AppConfig
환경 변수를 관리하는 설정 클래스입니다.

#### SecureStorageService
Flutter Secure Storage를 사용하여 토큰을 안전하게 저장/조회합니다.

#### AuthService
로그인, 로그아웃, 토큰 갱신 등의 인증 관련 API를 호출합니다.

#### BackgroundService
WorkManager를 사용하여 백그라운드에서 푸시 서버 연결을 유지합니다.

#### NFCCardOperations
NFC 카드와의 통신을 담당합니다.


## 📱 지원 플랫폼
- **Android**: API Level 21 (Android 5.0) 이상

## 🔍 트러블슈팅

### 1. NFC 관련 문제
- NFC가 활성화되어 있는지 확인
- 카드를 휴대폰 뒷면 중앙에 가까이 대기
- 금속 케이스나 자석이 있는 경우 제거

### 2. 푸시 알림 문제
- 알림 권한이 허용되어 있는지 확인
- 배터리 최적화에서 앱을 제외
- 네트워크 연결 상태 확인

### 3. 로그인 문제
- 서버 URL이 올바른지 확인
- 네트워크 연결 상태 확인
- 사번이 올바른지 확인