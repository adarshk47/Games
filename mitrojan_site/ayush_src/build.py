"""Build the AYUSH Vaidya pages into ../ayush/.

Every page shares the same <head>, top ticker, header menu and footer, so they live here
once. Page sources are in pages/*.src.html, split by markers:

    <!--title: ...-->  <!--description: ...-->  <!--nav: key-->
    <!--style-->    page CSS (goes into <head>)
    <!--body-->     the <main> of the page
    <!--i18n-->     <script>window.AYUSH_PAGE = {...}</script> (loaded before ayush.js)
    <!--scripts-->  page scripts that run after ayush.js

doctor.tpl.html is filled once per doctor from DOCTORS below.
Daily articles are plain .md files in articles/ (see articles/_TEMPLATE.md).
Clinic and doctor details to fill in later: CLINIC and DOCTOR_INFO below.
Run:  python build.py        (then deploy – see ../HOW_TO_UPDATE.md)
"""
import html
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', 'ayush'))
VERSION = '7'  # bump when ayush.css / ayush.js change, so browsers fetch the new files
SITE_URL = 'https://ayush.mitrojan.in/'

# ---------------------------------------------------------------------------
# FILL THESE IN LATER. While a value is '' the page shows ______ in its place,
# and buttons that need it (WhatsApp, call, map, Google profile, photo) stay hidden.
# Then run `python build.py` and deploy.
CLINIC = {
    'phone': '',            # shown as text, e.g. '+91 98765 43210'
    'whatsapp': '919310335795',  # digits with country code, e.g. '919876543210'
    'address': '',
    'hours': 'Mon – Sat · 10 AM – 1 PM, 5 – 7 PM',
    'reply_time': '',       # e.g. 'Within 24 hours'
    'map_embed': '',        # Google Maps > Share > Embed a map > the src="..." URL
    'google_profile': '',   # Google Business Profile link (for reviews)
    'fee_consult': '',      # 15-minute consultation, e.g. '₹300'
    'fee_monthly': '',      # Monthly Care plan
    'fee_yearly': '',       # Yearly Care plan
    'fee_family': '',       # Family Yearly Care plan
}
DOCTOR_INFO = {
    'dolly': {'degree': '', 'college': '', 'reg_no': '', 'since': '', 'experience': '', 'languages': '', 'photo': ''},
    'pooja': {'degree': '', 'college': '', 'reg_no': '', 'since': '', 'experience': '', 'languages': '', 'photo': ''},
}  # photo: an image file put in ../ayush/ (e.g. 'dolly.jpg') or a full https:// URL
BLANK = '<span class="blank-field">______</span>'


def lookup(key):
    group, field = key.split('.', 1)
    return (CLINIC if group == 'clinic' else DOCTOR_INFO[group])[field].strip()


def pretty_phone(digits):
    """'919310335795' -> '+91 93103 35795' for display."""
    d = re.sub(r'\D', '', digits)
    return f'+91 {d[2:7]} {d[7:]}' if len(d) == 12 and d.startswith('91') else digits


def fill_details(text):
    """<!--if:k-->…<!--/if:k--> kept only when k has a value; [[k]] text (or ______);
    [[raw:k]] value as-is (for links); [[tel:k]] digits and + only."""
    text = re.sub(r'<!--if:([\w.]+)-->(.*?)<!--/if:\1-->', lambda m: m.group(2) if lookup(m.group(1)) else '', text, flags=re.S)
    text = re.sub(r'<!--ifnot:([\w.]+)-->(.*?)<!--/ifnot:\1-->', lambda m: '' if lookup(m.group(1)) else m.group(2), text, flags=re.S)
    text = re.sub(r'\[\[raw:([\w.]+)\]\]', lambda m: html.escape(lookup(m.group(1))), text)
    text = re.sub(r'\[\[tel:([\w.]+)\]\]', lambda m: re.sub(r'[^\d+]', '', lookup(m.group(1))), text)
    text = re.sub(r'\[\[wa:([\w.]+)\]\]', lambda m: pretty_phone(lookup(m.group(1))) or BLANK, text)
    text = re.sub(r'\[\[([\w.]+)\]\]', lambda m: html.escape(lookup(m.group(1)), quote=False) or BLANK, text)
    return text

HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{title}</title>
<meta name="description" content="{description}">
<meta name="theme-color" content="#2f8f5b">
<link rel="canonical" href="{url}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="AYUSH Vaidya by Mitrojan">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{description}">
<meta property="og:url" content="{url}">
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
    <a href="consult.html"{cur_consult} data-i18n="navConsult">General Physician</a>
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
      <div><a href="dolly.html" data-i18n="ddDolly">Vaidya Dolly Gupta</a><a href="pooja.html" data-i18n="ddPooja">Vaidya Pooja Gupta</a><a href="consult.html" data-i18n="navConsult">General Physician</a><a href="diet.html" data-i18n="navDiet">Diet plan</a></div>
      <div><a href="benefits.html" data-i18n="navBenefits">Benefits</a><a href="products.html" data-i18n="navProducts">Products</a><a href="history.html" data-i18n="navHistory">History</a><a href="prakriti.html" data-i18n="mQuiz">Prakriti quiz</a><a href="articles.html" data-i18n="mArticles">Health articles</a></div>
      <div><a href="trust.html" data-i18n="mTrust">Doctors' credentials</a><a href="reviews.html" data-i18n="mReviews">Reviews</a><a href="contact.html" data-i18n="mContact">Contact</a><a href="policies.html" data-i18n="mPolicies">Policies</a><a href="admin.html" data-i18n="fAdmin">Clinic login</a><a href="https://mitrojan.in/" data-i18n="fHome">Mitrojan home</a></div>
    </div>
  </div>
  <div class="wrap note" style="color:#a9c7b6;margin-top:16px"><span data-i18n="fNote">This website does not give medical advice. In an emergency, call 112.</span> · <span data-i18n="fRights">© 2026 Mitrojan · Ideal World</span></div>
</footer>
<!--if:clinic.whatsapp--><a class="wa-float" href="https://wa.me/[[raw:clinic.whatsapp]]" target="_blank" rel="noopener" aria-label="Chat on WhatsApp">💬</a><!--/if:clinic.whatsapp-->
"""

NAV_KEYS = ['dolly', 'pooja', 'benefits', 'consult', 'diet', 'products', 'history', 'prakriti', 'trust', 'reviews', 'articles', 'contact', 'policies']

# Per-doctor content for doctor.tpl.src.html. Text marked "demo" on the page until the doctors confirm it.
# Each language: (en, hi, hinglish).
DOCTORS = {
    'dolly': {
        'INI': 'DG', 'BG': 'var(--peach)', 'FIRST': ('Dolly', 'डॉली', 'Dolly'),
        'NAME': ('Vaidya Dolly Gupta', 'वैद्य डॉली गुप्ता', 'Vaidya Dolly Gupta'),
        'ROLE': ('General Physician (Ayurveda)', 'जनरल फ़िज़िशियन (आयुर्वेद)', 'General Physician (Ayurveda)'),
        'ART': ('winter-health.html', '🧣', ('Winter health: stay well when it is cold', 'सर्दियों में सेहत: ठंड में कैसे रहें स्वस्थ', 'Sardi mein sehat: thand mein kaise rahein healthy')),
        'ABOUT1': ('Dolly is a General Physician in Ayurveda – your first stop for everyday health worries. In a short video call she listens to your symptoms, food, sleep and routine before suggesting anything.',
                   'डॉली जी आयुर्वेद में जनरल फ़िज़िशियन हैं – रोज़ की सेहत की चिंताओं के लिए आपका पहला पड़ाव। छोटी-सी वीडियो कॉल में वे पहले आपके लक्षण, भोजन, नींद और दिनचर्या सुनती हैं, फिर कोई सलाह देती हैं।',
                   'Dolly ji Ayurveda mein General Physician hain – roz ki sehat ki chintaon ke liye aapka pehla stop. Chhoti si video call mein woh pehle aapke lakshan, khaana, neend aur dincharya sunti hain, phir advice deti hain.'),
        'ABOUT2': ('Her approach is practical: simple changes to food and routine, Ayurvedic guidance where it fits, and a clear word on when you should see a doctor in person or get tests done.',
                   'उनका तरीका व्यावहारिक है: भोजन और दिनचर्या में आसान बदलाव, जहाँ ठीक हो वहाँ आयुर्वेदिक सलाह, और साफ़ बताना कि कब आमने-सामने डॉक्टर को दिखाना या जाँच कराना ज़रूरी है।',
                   'Unka tareeka practical hai: khaane aur dincharya mein aasaan badlaav, jahan theek ho wahan Ayurvedic advice, aur saaf batana ki kab aamne-saamne doctor ko dikhana ya test karana zaroori hai.'),
        'CTA2': ('consult.html', ('General Physician consultation 🩺', 'जनरल फ़िज़िशियन परामर्श 🩺', 'General Physician consultation 🩺')),
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
        'ART_HREF': d['ART'][0], 'ART_EMOJI': d['ART'][1], 'ART_EN': esc(d['ART'][2][0]),
        'HI_EXTRA': json.dumps(hi, ensure_ascii=False), 'HL_EXTRA': json.dumps(hl, ensure_ascii=False),
    }


# ---------------------------------------------------------------------------
# Daily articles: one .md file per article in articles/ (copy articles/_TEMPLATE.md).
# Files starting with "_" are not published. Each becomes article-<file name>.html and
# is listed, newest first, under "Latest from our Vaidyas" on articles.html.
ARTICLES_DIR = os.path.join(HERE, 'articles')
IMAGES_DIR = os.path.normpath(os.path.join(HERE, '..', 'ayush', 'images'))  # article photos go here
MAX_IMAGE_KB = 300
MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
LATEST_CARDS = 3  # newest articles shown as big cards; the rest go in the collapsed list below

# Hand-made article pages (pages/*.src.html) that also belong in the articles list.
STATIC_ARTICLES = [
    {'file': 'winter-health.html', 'author': 'dolly', 'emoji': '🧣', 'date': '2026-10-30', 'i18n': ('f1h', 'f1p'),
     'title': 'Winter health: stay well when it is cold', 'summary': 'Daily routine, what to eat, what to avoid, and when to see a doctor.'},
    {'file': 'winter-diet.html', 'author': 'pooja', 'emoji': '🥣', 'date': '2026-10-30', 'i18n': ('f2h', 'f2p'),
     'title': 'Your winter diet plan', 'summary': 'A sample day of Indian winter meals, easy swaps and lifestyle tips.'},
]


def pretty_date(iso):
    y, m, d = (int(x) for x in iso.split('-'))
    return f'{d} {MONTHS[m - 1]} {y}'


def image_src(name, where):
    """Photos are kept in ayush/images/; warn when one is missing or too big for phones."""
    if name.startswith(('http://', 'https://', '/')) or '/' in name:
        return name
    path = os.path.join(IMAGES_DIR, name)
    if not os.path.exists(path):
        print(f'  ! {where}: photo "{name}" is not in {IMAGES_DIR}')
    elif os.path.getsize(path) > MAX_IMAGE_KB * 1024:
        print(f'  ! {where}: photo "{name}" is {os.path.getsize(path) // 1024} KB – please make it smaller than {MAX_IMAGE_KB} KB')
    return 'images/' + name

ARTICLE_STYLE = """  .art-wrap { max-width: 820px; margin: 0 auto; padding: 34px 0 0; }
  .crumbs { font-size: 15px; color: var(--ink-2); margin: 0 0 14px; }
  .crumbs a { color: var(--leaf-d); font-weight: 600; text-decoration: none; }
  .cover { border-radius: 30px; padding: 34px 28px; background: linear-gradient(140deg, #d9f6e5, #e9e1ff 55%, #ffe1d9); position: relative; overflow: hidden; }
  .cover .cover-e { position: absolute; right: 24px; top: 18px; font-size: 64px; animation: bob 5s ease-in-out infinite; }
  .cover h1 { font-size: clamp(34px, 5.4vw, 58px); margin: 0 0 10px; max-width: 640px; }
  .cover p { color: var(--ink-2); font-size: 19px; margin: 0; max-width: 640px; }
  .by { display: flex; gap: 12px; align-items: center; margin: 18px 0 0; text-decoration: none; }
  .by .av { width: 52px; height: 52px; border-radius: 50%; display: grid; place-items: center; font-weight: 800; font-family: "Baloo 2", sans-serif; box-shadow: 0 0 0 3px #fff; }
  .by b { display: block; }
  .by small { color: var(--ink-2); }
  .art-body h2 { font-size: clamp(26px, 3.4vw, 34px); margin: 32px 0 10px; }
  .art-body h3 { font-size: 22px; margin: 24px 0 8px; }
  .art-body p, .art-body li { color: var(--ink-2); font-size: 18px; }
  .art-body ul { padding-left: 22px; }
  .art-body img { display: block; max-width: min(100%, 520px); max-height: 380px; object-fit: cover; border-radius: 20px; margin: 10px 0; box-shadow: var(--shadow); }
  .art-body a { color: var(--leaf-d); font-weight: 600; }
  .cover.has-img { display: grid; grid-template-columns: 1fr 210px; gap: 22px; align-items: center; }
  .cover .cover-img { width: 210px; height: 210px; object-fit: cover; border-radius: 24px; border: 5px solid #fff; box-shadow: var(--shadow); }
  .end { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 26px; }
  @media (max-width: 640px) {
    .cover { padding: 26px 18px; } .cover .cover-e { font-size: 44px; }
    .cover.has-img { grid-template-columns: 1fr; } .cover .cover-img { width: 100%; height: 190px; order: -1; }
  }"""


def md_inline(text, where=''):
    text = re.sub(r'!\[([^\]]*)\]\(([^)\s]+)\)', lambda m: f'<img src="{image_src(m.group(2), where)}" alt="{m.group(1)}" loading="lazy">', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)\s]+)\)', r'<a href="\2">\1</a>', text)
    return re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)


def md_to_html(md, where=''):
    """The small Markdown subset in _TEMPLATE.md: paragraphs, ## / ### headings, - lists, **bold**, links, images."""
    out, para, items = [], [], []
    inline = lambda t: md_inline(t, where)

    def flush():
        if para:
            out.append('<p>' + inline(' '.join(para)) + '</p>')
            para.clear()
        if items:
            out.append('<ul>' + ''.join(f'<li>{inline(i)}</li>' for i in items) + '</ul>')
            items.clear()

    for raw in md.splitlines():
        line = html.escape(raw.strip())
        if not line:
            flush()
        elif line.startswith('### '):
            flush(); out.append(f'<h3>{inline(line[4:])}</h3>')
        elif line.startswith('## '):
            flush(); out.append(f'<h2>{inline(line[3:])}</h2>')
        elif line.startswith('- '):
            if para:
                flush()
            items.append(line[2:])
        else:
            if items:
                flush()
            para.append(line)
    flush()
    return '\n    '.join(out)


def read_articles():
    arts = []
    if not os.path.isdir(ARTICLES_DIR):
        return arts
    for name in sorted(os.listdir(ARTICLES_DIR)):
        if not name.endswith('.md') or name.startswith('_'):
            continue
        text = open(os.path.join(ARTICLES_DIR, name), encoding='utf-8').read().replace('\r\n', '\n')
        head, sep, body = text.partition('\n---\n')
        assert sep, f'{name}: missing the --- line between the details and the article'
        meta = dict(line.split(':', 1) for line in head.splitlines() if ':' in line)
        meta = {k.strip(): v.strip() for k, v in meta.items()}
        for key in ('title', 'author', 'date', 'summary'):
            assert meta.get(key), f'{name}: "{key}:" is empty'
        assert meta['author'] in DOCTORS, f'{name}: author must be one of {list(DOCTORS)}'
        assert re.fullmatch(r'20\d\d-\d\d-\d\d', meta['date']), f'{name}: date must look like 2026-11-05'
        image = image_src(meta['image'], name) if meta.get('image') else ''
        arts.append(dict(meta, emoji=meta.get('emoji') or '🌿', file=f"article-{name[:-3]}.html", image=image,
                         pretty=pretty_date(meta['date']), body=md_to_html(body, name)))
    return sorted(arts, key=lambda a: a['date'], reverse=True)


def article_source(a):
    d = DOCTORS[a['author']]
    esc = lambda t: html.escape(t, quote=False)
    hi = {'auth': d['NAME'][1], 'authRole': d['ROLE'][1], 'bookWith': f"{d['NAME'][1]} के साथ बुक करें ↗", 'allArts': '← सभी लेख',
          'note': 'यह सामान्य जानकारी है, व्यक्तिगत चिकित्सकीय सलाह नहीं। डॉक्टर से पूछे बिना कोई दवा बंद या न बदलें।'}
    hl = {'auth': d['NAME'][2], 'authRole': d['ROLE'][2], 'bookWith': f"{d['NAME'][2]} ke saath book karo ↗", 'allArts': '← Saare articles',
          'note': 'Yeh general jaankari hai, personal medical advice nahi. Doctor se poochhe bina koi dawai band ya change mat karo.'}
    return f"""<!--title: {esc(a['title'])} – {esc(d['NAME'][0])} · AYUSH Vaidya-->
<!--description: {esc(a['summary'])}-->
<!--nav: articles-->
<!--style-->
{ARTICLE_STYLE}
<!--body-->
<main class="wrap"><article class="art-wrap">
  <p class="crumbs"><a href="index.html" data-i18n="navHome">Home</a> › <a href="articles.html" data-i18n="mArticles">Health articles</a></p>
  <header class="cover{' has-img' if a['image'] else ''}">
    {'' if a['image'] else f'<span class="cover-e" aria-hidden="true">{a["emoji"]}</span>'}
    <div>
    <h1>{esc(a['title'])}</h1>
    <p>{esc(a['summary'])}</p>
    <a class="by" href="{a['author']}.html"><span class="av" style="background:{d['BG']}">{d['INI']}</span><span><b data-i18n="auth">{esc(d['NAME'][0])}</b><small><span data-i18n="authRole">{esc(d['ROLE'][0])}</span> · {a['pretty']}</small></span></a>
    </div>
    {f'<img class="cover-img" src="{a["image"]}" alt="">' if a['image'] else ''}
  </header>
  <div class="art-body">
    {a['body']}
    <p class="note" style="margin-top:22px" data-i18n="note">This is general information, not personal medical advice. Never stop or change a medicine without asking your doctor.</p>
    <div class="end"><a class="btn primary" href="index.html?doctor={a['author']}#book" data-i18n="bookWith">Book with {esc(d['NAME'][0])} ↗</a><a class="btn" href="articles.html" data-i18n="allArts">← All articles</a></div>
  </div>
</article></main>
<!--i18n-->
<script>window.AYUSH_PAGE = {{ hi: {json.dumps(hi, ensure_ascii=False)}, hinglish: {json.dumps(hl, ensure_ascii=False)} }};</script>
"""


def latest_section(arts):
    """Newest articles as cards, then every older one in a collapsed list (date + headline)."""
    entries = sorted([dict(s, image='', pretty=pretty_date(s['date'])) for s in STATIC_ARTICLES] + arts,
                     key=lambda a: a['date'], reverse=True)
    if not entries:
        return ''
    esc = lambda t: html.escape(t, quote=False)
    keys = lambda a, i: f' data-i18n="{a["i18n"][i]}"' if a.get('i18n') else ''
    cards = []
    for a in entries[:LATEST_CARDS]:
        d = DOCTORS[a['author']]
        pic = f'<img class="fthumb" src="{a["image"]}" alt="">' if a['image'] else f'<span class="fe">{a["emoji"]}</span>'
        cards.append(f"""    <a class="card fa" href="{a['file']}">{pic}<span><span class="pill live">{a['pretty']}</span><h3{keys(a, 0)}>{esc(a['title'])}</h3><p{keys(a, 1)}>{esc(a['summary'])}</p><span class="fby"><span class="av" style="background:{d['BG']}">{d['INI']}</span><span>{esc(d['NAME'][0])}</span></span></span></a>""")
    html_out = ('<section class="block"><div class="wrap">\n  <div class="head"><span class="sticker" data-i18n="latestSticker">🆕 Latest</span><h2 data-i18n="latestH">Latest from our Vaidyas</h2></div>\n'
                '  <div class="feat">\n' + '\n'.join(cards) + '\n  </div>\n')
    older = entries[LATEST_CARDS:]
    if older:
        rows = '\n'.join(f"""      <li><a href="{a['file']}"><time datetime="{a['date']}">{a['pretty']}</time><span class="t"{keys(a, 0)}>{esc(a['title'])}</span><span class="who" style="background:{DOCTORS[a['author']]['BG']}">{DOCTORS[a['author']]['INI']}</span></a></li>"""
                         for a in older)
        html_out += (f'  <details class="card archive"><summary><span data-i18n="olderH">Older articles</span> ({len(older)})</summary>\n'
                     f'    <ul class="arch">\n{rows}\n    </ul>\n  </details>\n')
    return html_out + '</div></section>\n'


def split(src):
    meta = dict(re.findall(r'<!--(title|description|nav): (.*?)-->', src))
    parts = {}
    for name in ('style', 'body', 'i18n', 'scripts'):
        m = re.search(rf'<!--{name}-->\n(.*?)(?=\n<!--(?:style|body|i18n|scripts)-->|\Z)', src, re.S)
        parts[name] = m.group(1).rstrip() if m else ''
    return meta, parts


def page(meta, parts, name):
    nav = meta.get('nav', '')
    cur = {f'cur_{k}': (' aria-current="page"' if k == nav else '') for k in NAV_KEYS}
    book = f'index.html?doctor={nav}#book' if nav in DOCTORS else ('#book' if nav == 'home' else 'index.html#book')
    url = SITE_URL + ('' if name == 'index.html' else name)
    html = HEAD.format(title=meta['title'], description=meta['description'], url=url, v=VERSION, style=parts['style'])
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
        if os.path.isdir(IMAGES_DIR):
            shutil.copytree(IMAGES_DIR, os.path.join(OUT, 'images'), dirs_exist_ok=True)
        dirs.append(os.path.join(HERE, 'pages_suggest'))
    arts = read_articles()
    built = []
    for pages_dir in dirs:
        built += build_dir(pages_dir, suggest, arts)
    for a in arts:
        write(a['file'], page(*split(article_source(a)), a['file']), suggest)
        built.append(a['file'])
    if not suggest:
        write_seo_files(built)
    print('built into', OUT + ':', ', '.join(built))


def write_seo_files(pages):
    # sitemap.xml + robots.txt so search engines find every public page; admin.html stays out.
    urls = ''.join(f'  <url><loc>{SITE_URL}{"" if p == "index.html" else p}</loc></url>\n' for p in sorted(pages))
    open(os.path.join(OUT, 'sitemap.xml'), 'w', encoding='utf-8').write(
        '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + urls + '</urlset>\n')
    open(os.path.join(OUT, 'robots.txt'), 'w', encoding='utf-8').write(
        f'User-agent: *\nDisallow: /admin.html\nSitemap: {SITE_URL}sitemap.xml\n')


def build_dir(pages_dir, suggest, arts):
    built = []
    for name in sorted(os.listdir(pages_dir)):
        if not name.endswith('.src.html'):
            continue
        src = open(os.path.join(pages_dir, name), encoding='utf-8').read()
        src = src.replace('<!--latest-articles-->\n', latest_section(arts))
        if name == 'doctor.tpl.src.html':
            for key in DOCTORS:
                filled = src
                for k, v in doctor_values(key).items():
                    filled = filled.replace('{{' + k + '}}', v)
                assert '{{' not in filled, key
                write(f'{key}.html', page(*split(filled), f'{key}.html'), suggest)
                built.append(f'{key}.html')
            continue
        out = name.replace('.src.html', '.html')
        write(out, page(*split(src), out), suggest)
        built.append(out)
    return built


def write(name, html_text, suggest):
    html_text = fill_details(html_text)
    if suggest:
        html_text = html_text.replace('<body>\n', '<body>\n' + SUGGEST_BAR, 1)
    open(os.path.join(OUT, name), 'w', encoding='utf-8').write(html_text)


if __name__ == '__main__':
    main()
