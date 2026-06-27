import { initializeApp, getApps } from 'firebase/app';
import { getMessaging, getToken, onMessage } from 'firebase/messaging';
import { supabase } from '@/lib/supabase';

const firebaseConfig = {
  apiKey: 'AIzaSyBhjDg-AOeNJxM8ylhf0yXxuzn6svmeaO0',
  authDomain: 'ivey-cap.firebaseapp.com',
  projectId: 'ivey-cap',
  storageBucket: 'ivey-cap.firebasestorage.app',
  messagingSenderId: '632705951068',
  appId: process.env.NEXT_PUBLIC_FIREBASE_WEB_APP_ID || '1:632705951068:web:03c2c0084f7d05d055cd99',
  measurementId: 'G-NSETNNS5QV',
};

const VAPID_KEY = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY || 'BAPKF8-iwNFxa_E9y9GuVb0L03CMjkMv6OqItaR2MwXdU-p75yROAheeCIOjz_76Ggk4u2SMDw3sBDuUQ7ZzE1A';

export function isWebPushConfigured(): boolean {
  return (
    firebaseConfig.appId.length > 0 &&
    firebaseConfig.appId !== 'REPLACE_ME' &&
    VAPID_KEY.length > 0
  );
}

function getFirebaseApp() {
  if (getApps().length > 0) return getApps()[0];
  return initializeApp(firebaseConfig);
}

async function registerServiceWorker(): Promise<ServiceWorkerRegistration> {
  return navigator.serviceWorker.register('/firebase-messaging-sw.js');
}

export async function requestWebPushPermission(): Promise<string | null> {
  if (!isWebPushConfigured()) {
    console.warn('Firebase web push not configured — set FIREBASE_WEB_APP_ID and FIREBASE_VAPID_KEY in .env');
    return null;
  }
  if (!('Notification' in window) || !('serviceWorker' in navigator)) {
    return null;
  }

  const permission = await Notification.requestPermission();
  if (permission !== 'granted') return null;

  try {
    const app = getFirebaseApp();
    const sw = await registerServiceWorker();
    const messaging = getMessaging(app);
    const token = await getToken(messaging, {
      vapidKey: VAPID_KEY,
      serviceWorkerRegistration: sw,
    });
    await persistToken(token);

    // Handle foreground messages (app tab is open and active).
    onMessage(messaging, (payload) => {
      const title = payload.notification?.title ?? 'AgriLink';
      const body = payload.notification?.body ?? '';
      if (Notification.permission === 'granted') {
        new Notification(title, { body, icon: '/app-icon.png' });
      }
    });

    return token;
  } catch (e) {
    console.error('Web push registration failed:', e);
    return null;
  }
}

async function persistToken(token: string | null) {
  if (!token) return;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;
  await supabase
    .from('user_profiles')
    .update({ fcm_token: token })
    .eq('id', user.id);
}

export async function clearWebPushToken() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;
  await supabase
    .from('user_profiles')
    .update({ fcm_token: null })
    .eq('id', user.id);
}

export async function syncWebPushToken() {
  if (!isWebPushConfigured()) return;
  if (!('Notification' in window)) return;
  if (Notification.permission !== 'granted') return;

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  // Only sync if push_enabled is true in user settings.
  const { data: settings } = await supabase
    .from('user_notification_settings')
    .select('push_enabled')
    .eq('user_id', user.id)
    .maybeSingle();
  if (!settings?.push_enabled) return;

  try {
    const app = getFirebaseApp();
    const sw = await registerServiceWorker();
    const messaging = getMessaging(app);
    const token = await getToken(messaging, {
      vapidKey: VAPID_KEY,
      serviceWorkerRegistration: sw,
    });
    await persistToken(token);
  } catch (e) {
    console.error('Web push token sync failed:', e);
  }
}
