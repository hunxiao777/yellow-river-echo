"""Package four seasons into offline tile pyramids. Keep logical coordinates shared."""
from PIL import Image
from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[1]
out=root/'entry/src/main/resources/rawfile/experience'
src=Image.open(sys.argv[1]).convert('RGB')
w,h=src.size
for i,name in enumerate(('spring','summer','autumn','winter')):
    x=i%2*w//2;y=i//2*h//2
    im=src.crop((x,y,x+w//2,y+h//2))
    for level in range(4):
        factor=2**(3-level)
        size=(1024//factor,1536//factor)
        reduced=im.resize(size,Image.Resampling.LANCZOS)
        for tx in range((size[0]+255)//256):
            for ty in range((size[1]+255)//256):
                p=out/f'seasons/{name}/{level}/{tx}/{ty}.jpg';p.parent.mkdir(parents=True,exist_ok=True)
                reduced.crop((tx*256,ty*256,min(size[0],(tx+1)*256),min(size[1],(ty+1)*256))).save(p,quality=92)
    if name=='spring': im.resize((1024,1536),Image.Resampling.LANCZOS).save(out/'atlas.png')
(out/'seasons/manifest.json').write_text(json.dumps(dict(logicalSize=[1024,1536],sourcePanelSize=[w//2,h//2],seasons=['spring','summer','autumn','winter'],tileSize=256,maxLevel=3),indent=2))
print('Season tiles packaged; native panel resolution:',w//2,h//2)
