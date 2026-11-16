"""Check syntax and package-local Markdown destinations/anchors without applications."""
import ast
from pathlib import Path
import re
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]


def prose(path):
    text = path.read_text(encoding='utf-8')
    return re.sub(r'^```.*?^```[^\n]*$', '', text, flags=re.M | re.S)


def anchors(path):
    found = set()
    counts = {}
    for heading in re.findall(r'^#{1,6} +(.+?) *#*$', prose(path), re.M):
        anchor = re.sub(r'[^\w\- ]', '', heading.lower()).replace(' ', '-')
        count = counts.get(anchor, 0)
        counts[anchor] = count+1
        found.add(anchor if count == 0 else anchor+'-'+str(count))

    return found


checked = 0
for path in ROOT.rglob('*.md'):
    text = prose(path)
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
        target = target.strip().strip('<>')
        if re.match(r'[a-zA-Z][a-zA-Z0-9+.-]*:', target):
            continue
        location, _, fragment = unquote(target).partition('#')
        resolved = (path.parent/location).resolve() if location else path
        assert resolved.is_relative_to(ROOT), (path, 'outside package', target)
        assert resolved.is_file(), (path, 'missing', target)
        if fragment:
            assert resolved.suffix == '.md' and fragment in anchors(resolved), (path, 'missing anchor', target)
        checked += 1
    for target in re.findall(r'`((?:scripts|tests|references|improvements)/[^` ]+\.(?:md|py|ps1|js))`', text):
        assert (ROOT/target).is_file(), (path, 'missing root-relative command/reference', target)
for path in ROOT.rglob('*.py'):
    ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
assert len(list(ROOT.rglob('SKILL.md'))) == 1
assert len(list(ROOT.rglob('openai.yaml'))) == 1
print('PASS: Python syntax, single Skill/agent entry and', checked, 'local Markdown links/anchors')
