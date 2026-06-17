#!/usr/bin/env python3
"""Regenerate skills.json from each <skill>/SKILL.md frontmatter.

Tolerant indentation parser (PyYAML chokes on the unquoted scalars these files use —
descriptions/triggers and produces.format values like "16:9 video" contain colons).
Run with --check to dry-run and diff against the current skills.json without writing.
"""
import json, os, re, sys, collections

ROOT = os.path.dirname(os.path.abspath(__file__))

def coerce(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ('"', "'"):
        v = v[1:-1]
    if v in ('true', 'false'):
        return v == 'true'
    return v

def strip_inline_comment(v):
    # only for list items / simple tokens — strip ' # ...' trailing comment
    m = re.match(r'^(.*?)\s+#.*$', v)
    return (m.group(1) if m else v).strip()

def parse_flow_list(s):
    s = s.strip()
    assert s.startswith('[') and s.endswith(']'), s
    inner = s[1:-1].strip()
    if not inner:
        return []
    return [coerce(x) for x in inner.split(',') if x.strip()]

def parse_flow_map(s):
    s = s.strip()
    assert s.startswith('{') and s.endswith('}'), s
    inner = s[1:-1].strip()
    out = {}
    # split on top-level commas (no nesting expected in these files)
    for part in inner.split(','):
        if ':' not in part:
            continue
        k, val = part.split(':', 1)
        out[k.strip()] = coerce(val)
    return out

def indent_of(line):
    return len(line) - len(line.lstrip(' '))

def parse_block(lines, base_indent):
    """Parse a mapping at base_indent. Returns (dict, lines_consumed)."""
    result = {}
    i = 0
    while i < len(lines):
        raw = lines[i]
        if not raw.strip() or raw.strip().startswith('#'):
            i += 1; continue
        ci = indent_of(raw)
        if ci < base_indent:
            break
        if ci > base_indent:
            # shouldn't happen at top of a key; skip defensively
            i += 1; continue
        m = re.match(r'^([\w-]+):\s?(.*)$', raw.strip())
        if not m:
            i += 1; continue
        key, val = m.group(1), m.group(2)
        if val == '':
            # gather child lines (indent > ci)
            child = []
            j = i + 1
            while j < len(lines):
                l = lines[j]
                if not l.strip():
                    child.append(l); j += 1; continue
                if indent_of(l) <= ci and not l.strip().startswith('#'):
                    break
                if indent_of(l) <= ci and l.strip().startswith('#'):
                    # comment at or below this level — stop (belongs to sibling/parent)
                    break
                child.append(l); j += 1
            first = next((c for c in child if c.strip() and not c.strip().startswith('#')), '')
            if first.lstrip().startswith('- '):
                result[key] = parse_list(child)
            else:
                sub, _ = parse_block([c for c in child], indent_of(first) if first else ci + 2)
                result[key] = sub
            i = j
        elif re.match(r'^[|>][+-]?$', val):
            # YAML block scalar (literal | or folded >) — collect deeper-indented lines.
            # Existing skills.json stores all of these folded to a single line, so we
            # space-join the (dedented) non-empty content lines.
            child = []
            j = i + 1
            while j < len(lines):
                l = lines[j]
                if not l.strip():
                    child.append(''); j += 1; continue
                if indent_of(l) <= ci:
                    break
                child.append(l); j += 1
            result[key] = ' '.join(c.strip() for c in child if c.strip())
            i = j
        elif val.startswith('['):
            result[key] = parse_flow_list(val); i += 1
        else:
            result[key] = coerce(val); i += 1
    return result, i

def parse_list(lines):
    items = []
    k = 0
    while k < len(lines):
        l = lines[k]
        s = l.strip()
        if not s or s.startswith('#'):
            k += 1; continue
        if not s.startswith('- '):
            k += 1; continue
        rest = s[2:].strip()
        if rest.startswith('{'):
            items.append(parse_flow_map(rest))
        elif rest == '':
            # block-map item: collect following deeper-indented lines as a map
            item_indent = indent_of(l)
            child = []
            j = k + 1
            while j < len(lines) and (not lines[j].strip() or indent_of(lines[j]) > item_indent):
                child.append(lines[j]); j += 1
            sub, _ = parse_block(child, indent_of(child[0]) if child else item_indent + 2)
            items.append(sub); k = j; continue
        elif ':' in rest and not rest.startswith('"'):
            # inline "- key: val" → single-key map (rare)
            kk, vv = rest.split(':', 1)
            items.append({kk.strip(): coerce(vv)})
        else:
            items.append(coerce(strip_inline_comment(rest)))
        k += 1
    return items

def parse_frontmatter(path):
    t = open(path).read()
    m = re.match(r'^---\n(.*?)\n---', t, re.S)
    if not m:
        return None
    lines = m.group(1).split('\n')
    fm, _ = parse_block(lines, 0)
    return fm

def build_entry(name, fm):
    e = {}
    e['type'] = fm.get('kind', 'component')
    e['description'] = fm.get('description', '')
    if 'version' in fm: e['version'] = fm['version']
    if 'visibility' in fm: e['visibility'] = fm['visibility']
    wtu = fm.get('when-to-use') or fm.get('when_to_use')
    if wtu: e['whenToUse'] = wtu
    if 'inputs' in fm: e['inputs'] = fm['inputs']
    if 'dependsOn' in fm: e['dependencies'] = fm['dependsOn']
    if 'requires' in fm: e['requires'] = fm['requires']
    if 'produces' in fm: e['produces'] = fm['produces']
    md = fm.get('metadata')
    if isinstance(md, dict) and 'hermes' in md:
        e['hermes'] = md['hermes']
    if fm.get('deprecated') is True or fm.get('deprecated') == 'true':
        e['deprecated'] = True
    if 'supersededBy' in fm: e['supersededBy'] = fm['supersededBy']
    if os.path.isfile(os.path.join(ROOT, name, 'LEARNINGS.md')):
        e['learningsFile'] = f"{name}/LEARNINGS.md"
    return e

def main():
    check = '--check' in sys.argv
    cur = json.load(open(os.path.join(ROOT, 'skills.json')))
    skills = {}
    for d in sorted(os.listdir(ROOT)):
        p = os.path.join(ROOT, d, 'SKILL.md')
        if not os.path.isfile(p):
            continue
        fm = parse_frontmatter(p)
        if fm is None:
            # No YAML frontmatter — preserve the existing catalog entry rather than drop the skill.
            prev = cur.get('skills', {}).get(d)
            if prev is not None:
                skills[d] = prev
                print(f"  NOTE: {d}/SKILL.md has no frontmatter — preserved existing entry", file=sys.stderr)
            else:
                skills[d] = {"type": "component", "description": ""}
                print(f"  WARN: {d}/SKILL.md has no frontmatter and no prior entry — minimal stub", file=sys.stderr)
            continue
        skills[d] = build_entry(d, fm)

    meta = dict(cur.get('metadata', {}))
    meta['version'] = meta.get('version', '1.1')
    meta['lastUpdated'] = '2026-06-17'
    meta['totalSkills'] = len(skills)
    meta['activeSkills'] = sum(1 for e in skills.values()
                               if e.get('visibility') != 'deprecated' and not e.get('deprecated'))
    out = {'metadata': meta, 'skills': skills}

    if check:
        old = cur['skills']
        added = sorted(set(skills) - set(old))
        removed = sorted(set(old) - set(skills))
        changed = []
        for n in sorted(set(skills) & set(old)):
            if skills[n] != old[n]:
                changed.append(n)
        print(f"total {len(skills)} | added {added} | removed {removed}")
        print(f"changed ({len(changed)}):")
        for n in changed:
            ok, nk = set(old[n]), set(skills[n])
            note = ''
            if not old[n].get('whenToUse') and not old[n].get('inputs') and not old[n].get('produces'):
                note = ' [was STUB]'
            print(f"  {n}{note}: +{sorted(nk-ok)} -{sorted(ok-nk)}")
        return

    json.dump(out, open(os.path.join(ROOT, 'skills.json'), 'w'), indent=2, ensure_ascii=True)
    open(os.path.join(ROOT, 'skills.json'), 'a').write('\n')
    print(f"wrote skills.json: {meta['totalSkills']} skills, {meta['activeSkills']} active")

if __name__ == '__main__':
    main()
