# 제작 장비 목록 뽑기 (FOA_UI/ForeverCrafts.lua)

`tools/mapreveal` 의 CASC 읽기(casc.py · wdc5.py)를 같이 쓴다. 내 컴퓨터에 깔린 포에버 게임 파일에서만 읽는다 (다른 사이트 자료 없음).

1. DB2 꺼내기: SkillLineAbility(1266278) · SpellEffect(1140088) · Item(841626)
2. SkillLineAbility: 전문기술(164 대장 · 165 가죽 · 197 재봉 · 202 기계 · 333 마부) 주문 + 노란색 시작 숙련(TrivialSkillLineRankLow)
3. SpellEffect: 효과 24(아이템 만들기) → 만들어지는 아이템 번호
4. Item 표에 있으면 무기(2) · 방어구(4)만 남기고, 없는 건 게임 안에서 착용 부위로 거른다
5. `{아이템, 전문기술, 주문, 숙련}` 로 ForeverCrafts.lua 작성

게임 안에서는 요구 레벨을 아이템 정보로 확인하고, 숙련 / 6 으로 레벨 창을 먼저 좁혀서 서버에 아이템 정보를 너무 많이 요청하지 않는다.
