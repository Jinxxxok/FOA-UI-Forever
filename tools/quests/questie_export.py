#!/usr/bin/env python3
"""QuestieDB 포에버 합본 만들기 (QuestieDB 의 tools/export-forever.lua 를 그대로 돌린다)

사용: python3 -I questie_export.py <QuestieDB 폴더>
  → <QuestieDB>/src/corrections/Forever/combined/forever{Quest,Npc,Item,Object}DB.lua
셸 실행 · 파일 지우기는 막고, 폴더 만들기만 허용한다.
"""
import os, sys
from lupa import lua51

root = os.path.abspath(sys.argv[1])
os.makedirs(os.path.join(root, "src", "corrections", "Forever", "combined"), exist_ok=True)
os.chdir(root)
L = lua51.LuaRuntime(unpack_returned_tuples=True)
L.execute("os.execute = function() return 0 end; io.popen = nil; os.remove = nil; os.rename = nil")
L.globals().arg = L.table("--include-authored")
L.execute('dofile("tools/export-forever.lua")')
