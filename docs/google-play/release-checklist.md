# Flow 1.0.0 Google Play 출시 체크리스트

## 코드와 산출물

- [x] 고유 applicationId/namespace `com.gitzzang.flow`
- [x] 버전 `1.0.0+1`
- [x] API 36 타깃
- [x] 불필요한 `INTERNET`/저장소 권한 없음
- [x] Android 자동 백업 및 기기 간 데이터 이전 제외
- [x] cleartext 트래픽 차단
- [x] 별도 upload key 및 release signing 구성
- [x] 백업 평문 안내, 공유 후 임시 파일 삭제, 시작 시 오래된 파일 정리
- [x] 가져오기 10 MiB 제한과 구조·개수·문자열 길이 검증
- [x] PIN 실패 횟수 기록 및 10회 실패 시 1분 제한
- [x] 앱 내부 개인정보 처리 안내
- [x] `flutter analyze` 무경고, 전체 테스트 18개, Android release lint 성공
- [x] 서명된 release AAB 생성 및 인증서 검증
- [x] release APK 16 KB ZIP 정렬 및 모든 네이티브 ELF LOAD segment 정렬 검증 성공

## 스토어 자료

- [x] 한국어 앱 이름/간단한 설명/자세한 설명 초안
- [x] Data safety 답변 초안
- [x] 앱 액세스/광고/등급/타겟층 답변 초안
- [x] 개인정보처리방침 Markdown/HTML 초안
- [x] 1024×500 Feature Graphic
- [x] 개인정보처리방침의 공개 연락 경로 반영
- [x] 개인정보처리방침을 공개 HTTPS URL에 게시
- [x] 1080×1920 실제 앱 UI 렌더 스크린샷 4장

## 실기기 점검

- [ ] Android 16(API 36) 신규 설치와 실행
- [ ] 상태바/내비게이션 바/edge-to-edge/키보드 겹침
- [ ] 프롬프트 생성·편집·검색·복사·공유
- [ ] 폴더·태그·고정·정렬
- [ ] 사진 선택·표시·삭제
- [ ] PIN 설정, 오입력 제한, 앱 재시작, 백그라운드 재잠금
- [ ] 생체인증 성공/취소/실패 후 PIN 대체 경로
- [ ] 백업 내보내기, 정상 복원, 깨진 JSON 및 10 MiB 초과 거부
- [ ] 다크 모드, 작은 화면, 가로 화면, 큰 글꼴

## 사용자/Play Console 단계

- [ ] `android/app/upload-keystore.jks`와 `android/key.properties`를 암호화된 별도 저장소 두 곳에 백업
- [ ] Play Console에서 앱 생성(기본 언어 한국어, 앱 이름 Flow, 앱/무료)
- [ ] Play App Signing 활성화(앱 서명 키는 Google 생성 권장)
- [ ] Play Console에 공개 개인정보처리방침 URL 입력: `https://flow-privacy-policy.ppppjjwww.chatgpt.site`
- [ ] 스토어 등록정보와 그래픽/스크린샷 업로드
- [ ] Data safety, 앱 액세스, 광고, 콘텐츠 등급, 타겟층 설문 제출
- [ ] 내부 테스트 트랙에 AAB 업로드
- [ ] 자동 사전 출시 보고서와 정책 경고 확인
- [ ] 내부 테스터 설치·스모크 테스트 후 프로덕션 출시 신청

> Play Console 계정 생성, 개발자 신원/결제 확인, 정책 설문 제출과 최종 출시 버튼은 계정 소유자가 직접 확인해야 합니다.
