import hashlib,json,pathlib,urllib.request
root=pathlib.Path(".cache/city-packs");root.mkdir(parents=True,exist_ok=True)
ref="0f354850b474a1be5a714fec3a40f9d0c7705e9a"
items=[{"name":"index.world.pck","size":17422336,"sha":"96aa425b262e0114c1b2a502596a1436c113dff5"},{"name":"index.polyart.pck","size":17002496,"sha":"5d28403bccaa60abed5240c37e811b887bb46899"},{"name":"index.polyart_s3tc.pck","size":18803872,"sha":"2d7ea9bf5ceb51cd26394b5ce1ea3a31c8892eec"},{"name":"index.polyart_s3tc2.pck","size":2188224,"sha":"c1706e389b08f1841231c675d779e5af67cb77a1"}]
for item in items:
 p=root/item["name"]
 url=f"https://raw.githubusercontent.com/darknightxx/project-meadow-play/{ref}/test-main/{p.name}"
 urllib.request.urlretrieve(url,p)
 raw=p.read_bytes()
 assert len(raw)==item["size"],p
 digest=hashlib.sha1(f"blob {len(raw)}".encode()+b"\0"+raw).hexdigest()
 assert digest==item["sha"],p
 print(p.name,len(raw),digest)
