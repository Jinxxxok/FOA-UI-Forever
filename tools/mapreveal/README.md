# 지도 밝히기 자료 뽑기

내 컴퓨터에 깔린 포에버 게임 파일(CASC)에서 직접 읽는다. 다른 애드온 자료는 쓰지 않는다.

1. `step1.py`: 빌드 설정 → encoding → root 읽기 (`casc.py`: 로컬 인덱스 · BLTE)
2. `step2.py`: root(MFST v2)에서 파일 번호 → 내용 키
3. `step3.py`: `WorldMapOverlayTile.db2`(1957212) · `WorldMapOverlay.db2`(1134579) 꺼내기
4. `step5.py`: WDC5 표 읽기(`wdc5.py`) → 지도 그림별 덮개 크기 · 위치 · 타일 파일 번호 → `reveal.json`
5. `reveal.json` → `FOA_UI/MapRevealData.lua`
