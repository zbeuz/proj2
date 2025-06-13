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

// Route pour récupérer tous les terrains
router.get('/', verifyToken, async (req, res) => {
  console.log('Route GET /facilities appelée par l\'utilisateur ID:', req.user.id);
  try {
    const [facilities] = await pool.query('SELECT * FROM facilities');
    
    console.log(`${facilities.length} terrains récupérés`);
    res.json(facilities);
  } catch (error) {
    console.error('Erreur lors de la récupération des terrains:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour récupérer uniquement les terrains
router.get('/terrains', verifyToken, async (req, res) => {
  console.log('Route GET /facilities/terrains appelée par l\'utilisateur ID:', req.user.id);
  try {
    const [terrains] = await pool.query('SELECT * FROM facilities WHERE is_terrain = 1');
    
    console.log(`${terrains.length} terrains récupérés`);
    res.json(terrains);
  } catch (error) {
    console.error('Erreur lors de la récupération des terrains:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour récupérer un terrain par son ID
router.get('/:id', verifyToken, async (req, res) => {
  const facilityId = req.params.id;
  console.log(`Route GET /facilities/${facilityId} appelée par l'utilisateur ID: ${req.user.id}`);
  
  try {
    const [facilities] = await pool.query('SELECT * FROM facilities WHERE id = ?', [facilityId]);
    
    if (facilities.length === 0) {
      return res.status(404).json({ message: 'Terrain non trouvé' });
    }
    
    res.json(facilities[0]);
  } catch (error) {
    console.error(`Erreur lors de la récupération du terrain ID ${facilityId}:`, error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour créer un nouveau terrain (admin seulement)
router.post('/', verifyToken, verifyAdmin, async (req, res) => {
  console.log('Route POST /facilities appelée avec:', req.body);
  try {
    const { 
      name, 
      description, 
      image_url,
      opening_hours, 
      closing_hours, 
      is_available = 1,
      is_terrain = 0
    } = req.body;
    
    // Insérer le terrain dans la base de données
    const [result] = await pool.query(
      'INSERT INTO facilities (name, description, image_url, opening_hours, closing_hours, is_available, is_terrain) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [name, description, image_url, opening_hours, closing_hours, is_available, is_terrain]
    );
    
    res.status(201).json({
      id: result.insertId,
      name,
      description,
      image_url,
      opening_hours,
      closing_hours,
      is_available,
      is_terrain,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    console.error('Erreur lors de la création du terrain:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour mettre à jour un terrain (admin seulement)
router.put('/:id', verifyToken, verifyAdmin, async (req, res) => {
  const facilityId = req.params.id;
  console.log(`Route PUT /facilities/${facilityId} appelée avec:`, req.body);
  
  try {
    const { 
      name, 
      description, 
      image_url,
      opening_hours, 
      closing_hours, 
      is_available,
      is_terrain
    } = req.body;
    
    // Vérifier si le terrain existe
    const [facilities] = await pool.query('SELECT * FROM facilities WHERE id = ?', [facilityId]);
    
    if (facilities.length === 0) {
      return res.status(404).json({ message: 'Terrain non trouvé' });
    }
    
    // Mettre à jour le terrain
    await pool.query(
      'UPDATE facilities SET name = ?, description = ?, image_url = ?, opening_hours = ?, closing_hours = ?, is_available = ?, is_terrain = ? WHERE id = ?',
      [name, description, image_url, opening_hours, closing_hours, is_available, is_terrain, facilityId]
    );
    
    res.json({
      id: parseInt(facilityId),
      name,
      description,
      image_url,
      opening_hours,
      closing_hours,
      is_available,
      is_terrain,
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    console.error(`Erreur lors de la mise à jour du terrain ID ${facilityId}:`, error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour supprimer un terrain (admin seulement)
router.delete('/:id', verifyToken, verifyAdmin, async (req, res) => {
  const facilityId = req.params.id;
  console.log(`Route DELETE /facilities/${facilityId} appelée`);
  
  try {
    // Vérifier si le terrain existe
    const [facilities] = await pool.query('SELECT * FROM facilities WHERE id = ?', [facilityId]);
    
    if (facilities.length === 0) {
      return res.status(404).json({ message: 'Terrain non trouvé' });
    }
    
    // Supprimer le terrain
    await pool.query('DELETE FROM facilities WHERE id = ?', [facilityId]);
    
    res.json({ message: 'Terrain supprimé avec succès' });
  } catch (error) {
    console.error(`Erreur lors de la suppression du terrain ID ${facilityId}:`, error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

module.exports = router; 