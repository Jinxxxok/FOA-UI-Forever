# FOA UI — First of All (Forever)

**월드 오브 워크래프트: 포에버(WoW Forever)** 용 통합 UI 애드온입니다.

> 본섭(리테일)용은 [foa-ui](https://github.com/Jinxxxok/foa-ui) 저장소를 쓰세요.

- 지원 버전: 포에버 1.60.x (인터페이스 16001)
- 설정: 게임 안에서 `/foa` 또는 ESC 메뉴의 **FOA UI** 버튼

## 설치

### WowUp으로 설치 (자동 업데이트 · 추천)
1. WowUp 위쪽에서 게임 버전을 **World of Warcraft Forever** 로 고릅니다.
2. **Get Addons(애드온 받기)** 에서 `FOA` 를 검색해 설치합니다.
   (검색에 아직 안 나오면 **Install from URL** 에 `https://github.com/Jinxxxok/FOA-UI-Forever` 를 넣어도 똑같이 설치됩니다.)
3. 새 버전이 올라오면 WowUp 에 업데이트가 뜹니다. **업데이트 → 게임 접속** 하면 끝입니다.

### 직접 설치
1. [Releases](https://github.com/Jinxxxok/FOA-UI-Forever/releases) 에서 최신 `FOA_UI-forever-vX.X.X.zip` 을 받습니다.
2. 압축을 풀어 나온 `FOA_UI` 폴더를 `World of Warcraft/_forever_/Interface/AddOns/` 에 넣습니다.
   (본섭의 `_retail_` 폴더가 아니라 **`_forever_`** 폴더입니다.)
3. 캐릭터 선택 화면의 **애드온** 목록에서 드롭다운을 **모든 캐릭터** 로 두고 FOA UI 를 켭니다.

이미지(아이콘 / 글꼴)가 바뀐 버전으로 업데이트한 뒤에는 **게임을 완전히 껐다 켜야** 합니다.

## 포에버에서 알아둘 점

- 포에버는 본섭과 같은 엔진이라 기능 대부분이 같지만, 클래식 콘텐츠라 없는 기능은 오류 없이 자동으로 빠집니다.
  (예: 그 시절에 없던 직업 자원, 보스 타임라인이 없으면 보스 알림)
- 설정과 위치는 본섭과 따로 저장됩니다.

## 명령어

| 명령어 | 기능 |
|---|---|
| `/foa` | 설정 창 |
| `/foa edit` | 편집 모드 (위치 옮기기) |
| `/foa test` | 테스트 모드 |
| `/foa kb` | 빠른 단축키 설정 |
| `/foa reset` | 지금 캐릭터 위치 초기화 |
| `/foa log` | 막힌 동작 기록 보기 (오류 제보용) |

## 다른 애드온과 같이 쓸 때

ElvUI 같은 통합 UI 와는 함께 쓰지 마세요. 네임플레이트 / 가방 / 미터기 / 보스 알림 애드온을 쓰면 FOA 설정 창에서 해당 기능을 끄세요.

## 라이선스

FOA UI 는 **GNU General Public License v3.0 (또는 그 이후 버전)** 으로 배포됩니다. 전문: [`LICENSE`](LICENSE) · `FOA_UI/LICENSE.txt`

고쳐서 다시 배포할 때도 GPL-3.0 을 따라야 하고, 소스를 함께 공개해야 합니다. 퀘스트 자료 일부가 GPL-3.0 인 QuestieDB 에서 왔기 때문입니다 (아래 자료 출처).

## 사용한 자료와 라이선스

- 글꼴: IBM Plex Sans KR, Inter, Space Grotesk — SIL Open Font License 1.1
- 아이콘: Lucide — ISC License

## 자료 출처

- 던전 보스 · 전리품, 퀘스트 · 비행 지점 자료: [AllTheThings](https://github.com/ATTWoWAddon/AllTheThings) (MIT License · `FOA_UI/LICENSE-AllTheThings.txt`)
- 던전 한글 이름 · 권장 레벨 · 보스 순서, 직업 기술 레벨, 전문기술 빠른 레벨링 경로, 특성 레벨업 순서: [wowf.io](https://wowf.io/ko)
- 퀘스트 선행 · 택일 · 연결 퀘스트 · 조건(숙련도 · 평판 · 레벨) · 보고 NPC 와 자리: [QuestieDB](https://github.com/Questie/QuestieDB) 포에버 합본 자료 (GPL-3.0 · 포에버 실제 플레이 기록으로 확인한 선행 관계 포함 · `FOA_UI/LICENSE-QuestieDB.txt` · 만드는 방법은 `tools/quests/questie_export.py` → `tools/quests/gen_quests.py`)
- 포에버에서 바뀐 지도 경계(스톰윈드 · 동부 역병지대 · 멀고어 · 붉은마루 산맥) 변환식: QuestieDB 자료와 대조해 확인 (`tools/maps/forever_frame_fixes.json`)
- 아이콘: [Lucide](https://lucide.dev) (ISC License · `FOA_UI/Media/Icons/LICENSE-lucide.txt`)
