# 검증된 빌드 산출물

검증일: 2026년 8월 17일

## Play Console 업로드 파일

- 경로: `build/app/outputs/bundle/release/app-release.aab`
- 크기: 약 43.6 MB
- AAB SHA-256: `04F1A874ACE22A1BFDE5C6E2FB0B18B0B89E9338C4517E437FFB2AF64248863B`
- 서명자: `CN=Flow Upload, O=gitzzang, C=KR`
- `jarsigner -verify`: 성공

## 설치 테스트용 파일

- 경로: `build/app/outputs/flutter-apk/app-release.apk`
- Android build-tools 36.0.0 `zipalign -c -P 16 -v 4`: 성공
- NDK 28.2 `llvm-readelf -lW`: APK 내 12개 `.so`의 모든 최소 LOAD alignment가 `0x4000` 이상(`0x4000` 또는 `0x10000`) — 16 KB ELF 정렬 성공

빌드를 다시 생성하면 파일 SHA-256은 달라질 수 있으므로 업로드 직전에 다시 기록합니다.
