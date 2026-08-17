# Flow

Flow는 자주 사용하는 AI 프롬프트를 폴더와 태그로 정리하고 빠르게 복사·공유하는
Android/iOS 전용 Flutter 앱입니다.

## 주요 기능

- 프롬프트 생성, 편집, 복제, 고정, 검색 및 태그 필터
- 갤러리·카메라 이미지 첨부, 썸네일 및 확대 보기
- 프롬프트 구간별 색상 편집 및 카드 표시
- 반응형 모바일 카드 그리드와 빠른 폴더 이동
- 폴더 생성, 이름 변경, 삭제 및 드래그 재정렬
- 프롬프트 클립보드 복사와 Android/iOS 공유 시트
- PIN 및 생체인증 잠금, 백그라운드 자동 잠금
- Keychain/Keystore 기반 PIN 해시 저장
- 첨부 이미지를 포함하고 PIN은 제외하는 JSON 백업·복원
- 다크 모드, 터치 진동, 카드 글자 크기 및 접근성 대응

## 실행

```powershell
flutter pub get
flutter run -d android
```

iOS 빌드와 실제 기기 검증은 macOS와 Xcode가 필요합니다.

```bash
flutter run -d ios
```

## 검증

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

로컬 데이터 키 `flow_store_v1`은 이전 버전과 호환됩니다. 기존 평문 PIN은 첫 실행 시
보안 저장소로 이전되며, 새 백업에는 PIN이나 PIN 해시가 포함되지 않습니다.
