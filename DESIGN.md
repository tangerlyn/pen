# PENGWYN Design System

## 1. Atmosphere & Identity

PENGWYN은 만년필·잉크·노트를 차분하게 기록하고 공유하는 커뮤니티다. 화면은 종이처럼 밝고 여백이 넉넉하며, 네이비 한 색으로 신뢰감과 집중도를 만든다. 장식보다 필기구 사진과 사용자의 기록이 주인공이어야 한다.

## 2. Color

- Primary: `#1B2E4B`. 주요 버튼, 선택 상태, 핵심 아이콘에만 사용한다.
- Background/Surface: `#FFFFFF`. 앱 기본 배경과 카드 표면이다.
- Tinted app bar: `#F0F5FD`. 상단 영역을 본문과 부드럽게 구분한다.
- Primary text: `#1A1A1A`; secondary: `#757575`; tertiary: `#BDBDBD`.
- Divider: `#EEEEEE`; neutral chip: `#F2F4F7`.
- Error/success/warning은 각각 `#E53935`, `#43A047`, `#FB8C00`을 사용한다.
- 상태를 색만으로 전달하지 않는다. 선택, 오류, 성공에는 텍스트·아이콘·형태 중 하나를 함께 제공한다.

## 3. Typography

- 기본 글꼴은 Pretendard다.
- 화면 제목은 20–28sp, 카드·앱바 제목은 14–18sp, 본문은 12–16sp, 보조 라벨은 10–14sp 범위의 기존 `AppTextStyles` 토큰을 사용한다.
- 굵기는 제목 600–700, 본문 400, 라벨 400–600으로 제한한다.
- 한국어 본문은 임의 자간을 주지 않는다. 섹션 제목의 `-0.3` 자간만 기존 예외로 유지한다.
- 시스템 글자 크기 확대에서도 제목, 버튼, 하단 탐색이 잘리거나 넘치지 않아야 한다.

## 4. Spacing & Layout

- 기본 단위는 4dp이며 `4, 8, 12, 16, 20, 24, 32` 토큰을 사용한다.
- 화면 좌우 기본 여백은 16dp, 목록 항목은 좌우 20dp를 기준으로 한다.
- 필터·정렬·검색은 결과 목록보다 먼저 배치하고, 결과와 같은 스크롤 문맥을 유지한다.
- 44×44dp 이상의 터치 영역을 확보하고 SafeArea와 키보드 인셋을 보존한다.
- 기능 화면은 screen, controller/provider, feature widget으로 분리한다. 화면 파일은 조립과 내비게이션을, 컨트롤러는 상태 전이를, 위젯은 표시를 담당한다.

## 5. Components

- Buttons: 기본/외곽 버튼은 높이 52dp와 pill 형태를 사용한다. 비활성 상태는 동작하지 않음을 명확히 보여야 한다.
- Cards: 12dp radius와 네이비 8–9% 그림자를 사용하며 중첩 카드 그림자는 피한다.
- Chips: 20dp radius, 중립 배경과 네이비 선택 배경을 사용한다.
- Lists: 구분선은 `#EEEEEE`; 빈 상태, 로딩, 오류, 더 불러오기 상태를 각각 제공한다.
- Search: 리뷰와 커뮤니티 결과는 각자의 로딩·커서·종료 상태를 가진다. 전체 검색에서도 두 섹션은 독립적으로 더 불러온다.
- Bottom sheets: 위쪽 모서리 20dp, 드래그 핸들, SafeArea를 유지한다.

## 6. Motion & Interaction

- iOS와 Android 모두 Cupertino 페이지 전환을 사용하는 현재 정책을 유지한다.
- 탭 피드백은 짧은 scale/opacity 변화로 제한하고 상태 변경을 지연시키지 않는다.
- 무한 스크롤은 끝에서 약 200dp 전에 요청하며 중복 요청을 막는다.
- 네트워크 요청 중 새 검색이 시작되면 이전 결과가 현재 검색 상태를 덮어쓰지 못해야 한다.

## 7. Depth & Surface

- 깊이는 네이비 기반의 낮은 불투명도 그림자로만 표현한다.
- 일반 카드는 blur 10/offset 2, 강조 카드는 blur 16/offset 4를 사용한다.
- 하단 탐색은 별도 `AppShadows.nav`를 사용한다.
- 유리 효과는 기존 `AppGlass`의 80% 흰색, blur 10 범위에서만 사용한다.

## 8. Accessibility Constraints & Accepted Debt

- 본문 텍스트는 가능하면 4.5:1, 아이콘·대형 텍스트는 최소 3:1 대비를 목표로 한다.
- 시스템 최대 글자 크기에서 RenderFlex overflow, 텍스트 잘림, 가려진 액션이 없어야 한다.
- 이미지에는 의미 있는 semantics를 제공하고, 아이콘 전용 버튼은 tooltip 또는 semantic label을 가진다.
- 키보드와 스크린 리더 순서는 화면의 시각적 순서와 같아야 한다.
- 현재 `textTertiary #BDBDBD`를 흰 배경의 핵심 탐색 아이콘/라벨에 사용한 부분과 고정 높이 하단 탐색의 큰 글자 overflow는 기존 부채다. 이번 구조 분리에서 새로 확산하지 않으며 별도 접근성 수정 대상으로 기록한다.
