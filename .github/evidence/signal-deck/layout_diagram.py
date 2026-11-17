"""Layout diagram of the Signal deck from services/deck.js (not a render)."""
import json, shutil, subprocess, sys
from pathlib import Path
root = Path(sys.argv[1]); out = Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
src = (root/"services/deck.js").read_text().replace(".pragma library","",1)
# (label, physical WxH, scale, bar edge thickness, margin)
screens = [
 ("1920x1080 @1", 1920,1080,1.0,False),
 ("1920x1080 @1 + desktop clock bottom-right", 1920,1080,1.0,True),
 ("2560x1440 @1.25", 2560,1440,1.25,False),
 ("3840x2160 @2", 3840,2160,2.0,False),
 ("1366x768 @1", 1366,768,1.0,False),
 ("3440x1440 @1 ultrawide", 3440,1440,1.0,False),
]
BAR, MARGIN = 40, 48   # top bar thickness + shell margin, logical px
def compose(w,h,withclock):
    RES = "[clock]" if withclock else "[]"
    expr = f"""const a={{width:{w},height:{h}}};
      const clock={{x:{w}-420,y:{h}-240,width:420,height:240}};
      return compose({{area:a, items:items({{}}), hidden:[], reserved:{RES}, saved:{{}}}});"""
    r = subprocess.run(["node","-e",src+"\nconsole.log(JSON.stringify((()=>{"+expr+"})()));"],capture_output=True,text=True,check=True)
    return json.loads(r.stdout), (w-420,h-240,420,240)
S=0.18
parts=[]; y0=20; maxw=0
for label,pw,ph,sc,wc in screens:
    lw,lh=round(pw/sc),round(ph/sc)
    aw,ah=lw-2*MARGIN, lh-BAR-2*MARGIN
    res,clock=compose(aw,ah,wc)
    W,H=lw*S,lh*S
    g=[f'<text x="20" y="{y0}" font-family="IBM Plex Mono,monospace" font-size="13" fill="#E6E8EA">{label} → logical {lw}x{lh}, widget area {aw}x{ah}, shown {len(res["placements"])}/6, dropped {len(res["dropped"])}</text>']
    oy=y0+10
    g.append(f'<rect x="20" y="{oy}" width="{W}" height="{H}" fill="#0E1114" stroke="#3A4047"/>')
    g.append(f'<rect x="20" y="{oy}" width="{W}" height="{BAR*S}" fill="#1B2025" stroke="#3A4047"/>')
    ox,oyy=20+MARGIN*S, oy+(BAR+MARGIN)*S
    g.append(f'<rect x="{ox}" y="{oyy}" width="{aw*S}" height="{ah*S}" fill="none" stroke="#3A4047" stroke-dasharray="3 3"/>')
    cx,cy,cw,ch=clock
    if wc: g.append(f'<rect x="{ox+cx*S}" y="{oyy+cy*S}" width="{cw*S}" height="{ch*S}" fill="#2A2F35" stroke="#A8ABAD" stroke-dasharray="2 2"/><text x="{ox+cx*S+4}" y="{oyy+cy*S+12}" font-size="9" fill="#A8ABAD" font-family="IBM Plex Mono,monospace">clock (reserved)</text>')
    for p in res["placements"]:
        g.append(f'<rect x="{ox+p["x"]*S}" y="{oyy+p["y"]*S}" width="{p["width"]*S}" height="{p["height"]*S}" fill="#162029" stroke="#3FB6A8"/>')
        g.append(f'<text x="{ox+p["x"]*S+5}" y="{oyy+p["y"]*S+13}" font-size="9" fill="#E6E8EA" font-family="IBM Plex Mono,monospace">{p["id"][8:]} {p["width"]}x{p["height"]}</text>')
    for d in res["dropped"]:
        pass
    parts.append("\n".join(g)); y0=oy+H+28; maxw=max(maxw,W+40,760)
svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{maxw}" height="{y0}"><rect width="100%" height="100%" fill="#0A0C0E"/>'+"\n".join(parts)+"</svg>"
(out/"deck-layout.svg").write_text(svg)
subprocess.run(["rsvg-convert","-o",str(out/"deck-layout.png"),str(out/"deck-layout.svg")],check=True)
