// Firebase background message handler for AgriLink web push notifications.
// This file must stay in /public so it is served from the root of the domain.
// Service workers cannot access environment variables, so the Firebase config
// is inlined here.  The API key and project values are not secret — they are
// the same client-side keys already shipped in the mobile app bundle.
//
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBhjDg-AOeNJxM8ylhf0yXxuzn6svmeaO0',
  authDomain: 'ivey-cap.firebaseapp.com',
  projectId: 'ivey-cap',
  storageBucket: 'ivey-cap.firebasestorage.app',
  messagingSenderId: '632705951068',
  appId: '1:632705951068:web:03c2c0084f7d05d055cd99',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'AgriLink';
  const body = payload.notification?.body ?? '';
  self.registration.showNotification(title, {
    body,
    icon: '/app-icon.png',
  });
});
