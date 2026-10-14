import 'package:firebase_core/firebase_core.dart';

/// Firebase config of the "MasterG" web app (project PuzzleGame). These
/// values are public by design for web apps; data is protected by the
/// Firestore rules.
const webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAvjPRpbTGXb3LDaoXFJZeJt66D-rNK2hA',
  appId: '1:946096157144:web:b71838810ccecc0f5d02ad',
  messagingSenderId: '946096157144',
  projectId: 'project-8e4ae5be-6ac1-49ce-bc8',
  // Our own site: Firebase Hosting serves /__/auth/* here, so sign-in
  // redirects stay on the same domain (needed for iPhone Safari).
  authDomain: 'masterg-games.web.app',
  storageBucket: 'project-8e4ae5be-6ac1-49ce-bc8.firebasestorage.app',
  measurementId: 'G-R39QB9003L',
);
