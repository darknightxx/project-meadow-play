from pathlib import Path
import os,re
build='meadow-city-preview-20261126-'+os.environ['GITHUB_SHA'][:8]
p=Path('city-preview-src/game/city.gd')
p.write_text(re.sub(r'const BUILD_ID := "[^"]+"',f'const BUILD_ID := "{build}"',p.read_text()))
