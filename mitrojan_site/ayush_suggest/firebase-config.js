// Firebase web config of project PuzzleGame (same as the Master G web app).
// These values are public by design; the data is protected by Firestore rules
// (see ../../firestore_rules.txt, section "AYUSH Vaidya bookings").
export const firebaseConfig = {
  apiKey: 'AIzaSyAvjPRpbTGXb3LDaoXFJZeJt66D-rNK2hA',
  authDomain: 'project-8e4ae5be-6ac1-49ce-bc8.firebaseapp.com',
  projectId: 'project-8e4ae5be-6ac1-49ce-bc8',
  storageBucket: 'project-8e4ae5be-6ac1-49ce-bc8.firebasestorage.app',
  messagingSenderId: '946096157144',
  appId: '1:946096157144:web:b71838810ccecc0f5d02ad',
};

export const SDK = 'https://www.gstatic.com/firebasejs/10.12.2';

// 15-minute slots shown to patients (demo timings, change here).
export const SLOTS = [
  '10:00', '10:15', '10:30', '10:45', '11:00', '11:15', '11:30', '11:45', '12:00', '12:15', '12:30', '12:45',
  '17:00', '17:15', '17:30', '17:45', '18:00', '18:15', '18:30', '18:45',
];

export const DOCTORS = { dolly: 'Vaidya Dolly Gupta', pooja: 'Vaidya Pooja Gupta' };

// One Firestore document per doctor + slot, so a slot can never be booked twice.
export const bookingId = (date, time, doctor) => `${date}_${time.replace(':', '')}_${doctor}`;

export function isoDate(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
