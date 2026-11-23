"""Build-time only. Download pinned factual data; never called by the app."""
import json
import io
import zipfile
import urllib.request
from pathlib import Path

API_REV = '62af3592e7ef4498d90e68e7967096c5aabc8f33'
DB_REV = '8e5badd60b5d894284ccc927a56c9683529d2592'
CACHE = Path('.catalog-cache')

def archive(repo, revision):
    target = CACHE / f'{repo.split("/")[-1]}-{revision}.zip'
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        request = urllib.request.Request(f'https://codeload.github.com/{repo}/zip/{revision}', headers={'User-Agent': 'GI-Calculator-catalog-builder'})
        with urllib.request.urlopen(request, timeout=120) as response:
            target.write_bytes(response.read())
    return zipfile.ZipFile(io.BytesIO(target.read_bytes()))

def files(archive, prefix):
    result = {}
    for name in archive.namelist():
        relative = name.split('/', 1)[-1]
        if relative.startswith(prefix) and relative.endswith('.json'):
            result[relative] = json.loads(archive.read(name))
    return result

def prepare():
    api = files(archive('devesh-anand/genshin-api', API_REV), 'data/')
    db_zip = archive('theBowja/genshin-db', DB_REV)
    english = files(db_zip, 'src/data/English/')
    spanish = files(db_zip, 'src/data/Spanish/')
    (CACHE / 'offline-sources.json').write_text(json.dumps({'api': api, 'english': english, 'spanish': spanish}, ensure_ascii=False), encoding='utf-8')
    print(f'Cached {len(api)} API files, {len(english)} English and {len(spanish)} Spanish files.', flush=True)
    return api, english, spanish

if __name__ == '__main__':
    prepare()
