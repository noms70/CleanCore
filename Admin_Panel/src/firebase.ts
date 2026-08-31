import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
  apiKey: "AIzaSyBkByQALxi6tU9tj5Z9TKr4LPs5DJ_iQgw",
  authDomain: "cleancore-b98d6.firebaseapp.com",
  projectId: "cleancore-b98d6",
  storageBucket: "cleancore-b98d6.firebasestorage.app",
  messagingSenderId: "826663543245",
  appId: "1:826663543245:web:039209faa98f261d012484",
  measurementId: "G-F3CFLFFX93"
};

const app = initializeApp(firebaseConfig);

// Firestore
export const db = getFirestore(app);

// Firebase Auth
export const auth = getAuth(app);
