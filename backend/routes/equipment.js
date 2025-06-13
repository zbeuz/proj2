const express = require('express');
const router = express.Router();
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

// Route pour récupérer tous les équipements
router.get('/', verifyToken, async (req, res) => {
  console.log('Route GET /equipment appelée par l\'utilisateur ID:', req.user.id);
  try {
    const [equipment] = await pool.query('SELECT * FROM equipment');
    
    console.log(`${equipment.length} équipements récupérés`);
    res.json(equipment);
  } catch (error) {
    console.error('Erreur lors de la récupération des équipements:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour récupérer uniquement les équipements disponibles
router.get('/available', verifyToken, async (req, res) => {
  console.log('Route GET /equipment/available appelée par l\'utilisateur ID:', req.user.id);
  try {
    const [equipment] = await pool.query('SELECT * FROM equipment WHERE available_quantity > 0');
    
    console.log(`${equipment.length} équipements disponibles récupérés`);
    res.json(equipment);
  } catch (error) {
    console.error('Erreur lors de la récupération des équipements disponibles:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour récupérer un équipement par son ID
router.get('/:id', verifyToken, async (req, res) => {
  const equipmentId = req.params.id;
  console.log(`Route GET /equipment/${equipmentId} appelée par l'utilisateur ID: ${req.user.id}`);
  
  try {
    const [equipment] = await pool.query('SELECT * FROM equipment WHERE id = ?', [equipmentId]);
    
    if (equipment.length === 0) {
      return res.status(404).json({ message: 'Équipement non trouvé' });
    }
    
    res.json(equipment[0]);
  } catch (error) {
    console.error(`Erreur lors de la récupération de l'équipement ID ${equipmentId}:`, error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour créer un nouvel équipement (admin seulement)
router.post('/', verifyToken, verifyAdmin, async (req, res) => {
  console.log('Route POST /equipment appelée avec:', req.body);
  try {
    const { 
      name, 
      description, 
      image_url,
      total_quantity, 
      available_quantity, 
      category,
      condition = 'Bon'
    } = req.body;
    
    // Insérer l'équipement dans la base de données
    const [result] = await pool.query(
      'INSERT INTO equipment (name, description, image_url, total_quantity, available_quantity, category, `condition`) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [name, description, image_url, total_quantity, available_quantity || total_quantity, category, condition]
    );
    
    res.status(201).json({
      id: result.insertId,
      name,
      description,
      image_url,
      total_quantity,
      available_quantity: available_quantity || total_quantity,
      category,
      condition,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    console.error('Erreur lors de la création de l\'équipement:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour mettre à jour un équipement (admin seulement)
router.put('/:id', verifyToken, verifyAdmin, async (req, res) => {
  const equipmentId = req.params.id;
  console.log(`Route PUT /equipment/${equipmentId} appelée avec:`, req.body);
  
  try {
    const { 
      name, 
      description, 
      image_url,
      total_quantity, 
      available_quantity, 
      category,
      condition = 'Bon'
    } = req.body;
    
    // Vérifier si l'équipement existe
    const [equipment] = await pool.query('SELECT * FROM equipment WHERE id = ?', [equipmentId]);
    
    if (equipment.length === 0) {
      return res.status(404).json({ message: 'Équipement non trouvé' });
    }
    
    // Mettre à jour l'équipement
    await pool.query(
      'UPDATE equipment SET name = ?, description = ?, image_url = ?, total_quantity = ?, available_quantity = ?, category = ?, `condition` = ? WHERE id = ?',
      [name, description, image_url, total_quantity, available_quantity, category, condition, equipmentId]
    );
    
    res.json({
      id: parseInt(equipmentId),
      name,
      description,
      image_url,
      total_quantity,
      available_quantity,
      category,
      condition,
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    console.error(`Erreur lors de la mise à jour de l'équipement ID ${equipmentId}:`, error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour supprimer un équipement (admin seulement)
router.delete('/:id', verifyToken, verifyAdmin, async (req, res) => {
  const equipmentId = req.params.id;
  console.log(`Route DELETE /equipment/${equipmentId} appelée`);
  
  try {
    // Vérifier si l'équipement existe
    const [equipment] = await pool.query('SELECT * FROM equipment WHERE id = ?', [equipmentId]);
    
    if (equipment.length === 0) {
      return res.status(404).json({ message: 'Équipement non trouvé' });
    }
    
    // Supprimer l'équipement
    await pool.query('DELETE FROM equipment WHERE id = ?', [equipmentId]);
    
    res.json({ message: 'Équipement supprimé avec succès' });
  } catch (error) {
    console.error(`Erreur lors de la suppression de l'équipement ID ${equipmentId}:`, error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

module.exports = router; 