# 포에버 특성 가이드 데이터

FOA 특성 가이드는 세 가지 보기를 쓴다: **육성 · PvE · PvP** (특성 창 오른쪽 안내판의 세그먼트).

## 육성 — `FOA_UI/TalentData.lua`

- `en_builds.txt`: wowf.io 영문 레벨업 가이드의 특성 순서 (`레벨|이름|아이콘|목표/최대`).
- 아이콘 이름 → 파일 번호는 wowdev/wow-listfile 로 바꿔서 `TalentData.lua` 를 만든다.
- 게임 안에서는 아이콘 파일 번호로 특성을 찾으므로 한글/영문 클라이언트 모두 맞는다.

## PvE · PvP — `FOA_UI/TalentBuilds.lua` (게임 빌드 1.60.1, 2026-11-16)

| 출처 | 내용 |
|---|---|
| [RankedBoost 직업별 빌드](https://rankedboost.com/world-of-warcraft/forever/build/) | 직업마다 특성 칸 표(노드 번호 · 아이콘 파일 · 최대 단계 · 트리 · 줄) + PvE(레이드 · 탱커 · 힐러) · PvP 기본 빌드 |
| [Mobalytics 인증 PvP 공략](https://mobalytics.gg/wow-forever/pvp-class-guides) | 도적(Perplexity) · 전사(Omnivore) · 사냥꾼(Feor · Captain) · 사제(Hydra) PvP 빌드와 레벨별 찍는 순서 |
| [Kami-labs](https://kami-labs.fr/en/wow-forever/builds/) | 잠행 도적 PvE (RankedBoost 에 없음) · 특성 문자열을 RankedBoost 칸 순서(트리별 줄 → 칸)로 풀었다 |

- 두 사이트의 특성 칸 번호(노드)는 같은 게임 번호다 → 게임 안에서는 **노드 번호로 먼저** 찾고, 없으면 아이콘으로 찾는다.
- 찍는 순서: Mobalytics 는 작성자의 레벨별 순서를 그대로, 나머지는 가장 깊은 트리부터 위 줄 → 아래 줄 (같은 줄 선행 특성 먼저).
  작성자 순서가 줄 조건(줄마다 그 트리 5점)을 어기면 그 점수만 조건이 풀릴 때까지 뒤로 미룬다 (전사 "전장 기본" · 사제 "신성 깊게").
- 검사: 모든 빌드 51점 · 최대 단계 이하 · 줄 조건 통과 · 같은 배분 중복 없음.
- 형식: `nodes[직업] = "노드|아이콘|최대|트리|줄|영문 이름;..."`, `list = { "직업:전문화", 모드, 이름, 출처, "노드:목표 ..." }`.
