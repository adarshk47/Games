"""Build the AYUSH Vaidya pages into ../ayush/.

Every page shares the same <head>, top ticker, header menu and footer, so they live here
once. Page sources are in pages/*.src.html, split by markers:

    <!--title: ...-->  <!--description: ...-->  <!--nav: key-->
    <!--style-->    page CSS (goes into <head>)
    <!--body-->     the <main> of the page
    <!--i18n-->     <script>window.AYUSH_PAGE = {...}</script> (loaded before ayush.js)
    <!--scripts-->  page scripts that run after ayush.js

doctor.tpl.html is filled once per doctor from DOCTORS below.
Run:  python build.py        (then deploy mitrojan_site with firebase)
"""
import html
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', 'ayush'))
VERSION = '4'  # bump when ayush.css / ayush.js change, so browsers fetch the new files

HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{title}</title>
<meta name="description" content="{description}">
<meta name="theme-color" content="#2f8f5b">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 48 48'><rect width='48' height='48' rx='14' fill='%232f8f5b'/><path d='M24 38 C24 26 16 20 10 18 C12 28 18 34 24 38Z' fill='%23c9f2dc'/><path d='M24 38 C24 24 30 14 38 10 C38 24 32 32 24 38Z' fill='%23fff'/></svg>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Baloo+2:wght@600;700;800&family=Mukta:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="ayush.css?v={v}">
<style>
{style}
</style>
</head>
<body>
"""

TOP = """
<div class="topbar" aria-hidden="true"><div class="track">
  <span data-i18n="tk1">🌿 Ayurveda for today's life</span><span data-i18n="tk2">📹 15-minute online consultation</span><span data-i18n="tk3">🥗 Diet plans by Vaidya Pooja Gupta</span><span data-i18n="tk4">⚖️ Free BMI calculator</span><span data-i18n="tk5">🇮🇳 Across India, from home</span>
  <span data-i18n="tk1">🌿 Ayurveda for today's life</span><span data-i18n="tk2">📹 15-minute online consultation</span><span data-i18n="tk3">🥗 Diet plans by Vaidya Pooja Gupta</span><span data-i18n="tk4">⚖️ Free BMI calculator</span><span data-i18n="tk5">🇮🇳 Across India, from home</span>
</div></div>

<header class="site"><div class="wrap">
  <a class="logo" href="index.html" aria-label="AYUSH Vaidya home">
    <svg viewBox="0 0 48 48" aria-hidden="true"><defs><linearGradient id="lg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2f8f5b"/><stop offset="1" stop-color="#1fa39a"/></linearGradient></defs><rect width="48" height="48" rx="15" fill="url(#lg)"/><path d="M24 38 C24 26 16 20 10 18 C12 28 18 34 24 38Z" fill="#c9f2dc"/><path d="M24 38 C24 24 30 14 38 10 C38 24 32 32 24 38Z" fill="#fff"/><circle cx="36" cy="36" r="5" fill="#ffd84d"/></svg>
    <span><b data-i18n="brand">AYUSH Vaidya</b><small data-i18n="brandSub">by Mitrojan</small></span>
  </a>
  <nav class="main" id="mainNav" aria-label="Main">
    <div class="dd"><button type="button" aria-expanded="false"><span data-i18n="navDoctors">Doctors</span> ▾</button>
      <div class="dd-menu">
        <a href="dolly.html"{cur_dolly}><span class="av">DG</span><span><span data-i18n="ddDolly">Vaidya Dolly Gupta</span><small data-i18n="ddDollyRole">General Physician</small></span></a>
        <a href="pooja.html"{cur_pooja}><span class="av">PG</span><span><span data-i18n="ddPooja">Vaidya Pooja Gupta</span><small data-i18n="ddPoojaRole">Diet, Nutrition &amp; Lifestyle</small></span></a>
      </div>
    </div>
    <a href="benefits.html"{cur_benefits} data-i18n="navBenefits">Benefits</a>
    <a href="diet.html"{cur_diet} data-i18n="navDiet">Diet plan</a>
    <a href="products.html"{cur_products} data-i18n="navProducts">Products</a>
    <a href="history.html"{cur_history} data-i18n="navHistory">History</a>
    <div class="dd"><button type="button" aria-expanded="false"><span data-i18n="navMore">More</span> ▾</button>
      <div class="dd-menu">
        <a href="prakriti.html"{cur_prakriti}><span class="av">🧬</span><span data-i18n="mQuiz">Prakriti quiz</span></a>
        <a href="trust.html"{cur_trust}><span class="av">🛡️</span><span data-i18n="mTrust">Doctors' credentials</span></a>
        <a href="reviews.html"{cur_reviews}><span class="av">⭐</span><span data-i18n="mReviews">Reviews</span></a>
        <a href="articles.html"{cur_articles}><span class="av">📰</span><span data-i18n="mArticles">Health articles</span></a>
        <a href="contact.html"{cur_contact}><span class="av">📞</span><span data-i18n="mContact">Contact</span></a>
        <a href="policies.html"{cur_policies}><span class="av">⚖️</span><span data-i18n="mPolicies">Policies</span></a>
      </div>
    </div>
    <a class="cta" href="{book}" data-i18n="navBook">Book now</a>
  </nav>
  <div class="lang" role="group" aria-label="Language"><button type="button" data-lang="en" aria-pressed="true">EN</button><button type="button" data-lang="hi" aria-pressed="false" lang="hi">हिं</button><button type="button" data-lang="hinglish" aria-pressed="false">Hinglish</button></div>
  <button class="menu-btn" type="button" aria-expanded="false" aria-controls="mainNav" aria-label="Menu">☰</button>
</div></header>
"""

FOOT = """
<footer class="site">
  <div class="wrap">
    <div class="fcols">
      <div><b data-i18n="brand">AYUSH Vaidya</b><p class="note" style="color:#a9c7b6;margin:6px 0 0" data-i18n="fAbout">Online Ayurveda care by Mitrojan.</p></div>
      <div><a href="dolly.html" data-i18n="ddDolly">Vaidya Dolly Gupta</a><a href="pooja.html" data-i18n="ddPooja">Vaidya Pooja Gupta</a><a href="diet.html" data-i18n="navDiet">Diet plan</a></div>
      <div><a href="benefits.html" data-i18n="navBenefits">Benefits</a><a href="products.html" data-i18n="navProducts">Products</a><a href="history.html" data-i18n="navHistory">History</a><a href="prakriti.html" data-i18n="mQuiz">Prakriti quiz</a><a href="articles.html" data-i18n="mArticles">Health articles</a></div>
      <div><a href="trust.html" data-i18n="mTrust">Doctors' credentials</a><a href="reviews.html" data-i18n="mReviews">Reviews</a><a href="contact.html" data-i18n="mContact">Contact</a><a href="policies.html" data-i18n="mPolicies">Policies</a><a href="admin.html" data-i18n="fAdmin">Clinic login</a><a href="https://mitrojan.in/" data-i18n="fHome">Mitrojan home</a></div>
    </div>
  </div>
  <div class="wrap note" style="color:#a9c7b6;margin-top:16px"><span data-i18n="fNote">This website does not give medical advice. In an emergency, call 112.</span> · <span data-i18n="fRights">© 2026 Mitrojan · Ideal World</span></div>
</footer>
"""

NAV_KEYS = ['dolly', 'pooja', 'benefits', 'diet', 'products', 'history', 'prakriti', 'trust', 'reviews', 'articles', 'contact', 'policies']

# Per-doctor content for doctor.tpl.src.html. Text marked "demo" on the page until the doctors confirm it.
# Each language: (en, hi, hinglish).
DOCTORS = {
    'dolly': {
        'INI': 'DG', 'BG': 'var(--peach)', 'FIRST': ('Dolly', 'डॉली', 'Dolly'),
        'NAME': ('Vaidya Dolly Gupta', 'वैद्य डॉली गुप्ता', 'Vaidya Dolly Gupta'),
        'ROLE': ('General Physician (Ayurveda)', 'जनरल फ़िज़िशियन (आयुर्वेद)', 'General Physician (Ayurveda)'),
        'QUAL': 'BAMS (demo) · Reg. DEMO-AYU-0001',
        'ART': ('winter-health.html', '🧣', ('Winter health: stay well when it is cold', 'सर्दियों में सेहत: ठंड में कैसे रहें स्वस्थ', 'Sardi mein sehat: thand mein kaise rahein healthy')),
        'ABOUT1': ('Dolly is a General Physician in Ayurveda – your first stop for everyday health worries. In a short video call she listens to your symptoms, food, sleep and routine before suggesting anything.',
                   'डॉली जी आयुर्वेद में जनरल फ़िज़िशियन हैं – रोज़ की सेहत की चिंताओं के लिए आपका पहला पड़ाव। छोटी-सी वीडियो कॉल में वे पहले आपके लक्षण, भोजन, नींद और दिनचर्या सुनती हैं, फिर कोई सलाह देती हैं।',
                   'Dolly ji Ayurveda mein General Physician hain – roz ki sehat ki chintaon ke liye aapka pehla stop. Chhoti si video call mein woh pehle aapke lakshan, khaana, neend aur dincharya sunti hain, phir advice deti hain.'),
        'ABOUT2': ('Her approach is practical: simple changes to food and routine, Ayurvedic guidance where it fits, and a clear word on when you should see a doctor in person or get tests done.',
                   'उनका तरीका व्यावहारिक है: भोजन और दिनचर्या में आसान बदलाव, जहाँ ठीक हो वहाँ आयुर्वेदिक सलाह, और साफ़ बताना कि कब आमने-सामने डॉक्टर को दिखाना या जाँच कराना ज़रूरी है।',
                   'Unka tareeka practical hai: khaane aur dincharya mein aasaan badlaav, jahan theek ho wahan Ayurvedic advice, aur saaf batana ki kab aamne-saamne doctor ko dikhana ya test karana zaroori hai.'),
        'CTA2': ('mailto:aiforsmart@gmail.com?subject=Question%20for%20Vaidya%20Dolly%20Gupta', ('Ask a question', 'सवाल पूछें', 'Sawaal poochhiye')),
        'HELPS': [
            ('🤧', ('Everyday health problems', 'रोज़ की सेहत की परेशानियाँ', 'Roz ki sehat ki pareshaniyan'), ('Cold, cough, body ache, tiredness – first advice and when to see a doctor.', 'सर्दी, खाँसी, बदन दर्द, थकान – पहली सलाह और कब डॉक्टर को दिखाएँ।', 'Sardi, khaansi, badan dard, thakaan – pehli advice aur kab doctor ko dikhayein.')),
            ('🔥', ('Digestion', 'पाचन', 'Digestion'), ('Gas, acidity, constipation and heaviness after meals.', 'गैस, एसिडिटी, कब्ज़ और खाने के बाद भारीपन।', 'Gas, acidity, kabz aur khaane ke baad bhaaripan.')),
            ('😴', ('Sleep & stress', 'नींद और तनाव', 'Neend aur stress'), ('Poor sleep, low energy and a calmer daily routine.', 'कम नींद, थकावट और शांत दिनचर्या।', 'Kam neend, kam energy aur shaant dincharya.')),
            ('🦴', ('Joint & back stiffness', 'जोड़ों और कमर की जकड़न', 'Jodon aur kamar ki jakdan'), ('Routine, movement and lifestyle advice.', 'दिनचर्या, चलने-फिरने और जीवनशैली की सलाह।', 'Dincharya, movement aur lifestyle advice.')),
            ('🩸', ('Sugar & BP routine', 'शुगर और बीपी की दिनचर्या', 'Sugar aur BP ki dincharya'), ('Lifestyle support alongside your regular treatment.', 'आपके चल रहे इलाज के साथ जीवनशैली की मदद।', 'Aapke chal rahe ilaaj ke saath lifestyle support.')),
            ('🍂', ('Seasonal care', 'ऋतु के अनुसार देखभाल', 'Mausam ke hisaab se care'), ('Staying well as the season changes.', 'मौसम बदलने पर स्वस्थ रहना।', 'Mausam badalne par healthy rehna.')),
        ],
    },
    'pooja': {
        'INI': 'PG', 'BG': 'var(--mint)', 'FIRST': ('Pooja', 'पूजा', 'Pooja'),
        'NAME': ('Vaidya Pooja Gupta', 'वैद्य पूजा गुप्ता', 'Vaidya Pooja Gupta'),
        'ROLE': ('Diet, Nutrition & Lifestyle Management (Ayurveda)', 'आहार, पोषण और जीवनशैली प्रबंधन (आयुर्वेद)', 'Diet, Nutrition aur Lifestyle Management (Ayurveda)'),
        'QUAL': 'BAMS (demo) · Reg. DEMO-AYU-0002',
        'ART': ('winter-diet.html', '🥣', ('Your winter diet plan', 'सर्दियों का डाइट प्लान', 'Sardiyon ka diet plan')),
        'ABOUT1': ('Pooja focuses on diet and nutrition in Ayurveda. She looks at your body type, routine, region and taste to plan meals you can actually follow at home.',
                   'पूजा जी आयुर्वेद में आहार और पोषण पर ध्यान देती हैं। वे आपकी प्रकृति, दिनचर्या, इलाके और स्वाद को देखकर ऐसा भोजन तय करती हैं जिसे आप घर पर सच में अपना सकें।',
                   'Pooja ji Ayurveda mein diet aur nutrition par focus karti hain. Woh aapki prakriti, dincharya, ilaaka aur swaad dekh kar aisa khaana plan karti hain jo aap ghar par sach mein follow kar sakein.'),
        'ABOUT2': ('No crash diets – just a personal diet chart with Indian food, sensible portions and seasonal changes, reviewed with you over time.',
                   'कोई क्रैश डाइट नहीं – बस भारतीय भोजन, सही मात्रा और ऋतु के बदलावों वाला व्यक्तिगत डाइट चार्ट, जिसे समय-समय पर आपके साथ देखा जाता है।',
                   'Koi crash diet nahi – bas Indian khaana, sahi quantity aur mausam ke badlaav wala personal diet chart, jo time-time par aapke saath review hota hai.'),
        'CTA2': ('diet.html', ('Request a diet plan 🥗', 'डाइट प्लान माँगें 🥗', 'Diet plan maangiye 🥗')),
        'HELPS': [
            ('🥗', ('Personal diet chart', 'व्यक्तिगत डाइट चार्ट', 'Personal diet chart'), ('Meals planned for your body, routine and taste.', 'आपके शरीर, दिनचर्या और स्वाद के हिसाब से भोजन।', 'Aapke body, dincharya aur swaad ke hisaab se khaana.')),
            ('⚖️', ('Weight goals', 'वज़न के लक्ष्य', 'Weight goals'), ('Healthy weight loss or gain, without crash diets.', 'बिना क्रैश डाइट के, सेहतमंद तरीके से वज़न घटाना या बढ़ाना।', 'Bina crash diet ke, healthy tareeke se weight ghatana ya badhana.')),
            ('🩸', ('Sugar & BP-friendly eating', 'शुगर और बीपी के अनुकूल भोजन', 'Sugar aur BP-friendly khaana'), ('Diet support alongside your regular treatment.', 'आपके चल रहे इलाज के साथ आहार की मदद।', 'Aapke chal rahe ilaaj ke saath diet support.')),
            ('🧘', ('Lifestyle management', 'जीवनशैली प्रबंधन', 'Lifestyle management'), ('Sleep, activity, stress and screen time – a daily routine that fits your life.', 'नींद, व्यायाम, तनाव और स्क्रीन टाइम – आपकी ज़िंदगी के हिसाब से दिनचर्या।', 'Neend, activity, stress aur screen time – aapki life ke hisaab se dincharya.')),
            ('👨‍👩‍👧', ('Family & kids nutrition', 'परिवार और बच्चों का पोषण', 'Family aur bachchon ka poshan'), ('One healthy kitchen for the whole family.', 'पूरे परिवार के लिए एक सेहतमंद रसोई।', 'Poori family ke liye ek healthy kitchen.')),
            ('🍂', ('Seasonal diet', 'ऋतु के अनुसार आहार', 'Mausam ke hisaab se diet'), ('What to eat in summer, monsoon and winter.', 'गर्मी, बरसात और सर्दी में क्या खाएँ।', 'Garmi, barsaat aur sardi mein kya khayein.')),
        ],
    },
}


def doctor_values(key):
    d = DOCTORS[key]
    other = next(k for k in DOCTORS if k != key)
    o = DOCTORS[other]
    esc = lambda t: html.escape(t, quote=False)
    helps, hi, hl = [], {}, {}
    for i, (emoji, h, p) in enumerate(d['HELPS'], 1):
        helps.append(f'      <div class="card help"><span class="e">{emoji}</span><div><h4 data-i18n="h{i}h">{esc(h[0])}</h4><p data-i18n="h{i}p">{esc(p[0])}</p></div></div>')
        hi[f'h{i}h'], hi[f'h{i}p'], hl[f'h{i}h'], hl[f'h{i}p'] = h[1], p[1], h[2], p[2]
    for field, lang_key in (('ROLE', 'role'), ('ABOUT1', 'about1'), ('ABOUT2', 'about2')):
        hi[lang_key], hl[lang_key] = d[field][1], d[field][2]
    hi['cta2'], hl['cta2'] = d['CTA2'][1][1], d['CTA2'][1][2]
    hi['otherRole'], hl['otherRole'] = o['ROLE'][1], o['ROLE'][2]
    hi['artTitle'], hl['artTitle'] = d['ART'][2][1], d['ART'][2][2]
    return {
        'ID': key, 'INI': d['INI'], 'BG': d['BG'],
        'NAME_EN': esc(d['NAME'][0]), 'NAME_HI': d['NAME'][1], 'FIRST_EN': d['FIRST'][0], 'FIRST_HI': d['FIRST'][1],
        'ROLE_EN': esc(d['ROLE'][0]), 'ABOUT1_EN': esc(d['ABOUT1'][0]), 'ABOUT2_EN': esc(d['ABOUT2'][0]),
        'CTA2_HREF': d['CTA2'][0], 'CTA2_EN': esc(d['CTA2'][1][0]), 'HELPS': '\n'.join(helps),
        'OTHER_ID': other, 'OTHER_INI': o['INI'], 'OTHER_EN': esc(o['NAME'][0]), 'OTHER_HI': o['NAME'][1],
        'OTHER_BG': o['BG'], 'OTHER_ROLE_EN': esc(o['ROLE'][0]),
        'QUAL': esc(d['QUAL']), 'ART_HREF': d['ART'][0], 'ART_EMOJI': d['ART'][1], 'ART_EN': esc(d['ART'][2][0]),
        'HI_EXTRA': json.dumps(hi, ensure_ascii=False), 'HL_EXTRA': json.dumps(hl, ensure_ascii=False),
    }


def split(src):
    meta = dict(re.findall(r'<!--(title|description|nav): (.*?)-->', src))
    parts = {}
    for name in ('style', 'body', 'i18n', 'scripts'):
        m = re.search(rf'<!--{name}-->\n(.*?)(?=\n<!--(?:style|body|i18n|scripts)-->|\Z)', src, re.S)
        parts[name] = m.group(1).rstrip() if m else ''
    return meta, parts


def page(meta, parts):
    nav = meta.get('nav', '')
    cur = {f'cur_{k}': (' aria-current="page"' if k == nav else '') for k in NAV_KEYS}
    book = f'index.html?doctor={nav}#book' if nav in DOCTORS else ('#book' if nav == 'home' else 'index.html#book')
    html = HEAD.format(title=meta['title'], description=meta['description'], v=VERSION, style=parts['style'])
    html += TOP.format(book=book, **cur)
    html += '\n' + parts['body'] + '\n' + FOOT + '\n'
    html += parts['i18n'] + '\n' + f'<script src="ayush.js?v={VERSION}"></script>\n'
    if parts['scripts']:
        html += parts['scripts'] + '\n'
    html += '</body>\n</html>\n'
    return html


SUGGEST_BAR = """<div style="background:#1b1b3a;color:#ffd84d;font-weight:700;font-size:14px;padding:8px 16px;text-align:center;line-height:1.7">
  💡 Suggestion preview (local only) ·
  <a style="color:#fff" href="suggestions.html">Checklist</a> ·
  <a style="color:#fff" href="trust.html">Credentials</a> ·
  <a style="color:#fff" href="prakriti.html">Prakriti quiz</a> ·
  <a style="color:#fff" href="contact.html">Contact &amp; clinic</a> ·
  <a style="color:#fff" href="reviews.html">Reviews</a> ·
  <a style="color:#fff" href="articles.html">Articles</a> ·
  <a style="color:#fff" href="policies.html">Policies</a>
</div>
"""


def main():
    # `python build.py --suggest` builds a local-only preview with extra pages into ../ayush_suggest.
    global OUT
    suggest = '--suggest' in sys.argv
    dirs = [os.path.join(HERE, 'pages')]
    if suggest:
        OUT = os.path.normpath(os.path.join(HERE, '..', 'ayush_suggest'))
        os.makedirs(OUT, exist_ok=True)
        live = os.path.normpath(os.path.join(HERE, '..', 'ayush'))
        for static in ('ayush.css', 'ayush.js', 'booking.js', 'firebase-config.js', 'admin.html'):
            shutil.copy(os.path.join(live, static), OUT)
        dirs.append(os.path.join(HERE, 'pages_suggest'))
    built = []
    for pages_dir in dirs:
        built += build_dir(pages_dir, suggest)
    print('built into', OUT + ':', ', '.join(built))


def build_dir(pages_dir, suggest):
    built = []
    for name in sorted(os.listdir(pages_dir)):
        if not name.endswith('.src.html'):
            continue
        src = open(os.path.join(pages_dir, name), encoding='utf-8').read()
        if name == 'doctor.tpl.src.html':
            for key in DOCTORS:
                filled = src
                for k, v in doctor_values(key).items():
                    filled = filled.replace('{{' + k + '}}', v)
                assert '{{' not in filled, key
                write(f'{key}.html', page(*split(filled)), suggest)
                built.append(f'{key}.html')
            continue
        out = name.replace('.src.html', '.html')
        write(out, page(*split(src)), suggest)
        built.append(out)
    return built


def write(name, html_text, suggest):
    if suggest:
        html_text = html_text.replace('<body>\n', '<body>\n' + SUGGEST_BAR, 1)
    open(os.path.join(OUT, name), 'w', encoding='utf-8').write(html_text)


if __name__ == '__main__':
    main()
