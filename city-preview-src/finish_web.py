from pathlib import Path
import json, os, shutil, gzip
p=Path('city-preview-build/index.html')
html=p.read_text()
html=html.replace('<title>Meadowfall — City Preview</title>','<title>Meadowfall · เวียงธารหลิว</title>')
html=html.replace('</head>','<link rel="stylesheet" href="web-ui.css"></head>')
html=html.replace('<script src="index.js">','<script src="compressed-loader.js"></script><script src="index.js">')
assert 'compressed-loader.js' in html
html=html.replace('</body>','<script src="web-ui.js"></script></body>')
html=html.replace('width=device-width, initial-scale=1.0, user-scalable=no','width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover')
p.write_text(html)
for name in ['web-ui.js','web-ui.css','compressed-loader.js']:shutil.copy2('city-preview-src/'+name,'city-preview-build/'+name)
Path('city-preview-build/index.wasm.gz').write_bytes(gzip.compress(Path('city-preview-build/index.wasm').read_bytes(),compresslevel=9,mtime=0))
Path('city-preview-build/BUILD-ID.json').write_text(json.dumps({'id':'meadow-city-preview-20261126-'+os.environ['GITHUB_SHA'][:8],'source_commit':os.environ.get('GITHUB_SHA'),'asset_source_commit':'0f354850b474a1be5a714fec3a40f9d0c7705e9a','map_source_commit':'6d7b4f2d7276a4ebd09ac840bd615c0f64f23c63','scope':'Standalone exploration preview, not the MMO server. No real money or account changes.'},indent=2))
files={p.name:p.stat().st_size for p in Path('city-preview-build').iterdir() if p.is_file()}
assert files['index.pck']<=20*1024*1024,files
Path('city-preview-reports/build-sizes.json').write_text(json.dumps(files,indent=2))
