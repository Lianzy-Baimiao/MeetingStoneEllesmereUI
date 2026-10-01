"""Validate and build both the versioned upload ZIP and the user's original ZIP."""
from pathlib import Path
import re
import subprocess
import sys
import zipfile
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
toc = ROOT / 'MeetingStoneEllesmereUI.toc'
text = toc.read_text(encoding='utf-8-sig')
version = re.search(r'^## Version: (.+)$', text, re.M).group(1)
runtime = [line.strip() for line in text.splitlines()
           if line.strip() and not line.lstrip().startswith('#')]
files = [toc.name, *runtime, 'CHANGELOG.md']
subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', str(ROOT / 'tests'), '-v'], check=True)
lua = LuaRuntime()
for name in runtime:
    lua.execute('assert(loadstring(...))', (ROOT / name).read_text(encoding='utf-8-sig'))
print(f'Lua 5.1 syntax: {len(runtime)} files OK')

versioned = ROOT.parent / f'{ROOT.name}-{version}.zip'
with zipfile.ZipFile(versioned, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(ROOT / name, f'{ROOT.name}/{name}')
with zipfile.ZipFile(versioned) as archive:
    assert archive.testzip() is None
    assert len(archive.namelist()) == len(files)
    for name in files:
        assert archive.read(f'{ROOT.name}/{name}') == (ROOT / name).read_bytes()
original = ROOT.parent / f'{ROOT.name}.zip'
original.write_bytes(versioned.read_bytes())
assert original.read_bytes() == versioned.read_bytes()
print(f'Package verified: {versioned.name} ({versioned.stat().st_size} bytes)')
print(f'Original package updated: {original.name}')
