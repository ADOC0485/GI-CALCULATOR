"""Build-time only. Spanish names by game ID from a pinned genshin-db archive.

Usage: python -I tool/build_spanish_names.py
Reads .catalog-cache/genshin-db-<rev>.zip (downloaded by build_offline_catalog.py)
and writes assets/catalog/nombres-es.json.
"""
import json
import re
import sys
import zipfile
from pathlib import Path

DB_REV = '8e5badd60b5d894284ccc927a56c9683529d2592'
ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / '.catalog-cache' / f'genshin-db-{DB_REV}.zip'
OUTPUT = ROOT / 'assets' / 'catalog' / 'nombres-es.json'
TIER = re.compile(r'\s+(I|II|III|IV|V|VI)$')


def main():
    if not ARCHIVE.exists():
        sys.exit(f'Falta {ARCHIVE}; ejecuta antes tool/build_offline_catalog.py')
    archive = zipfile.ZipFile(ARCHIVE)
    prefix = f'genshin-db-{DB_REV}/src/data/'

    def folder(language, category):
        start = f'{prefix}{language}/{category}/'
        for name in archive.namelist():
            if name.startswith(start) and name.endswith('.json'):
                yield name[len(start):], json.loads(archive.read(name))

    names = {}
    for category, kind in [('materials', 'material'), ('characters', 'character'),
                           ('weapons', 'weapon')]:
        for _, data in folder('Spanish', category):
            if isinstance(data.get('id'), int) and data.get('name'):
                names[f'{kind}:{data["id"]}'] = data['name']
    english = {file: data for file, data in folder('English', 'domains')}
    for file, data in folder('Spanish', 'domains'):
        source = english.get(file)
        if source and source.get('name') and data.get('name'):
            names[f'domain:{TIER.sub("", source["name"])}'] = TIER.sub('', data['name'])
    payload = {
        'source': f'https://github.com/theBowja/genshin-db/tree/{DB_REV}',
        'license': 'MIT (genshin-db, copyright theBowja)',
        'names': dict(sorted(names.items())),
    }
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=0), encoding='utf-8')
    print(f'{len(names)} nombres -> {OUTPUT}')


if __name__ == '__main__':
    main()
