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

// Route pour récupérer toutes les réservations (admin seulement)
router.get('/', verifyToken, verifyAdmin, async (req, res) => {
  try {
    const [reservations] = await pool.query(`
      SELECT r.*, 
        c.name as course_title, 
        e.name as equipment_name,
        f.name as facility_name
      FROM reservations r
      LEFT JOIN courses c ON r.course_id = c.id
      LEFT JOIN equipment e ON r.equipment_id = e.id
      LEFT JOIN facilities f ON r.facility_id = f.id
      ORDER BY r.start_time DESC
    `);
    
    res.json(reservations);
  } catch (error) {
    console.error('Erreur lors de la récupération des réservations:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour récupérer les réservations de l'utilisateur courant
router.get('/me', verifyToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    const [reservations] = await pool.query(`
      SELECT r.*, 
        c.name as course_title, 
        e.name as equipment_name,
        f.name as facility_name,
        DATE(r.start_time) as date
      FROM reservations r
      LEFT JOIN courses c ON r.course_id = c.id
      LEFT JOIN equipment e ON r.equipment_id = e.id
      LEFT JOIN facilities f ON r.facility_id = f.id
      WHERE r.user_id = ?
      ORDER BY r.start_time DESC
    `, [userId]);
    
    res.json(reservations);
  } catch (error) {
    console.error(`Erreur lors de la récupération des réservations de l'utilisateur courant:`, error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour récupérer les réservations d'un utilisateur
router.get('/user/:userId', verifyToken, async (req, res) => {
  const userId = req.params.userId;
  
  // Vérifier que l'utilisateur demande ses propres réservations ou est admin
  if (parseInt(userId) !== req.user.id && req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Accès refusé: vous ne pouvez voir que vos propres réservations' });
  }
  
  try {
    const [reservations] = await pool.query(`
      SELECT r.*, 
        c.name as course_title, 
        e.name as equipment_name,
        f.name as facility_name
      FROM reservations r
      LEFT JOIN courses c ON r.course_id = c.id
      LEFT JOIN equipment e ON r.equipment_id = e.id
      LEFT JOIN facilities f ON r.facility_id = f.id
      WHERE r.user_id = ?
      ORDER BY r.start_time DESC
    `, [userId]);
    
    res.json(reservations);
  } catch (error) {
    console.error(`Erreur lors de la récupération des réservations de l'utilisateur ${userId}:`, error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route pour créer une réservation
router.post('/', verifyToken, async (req, res) => {
  console.log('Tentative de création de réservation:', req.body);
  
  const { 
    course_id, 
    equipment_id, 
    facility_id, 
    start_time, 
    end_time, 
    pickup_date, 
    return_date,
    equipment_quantity
  } = req.body;
  
  const userId = req.user.id;
  
  // Vérification: au moins un des IDs doit être fourni
  if (!course_id && !equipment_id && !facility_id) {
    return res.status(400).json({ message: 'Vous devez spécifier un cours, un équipement ou un terrain à réserver' });
  }
  
  // Vérifier que les formats de date sont valides
  if (!start_time || !end_time) {
    return res.status(400).json({ message: 'Les dates de début et de fin sont requises' });
  }
  
  try {
    // Tentative de conversion des dates
    const startDateTime = new Date(start_time);
    const endDateTime = new Date(end_time);
    
    // Correction du décalage horaire : ajout de 2 heures pour passer de UTC à UTC+2 (heure d'été française)
    const timeZoneOffset = 2; // UTC+2 pour la France en été
    
    // Créer de nouvelles dates avec le décalage horaire corrigé
    const correctedStartDateTime = new Date(startDateTime);
    correctedStartDateTime.setHours(startDateTime.getHours() + timeZoneOffset);
    
    const correctedEndDateTime = new Date(endDateTime);
    correctedEndDateTime.setHours(endDateTime.getHours() + timeZoneOffset);
    
    // Traitement des dates de retrait et de retour pour équipement, si fournies
    let pickupDateTime = null;
    let returnDateTime = null;
    let correctedPickupDateTime = null;
    let correctedReturnDateTime = null;
    
    if (equipment_id && pickup_date && return_date) {
      pickupDateTime = new Date(pickup_date);
      returnDateTime = new Date(return_date);
      
      // Corriger également ces dates
      correctedPickupDateTime = new Date(pickupDateTime);
      correctedPickupDateTime.setHours(pickupDateTime.getHours() + timeZoneOffset);
      
      correctedReturnDateTime = new Date(returnDateTime);
      correctedReturnDateTime.setHours(returnDateTime.getHours() + timeZoneOffset);
      
      if (isNaN(pickupDateTime.getTime()) || isNaN(returnDateTime.getTime())) {
        return res.status(400).json({ message: 'Formats de dates de retrait/retour invalides' });
      }
      
      // Vérifier si les dates sont différentes ou, si elles sont identiques, que le retour est après le retrait (via l'heure)
      if (returnDateTime < pickupDateTime) {
        return res.status(400).json({ message: 'La date de retour doit être après la date de retrait' });
      }
      
      // Si les dates sont identiques, s'assurer que l'heure de fin est après l'heure de début
      if (returnDateTime.getFullYear() === pickupDateTime.getFullYear() &&
          returnDateTime.getMonth() === pickupDateTime.getMonth() &&
          returnDateTime.getDate() === pickupDateTime.getDate() &&
          endDateTime <= startDateTime) {
        return res.status(400).json({ message: 'Pour une réservation sur la même journée, l\'heure de fin doit être après l\'heure de début' });
      }
    }
    
    console.log('Dates reçues - start_time:', start_time, '- end_time:', end_time);
    console.log('Dates converties - startDateTime:', startDateTime, '- endDateTime:', endDateTime);
    console.log('Dates corrigées - correctedStartDateTime:', correctedStartDateTime, '- correctedEndDateTime:', correctedEndDateTime);
    
    // Validation des dates
    if (isNaN(startDateTime.getTime()) || isNaN(endDateTime.getTime())) {
      console.error('Erreur de format de date - startDateTime.getTime():', 
        isNaN(startDateTime.getTime()) ? 'INVALIDE' : 'OK', 
        '- endDateTime.getTime():', 
        isNaN(endDateTime.getTime()) ? 'INVALIDE' : 'OK');
      return res.status(400).json({ message: 'Formats de date invalides' });
    }
    
    // Vérifier que la date de fin est après la date de début
    if (endDateTime <= startDateTime) {
      return res.status(400).json({ message: 'La date de fin doit être après la date de début' });
    }

    // Vérifier que les heures sont entre 8h et 22h en utilisant les dates corrigées
    const startHour = correctedStartDateTime.getHours();
    const endHour = correctedEndDateTime.getHours();
    const endMinutes = correctedEndDateTime.getMinutes();
    
    console.log(`Heures de réservation corrigées - startHour: ${startHour}, endHour: ${endHour}, endMinutes: ${endMinutes}`);
    
    // Récupérer les heures d'ouverture depuis les paramètres
    const [settings] = await pool.query('SELECT min_hour, max_hour FROM reservation_settings LIMIT 1');
    const minHour = settings[0].min_hour; // normalement 8
    const maxHour = settings[0].max_hour; // normalement 22
    
    // Vérifier que l'heure de début est au moins minHour et que l'heure de fin est au plus maxHour
    if (startHour < minHour || (endHour > maxHour || (endHour === maxHour && endMinutes > 0))) {
      return res.status(400).json({ 
        message: `Les réservations ne sont autorisées qu'entre ${minHour}h et ${maxHour}h`,
        details: `Heure début: ${startHour}h, Heure fin: ${endHour}h${endMinutes > 0 ? endMinutes + 'min' : ''}`
      });
    }
    
    // Formatage des dates en format MySQL - Utiliser les dates originales pour MySQL car la DB est en UTC
    const formattedStartTime = startDateTime.toISOString().slice(0, 19).replace('T', ' ');
    const formattedEndTime = endDateTime.toISOString().slice(0, 19).replace('T', ' ');
    const formattedPickupDate = pickupDateTime ? pickupDateTime.toISOString().slice(0, 19).replace('T', ' ') : null;
    const formattedReturnDate = returnDateTime ? returnDateTime.toISOString().slice(0, 19).replace('T', ' ') : null;
    
    console.log('Dates formatées pour MySQL:', formattedStartTime, formattedEndTime);
    if (formattedPickupDate && formattedReturnDate) {
      console.log('Dates de retrait/retour formatées:', formattedPickupDate, formattedReturnDate);
    }
    
    // Début d'une transaction
    await pool.query('START TRANSACTION');
    
    // Si c'est une réservation de terrain, vérifier la disponibilité
    if (facility_id) {
      const [facilities] = await pool.query('SELECT * FROM facilities WHERE id = ?', [facility_id]);
      
      if (facilities.length === 0) {
        await pool.query('ROLLBACK');
        return res.status(400).json({ message: 'Ce terrain n\'existe pas' });
      }
      
      // Vérifier s'il n'y a pas déjà une réservation pour ce terrain à cette date et ce créneau
      const [existingReservations] = await pool.query(`
        SELECT * FROM reservations 
        WHERE facility_id = ? AND 
        ((start_time <= ? AND end_time > ?) OR (start_time < ? AND end_time >= ?) OR (start_time >= ? AND end_time <= ?))
        AND status != 'Annulée'
      `, [facility_id, formattedStartTime, formattedStartTime, formattedEndTime, formattedEndTime, formattedStartTime, formattedEndTime]);
      
      if (existingReservations.length > 0) {
        await pool.query('ROLLBACK');
        return res.status(400).json({ message: 'Ce terrain est déjà réservé pour ce créneau horaire' });
      }
    }
    
    // Pour les équipements, vérifier la disponibilité
    if (equipment_id) {
      const quantityToReserve = equipment_quantity || 1;
      
      const [equipment] = await pool.query('SELECT * FROM equipment WHERE id = ? AND available_quantity >= ?', 
        [equipment_id, quantityToReserve]);
      
      if (equipment.length === 0) {
        await pool.query('ROLLBACK');
        return res.status(400).json({ 
          message: `Cet équipement n'est pas disponible en quantité suffisante (${quantityToReserve} demandé(s))` 
        });
      }
      
      // Pour les équipements, utiliser les dates de pickup/return si fournies
      // sinon utiliser start_time/end_time
      const finalStartTime = formattedPickupDate || formattedStartTime;
      const finalEndTime = formattedReturnDate || formattedEndTime;
      
      // Vérifier les chevauchements avec d'autres réservations
      const [bookedQuantity] = await pool.query(`
        SELECT SUM(equipment_quantity) as total_booked
        FROM reservations 
        WHERE equipment_id = ? AND 
        ((start_time <= ? AND end_time > ?) OR (start_time < ? AND end_time >= ?) OR (start_time >= ? AND end_time <= ?))
        AND status != 'Annulée'
      `, [equipment_id, finalStartTime, finalStartTime, finalEndTime, finalEndTime, finalStartTime, finalEndTime]);
      
      const totalBooked = bookedQuantity[0].total_booked || 0;
      const availableQuantity = equipment[0].available_quantity - totalBooked;
      
      if (availableQuantity < quantityToReserve) {
        await pool.query('ROLLBACK');
        return res.status(400).json({ 
          message: `Seulement ${availableQuantity} unité(s) disponible(s) pour cette période (${quantityToReserve} demandé(s))` 
        });
      }
      
      // Mettre à jour la quantité disponible temporairement (sera remise à jour avec un trigger)
      await pool.query('UPDATE equipment SET available_quantity = available_quantity - ? WHERE id = ?', 
        [quantityToReserve, equipment_id]);
    }
    
    // Pour les cours, vérifier qu'il y a des places disponibles et décrémenter
    if (course_id) {
      const [course] = await pool.query('SELECT * FROM courses WHERE id = ? AND available_spots > 0', [course_id]);
      
      if (course.length === 0) {
        await pool.query('ROLLBACK');
        return res.status(400).json({ message: 'Ce cours n\'a plus de places disponibles' });
      }
      
      // Décrémenter le nombre de places disponibles
      await pool.query('UPDATE courses SET available_spots = available_spots - 1 WHERE id = ?', [course_id]);
    }
    
    try {
      // Préparation des paramètres pour l'insertion
      const params = [
        userId,
        course_id || null,
        equipment_id || null, 
        facility_id || null,
        formattedStartTime,
        formattedEndTime
      ];
      
      // Si c'est une réservation d'équipement avec dates spécifiques
      let sql = `
        INSERT INTO reservations (
          user_id, course_id, equipment_id, facility_id, 
          start_time, end_time, status
        ) VALUES (?, ?, ?, ?, ?, ?, 'Confirmée')
      `;
      
      if (equipment_id && formattedPickupDate && formattedReturnDate) {
        sql = `
          INSERT INTO reservations (
            user_id, course_id, equipment_id, facility_id, 
            start_time, end_time, status, 
            pickup_date, return_date, equipment_quantity
          ) VALUES (?, ?, ?, ?, ?, ?, 'Confirmée', ?, ?, ?)
        `;
        params.push(formattedPickupDate, formattedReturnDate, equipment_quantity || 1);
      } else if (equipment_id) {
        // Cas où on a juste equipment_quantity sans dates spécifiques
        sql = `
          INSERT INTO reservations (
            user_id, course_id, equipment_id, facility_id, 
            start_time, end_time, status, equipment_quantity
          ) VALUES (?, ?, ?, ?, ?, ?, 'Confirmée', ?)
        `;
        params.push(equipment_quantity || 1);
      }
      
      console.log('Insertion dans la base de données avec les paramètres:', params);
      
      // Créer la réservation
      const [result] = await pool.query(sql, params);
      
      console.log('Réservation créée avec succès, ID:', result.insertId);
      
      // Récupérer les détails de la réservation créée
      const [reservations] = await pool.query(`
        SELECT r.*, 
          c.name as course_title, 
          e.name as equipment_name,
          f.name as facility_name,
          DATE(r.start_time) as date
        FROM reservations r
        LEFT JOIN courses c ON r.course_id = c.id
        LEFT JOIN equipment e ON r.equipment_id = e.id
        LEFT JOIN facilities f ON r.facility_id = f.id
        WHERE r.id = ?
      `, [result.insertId]);
      
      if (reservations.length === 0) {
        await pool.query('ROLLBACK');
        return res.status(500).json({ message: 'Erreur lors de la récupération de la réservation créée' });
      }
      
      // Valider la transaction
      await pool.query('COMMIT');
      
      res.status(201).json(reservations[0]);
    } catch (error) {
      await pool.query('ROLLBACK');
      console.error('Erreur lors de la création de la réservation:', error);
      res.status(500).json({ message: 'Erreur serveur: ' + error.message });
    }
  } catch (error) {
    console.error('Erreur lors du traitement de la réservation:', error);
    res.status(500).json({ message: 'Erreur serveur: ' + error.message });
  }
});

// Route commune pour annuler une réservation (supporte PUT et PATCH)
const handleCancelReservation = async (req, res) => {
  const reservationId = parseInt(req.params.id, 10);
  const userId = req.user.id;
  
  console.log(`Tentative d'annulation de réservation - ID: ${reservationId}, User: ${userId}, Method: ${req.method}`);
  
  if (isNaN(reservationId)) {
    console.error('ID de réservation invalide:', req.params.id);
    return res.status(400).json({ message: 'ID de réservation invalide' });
  }
  
  try {
    await pool.query('START TRANSACTION');
    
    const [reservations] = await pool.query(
      'SELECT * FROM reservations WHERE id = ? AND user_id = ?', 
      [reservationId, userId]
    );
    
    if (reservations.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ message: 'Réservation non trouvée ou accès refusé' });
    }
    
    const reservation = reservations[0];
    
    if (reservation.status === 'Annulée') {
      await pool.query('ROLLBACK');
      return res.status(400).json({ message: 'Cette réservation est déjà annulée' });
    }
    
    await pool.query(
      'UPDATE reservations SET status = "Annulée" WHERE id = ?',
      [reservationId]
    );
    
    if (reservation.facility_id) {
      await pool.query('UPDATE facilities SET is_available = 1 WHERE id = ?', [reservation.facility_id]);
    }
    
    if (reservation.equipment_id) {
      // Restituer la quantité complète et non pas juste 1 équipement
      const quantityToRestore = reservation.equipment_quantity || 1;
      console.log(`Restitution de ${quantityToRestore} unité(s) pour l'équipement ${reservation.equipment_id}`);
      
      await pool.query(
        'UPDATE equipment SET available_quantity = available_quantity + ? WHERE id = ?',
        [quantityToRestore, reservation.equipment_id]
      );
    }
    
    // Si c'est une réservation de cours, incrémenter le nombre de places disponibles
    if (reservation.course_id) {
      await pool.query(
        'UPDATE courses SET available_spots = available_spots + 1 WHERE id = ?',
        [reservation.course_id]
      );
      console.log(`Place restituée pour le cours ${reservation.course_id}`);
    }
    
    await pool.query('COMMIT');
    console.log(`Réservation annulée avec succès - ID: ${reservationId}`);
    
    res.status(200).json({ 
      success: true,
      message: 'Réservation annulée avec succès',
      reservation: {
        id: reservationId,
        status: 'Annulée'
      }
    });
  } catch (error) {
    await pool.query('ROLLBACK');
    console.error(`Erreur lors de l'annulation de la réservation ${reservationId}:`, error);
    res.status(500).json({ 
      success: false,
      message: 'Erreur lors de l\'annulation de la réservation',
      error: error.message 
    });
  }
};

// Route PATCH pour annuler une réservation
router.patch('/:id/cancel', verifyToken, handleCancelReservation);

// Route PUT pour annuler une réservation
router.put('/:id/cancel', verifyToken, handleCancelReservation);

module.exports = router; 