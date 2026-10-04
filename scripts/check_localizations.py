"""Validate translated keys and printf argument signatures before cloud compilation."""
from pathlib import Path
import json, re
root = Path(__file__).resolve().parents[1]
def read(locale):
    text = (root/'Sources'/f'{locale}.lproj'/'Localizable.strings').read_text(encoding='utf-8')
    pairs = re.findall(r'("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*")\s*;', text)
    result = {json.loads(k): json.loads(v) for k,v in pairs}
    assert len(result) == len(pairs), f'{locale}: duplicate keys'
    return result
english, chinese = read('en_US'), read('zh_Hans_CN')
assert english.keys() == chinese.keys(), 'Locale key sets differ'
literal = r'@("(?:[^"\\]|\\.)*")'
source = '\n'.join(p.read_text(encoding='utf-8') for p in (root/'Sources').glob('*.m'))
direct = {json.loads(k) for k in re.findall(r'IG[TF]\(\s*'+literal, source)}
assert direct <= english.keys(), f'Missing direct keys: {direct-english.keys()}'
formats = re.compile(r'%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|ll|[hljztL])?[@diuoxXfFeEgGaAcsp%]')
for key in english:
    assert formats.findall(english[key]) == formats.findall(chinese[key]), f'Format mismatch: {key}'
    assert chinese[key], f'Empty translation: {key}'
print(f'{len(english)} bilingual strings validated; direct keys and format signatures match.')
