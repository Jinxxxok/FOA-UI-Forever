# 던전 지도 · 보스 위치 뽑기

`tools/mapreveal` 의 CASC 읽기(casc.py · wdc5.py)를 같이 쓴다. 내 컴퓨터에 깔린 게임 파일에서만 읽는다.

- step6: 포에버 UiMap 표 확인 (포에버에는 던전 지도 표가 없음)
- step7~9: 본섭 UiMapXMapArt · UiMapArtTile 로 던전 지도 타일 파일 번호 → 그 파일이 포에버 게임 파일에도 있는지 확인 (전부 있음)
- step11~13: 본섭 JournalEncounter(던전 도감) → 보스 이름 · 지도 · 위치
- step14: dmaps.json 으로 정리 → `gen_dmaps.py` 로 FOA_UI/DungeonMaps.lua
