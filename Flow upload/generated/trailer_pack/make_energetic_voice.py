"""Standalone voice-only exports; preserve existing video edits."""
from pathlib import Path
import sys, asyncio, subprocess, json
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/"dependencies"))
import edge_tts
OUT=ROOT/"Energetic_Voiceovers"
OUT.mkdir(exist_ok=True)
SCRIPTS={
    "Hindi":("hi-IN-SwaraNeural",
        "स्क्रोल बहुत हुआ, अब अपनी चाल दिखाओ! मास्टर जी में ब्लॉक्स जमाओ, परफेक्ट फिट ढूँढो और स्कोर बढ़ाओ। "
        "ऐरो समझो, अपना रास्ता खोजो, बाहर निकल पाओगे? चेस में दो कदम आगे सोचो और बाज़ी अपने नाम करो। "
        "रंग मिलाओ, सही मैच का सुकून ही अलग है! स्वाइप करो, नंबर मर्ज करो और अगले नंबर तक पहुँचो। "
        "टाइल्स सरकाओ, पैटर्न पकड़ो, हर मोड़ पर नया चैलेंज! मेज़ से बाहर निकलो, रंग जोड़ो और अपना फ़्लो पाओ। "
        "फिर बस जैम, नया पज़ल, नया मूड! तुम्हारा ब्रेक, तुम्हारे मूड का चैलेंज। "
        "मास्टर जी, खेलो अपने अंदाज़ में! तो क्या होगी तुम्हारी अगली चाल?"),
    "English":("en-IN-NeerjaNeural",
        "Stop scrolling, start solving! Welcome to Master G, where your next move is the whole game. "
        "Stack the blocks, find the perfect fit and chase your next score. "
        "Read the arrows, pick your route, can you find your way out? "
        "Think ahead in chess and make every move count! "
        "Sort the colours, find that perfect match, then swipe, merge and go bigger. "
        "Slide the tiles, spot the pattern and take on a new challenge around every turn. "
        "Escape the maze, connect the colours and find your flow! "
        "Switch it up with Bus Jam, new puzzle, new mood. "
        "Your break, your mood, your challenge. Master G, play your way! What's your next move?")
}
async def main():
    report=[]
    for lang,(voice,script) in SCRIPTS.items():
        raw=OUT/f"source_{lang}.mp3"
        await edge_tts.Communicate(script,voice,rate="+20%",pitch="+5Hz").save(str(raw))
        # Retain short natural breaths while reducing longer TTS pauses.
        filt="silenceremove=start_periods=1:start_duration=0.02:start_threshold=-48dB:stop_periods=-1:stop_duration=0.28:stop_threshold=-48dB:stop_silence=0.12,highpass=f=75,acompressor=threshold=0.16:ratio=2:attack=10:release=100:makeup=1.3,loudnorm=I=-16:TP=-1.5:LRA=7"
        wav=OUT/f"Master_G_{lang}_Female_Energetic.wav"
        mp3=wav.with_suffix(".mp3")
        subprocess.run(["ffmpeg","-y","-v","error","-i",str(raw),"-af",filt,"-ar","48000","-c:a","pcm_s16le",str(wav)],check=True)
        subprocess.run(["ffmpeg","-y","-v","error","-i",str(wav),"-c:a","libmp3lame","-b:a","192k",str(mp3)],check=True)
        p=json.loads(subprocess.check_output(["ffprobe","-v","error","-show_entries","format=duration","-of","json",str(wav)]))
        report.append({"language":lang,"voice":voice,"duration":round(float(p["format"]["duration"]),2),"rate":"+20%","pitch":"+5Hz","music":False})
        (OUT/f"Script_{lang}.txt").write_text(script,encoding="utf-8")
    (OUT/"audio_details.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print(json.dumps(report,indent=2))
asyncio.run(main())
