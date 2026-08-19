# Upload key 보관 안내

## 파일

- 비공개 keystore: `android/app/upload-keystore.jks`
- 비공개 비밀번호 설정: `android/key.properties`
- 공개 인증서: `upload_certificate.pem`
- alias: `upload`

keystore와 `key.properties`는 Git에서 제외됩니다. 두 파일을 함께 암호화한 뒤 서로 다른 안전한 위치 두 곳에 백업하세요. 공개 저장소, 메신저 또는 일반 이메일에 올리지 마세요.

Play App Signing을 사용할 때 이 키는 AAB 업로드 신원을 확인하는 upload key이며, 사용자에게 배포되는 APK의 app signing key는 Google Play가 관리하도록 설정하는 것을 권장합니다.

## 인증서 지문

- SHA-1: `73:DB:A0:8D:38:95:A9:AA:37:86:D4:69:78:69:DE:D6:92:8B:65:CA`
- SHA-256: `1D:9A:18:76:9A:8A:7F:FC:8F:A1:B7:11:13:8D:C0:2F:D6:72:34:2E:F4:38:2F:29:30:C6:B8:BC:14:23:AE:B9`

비밀번호는 이 문서에 기록하지 않습니다. 키를 분실하면 Play Console의 upload key 재설정 절차가 필요하며 출시 일정이 지연될 수 있습니다.
