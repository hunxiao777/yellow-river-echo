"""Bake real Terrarium elevations for the full Yellow River view, no synthetic peaks."""
import io, math, json, urllib.request
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.tmp/basin-dem';CACHE.mkdir(parents=True,exist_ok=True)
Z=7; W=257; H=129
def xy(lon,lat):
 return (lon+180)/360*2**Z,(1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*2**Z
x0,y0=map(math.floor,xy(95.6,42));x1,y1=map(math.floor,xy(120.4,32.8))
def tile(pair):
 x,y=pair;p=CACHE/f'{Z}-{x}-{y}.png'
 if not p.exists():
  data=urllib.request.urlopen(f'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{Z}/{x}/{y}.png',timeout=45).read()
  Image.open(io.BytesIO(data)).verify();p.write_bytes(data)
 a=np.array(Image.open(p).convert('RGB'),dtype=float)
 return x,y,a[:,:,0]*256+a[:,:,1]+a[:,:,2]/256-32768
jobs=[(x,y) for x in range(x0,x1+1) for y in range(y0,y1+1)]
full=np.zeros(((y1-y0+1)*256,(x1-x0+1)*256),dtype=float)
with ThreadPoolExecutor(6) as pool:
 for x,y,a in pool.map(tile,jobs):full[(y-y0)*256:(y-y0+1)*256,(x-x0)*256:(x-x0+1)*256]=a
out=[]
for row in range(H):
 lat=42-row/(H-1)*9.2
 for col in range(W):
  lon=95.6+col/(W-1)*24.8;x,y=xy(lon,lat)
  px=(x-x0)*256;py=(y-y0)*256;ix=int(px);iy=int(py);fx=px-ix;fy=py-iy
  h=full[iy,ix]*(1-fx)*(1-fy)+full[iy,ix+1]*fx*(1-fy)+full[iy+1,ix]*(1-fx)*fy+full[iy+1,ix+1]*fx*fy
  out.append(round(max(0,h)))
p=ROOT/'entry/src/main/ets/common/BasinElevation.ets'
p.write_text('// AWS Terrain Tiles / Mapzen (Terrarium), real DEM resampled to 257x129.\n// Sources and attribution: https://github.com/tilezen/joerd/blob/master/docs/attribution.md\nexport const BASIN_DEM: number[] = '+json.dumps(out,separators=(',',':'))+';\n',encoding='utf-8')
(CACHE/'provenance.json').write_text(json.dumps(dict(source='AWS Terrain Tiles / Mapzen Terrarium',zoom=Z,bbox=[95.6,32.8,120.4,42],width=W,height=H,min=min(out),max=max(out),tiles=len(jobs)),indent=2))
print('Real DEM saved:',len(out),'samples; range',min(out),max(out),'m;',len(jobs),'tiles')
