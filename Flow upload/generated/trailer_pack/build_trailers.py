"""Master G bilingual trailer production. All output stays beside this script."""
from pathlib import Path
import sys, json, subprocess, math, wave, concurrent.futures, asyncio
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "dependencies"))
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ASSETS = ROOT / "assets"
WORK = ROOT / "work"
WORK.mkdir(exist_ok=True)
FPS = 30
SCENES = [
    dict(d=4, t=218, game="YOUR NEXT MOVE", en=["STOP SCROLLING.", "START SOLVING."], hi=["स्क्रोल बहुत हुआ।", "अब चाल दिखाओ।"], suben="Meet your next puzzle obsession.", subhi="मिलिए अपने नए गेमिंग चैलेंज से।", ven="Enough scrolling. Time for your next move. Master G.", vhi="स्क्रोल बहुत हुआ। अब अपनी अगली चाल दिखाओ। मास्टर जी।"),
    dict(d=5, t=18, game="BLOCK PUZZLE", en=["MAKE SPACE.", "MAKE IT COUNT."], hi=["ब्लॉक्स जमाओ।", "स्कोर बढ़ाओ।"], suben="Place. Clear. Go again.", subhi="हर सही फिट के साथ आगे बढ़ो।", ven="Stack the blocks. Find the perfect fit. Keep the board alive.", vhi="ब्लॉक्स जमाओ। सही जगह ढूँढो। और बोर्ड पर अपना गेम बनाए रखो।"),
    dict(d=5, t=48, game="ARROW MAZE", en=["ONE WAY OUT.", "YOUR CALL."], hi=["रास्ता एक।", "चाल तुम्हारी।"], suben="Read the arrows. Find your route.", subhi="ऐरो समझो। अपना रास्ता खोजो।", ven="Follow the arrows. Read the maze. Can you find your way out?", vhi="ऐरो समझो। रास्ता खोजो। देखते हैं, इस भूलभुलैया से कौन निकलता है।"),
    dict(d=5, t=78, game="CHESS", en=["THINK AHEAD.", "OWN THE BOARD."], hi=["दो कदम आगे।", "बाज़ी तुम्हारी।"], suben="A little strategy. A bigger challenge.", subhi="हर चाल के पीछे एक प्लान।", ven="Switch to chess. Think a move ahead. Make every piece count.", vhi="अब चेस की बारी। दो कदम आगे सोचो। और हर चाल में अपना प्लान दिखाओ।"),
    dict(d=5, t=102, game="BALL SORT", en=["SORT THE CHAOS.", "FIND YOUR FLOW."], hi=["रंग मिलाओ।", "गेम बनाओ।"], suben="One colour. One satisfying move.", subhi="एक सही मूव। और रंग सेट।", ven="Sort the colours. Untangle the chaos. That perfect match feels good.", vhi="कलर्स सॉर्ट करो। उलझन सुलझाओ। सही मैच का सुकून ही अलग है।"),
    dict(d=4, t=122, game="2048", en=["SMALL MOVES.", "BIGGER NUMBERS."], hi=["छोटी चाल।", "बड़ा नंबर।"], suben="Swipe. Merge. Keep chasing.", subhi="स्वाइप करो। मर्ज करो। आगे बढ़ो।", ven="Swipe. Merge. Chase the next number in twenty forty eight.", vhi="स्वाइप करो। नंबर मर्ज करो। ट्वेंटी फोर्टी एट में आगे बढ़ो।"),
    dict(d=4, t=159, game="SLIDING PUZZLE", en=["SHUFFLE THE GRID.", "SOLVE THE VIBE."], hi=["टाइल्स सरकाओ।", "पज़ल सुलझाओ।"], suben="Every tile has its place.", subhi="हर टाइल की सही जगह खोजो।", ven="Slide the tiles. Find the pattern. Put your next move to the test.", vhi="टाइल्स सरकाओ। पैटर्न पकड़ो। अब अपनी अगली चाल आज़माओ।"),
    dict(d=5, t=181, game="MAZE ESCAPE", en=["GET LOST.", "THEN GET OUT."], hi=["रास्ता खोजो।", "बाहर निकलो।"], suben="A maze worth getting into.", subhi="हर मोड़ पर नया चैलेंज।", ven="Take on the maze. Every turn brings a different challenge.", vhi="मेज़ में उतर जाओ। हर मोड़ पर नया चैलेंज। एग्ज़िट तक पहुँच पाओगे?"),
    dict(d=5, t=214, game="FLOW", en=["CONNECT COLOURS.", "CHASE THE GLOW."], hi=["रंग जोड़ो।", "अपना फ़्लो पाओ।"], suben="Connect the dots. Complete the path.", subhi="डॉट्स जोड़ो। रास्ता पूरा करो।", ven="Connect the colours. Find your flow. Bring the whole board together.", vhi="एक जैसे रंग जोड़ो। अपना फ़्लो पाओ। और पूरा बोर्ड कनेक्ट कर दो।"),
    dict(d=4, image="9.jpeg", game="BUS JAM", en=["CLEAR THE JAM.", "KEEP IT MOVING."], hi=["जैम हटाओ।", "बस बढ़ाओ।"], suben="Another puzzle. A whole new mood.", subhi="नया पज़ल। नया मूड।", ven="Then switch it up with Bus Jam. New puzzle. New mood.", vhi="फिर बस जैम ट्राय करो। नया पज़ल। बिल्कुल नया मूड।"),
    dict(d=5, t=23, game="PICK YOUR CHALLENGE", en=["YOUR BREAK.", "YOUR PLAYLIST."], hi=["तुम्हारा ब्रेक।", "तुम्हारा गेम।"], suben="Blocks. Chess. Mazes. And more.", subhi="ब्लॉक्स, चेस, मेज़ और भी बहुत कुछ।", ven="Blocks, chess, mazes and more. Pick the challenge that fits your mood.", vhi="ब्लॉक्स, चेस, मेज़ और भी बहुत कुछ। अपने मूड का चैलेंज चुनो।"),
    dict(d=5, t=220, game="MASTER G", en=["WHAT'S YOUR", "NEXT MOVE?"], hi=["अब तुम्हारी", "अगली चाल?"], suben="MASTER G  •  Play your way.", subhi="MASTER G  •  खेलो अपने अंदाज़ में।", ven="Master G. Play your way. What's your next move?", vhi="मास्टर जी। खेलो अपने अंदाज़ में। तो, क्या होगी तुम्हारी अगली चाल?"),
]
# Breathing room for a natural trailer read; do not cram a paragraph into each cut.
SHORT_HI = [
    "स्क्रोल बहुत हुआ। अब चाल दिखाओ।",
    "ब्लॉक्स जमाओ। परफेक्ट फिट ढूँढो।",
    "ऐरो समझो। बाहर निकल पाओगे?",
    "चेस में दो कदम आगे सोचो।",
    "रंग मिलाओ। सही मैच का सुकून ही अलग है।",
    "स्वाइप। मर्ज। और अगला नंबर।",
    "टाइल्स सरकाओ। पैटर्न पकड़ो।",
    "हर मोड़ पर चैलेंज। एग्ज़िट ढूँढ पाओगे?",
    "रंग जोड़ो। अपना फ़्लो पाओ।",
    "बस जैम। नया पज़ल, नया मूड।",
    "तुम्हारा ब्रेक। तुम्हारे मूड का चैलेंज।",
    "मास्टर जी। क्या होगी तुम्हारी अगली चाल?",
]
SHORT_EN = [
    "Stop scrolling. Start solving.",
    "Stack the blocks. Find the perfect fit.",
    "Read the arrows. Find your way out.",
    "Think ahead. Own the chessboard.",
    "Sort the colours. That perfect match feels good.",
    "Swipe. Merge. Go bigger.",
    "Slide the tiles. Find the pattern.",
    "Every turn, a new challenge. Find your escape.",
    "Connect the colours. Find your flow.",
    "Bus Jam. New puzzle. New mood.",
    "Your break. Your mood. Your challenge.",
    "Master G. What's your next move?",
]
for s,hi,en in zip(SCENES,SHORT_HI,SHORT_EN):
    s["vhi"]=hi
    s["ven"]=en

def run(args):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode: raise RuntimeError(r.stderr[-5000:])
    return r

def ff(args):
    return run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", *map(str,args)])

def probe(p):
    return json.loads(run(["ffprobe","-v","error","-show_format","-show_streams","-of","json",str(p)]).stdout)

def font(size, bold=True):
    return ImageFont.truetype("C:/Windows/Fonts/" + ("segoeuib.ttf" if bold else "segoeui.ttf"), size)

def bg(w,h):
    y,x=np.mgrid[0:h,0:w].astype(np.float32)
    a=np.exp(-((x-w*.80)**2+(y-h*.30)**2)/(w*.46)**2)
    b=np.exp(-((x-w*.15)**2+(y-h*.82)**2)/(w*.42)**2)
    arr=np.stack([10+30*a+10*b,12+15*a+9*b,25+53*a+14*b],axis=-1)
    im=Image.fromarray(np.uint8(np.clip(arr,0,255)))
    d=ImageDraw.Draw(im)
    rng=np.random.default_rng(42)
    for _ in range(60):
        xx=int(rng.uniform(0,w)); yy=int(rng.uniform(0,h)); rr=int(rng.choice([1,1,2]))
        d.ellipse((xx,yy,xx+rr,yy+rr),fill=(65,61,81))
    d.arc((w*.25,-h*.35,w*1.23,h*.90),30,280,fill=(50,40,72),width=2)
    d.arc((w*.45,-h*.30,w*1.4,h*1.1),30,280,fill=(40,33,60),width=2)
    return im

def txt(d,xy,s,size,fill="#f5f1ff",bold=True):
    d.text(xy,s,font=font(size,bold),fill=fill)

def prepare_visuals():
    text_jobs=[]
    for orient,w,h in [("wide",1920,1080),("vertical",1080,1920)]:
        wide=orient=="wide"
        screen=(1280,118,416,850) if wide else (240,424,600,1226)
        x,y,sw,sh=screen
        for i,s in enumerate(SCENES):
            base=bg(w,h)
            d=ImageDraw.Draw(base)
            # Layered handset edge and halo, preserving the actual portrait gameplay.
            d.rounded_rectangle((x-22,y-22,x+sw+22,y+sh+22),34,fill="#151524",outline="#655173",width=2)
            d.rounded_rectangle((x-10,y-10,x+sw+10,y+sh+10),26,fill="#070811")
            tx=140 if wide else 82
            txt(d,(tx,72 if wide else 72),"MASTER G",32 if wide else 34,fill="#e8bd72")
            txt(d,(w-310 if wide else 760,82),"PLAY YOUR WAY",17,fill="#a7a0b9")
            d.line((tx,140 if wide else 144,w-tx,140 if wide else 144),fill="#393047",width=2)
            if wide:
                txt(d,(tx,850),f"{i+1:02d}  /  12",22,fill="#887d9c")
                d.rectangle((tx,924,1000,927),fill="#312c40")
                d.rectangle((tx,924,tx+int(860*(i+1)/12),927),fill="#e8bd72")
                txt(d,(tx,966),"MASTER G  /  GAMEPLAY TRAILER",17,fill="#887d9c")
            else:
                txt(d,(82,1730),f"{i+1:02d}  /  12",20,fill="#887d9c")
                d.rectangle((82,1785,998,1788),fill="#312c40")
                d.rectangle((82,1785,82+int(916*(i+1)/12),1788),fill="#e8bd72")
            base.save(WORK/f"bg_{orient}_{i:02}.png")
            for lang in ["en","hi"]:
                items=[]
                def item(text,x,y,size,color,bold=True):
                    items.append(dict(text=text,x=x,y=y,size=size,color=color,bold=bold,hindi=lang=="hi"))
                item(s["game"],tx,246 if wide else 185,23 if wide else 24,"#e8bd72")
                lines=s[lang]
                maxlen=max(len(z) for z in lines)
                size=min(88, int(930/maxlen*1.65)) if wide else min(67,int(900/maxlen*1.65))
                if lang=="hi":size=92 if wide else 70
                yy=330 if wide else 242
                step=112 if wide else 82
                for j,line in enumerate(lines):item(line,tx,yy+j*step,size,"#f7f3ff")
                item(s["sub"+lang],tx,630 if wide else 1668,30 if wide else 27,"#bdb1ce",False)
                text_jobs.append(dict(width=w,height=h,output=str(WORK/f"text_{orient}_{lang}_{i:02}.png"),items=items))
        (WORK/f"layout_{orient}.json").write_text(json.dumps(screen))
    (WORK/"text_jobs.json").write_text(json.dumps(text_jobs,ensure_ascii=False),encoding="utf-8")
    run(["powershell.exe","-NoProfile","-ExecutionPolicy","Bypass","-File",str(ROOT/"render_text.ps1"),"-Root",str(ROOT)])
    print("Design plates rendered",flush=True)

async def voices():
    import edge_tts
    for lang,voice in [("hi","hi-IN-SwaraNeural"),("en","en-IN-NeerjaNeural")]:
        for i,s in enumerate(SCENES):
            p=ASSETS/f"voice_female_{lang}_{i:02}.mp3"
            if not p.exists() or p.stat().st_size<1000:
                await edge_tts.Communicate(s["v"+lang],voice,rate="+10%",pitch="+2Hz").save(str(p))
            print(f"Voice {lang} {i+1}/12 ready",flush=True)

def music():
    sr=44100; dur=56; n=sr*dur
    out=np.zeros((n,2),np.float32)
    rng=np.random.default_rng(29)
    def add(v,start,pan=0):
        st=int(start*sr)
        if st<0: return
        en=min(n,st+len(v)); v=v[:en-st]
        if len(v):
            out[st:en,0]+=v*(.8-.2*pan);out[st:en,1]+=v*(.8+.2*pan)
    def hz(m):return 440*2**((m-69)/12)
    # Original minor-key electronic score: pulse, plucks, sub, percussion, and risers.
    beat=60/112
    chords=[[45,52,57,60],[41,48,53,57],[48,55,60,64],[43,50,55,59]]
    for start in np.arange(0,dur,beat*8):
        chord=chords[int(start/(beat*8))%4]
        t=np.arange(int(beat*8*sr))/sr
        env=np.minimum(t/.7,1)*np.minimum((t[-1]-t)/.8,1)
        v=sum(np.sin(2*np.pi*hz(m)*t+.18*np.sin(2*np.pi*.3*t)) for m in chord)/4
        add(v*env*.13,start)
    for j,start in enumerate(np.arange(0,dur,beat/2)):
        chord=chords[int(start/(beat*8))%4]; m=chord[j%4]+24
        t=np.arange(int(.6*sr))/sr; env=np.exp(-t*9)*np.minimum(t/.008,1)
        v=(np.sin(2*np.pi*hz(m)*t)+.25*np.sin(2*np.pi*hz(m)*2*t))*env
        add(v*.095,start,math.sin(j)*.8)
    for j,start in enumerate(np.arange(0,dur,beat)):
        if start<4 or start>52:continue
        t=np.arange(int(.25*sr))/sr
        kick=np.sin(2*np.pi*(45*t+9*(1-np.exp(-t*25))))*np.exp(-t*20)*.38
        add(kick,start)
        if j%2:
            sn=rng.normal(0,1,len(t))*np.exp(-t*30)*.075
            add(sn,start)
        tt=np.arange(int(.07*sr))/sr
        noise=rng.normal(0,1,len(tt)); noise=np.diff(noise,prepend=0)
        add(noise*np.exp(-tt*85)*.025,start+beat/2,(-1)**j*.7)
        bassm=chords[int(start/(beat*8))%4][0]-12
        bt=np.arange(int(beat*.8*sr))/sr
        add(np.sin(2*np.pi*hz(bassm)*bt)*np.exp(-bt*5)*.18,start)
    cursor=0
    for s in SCENES:
        if cursor:
            t=np.arange(int(.55*sr))/sr
            noise=rng.normal(0,1,len(t))
            smooth=np.convolve(noise,np.ones(7)/7,mode="same")
            add(smooth*np.sin(np.pi*t/.55)**2*.16,cursor-.4)
        cursor+=s["d"]
    time=np.arange(n)/sr
    out*=np.minimum(time/1.5,1)[:,None]*np.clip((dur-time)/2,0,1)[:,None]
    out=np.tanh(out*1.5)*.64
    with wave.open(str(ASSETS/"original_score.wav"),"wb") as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(sr);f.writeframes((out*32767).astype("<i2").tobytes())
    for lang in ["en","hi"]:
        voicearr=np.zeros((n,2),np.float32);cursor=0
        for i,s in enumerate(SCENES):
            inp=ASSETS/f"voice_female_{lang}_{i:02}.mp3"
            length=float(probe(inp)["format"]["duration"])
            speed=max(1,length/(s["d"]-.45))
            r=subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-i",str(inp),"-af",f"atempo={speed}","-ar",str(sr),"-ac","2","-f","f32le","pipe:1"],capture_output=True,check=True)
            samples=np.frombuffer(r.stdout,dtype="<f4").reshape(-1,2)
            start=int((cursor+.18)*sr);end=min(n,start+len(samples))
            voicearr[start:end]+=samples[:end-start]
            cursor+=s["d"]
        # Lower the score during speech while retaining the transient punctuation.
        active=np.max(np.abs(voicearr),axis=1)>.012
        win=int(sr*.18)
        env=np.convolve(active[::441].astype(float),np.ones(19)/19,mode="same")
        duck=np.interp(np.arange(n),np.arange(len(env))*441,env)
        mix=voicearr*1.4 + out*(.27-.13*np.minimum(duck*3,1))[:,None]
        mix=np.clip(mix,-.95,.95)
        with wave.open(str(ASSETS/f"mix_{lang}.wav"),"wb") as f:
            f.setnchannels(2);f.setsampwidth(2);f.setframerate(sr);f.writeframes((mix*32767).astype("<i2").tobytes())
    print("Indian-accent narration and original music mixed",flush=True)

def scene_video(orient,i):
    s=SCENES[i]; d=s["d"]; wide=orient=="wide"
    w,h=(1920,1080) if wide else (1080,1920)
    x,y,sw,sh=json.loads((WORK/f"layout_{orient}.json").read_text())
    output=WORK/f"clean_{orient}_{i:02}.mp4"
    if output.exists():return output
    args=["-threads","2","-loop","1","-framerate",str(FPS),"-i",WORK/f"bg_{orient}_{i:02}.png"]
    if "image" in s:
        args+=["-loop","1","-framerate",str(FPS),"-i",ASSETS/s["image"]]
        crop="crop=iw:ih-40:0:20"
    else:
        args+=["-ss",str(s["t"]),"-i",ASSETS/"recording.mp4"]
        crop="crop=480:980:0:32"
    # Subtle push-in inside the screen; 30 fps CFR fixes irregular phone capture timestamps.
    filt=f"[1:v]{crop},fps={FPS},scale={sw+12}:{sh+24},crop={sw}:{sh}:6:12,setsar=1[game];[0:v][game]overlay={x}:{y}:shortest=1,format=yuv420p[v]"
    args+=["-filter_complex_threads","2","-filter_complex",filt,"-map","[v]","-an","-t",str(d),"-c:v","libx264","-threads","2","-preset","fast","-crf","19",output]
    ff(args)
    print(f"Gameplay {orient} {i+1}/12 rendered",flush=True)
    return output

def final(orient,lang):
    # One language pass per scene adds a restrained entrance and transition on the complete frame.
    segments=[]
    for i,s in enumerate(SCENES):
        p=WORK/f"final_{orient}_{lang}_{i:02}.mp4"
        if not p.exists():
            filt=f"[1:v]format=rgba,fade=t=in:st=0.08:d=0.30:alpha=1[title];[0:v][title]overlay=0:0,fade=t=in:st=0:d=0.12,fade=t=out:st={s['d']-.14}:d=0.14,format=yuv420p[v]"
            ff(["-threads","2","-i",WORK/f"clean_{orient}_{i:02}.mp4","-loop","1","-framerate",FPS,"-i",WORK/f"text_{orient}_{lang}_{i:02}.png","-filter_complex_threads","2","-filter_complex",filt,"-map","[v]","-an","-t",s["d"],"-c:v","libx264","-threads","2","-preset","fast","-crf","19",p])
        segments.append(p)
    cat=WORK/f"concat_{orient}_{lang}.txt"
    cat.write_text("\n".join(f"file '{p.as_posix()}'" for p in segments),encoding="utf-8")
    name=f"Master_G_{'Hindi' if lang=='hi' else 'English'}_{'16x9' if orient=='wide' else '9x16'}_56s.mp4"
    ff(["-f","concat","-safe","0","-i",cat,"-i",ASSETS/f"mix_{lang}.wav","-map","0:v:0","-map","1:a:0","-c:v","copy","-af","loudnorm=I=-16:TP=-1.5:LRA=9","-c:a","aac","-b:a","192k","-t","56","-movflags","+faststart",ROOT/name])
    ff(["-ss","2","-i",ROOT/name,"-frames:v","1","-update","1",ROOT/f"Preview_{lang}_{orient}.jpg"])
    print("FINISHED "+name,flush=True)

def metadata():
    (ROOT/"production_manifest.json").write_text(json.dumps({"brand":"Master G","duration":56,"fps":30,"voices":{"hi":"hi-IN-SwaraNeural","en":"en-IN-NeerjaNeural"},"score":"Original locally synthesized electronic music","scenes":SCENES},ensure_ascii=False,indent=2),encoding="utf-8")
    for lang in ["en","hi"]:
        cursor=0; lines=[]
        def stamp(t):return f"00:{int(t)//60:02}:{int(t)%60:02},000"
        for i,s in enumerate(SCENES):
            lines.extend([str(i+1),f"{stamp(cursor)} --> {stamp(cursor+s['d'])}",s["v"+lang],""])
            cursor+=s["d"]
        (ROOT/f"Master_G_{lang}.srt").write_text("\n".join(lines),encoding="utf-8")

if __name__=="__main__":
    mode=sys.argv[1] if len(sys.argv)>1 else "all"
    if mode=="voices":asyncio.run(voices())
    elif mode=="design":prepare_visuals();metadata()
    elif mode=="music":music()
    elif mode=="render":
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(lambda x:scene_video(*x),[(o,i) for o in ["wide","vertical"] for i in range(len(SCENES))]))
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(lambda x:final(*x),[(o,l) for o in ["wide","vertical"] for l in ["en","hi"]]))
