import 'package:firebase_core/firebase_core.dart';

/// Firebase config of the "MasterG" web app (project PuzzleGame). These
/// values are public by design for web apps; data is protected by the
/// Firestore rules.
///
/// Sign-in runs through the site's own domain when it is one of our Firebase
/// Hosting domains (Hosting serves `/__/auth/handler` there), so browsers that
/// block third-party storage (Safari, Chrome on phones) still finish a
/// redirect sign-in.
FirebaseOptions get webFirebaseOptions => FirebaseOptions(
  apiKey: 'AIzaSyAvjPRpbTGXb3LDaoXFJZeJt66D-rNK2hA',
  appId: '1:946096157144:web:b71838810ccecc0f5d02ad',
  messagingSenderId: '946096157144',
  projectId: 'project-8e4ae5be-6ac1-49ce-bc8',
  authDomain: _authHosts.contains(Uri.base.host) ? Uri.base.host : 'project-8e4ae5be-6ac1-49ce-bc8.firebaseapp.com',
  storageBucket: 'project-8e4ae5be-6ac1-49ce-bc8.firebasestorage.app',
  measurementId: 'G-R39QB9003L',
);

const _authHosts = {'masterg-games.web.app', 'masterg-games.firebaseapp.com', 'games.mitrojan.in'};
