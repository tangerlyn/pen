# Lessons

## 검증 안 한 외부 링크·URL 규칙을 "된다"고 안내하지 않기 (2026-10-12)
- 실수: Looker Studio Linking API URL을 실제로 열어보지 않고 "링크를 열면 데이터 소스 4개가 붙은 보고서가 만들어진다"고 안내 → 템플릿 없이 ds0~ds3를 쓰면 `ds0은(는) 유효한 데이터 소스 별칭이 아닙니다` 오류
- 규칙: 내가 직접 실행해볼 수 없는 외부 서비스의 URL·설정 방식은 "시도해볼 링크"로 안내하고, 실패 시 대체 경로(수동 절차)를 처음부터 같이 준다

## 기준선 수치는 집계 명령의 출력 형식을 확인한 뒤 보고하기 (2026-10-18)
- 실수: `flutter analyze` 결과를 `grep -E "^\s+(info|warning|error)"`로 세어 "warning 0"이라고 보고 → 실제로는 기존 warning 1개(`post_repository.dart:302`)가 있었음. 총 109건인데 info 108건만 잡힌 차이를 놓침
- 규칙: 분류별 합계가 도구가 출력한 총계와 맞는지 대조한 뒤 보고한다. 안 맞으면 빠진 줄을 직접 확인한다

## 배포를 안내하기 전에 배포 대상 런타임 수명을 확인하기 (2026-11-11)
- 실수: Cloud Functions 배포 명령을 안내했는데 `functions/package.json`의 `engines.node`가 20이었고, Node 20 런타임은 2026-10-31에 폐기돼 배포가 실패함
- 규칙: functions 배포를 안내·실행하기 전에 `engines.node`를 firebase-tools의 `lib/deploy/functions/runtimes/supported/types.js` 폐기일과 대조한다. 폐기 6개월 이내면 미리 올린다
