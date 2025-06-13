const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

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
router.get('/', verifyToken, async (req, res) => {
  console.log('Route GET /users appelée par l\'utilisateur ID:', req.user.id);
  try {
    const [users] = await pool.query('SELECT id, username, email, role, created_at FROM users');
    
    console.log(`${users.length} utilisateurs récupérés`);
    res.json(users);
  } catch (error) {
    console.error('Erreur lors de la récupération des utilisateurs:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour récupérer un utilisateur par son ID
router.get('/:id', verifyToken, async (req, res) => {
  const userId = req.params.id;
  console.log(`Route GET /users/${userId} appelée par l'utilisateur ID: ${req.user.id}`);
  
  try {
    const [users] = await pool.query(
      'SELECT id, username, email, role, created_at FROM users WHERE id = ?', 
      [userId]
    );
    
    if (users.length === 0) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }
    
    res.json(users[0]);
  } catch (error) {
    console.error(`Erreur lors de la récupération de l'utilisateur ID ${userId}:`, error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour créer un nouvel utilisateur (admin seulement)
router.post('/', verifyToken, verifyAdmin, async (req, res) => {
  console.log('Route POST /users appelée avec:', req.body);
  try {
    const { username, email, password, role } = req.body;
    
    // Vérifier si l'utilisateur existe déjà
    const [existingUsers] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
    
    if (existingUsers.length > 0) {
      return res.status(400).json({ message: 'Cet email est déjà utilisé' });
    }
    
    // Hacher le mot de passe
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);
    
    // Insérer l'utilisateur dans la base de données
    const [result] = await pool.query(
      'INSERT INTO users (username, email, password, role) VALUES (?, ?, ?, ?)',
      [username, email, hashedPassword, role || 'user']
    );
    
    res.status(201).json({
      id: result.insertId,
      username,
      email,
      role: role || 'user'
    });
  } catch (error) {
    console.error('Erreur lors de la création de l\'utilisateur:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour mettre à jour un utilisateur (admin seulement)
router.put('/:id', verifyToken, verifyAdmin, async (req, res) => {
  const userId = req.params.id;
  console.log(`Route PUT /users/${userId} appelée avec:`, req.body);
  
  try {
    const { username, email, role } = req.body;
    
    // Vérifier si l'utilisateur existe
    const [users] = await pool.query('SELECT * FROM users WHERE id = ?', [userId]);
    
    if (users.length === 0) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }
    
    // Mettre à jour l'utilisateur
    await pool.query(
      'UPDATE users SET username = ?, email = ?, role = ? WHERE id = ?',
      [username, email, role, userId]
    );
    
    res.json({
      id: parseInt(userId),
      username,
      email,
      role
    });
  } catch (error) {
    console.error(`Erreur lors de la mise à jour de l'utilisateur ID ${userId}:`, error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour supprimer un utilisateur (admin seulement)
router.delete('/:id', verifyToken, verifyAdmin, async (req, res) => {
  const userId = req.params.id;
  console.log(`Route DELETE /users/${userId} appelée`);
  
  try {
    // Vérifier si l'utilisateur existe
    const [users] = await pool.query('SELECT * FROM users WHERE id = ?', [userId]);
    
    if (users.length === 0) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }
    
    // Empêcher la suppression de son propre compte
    if (parseInt(userId) === req.user.id) {
      return res.status(400).json({ message: 'Vous ne pouvez pas supprimer votre propre compte' });
    }
    
    // Supprimer l'utilisateur
    await pool.query('DELETE FROM users WHERE id = ?', [userId]);
    
    res.json({ message: 'Utilisateur supprimé avec succès' });
  } catch (error) {
    console.error(`Erreur lors de la suppression de l'utilisateur ID ${userId}:`, error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

module.exports = router; 