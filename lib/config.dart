import 'package:firebase_core/firebase_core.dart';

// Estos identificadores públicos provienen del google-services.json entregado.
const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAuh64b_I2OtC7KYuubCVx9plEe2pojp2M',
  appId: '1:919252353880:android:3d32e8039ee5faf55d5b2d',
  messagingSenderId: '919252353880',
  projectId: 'lapticon-eba31',
  storageBucket: 'lapticon-eba31.firebasestorage.app',
);

const backendUrl = 'https://lapticon-backend.onrender.com';
// Configurar con --dart-define=AERODATA_API_KEY=... al ejecutar o compilar.
const aerodataKey = String.fromEnvironment('AERODATA_API_KEY');
const aerodataHost = 'aerodatabox.p.rapidapi.com';
