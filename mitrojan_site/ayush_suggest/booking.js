// Booking form used by the home page and the diet page. A request is one Firestore
// document per doctor + slot (see firebase-config.js and the Firestore rules), so a
// taken slot is refused by the rules instead of being overwritten.
import { firebaseConfig, SDK, SLOTS, bookingId, isoDate } from './firebase-config.js';

let db, fs;
async function firestore() {
  if (!db) {
    const [{ initializeApp }, firestoreMod] = await Promise.all([import(`${SDK}/firebase-app.js`), import(`${SDK}/firebase-firestore.js`)]);
    fs = firestoreMod;
    db = fs.getFirestore(initializeApp(firebaseConfig));
  }
  return db;
}

/**
 * form: the <form> with fields name, phone, date, time, lang, consent and either a
 *       `doctor` radio group or options.doctor.
 * options.doctor: fixed doctor id ('pooja' on the diet page).
 * options.reason(form): text for the booking note (max 300 characters).
 * Messages come from hidden spans `#msgs [data-i18n=msgX]`, so they follow the language switch.
 */
export function setupBooking(form, options = {}) {
  const msgBox = form.querySelector('.form-msg');
  const dateIn = form.elements.date;
  const timeIn = form.elements.time;
  const submit = form.querySelector('[type=submit]');
  const msg = (key) => document.querySelector(`#msgs [data-i18n="${key}"]`).textContent;
  const show = (key, kind) => { msgBox.textContent = msg(key); msgBox.className = `form-msg full ${kind}`; };

  const today = new Date();
  const max = new Date(); max.setDate(max.getDate() + 60);
  dateIn.min = isoDate(today); dateIn.max = isoDate(max); dateIn.value = isoDate(today);

  function fillSlots() {
    const now = new Date();
    const isToday = dateIn.value === isoDate(now);
    const minutesNow = now.getHours() * 60 + now.getMinutes() + 30;
    const keep = timeIn.value;
    timeIn.replaceChildren();
    for (const t of SLOTS) {
      const [h, m] = t.split(':').map(Number);
      if (isToday && h * 60 + m < minutesNow) continue;
      const label = `${((h + 11) % 12) + 1}:${String(m).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}`;
      timeIn.append(new Option(label, t, false, t === keep));
    }
    timeIn.disabled = timeIn.options.length === 0;
  }
  dateIn.addEventListener('change', fillSlots);
  fillSlots();
  if (timeIn.disabled) { dateIn.value = isoDate(new Date(Date.now() + 864e5)); fillSlots(); }

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const f = form.elements;
    const name = f.name.value.trim().replace(/\s+/g, ' ');
    const phone = f.phone.value.replace(/\D/g, '').replace(/^(91|0)(?=[6-9]\d{9}$)/, '');
    if (name.length < 2) return show('msgName', 'err');
    if (!/^[6-9]\d{9}$/.test(phone)) return show('msgPhone', 'err');
    if (!f.date.value || !f.time.value) return show('msgSlot', 'err');
    if (!f.consent.checked) return show('msgConsent', 'err');

    submit.disabled = true;
    show('msgSending', 'ok');
    const choice = options.doctor || f.doctor.value;
    const doctors = choice === 'any' ? ['dolly', 'pooja'] : [choice];
    const reason = (options.reason ? options.reason(form) : (f.reason ? f.reason.value : '')).trim().slice(0, 300);
    try {
      await firestore();
      for (const doctor of doctors) {
        const data = { name, phone, doctor, date: f.date.value, time: f.time.value, lang: f.lang.value,
          status: 'requested', consent: true, createdAt: fs.serverTimestamp() };
        if (reason) data.reason = reason;
        try {
          // setDoc on an existing slot counts as an update, which the rules refuse: the slot is taken.
          await fs.setDoc(fs.doc(db, 'ayush_bookings', bookingId(data.date, data.time, doctor)), data);
          form.reset(); dateIn.value = isoDate(new Date()); fillSlots();
          return show('msgOk', 'ok');
        } catch (e) {
          if (e.code !== 'permission-denied') throw e;
        }
      }
      show('msgTaken', 'err');
    } catch (e) {
      console.error(e);
      show('msgFail', 'err');
    } finally {
      submit.disabled = false;
    }
  });
}
