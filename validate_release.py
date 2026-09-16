#!/usr/bin/env python3
"""Verify the complete 1.3.2 B42.20-only payload; no game or network access."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat

EXPECTED_TREE = 'd6d43d081cc79e653b7f03b365a4cd15926b28b0'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def git_hash(kind, data):
    return hashlib.sha1(kind.encode() + b' ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def tree_hash(files):
    root = {}
    for name, digest in files.items():
        node = root
        parts = name.split('/')
        for part in parts[:-1]:
            node = node.setdefault(part, {})
        node[parts[-1]] = digest
    def visit(node):
        data = bytearray()
        for name, value in sorted(node.items(), key=lambda kv: (kv[0] + ('/' if isinstance(kv[1], dict) else '')).encode('utf-8')):
            directory = isinstance(value, dict)
            data.extend((b'40000 ' if directory else b'100644 ') + name.encode('utf-8') + b'\0')
            data.extend(bytes.fromhex(visit(value) if directory else value))
        return git_hash('tree', bytes(data))
    return visit(root)


def validate(root):
    root = Path(root).absolute()
    mod = root / 'workshop/Contents/mods/LegacyJournal'
    require(mod.is_dir(), 'Missing LegacyJournal source directory')
    for p in (mod, *mod.parents):
        require(not p.is_symlink(), 'Linked source path refused: ' + str(p))
    manifest = json.loads((root / 'release-manifest.json').read_text(encoding='utf-8'))
    require(manifest.get('schema') == 1 and manifest.get('version') == '1.3.2'
            and manifest.get('mod_id') == 'LegacyJournal'
            and manifest.get('workshop_id') == '3788037313', 'Wrong release identity')
    expected = manifest['files']
    require(len(expected) == 22 and 'mod.info' not in expected, 'Expected 22 B42.20-only runtime files')
    require(manifest.get('runtime_tree') == EXPECTED_TREE and tree_hash(expected) == EXPECTED_TREE,
            'Manifest is not the pinned cleaned release')
    contents = {}
    for current, dirs, names in os.walk(mod, followlinks=False):
        for name in dirs + names:
            p = Path(current) / name
            require(not p.is_symlink(), 'Source symlink refused: ' + str(p))
        for name in names:
            p = Path(current) / name
            require(stat.S_ISREG(p.stat().st_mode), 'Nonregular source file: ' + str(p))
            contents[p.relative_to(mod).as_posix()] = p.read_bytes()
    require(set(contents) == set(expected), 'Runtime file set mismatch; extra=%s missing=%s' %
            (sorted(set(contents) - set(expected)), sorted(set(expected) - set(contents))))
    for name, raw in contents.items():
        require(git_hash('blob', raw) == expected[name], 'Runtime bytes differ: ' + name)
    require((mod / 'common').is_dir(), 'common directory must be retained')
    info = contents['42.20/mod.info'].decode('utf-8-sig')
    require(re.search(r'^id=LegacyJournal\s*$', info, re.M)
            and re.search(r'^modversion=1\.3\.2\s*$', info, re.M), 'Wrong B42.20 metadata')
    tables = {}
    for locale in ('EN', 'CN', 'CH'):
        table = {}
        for group in ('ContextMenu', 'IG_UI', 'Sandbox'):
            raw = contents['42.20/media/lua/shared/Translate/%s/%s.json' % (locale, group)]
            values = json.loads(raw.decode('utf-8-sig'))
            require(not (table.keys() & values.keys()), 'Duplicate translation key')
            table.update(values)
        tables[locale] = table
    require(set(tables['EN']) == set(tables['CN']) == set(tables['CH']), 'Translation key mismatch')
    for key, value in tables['EN'].items():
        for locale in tables:
            translated = tables[locale][key]
            require(isinstance(translated, str) and translated.strip(), 'Empty translation: ' + key)
            require(sorted(re.findall(r'%\d+|%[sdif]', translated)) == sorted(re.findall(r'%\d+|%[sdif]', value)),
                    'Translation placeholders differ: ' + key)
    print('RELEASE_SOURCE_OK | Personal Journal 1.3.2 | files=22 | tree=' + EXPECTED_TREE)
    print('Offline file/metadata validation only; no game loading or Workshop upload performed.')
    return contents


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent)
    try:
        validate(parser.parse_args().root)
    except (ValueError, OSError, KeyError, TypeError) as error:
        raise SystemExit('RELEASE_SOURCE_FAILED: ' + str(error))
