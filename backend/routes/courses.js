const express = require('express');
const router = express.Router();
const pool = require('../config/db');

// Get all courses
router.get('/', async (req, res) => {
  try {
    console.log('GET /courses - Récupération de tous les cours');
    const [courses] = await pool.query(`
      SELECT c.*, f.name as facility_name, f.is_terrain 
      FROM courses c
      LEFT JOIN facilities f ON c.facility_id = f.id
    `);
    
    console.log(`${courses.length} cours récupérés, récupération des équipements...`);
    
    // Get equipment for each course
    try {
      for (const course of courses) {
        try {
          console.log(`Recherche des équipements pour le cours ${course.id}`);
          const [equipment] = await pool.query(`
            SELECT ce.*, e.name as equipment_name, e.description as equipment_description 
            FROM course_equipment ce
            JOIN equipment e ON ce.equipment_id = e.id
            WHERE ce.course_id = ?
          `, [course.id]);
          
          console.log(`${equipment.length} équipements trouvés pour le cours ${course.id}`);
          course.equipment = equipment || [];
        } catch (equipmentError) {
          // Si la table n'existe pas ou autre erreur avec les équipements
          console.log(`Erreur récupération équipement pour cours ${course.id}:`, equipmentError.message);
          course.equipment = [];
        }
      }
    } catch (error) {
      console.log('Erreur lors de la récupération des équipements:', error.message);
      // On continue pour renvoyer les cours même sans équipements
    }
    
    res.json(courses || []);
  } catch (error) {
    console.error('Error fetching courses:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get available equipment for courses
router.get('/equipment/available', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT * FROM equipment 
      WHERE available_quantity > 0 AND is_available = 1
      ORDER BY name ASC
    `);
    
    res.json(rows || []);
  } catch (error) {
    console.error('Error fetching available equipment:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get available terrains for courses
router.get('/terrains/available', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT * FROM facilities 
      WHERE is_terrain = 1 AND is_available = 1
      ORDER BY name ASC
    `);
    
    res.json(rows || []);
  } catch (error) {
    console.error('Error fetching available terrains:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get course by ID
router.get('/:id', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT c.*, f.name as facility_name, f.is_terrain FROM courses c LEFT JOIN facilities f ON c.facility_id = f.id WHERE c.id = ?',
      [req.params.id]
    );
    
    if (rows.length === 0) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    // Get course schedules
    const [schedules] = await pool.query(
      'SELECT * FROM course_schedules WHERE course_id = ?',
      [req.params.id]
    );
    
    // Get course equipment
    let equipment = [];
    try {
      [equipment] = await pool.query(`
        SELECT ce.*, e.name as equipment_name, e.description as equipment_description 
        FROM course_equipment ce
        JOIN equipment e ON ce.equipment_id = e.id
        WHERE ce.course_id = ?
      `, [req.params.id]);
    } catch (error) {
      console.log(`Erreur récupération équipement pour cours ${req.params.id}:`, error.message);
      // On continue sans les équipements
    }
    
    const course = rows[0];
    course.schedules = schedules;
    course.equipment = equipment || [];
    
    res.json(course);
  } catch (error) {
    console.error('Error fetching course:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create a new course (admin only)
router.post('/', async (req, res) => {
  const { 
    name, 
    description, 
    duration, 
    max_capacity, 
    price, 
    facility_id, 
    image_url, 
    schedules,
    equipment,
    date,
    time
  } = req.body;
  
  // Log des données reçues
  console.log('POST /courses - Création d\'un cours');
  console.log('Données reçues:', {
    name, description, duration, max_capacity, price, facility_id, 
    image_url, schedules, equipment, date, time
  });
  
  try {
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    
    try {
      // Check if facility is a terrain when provided
      let isTerrain = false;
      if (facility_id) {
        const [facilityRows] = await connection.query(
          'SELECT is_terrain FROM facilities WHERE id = ?',
          [facility_id]
        );
        
        if (facilityRows.length > 0) {
          isTerrain = facilityRows[0].is_terrain === 1;
        }
      }
      
      // Insert course
      const [result] = await connection.query(
        `INSERT INTO courses (name, description, duration, max_capacity, available_spots, price, facility_id, image_url, date, time) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [name, description, duration, max_capacity, max_capacity, price, facility_id, image_url, date || null, time || null]
      );
      
      const courseId = result.insertId;
      console.log(`Cours créé avec ID: ${courseId}`);
      
      // Insert schedules if provided
      if (schedules && schedules.length > 0) {
        for (const schedule of schedules) {
          await connection.query(
            `INSERT INTO course_schedules (course_id, day_of_week, start_time, end_time) 
             VALUES (?, ?, ?, ?)`,
            [courseId, schedule.day_of_week, schedule.start_time, schedule.end_time]
          );
        }
      }
      
      // Insert equipment if provided
      if (equipment && Array.isArray(equipment) && equipment.length > 0) {
        console.log(`Tentative d'ajout de ${equipment.length} équipements:`, equipment);
        for (const item of equipment) {
          console.log(`Ajout de l'équipement ${item.equipment_id} avec quantité ${item.quantity || 1}`);
          
          // Insérer l'équipement dans la relation
          await connection.query(
            `INSERT INTO course_equipment (course_id, equipment_id, quantity) 
             VALUES (?, ?, ?)`,
            [courseId, item.equipment_id, item.quantity || 1]
          );
          
          // Mettre à jour la quantité disponible dans le stock d'équipement
          await connection.query(
            `UPDATE equipment 
             SET available_quantity = available_quantity - ? 
             WHERE id = ? AND available_quantity >= ?`,
            [item.quantity || 1, item.equipment_id, item.quantity || 1]
          );
          
          console.log(`Stock de l'équipement ${item.equipment_id} mis à jour`);
        }
      }
      
      // Si un terrain est associé, mettre à jour directement is_available
      if (facility_id && isTerrain) {
        console.log(`Mise à jour directe de is_available pour le terrain ${facility_id}`);
        await connection.query(
          `UPDATE facilities SET is_available = 0 WHERE id = ?`,
          [facility_id]
        );
        console.log(`Le terrain ${facility_id} a été marqué comme indisponible`);
      }
      
      // Créer automatiquement une réservation si un terrain est associé et une date/heure est spécifiée
      if (facility_id && isTerrain && date && time) {
        // Formater la date et l'heure pour MySQL
        const startDateTime = new Date(`${date}T${time}`);
        const endDateTime = new Date(startDateTime.getTime() + duration * 60000); // Ajouter la durée en minutes
        
        const formattedStartTime = startDateTime.toISOString().slice(0, 19).replace('T', ' ');
        const formattedEndTime = endDateTime.toISOString().slice(0, 19).replace('T', ' ');
        
        console.log(`Création d'une réservation automatique pour le terrain ${facility_id}:`);
        console.log(`- Cours: ${courseId}`);
        console.log(`- Date/heure début: ${formattedStartTime}`);
        console.log(`- Date/heure fin: ${formattedEndTime}`);
        
        // Créer la réservation - Utilisateur admin par défaut (ID 1)
        await connection.query(`
          INSERT INTO reservations (user_id, course_id, facility_id, start_time, end_time, status) 
          VALUES (1, ?, ?, ?, ?, 'Confirmée')
        `, [courseId, facility_id, formattedStartTime, formattedEndTime]);
      }
      
      await connection.commit();
      
      res.status(201).json({ 
        id: courseId, 
        name, 
        description, 
        duration, 
        max_capacity, 
        available_spots: max_capacity, 
        price, 
        facility_id, 
        image_url,
        date,
        time,
        schedules: schedules || [],
        equipment: equipment || [],
        is_terrain: isTerrain
      });
    } catch (error) {
      await connection.rollback();
      console.error('Erreur lors de la création du cours (transaction rollback):', error);
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Error creating course:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Update a course (admin only)
router.put('/:id', async (req, res) => {
  const { 
    name, 
    description, 
    duration, 
    max_capacity, 
    available_spots, 
    price, 
    facility_id, 
    image_url, 
    schedules,
    equipment,
    date,
    time
  } = req.body;
  
  try {
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    
    try {
      // Get current course data to check if facility has changed
      const [currentCourse] = await connection.query(
        'SELECT facility_id FROM courses WHERE id = ?',
        [req.params.id]
      );
      
      const oldFacilityId = currentCourse.length > 0 ? currentCourse[0].facility_id : null;
      
      // Check if facility is a terrain when provided
      let isTerrain = false;
      if (facility_id) {
        const [facilityRows] = await connection.query(
          'SELECT is_terrain FROM facilities WHERE id = ?',
          [facility_id]
        );
        
        if (facilityRows.length > 0) {
          isTerrain = facilityRows[0].is_terrain === 1;
        }
      }
      
      // Update course
      await connection.query(
        `UPDATE courses 
         SET name = ?, description = ?, duration = ?, max_capacity = ?, 
             available_spots = ?, price = ?, facility_id = ?, image_url = ?,
             date = ?, time = ?
         WHERE id = ?`,
        [name, description, duration, max_capacity, available_spots, price, facility_id, image_url, date, time, req.params.id]
      );
      
      // If facility changed, update availability
      if (oldFacilityId !== facility_id) {
        // If the old facility was set, make it available again
        if (oldFacilityId) {
          await connection.query(
            `UPDATE facilities SET is_available = 1 WHERE id = ?`,
            [oldFacilityId]
          );
          console.log(`Ancien terrain ${oldFacilityId} remis à disponible`);
        }
        
        // If new facility is a terrain, make it unavailable
        if (facility_id && isTerrain) {
          await connection.query(
            `UPDATE facilities SET is_available = 0 WHERE id = ?`,
            [facility_id]
          );
          console.log(`Nouveau terrain ${facility_id} marqué comme indisponible`);
        }
      }
      
      // Update schedules if provided
      if (schedules && schedules.length > 0) {
        // Delete existing schedules
        await connection.query('DELETE FROM course_schedules WHERE course_id = ?', [req.params.id]);
        
        // Insert new schedules
        for (const schedule of schedules) {
          await connection.query(
            `INSERT INTO course_schedules (course_id, day_of_week, start_time, end_time) 
             VALUES (?, ?, ?, ?)`,
            [req.params.id, schedule.day_of_week, schedule.start_time, schedule.end_time]
          );
        }
      }
      
      // Update equipment if provided
      if (equipment && Array.isArray(equipment)) {
        // Get existing equipment to compare and adjust stock
        const [existingEquipment] = await connection.query(
          'SELECT * FROM course_equipment WHERE course_id = ?', 
          [req.params.id]
        );
        
        // Restore stock for removed equipment
        for (const oldItem of existingEquipment) {
          const stillExists = equipment.length > 0 && equipment.some(newItem => 
            newItem.equipment_id === oldItem.equipment_id && 
            newItem.id === oldItem.id
          );
          
          if (!stillExists) {
            // Restore stock for equipment that has been removed
            await connection.query(
              `UPDATE equipment 
               SET available_quantity = available_quantity + ? 
               WHERE id = ?`,
              [oldItem.quantity, oldItem.equipment_id]
            );
            console.log(`Stock restauré pour l'équipement ${oldItem.equipment_id} (${oldItem.quantity})`);
          }
        }
        
        // Delete existing equipment relationships
        await connection.query('DELETE FROM course_equipment WHERE course_id = ?', [req.params.id]);
        
        // Insert new equipment relationships and update stock only if there are equipment items
        if (equipment.length > 0) {
          for (const item of equipment) {
            // Find if this equipment was already in the course
            const oldItem = existingEquipment.find(e => e.equipment_id === item.equipment_id);
            const oldQuantity = oldItem ? oldItem.quantity : 0;
            const newQuantity = item.quantity || 1;
            
            // Calculate net change in stock (negative means more used, positive means less used)
            const stockChange = oldQuantity - newQuantity;
            
            // Insert new equipment relation
            await connection.query(
              `INSERT INTO course_equipment (course_id, equipment_id, quantity) 
               VALUES (?, ?, ?)`,
              [req.params.id, item.equipment_id, newQuantity]
            );
            
            // Update stock only if there's a change
            if (stockChange !== 0) {
              await connection.query(
                `UPDATE equipment 
                 SET available_quantity = available_quantity + ? 
                 WHERE id = ?`,
                [stockChange, item.equipment_id]
              );
              console.log(`Stock ajusté pour l'équipement ${item.equipment_id} (${stockChange})`);
            }
          }
        }
      }
      
      await connection.commit();
      
      res.json({ 
        id: parseInt(req.params.id), 
        name, 
        description, 
        duration, 
        max_capacity, 
        available_spots, 
        price, 
        facility_id, 
        image_url,
        date,
        time,
        schedules: schedules || [],
        equipment: equipment || [],
        is_terrain: isTerrain
      });
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Error updating course:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete a course (admin only)
router.delete('/:id', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    
    try {
      // Récupérer les détails du cours, notamment le facility_id
      const [courseDetails] = await connection.query(
        'SELECT facility_id FROM courses WHERE id = ?',
        [req.params.id]
      );
      
      // Get equipment to restore stock
      const [courseEquipment] = await connection.query(
        'SELECT * FROM course_equipment WHERE course_id = ?', 
        [req.params.id]
      );
      
      // Restore stock for all equipment used in the course
      for (const item of courseEquipment) {
        await connection.query(
          `UPDATE equipment 
           SET available_quantity = available_quantity + ? 
           WHERE id = ?`,
          [item.quantity, item.equipment_id]
        );
        console.log(`Stock restauré pour l'équipement ${item.equipment_id} (${item.quantity})`);
      }
      
      // Si le cours avait un terrain, le rendre disponible
      if (courseDetails.length > 0 && courseDetails[0].facility_id) {
        const facilityId = courseDetails[0].facility_id;
        
        console.log(`Remise en disponibilité du terrain ${facilityId}`);
        
        // Mettre à jour le terrain pour le rendre disponible
        await connection.query(
          `UPDATE facilities SET is_available = 1 WHERE id = ?`,
          [facilityId]
        );

        // Annuler toutes les réservations actives pour ce terrain liées à ce cours
        await connection.query(
          `UPDATE reservations 
           SET status = 'Annulée' 
           WHERE facility_id = ? AND course_id = ? AND status = 'Confirmée'`,
          [facilityId, req.params.id]
        );
        
        console.log(`Terrain ${facilityId} remis en disponibilité`);
      }
      
      // Delete course schedules
      await connection.query('DELETE FROM course_schedules WHERE course_id = ?', [req.params.id]);
      
      // Delete course equipment relationships
      await connection.query('DELETE FROM course_equipment WHERE course_id = ?', [req.params.id]);
      
      // Delete course
      const [result] = await connection.query('DELETE FROM courses WHERE id = ?', [req.params.id]);
      
      await connection.commit();
      
      if (result.affectedRows === 0) {
        return res.status(404).json({ message: 'Course not found' });
      }
      
      res.json({ message: 'Course deleted successfully' });
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Error deleting course:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router; 