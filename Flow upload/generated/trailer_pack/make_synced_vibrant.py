"""56-second, scene-synced energetic female narration and vibrant video masters."""
from pathlib import Path
import sys, asyncio, subprocess, json, wave, concurrent.futures, zipfile
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/"dependencies"))
import numpy as np
import edge_tts
from build_trailers import SCENES, probe
OUT=ROOT/"Vibrant_Synced"
WORK=OUT/"work"
WORK.mkdir(parents=True,exist_ok=True)
SCRIPTS={
 "Hindi":[
  "स्क्रोल बहुत हुआ, अब अपनी चाल दिखाओ! मास्टर जी में गेम ऑन!",
  "ब्लॉक्स जमाओ, परफेक्ट फिट ढूँढो और लाइन क्लियर करो। अपना स्कोर बढ़ाते जाओ!",
  "ऐरो समझो, हर रास्ते पर नज़र रखो। इस भूलभुलैया से बाहर निकल पाओगे?",
  "चेस में दो कदम आगे सोचो, अपना प्लान बनाओ और हर चाल से बाज़ी पलटो!",
  "रंग मिलाओ, उलझन सुलझाओ। बॉल सॉर्ट में सही मैच का सुकून ही अलग है!",
  "स्वाइप करो, नंबर मर्ज करो। ट्वेंटी फोर्टी एट में और आगे बढ़ो!",
  "टाइल्स सरकाओ, सही पैटर्न पकड़ो। हर नंबर को उसकी जगह पहुँचाओ!",
  "मेज़ में हर मोड़ पर नया चैलेंज। सही रास्ता चुनकर एग्ज़िट तक पहुँच पाओगे?",
  "एक जैसे रंग जोड़ो, सारे रास्ते पूरे करो। अब अपना फ़्लो दिखाने की बारी!",
  "बस जैम का चैलेंज लो, जैम हटाओ। नया पज़ल, बिल्कुल नया मूड!",
  "ब्लॉक्स, चेस, मेज़ और भी बहुत कुछ। तुम्हारा ब्रेक, तुम्हारे मूड का चैलेंज!",
  "मास्टर जी, खेलो अपने अंदाज़ में! तो बताओ, अब क्या होगी तुम्हारी अगली चाल?"
 ],
 "English":[
  "Stop scrolling, start solving! Master G is ready for your next move!",
  "Stack the blocks, find the perfect fit, clear those lines and chase your next score!",
  "Read the arrows, choose your route and find your way out. Think you can escape?",
  "Switch to chess, think two moves ahead and make every piece part of your plan!",
  "Sort the colours and untangle the chaos. In Ball Sort, that perfect match feels good!",
  "Swipe, merge and chase bigger numbers. Keep your next move going in twenty forty eight!",
  "Slide the tiles, spot the pattern and put every number right where it belongs!",
  "Take on the maze, where every turn brings a challenge. Can you find your escape?",
  "Connect matching colours, complete the paths and bring the whole board together. Find your flow!",
  "Take on Bus Jam and clear the jam. A new puzzle, a whole new mood!",
  "Blocks, chess, mazes and more. It's your break, so pick the challenge that fits your mood!",
  "Master G, play your way and make every move your own! So, what's your next move?"
 ]}
def ff(args,raw=False):
 r=subprocess.run(["ffmpeg","-y","-v","error",*map(str,args)],capture_output=True,check=True)
 return r.stdout
async def speech():
 for lang,voice in [("Hindi","hi-IN-SwaraNeural"),("English","en-IN-NeerjaNeural")]:
  for i,text in enumerate(SCRIPTS[lang]):
   p=WORK/f"{lang}_{i:02}.mp3"
   if not p.exists():
    await edge_tts.Communicate(text,voice,rate="+20%",pitch="+5Hz").save(str(p))
  print(lang+" energetic voice ready",flush=True)
def wav(path,data,sr=48000):
 with wave.open(str(path),"wb") as f:
  f.setnchannels(2);f.setsampwidth(2);f.setframerate(sr)
  f.writeframes((np.clip(data,-.98,.98)*32767).astype("<i2").tobytes())
def sound():
 sr=48000;n=sr*56
 score=np.frombuffer(ff(["-i",ROOT/"assets/original_score.wav","-ar",sr,"-ac",2,"-f","f32le","pipe:1"]),dtype="<f4").reshape(-1,2)[:n]
 report=[]
 for lang in SCRIPTS:
  track=np.zeros((n,2),np.float32);cursor=0;captions=[]
  for i,(s,text) in enumerate(zip(SCENES,SCRIPTS[lang])):
   filt="silenceremove=start_periods=1:start_duration=0.02:start_threshold=-48dB:stop_periods=-1:stop_duration=0.24:stop_threshold=-48dB:stop_silence=0.10"
   trimmed=WORK/f"trim_{lang}_{i:02}.wav"
   ff(["-i",WORK/f"{lang}_{i:02}.mp3","-af",filt,"-ar",sr,"-ac",2,trimmed])
   duration=float(probe(trimmed)["format"]["duration"])
   target=s["d"]-.24
   speed=max(1,duration/target)
   samples=np.frombuffer(ff(["-i",trimmed,"-af",f"atempo={speed:.6f},highpass=f=75,acompressor=threshold=0.16:ratio=2:attack=10:release=100:makeup=1.3","-ar",sr,"-ac",2,"-f","f32le","pipe:1"]),dtype="<f4").reshape(-1,2)
   start=int((cursor+.08)*sr)
   assert len(samples)<=int((s["d"]-.1)*sr), (lang,i,len(samples)/sr)
   track[start:start+len(samples)]+=samples
   report.append(dict(language=lang,scene=i+1,game=s["game"],start=cursor,end=cursor+s["d"],speech_start=cursor+.08,speech_end=round((start+len(samples))/sr,3),tempo=round(speed,3)))
   def ts(t):
    ms=round(t*1000);return f"00:{ms//60000:02d}:{ms//1000%60:02d},{ms%1000:03d}"
   captions.extend([str(i+1),f"{ts(cursor+.08)} --> {ts((start+len(samples))/sr)}",text,""])
   cursor+=s["d"]
  (OUT/f"Master_G_{lang}_Synced.srt").write_text("\n".join(captions),encoding="utf-8")
  raw=WORK/f"voice_{lang}.wav";wav(raw,track)
  ff(["-i",raw,"-af","loudnorm=I=-16:TP=-1.5:LRA=7","-ar",sr,"-c:a","pcm_s16le",OUT/f"Master_G_{lang}_Synced_Voice_56s.wav"])
  ff(["-i",OUT/f"Master_G_{lang}_Synced_Voice_56s.wav","-b:a","192k",OUT/f"Master_G_{lang}_Synced_Voice_56s.mp3"])
  # Narration is dominant; score rises slightly during brief breaths.
  active=(np.max(np.abs(track),axis=1)>.012)[::480]
  smooth=np.convolve(active.astype(float),np.ones(15)/15,mode="same")
  duck=np.interp(np.arange(n),np.arange(len(smooth))*480,smooth)
  mix=track*1.3+score*(.24-.11*np.minimum(duck*3,1))[:,None]
  wav(WORK/f"mix_{lang}.wav",mix)
 (OUT/"scene_sync.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
 print("Both 56-second scene-synced soundtracks ready",flush=True)
def render(task):
 lang,ratio=task
 p=OUT/f"Master_G_{lang}_{ratio}_Vibrant_Synced_56s.mp4"
 ff(["-threads",2,"-i",ROOT/f"Master_G_{lang}_{ratio}_56s.mp4","-i",WORK/f"mix_{lang}.wav",
     "-map","0:v:0","-map","1:a:0","-vf","eq=saturation=1.28:contrast=1.04:brightness=0.012:gamma=1.09",
     "-c:v","libx264","-threads",2,"-preset","fast","-crf",18,
     "-af","loudnorm=I=-16:TP=-1.5:LRA=7","-ar",48000,"-c:a","aac","-b:a","192k","-t",56,"-movflags","+faststart",p])
 ff(["-ss",2,"-i",p,"-frames:v",1,"-update",1,OUT/f"Preview_{lang}_{ratio}.jpg"])
 info=probe(p)
 v=next(x for x in info["streams"] if x["codec_type"]=="video")
 a=next(x for x in info["streams"] if x["codec_type"]=="audio")
 assert abs(float(v["duration"])-56)<.05 and abs(float(a["duration"])-56)<.05
 assert int(v["nb_frames"])==1680
 ff(["-i",p,"-f","null","-"])
 print("Verified "+p.name,flush=True)
 return dict(file=p.name,duration=float(info["format"]["duration"]),dimensions=[v["width"],v["height"]],frames=v["nb_frames"],decoded=True)
if __name__=="__main__":
 mode=sys.argv[1] if len(sys.argv)>1 else "all"
 if mode=="speech":asyncio.run(speech())
 else:
  sound()
  with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
   result=list(pool.map(render,[(l,r) for l in SCRIPTS for r in ["16x9","9x16"]]))
  (OUT/"verification.json").write_text(json.dumps(result,indent=2))
  with zipfile.ZipFile(OUT/"Master_G_Vibrant_Synced_Pack.zip","w",zipfile.ZIP_STORED) as z:
   for pattern in ["*.mp4","*.mp3","*.wav","*.srt","Preview*.jpg"]:
    for f in OUT.glob(pattern):z.write(f,f.name)
