const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

// Route d'inscription
router.post('/register', async (req, res) => {
  console.log('Route /register appelée avec:', req.body);
  try {
    const { username, email, password } = req.body;
    
    // Vérifier si l'utilisateur existe déjà
    console.log('Vérification si l\'email existe déjà:', email);
    const [existingUsers] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
    
    if (existingUsers.length > 0) {
      console.log('Email déjà utilisé');
      return res.status(400).json({ message: 'Cet email est déjà utilisé' });
    }
    
    // Hacher le mot de passe
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);
    
    // Insérer l'utilisateur dans la base de données
    console.log('Insertion de l\'utilisateur dans la base de données');
    const [result] = await pool.query(
      'INSERT INTO users (username, email, password) VALUES (?, ?, ?)',
      [username, email, hashedPassword]
    );
    
    // Générer un token JWT
    const token = jwt.sign(
      { id: result.insertId, username, email },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );
    
    console.log('Utilisateur créé avec succès, ID:', result.insertId);
    res.status(201).json({
      message: 'Utilisateur créé avec succès',
      token,
      user: { id: result.insertId, username, email }
    });
  } catch (error) {
    console.error('Erreur lors de l\'inscription:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route de connexion
router.post('/login', async (req, res) => {
  console.log('Route /login appelée avec:', req.body);
  try {
    const { email, password } = req.body;
    
    // Vérifier si l'utilisateur existe
    console.log('Recherche de l\'utilisateur avec email:', email);
    const [users] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
    
    if (users.length === 0) {
      console.log('Aucun utilisateur trouvé avec cet email');
      return res.status(400).json({ message: 'Email ou mot de passe incorrect' });
    }
    
    const user = users[0];
    console.log('Utilisateur trouvé, vérification du mot de passe');
    
    // Vérifier le mot de passe
    const isPasswordValid = await bcrypt.compare(password, user.password);
    
    if (!isPasswordValid) {
      console.log('Mot de passe invalide');
      return res.status(400).json({ message: 'Email ou mot de passe incorrect' });
    }
    
    // Générer un token JWT
    const token = jwt.sign(
      { id: user.id, username: user.username, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );
    
    console.log('Connexion réussie pour l\'utilisateur ID:', user.id, 'Rôle:', user.role);
    res.json({
      message: 'Connexion réussie',
      token,
      user: { 
        id: user.id, 
        username: user.username, 
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Erreur lors de la connexion:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Middleware pour vérifier le token JWT
const verifyToken = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Token non fourni' });
  }
  
  const token = authHeader.split(' ')[1];
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    console.error('Erreur de vérification du token:', error);
    return res.status(401).json({ message: 'Token invalide' });
  }
};

// Middleware pour vérifier si l'utilisateur est admin
const verifyAdmin = async (req, res, next) => {
  try {
    const [users] = await pool.query('SELECT role FROM users WHERE id = ?', [req.user.id]);
    
    if (users.length === 0) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }
    
    if (users[0].role !== 'admin') {
      return res.status(403).json({ message: 'Accès refusé: rôle admin requis' });
    }
    
    next();
  } catch (error) {
    console.error('Erreur lors de la vérification du rôle admin:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
};

// Route pour récupérer tous les utilisateurs (admin seulement)
router.get('/users', verifyToken, verifyAdmin, async (req, res) => {
  console.log('Route /users appelée par l\'utilisateur ID:', req.user.id);
  try {
    const [users] = await pool.query('SELECT id, username, email, role, created_at FROM users');
    
    console.log(`${users.length} utilisateurs récupérés`);
    res.json(users);
  } catch (error) {
    console.error('Erreur lors de la récupération des utilisateurs:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

module.exports = router; 