const express = require('express');
const cors = require('cors');
require('dotenv').config();
const path = require('path');

const app = express();

// Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin', 'X-Requested-With'],
  exposedHeaders: ['Content-Range', 'X-Content-Range'],
  credentials: true,
  maxAge: 86400
}));
app.use(express.json());

// Middleware pour gestion des fichiers uploadés
app.use(express.urlencoded({ extended: true }));

// Middleware de logging
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  
  // Log du corps de la requête si présent
  if (req.method !== 'GET' && req.body) {
    const sanitizedBody = { ...req.body };
    // Suppression des données sensibles
    if (sanitizedBody.password) sanitizedBody.password = '***';
    console.log('  Body:', JSON.stringify(sanitizedBody, null, 2));
  }
  
  // Log détaillé des headers pour les requêtes d'upload
  if (req.url.includes('/upload')) {
    console.log('  Headers:', JSON.stringify(req.headers, null, 2));
    console.log('  Upload request detected');
  }
  
  // Capture de la réponse
  const originalSend = res.send;
  res.send = function(body) {
    console.log(`  Response (${res.statusCode}):`);
    if (body && body.length < 1000) console.log('  ', typeof body === 'string' ? body : JSON.stringify(body).substring(0, 500));
    return originalSend.apply(res, arguments);
  };
  
  next();
});

// Servir les fichiers statiques du dossier public
app.use(express.static(path.join(__dirname, 'public')));

// Route pour vérifier l'accès aux fichiers statiques
app.get('/uploads-check', (req, res) => {
  res.json({
    success: true,
    message: 'Le dossier uploads est accessible',
    publicPath: path.join(__dirname, 'public'),
    uploadsPath: path.join(__dirname, 'public', 'uploads')
  });
});

// Simple ping route pour tester la connectivité
app.get('/ping', (req, res) => {
  console.log('Route /ping appelée');
  res.json({ success: true, message: 'pong' });
});

// Route de test pour vérifier que le serveur fonctionne
app.get('/test', (req, res) => {
  console.log('Route de test appelée');
  res.json({ message: 'Le serveur fonctionne correctement!' });
});

// Routes
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const facilityRoutes = require('./routes/facilities');
const equipmentRoutes = require('./routes/equipment');
const courseRoutes = require('./routes/courses');
const uploadRoutes = require('./routes/upload');
const reservationRoutes = require('./routes/reservations');

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/facilities', facilityRoutes);
app.use('/api/equipment', equipmentRoutes);
app.use('/api/courses', courseRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/reservations', reservationRoutes);

// Base route
app.get('/', (req, res) => {
  console.log('Route racine appelée');
  res.send('API is running');
});

// Port
const PORT = process.env.PORT || 5000;

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Test the API at http://localhost:${PORT}/test`);
  console.log(`Or using your network IP: http://192.168.1.185:${PORT}/test`);
}); 