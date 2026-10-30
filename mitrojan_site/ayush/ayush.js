// AYUSH Vaidya – shared script for every page: language (EN / हिं / Hinglish), the
// floating health-tips background and the mobile menu.
// English lives in the HTML. A page adds its own Hindi/Hinglish strings in
// window.AYUSH_PAGE = { hi: {...}, hinglish: {...} } before loading this file.
(function () {
  var SHARED = {
    hi: {
      brand: 'आयुष वैद्य', brandSub: 'मित्रोजन द्वारा', menu: 'मेन्यू',
      navDoctors: 'चिकित्सक', navBenefits: 'फ़ायदे', navEat: 'क्या खाएँ', navBmi: 'BMI', navBook: 'बुक करें', navHome: 'होम',
      navDiet: 'डाइट प्लान', navProducts: 'प्रोडक्ट', navHistory: 'इतिहास', navMore: 'और',
      mQuiz: 'प्रकृति क्विज़', mTrust: 'चिकित्सकों की योग्यता', mReviews: 'समीक्षाएँ', mArticles: 'स्वास्थ्य लेख', mContact: 'संपर्क', mPolicies: 'नीतियाँ',
      ddDolly: 'वैद्य डॉली गुप्ता', ddPooja: 'वैद्य पूजा गुप्ता', ddDollyRole: 'जनरल फ़िज़िशियन', ddPoojaRole: 'आहार, पोषण और जीवनशैली',
      tk1: '🌿 आयुर्वेद, आज की ज़िंदगी के लिए', tk2: '📹 15 मिनट का ऑनलाइन परामर्श', tk3: '🥗 वैद्य पूजा गुप्ता के डाइट प्लान', tk4: '⚖️ मुफ़्त BMI कैलकुलेटर', tk5: '🇮🇳 पूरे भारत में, घर बैठे',
      fHome: 'मित्रोजन होम', fAdmin: 'क्लिनिक लॉग इन', fRights: '© 2026 मित्रोजन · Ideal World', fAbout: 'मित्रोजन की ऑनलाइन आयुर्वेद देखभाल।',
      fNote: 'यह वेबसाइट चिकित्सकीय सलाह नहीं देती। आपात स्थिति में 112 पर कॉल करें।'
    },
    hinglish: {
      brand: 'AYUSH Vaidya', brandSub: 'Mitrojan ki taraf se', menu: 'Menu',
      navDoctors: 'Doctors', navBenefits: 'Fayde', navEat: 'Kya khayein', navBmi: 'BMI', navBook: 'Book kariye', navHome: 'Home',
      navDiet: 'Diet plan', navProducts: 'Products', navHistory: 'Itihaas', navMore: 'Aur',
      mQuiz: 'Prakriti quiz', mTrust: 'Doctors ki qualification', mReviews: 'Reviews', mArticles: 'Health articles', mContact: 'Contact', mPolicies: 'Policies',
      ddDolly: 'Vaidya Dolly Gupta', ddPooja: 'Vaidya Pooja Gupta', ddDollyRole: 'General Physician', ddPoojaRole: 'Diet, Nutrition aur Lifestyle',
      tk1: '🌿 Ayurveda, aaj ki life ke liye', tk2: '📹 15 minute ka online consultation', tk3: '🥗 Vaidya Pooja Gupta ke diet plans', tk4: '⚖️ Free BMI calculator', tk5: '🇮🇳 Poore Bharat mein, ghar baithe',
      fHome: 'Mitrojan home', fAdmin: 'Clinic login', fRights: '© 2026 Mitrojan · Ideal World', fAbout: 'Mitrojan ki online Ayurveda care.',
      fNote: 'Yeh website medical advice nahi deti. Emergency mein 112 par call kariye.'
    }
  };

  var TIPS = {
    en: ['💧 Drink enough water', '🚶 Walk 30 minutes a day', '😴 Sleep 7–8 hours', '🧘 Stretch or do yoga', '🥗 Half your plate: vegetables', '☀️ Get morning sunlight',
      '📵 Take a screen break every hour', '🍲 Early, light dinner', '🧂 Less salt and sugar', '🌾 Try millets', '🫁 5 minutes of deep breathing', '🍎 Eat seasonal fruit',
      '🩺 Yearly health check-up', '🧼 Wash your hands', '🚭 Say no to tobacco', '😊 Talk, laugh, de-stress'],
    hi: ['💧 पर्याप्त पानी पिएँ', '🚶 रोज़ 30 मिनट टहलें', '😴 7–8 घंटे की नींद', '🧘 योग या स्ट्रेचिंग करें', '🥗 आधी थाली सब्ज़ियाँ', '☀️ सुबह की धूप लें',
      '📵 हर घंटे स्क्रीन से ब्रेक', '🍲 रात का खाना जल्दी और हल्का', '🧂 नमक और चीनी कम', '🌾 मोटा अनाज (मिलेट) खाएँ', '🫁 5 मिनट गहरी साँस', '🍎 मौसमी फल खाएँ',
      '🩺 साल में एक बार जाँच', '🧼 हाथ धोएँ', '🚭 तंबाकू को ना', '😊 बात करें, हँसें, तनाव घटाएँ'],
    hinglish: ['💧 Paani bharpoor piyo', '🚶 Roz 30 minute walk', '😴 7–8 ghante ki neend', '🧘 Yoga ya stretching', '🥗 Aadhi thali sabzi', '☀️ Subah ki dhoop lo',
      '📵 Har ghante screen break', '🍲 Dinner jaldi aur halka', '🧂 Namak-cheeni kam', '🌾 Millets try karo', '🫁 5 minute deep breathing', '🍎 Mausami phal khao',
      '🩺 Saal mein ek check-up', '🧼 Haath dhoyo', '🚭 Tobacco ko na', '😊 Baat karo, hanso, stress kam karo']
  };

  var PAGE = window.AYUSH_PAGE || {};
  var I18N = { en: {}, hi: Object.assign({}, SHARED.hi, PAGE.hi), hinglish: Object.assign({}, SHARED.hinglish, PAGE.hinglish) };
  var nodes = document.querySelectorAll('[data-i18n]');
  var phs = document.querySelectorAll('[data-i18n-ph]');
  nodes.forEach(function (el) { I18N.en[el.dataset.i18n] = el.textContent; });
  phs.forEach(function (el) { I18N.en[el.dataset.i18nPh] = el.placeholder; });
  var SITES = /^(mitrojan\.in|ayush\.mitrojan\.in|bittumobile\.mitrojan\.in)$/;
  var current = 'en';

  // ---- background ----
  var bg = document.createElement('div');
  bg.className = 'bg';
  bg.setAttribute('aria-hidden', 'true');
  bg.innerHTML = '<span class="blob b1"></span><span class="blob b2"></span><span class="blob b3"></span>' +
    ['🩺', '🌿', '🍃', '❤️', '🧘', '🥕'].map(function (e, i) {
      return '<span class="icon" style="left:' + [6, 88, 14, 80, 46, 92][i] + '%;top:' + [22, 30, 68, 74, 88, 52][i] + '%;animation-delay:-' + i * 1.3 + 's">' + e + '</span>';
    }).join('');
  document.body.prepend(bg);
  function drawTips(lang) {
    bg.querySelectorAll('.tip').forEach(function (t) { t.remove(); });
    var list = TIPS[lang] || TIPS.en;
    var n = window.innerWidth < 700 ? 8 : list.length;
    for (var i = 0; i < n; i++) {
      var s = document.createElement('span');
      s.className = 'tip';
      s.textContent = list[i];
      s.style.setProperty('--x', ((i * 37) % 88 + 2) + '%');
      s.style.setProperty('--d', (32 + (i % 5) * 6) + 's');
      s.style.setProperty('--delay', '-' + ((i * 5.3) % 40).toFixed(1) + 's');
      bg.append(s);
    }
  }

  function setLang(lang) {
    if (!I18N[lang]) lang = 'en';
    current = lang;
    var dict = I18N[lang];
    nodes.forEach(function (el) { var t = dict[el.dataset.i18n]; if (t != null) el.textContent = t; });
    phs.forEach(function (el) { var t = dict[el.dataset.i18nPh]; if (t != null) el.placeholder = t; });
    document.documentElement.lang = lang === 'hi' ? 'hi' : lang === 'hinglish' ? 'hi-Latn' : 'en';
    document.querySelectorAll('.lang button').forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.lang === lang)); });
    // Links to the other Mitrojan sites carry ?lang=, so the choice follows the visitor.
    document.querySelectorAll('a[href^="http"]').forEach(function (a) {
      var u = new URL(a.href);
      if (!SITES.test(u.hostname)) return;
      if (lang === 'en') u.searchParams.delete('lang'); else u.searchParams.set('lang', lang);
      a.href = u.toString();
    });
    try { localStorage.setItem('mitrojan.lang', lang); } catch (e) {}
    drawTips(lang);
    document.dispatchEvent(new CustomEvent('ayush:lang', { detail: lang }));
  }

  window.AYUSH = {
    get lang() { return current; },
    t: function (key) { var d = I18N[current]; return d[key] != null ? d[key] : I18N.en[key]; },
    setLang: setLang
  };

  document.querySelectorAll('.lang button').forEach(function (b) { b.addEventListener('click', function () { setLang(b.dataset.lang); }); });

  // ---- menu (mobile) and doctors dropdown ----
  var header = document.querySelector('header.site');
  var menuBtn = document.querySelector('.menu-btn');
  if (menuBtn) menuBtn.addEventListener('click', function () {
    var open = header.classList.toggle('open');
    menuBtn.setAttribute('aria-expanded', String(open));
  });
  document.querySelectorAll('nav.main a').forEach(function (a) { a.addEventListener('click', function () { header.classList.remove('open'); }); });
  document.querySelectorAll('.dd > button').forEach(function (b) {
    b.addEventListener('click', function (ev) {
      ev.stopPropagation();
      var open = b.parentElement.classList.toggle('open');
      b.setAttribute('aria-expanded', String(open));
    });
  });
  document.addEventListener('click', function () { document.querySelectorAll('.dd.open').forEach(function (d) { d.classList.remove('open'); }); });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { document.querySelectorAll('.dd.open').forEach(function (d) { d.classList.remove('open'); }); header.classList.remove('open'); }
  });

  var saved = new URLSearchParams(location.search).get('lang');
  if (!I18N[saved]) {
    try { saved = localStorage.getItem('mitrojan.lang') || localStorage.getItem('ayush.lang'); } catch (e) { saved = null; }
  }
  setLang(saved || 'en');
})();
