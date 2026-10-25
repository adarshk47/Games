from pathlib import Path
import sys,json,subprocess,concurrent.futures,shutil
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/"dependencies"))
from PIL import Image,ImageDraw,ImageFont
from build_trailers import SCENES,probe,ff,run
OUT=ROOT/"Animated_Gameplay_16x9";WORK=OUT/"work"
WORK.mkdir(parents=True,exist_ok=True);(OUT/"assets").mkdir(exist_ok=True)
for n in ["Hind-Bold.ttf","Hind-Regular.ttf"]:shutil.copy2(ROOT/"assets"/n,OUT/"assets"/n)
refs=["17.jpeg","14.jpeg",None,"8.jpeg","WhatsApp Image 2026-10-20 at 8.39.27 AM.jpeg","7.jpeg","6.jpeg","4.jpeg","15.jpeg","9.jpeg","14.jpeg","17.jpeg"]
# Each scene has a full gameplay view, an animated enlarged detail, and a second state.
# Image panels cover 82.5% of the canvas; type is restricted to the top 90 pixels.
ys=[350,184,360,320,335,480,400,330,350,440,184,350]
jobs=[]
for i,s in enumerate(SCENES):
 im=Image.new("RGB",(1920,1080),"#111326");d=ImageDraw.Draw(im)
 d.rounded_rectangle((22,102,498,1058),18,fill="#21c3d1")
 d.rounded_rectangle((502,102,1418,1058),18,fill="#6a4bdf")
 d.rounded_rectangle((1422,102,1898,1058),18,fill="#e5b25e")
 im.save(WORK/f"bg_{i}.png")
 title="  ".join(s["hi"])
 jobs.append(dict(width=1920,height=1080,output=str(WORK/f"label_{i}.png"),items=[
  dict(text="MASTER G",x=32,y=23,size=38,color="#ffd37e",bold=True,hindi=False),
  dict(text=title,x=520,y=23,size=36,color="#ffffff",bold=True,hindi=True),
  dict(text=s["game"],x=1460,y=34,size=20,color="#bdbad9",bold=True,hindi=False)]))
(WORK/"text_jobs.json").write_text(json.dumps(jobs,ensure_ascii=False),encoding="utf-8")
run(["powershell.exe","-NoProfile","-ExecutionPolicy","Bypass","-File",str(ROOT/"render_text.ps1"),"-Root",str(OUT)])
for i in [2]:
 ff(["-ss",54,"-i",ROOT/"assets/recording.mp4","-frames:v",1,"-update",1,WORK/f"ref_{i}.png"])
def scene(i):
 s=SCENES[i];dur=s["d"];p=WORK/f"scene_{i:02}.mp4"
 args=["-threads",2]
 if "image" in s:args+=["-loop",1,"-framerate",30,"-i",ROOT/"assets"/s["image"]]
 else:args+=["-ss",s["t"],"-i",ROOT/"assets/recording.mp4"]
 ref=ROOT/"assets"/refs[i] if refs[i] else WORK/f"ref_{i}.png"
 args+=["-loop",1,"-framerate",30,"-i",ref,"-loop",1,"-framerate",30,"-i",WORK/f"bg_{i}.png","-loop",1,"-framerate",30,"-i",WORK/f"label_{i}.png"]
 source="scale=480:1056,crop=480:960:0:48" if "image" in s else "crop=480:960:0:48"
 # Left panel preserves all gameplay; center shows a moving close-up.
 crop_y=max(0,ys[i]-48)
 filt=f"[0:v]{source},fps=30,setpts=PTS-STARTPTS,split=2[full][detail];"
 filt+="[full]scale=460:940,setsar=1[left];"
 filt+=f"[detail]crop=464:484:8:{crop_y},zoompan=z='1.02+0.10*on/{dur*30}':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=1:s=900x940:fps=30,setsar=1[mid];"
 filt+=f"[1:v]scale=480:1056,crop=480:980:0:35,zoompan=z='1.01+0.06*on/{dur*30}':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=1:s=460x940:fps=30,setsar=1[right];"
 filt+="[2:v][left]overlay=30:110[a];[a][mid]overlay=510:110[b];[b][right]overlay=1430:110[c];"
 filt+=f"[c]eq=saturation=1.24:contrast=1.035:brightness=0.008:gamma=1.06[graded];[graded][3:v]overlay=0:0,fade=t=in:d=0.10,fade=t=out:st={dur-.1}:d=0.10,format=yuv420p[v]"
 ff(args+["-filter_complex_threads",2,"-filter_complex",filt,"-map","[v]","-an","-t",dur,"-c:v","libx264","-threads",2,"-preset","fast","-crf",19,p])
 print(f"Scene {i+1}/12 ready",flush=True)
 return p
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:paths=list(pool.map(scene,range(12)))
cat=WORK/"concat.txt";cat.write_text("\n".join(f"file '{p.as_posix()}'" for p in paths))
final=OUT/"Master_G_Hindi_16x9_Animated_80percent_56s.mp4"
ff(["-f","concat","-safe",0,"-i",cat,"-i",ROOT/"Vibrant_Synced/work/mix_Hindi.wav","-map","0:v","-map","1:a","-c:v","copy","-af","loudnorm=I=-16:TP=-1.5:LRA=7","-c:a","aac","-b:a","192k","-t",56,"-movflags","+faststart",final])
ff(["-ss",39,"-i",final,"-frames:v",1,"-update",1,OUT/"Preview.jpg"])
info=probe(final);v=next(s for s in info["streams"] if s["codec_type"]=="video")
assert int(v["nb_frames"])==1680 and abs(float(v["duration"])-56)<.05
ff(["-i",final,"-f","null","-"])
(OUT/"verification.json").write_text(json.dumps({"duration":56,"resolution":[1920,1080],"frames":1680,"visual_area_percent":82.5,"audio":"Same scene-synced Hindi female narration","animation":"Live gameplay plus continuous pan/zoom on detail and screenshot panels","decode_ok":True},indent=2))
print("VERIFIED "+str(final),flush=True)
