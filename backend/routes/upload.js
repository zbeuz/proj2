const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Ensure upload directories exist
const uploadBaseDir = path.join('public', 'uploads');
// Create base upload directory if it doesn't exist
if (!fs.existsSync(uploadBaseDir)) {
  fs.mkdirSync(uploadBaseDir, { recursive: true });
}

// Create subdirectories for different entity types
const uploadSubDirs = ['facilities', 'equipment', 'courses', 'general'];
uploadSubDirs.forEach(dir => {
  const fullPath = path.join(uploadBaseDir, dir);
  if (!fs.existsSync(fullPath)) {
    fs.mkdirSync(fullPath, { recursive: true });
  }
});

// Configuration de multer pour le stockage des fichiers
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    // Récupérer le dossier depuis la requête ou utiliser 'uploads' par défaut
    const folder = req.body.folder || 'general';
    const uploadPath = path.join('public', 'uploads', folder);
    
    // Créer le dossier s'il n'existe pas
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    
    cb(null, uploadPath);
  },
  filename: function (req, file, cb) {
    // Générer un nom de fichier unique avec horodatage
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const extension = path.extname(file.originalname);
    cb(null, file.fieldname + '-' + uniqueSuffix + extension);
  }
});

// Configuration des filtres pour n'accepter que les images
const fileFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Seules les images sont autorisées!'), false);
  }
};

// Initialisation de multer avec la configuration
const upload = multer({ 
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024 // limite à 5MB
  }
});

// Route d'upload d'image
router.post('/', upload.single('image'), (req, res) => {
  try {
    console.log('Requête d\'upload reçue');
    console.log('Body:', req.body);
    console.log('Fichier:', req.file);
    
    if (!req.file) {
      console.log('Aucun fichier détecté dans la requête');
      return res.status(400).json({ message: 'Aucun fichier téléchargé' });
    }
    
    // Construire l'URL de l'image
    const protocol = req.protocol;
    const host = req.get('host');
    const folder = req.body.folder || 'general';
    const imageUrl = `${protocol}://${host}/uploads/${folder}/${req.file.filename}`;
    
    console.log('URL de l\'image générée:', imageUrl);
    
    res.status(201).json({
      message: 'Image téléchargée avec succès',
      imageUrl: imageUrl,
      file: req.file
    });
  } catch (error) {
    console.error('Erreur lors de l\'upload du fichier:', error);
    res.status(500).json({ message: 'Erreur lors de l\'upload du fichier', error: error.message });
  }
});

// Gestionnaire d'erreur pour multer
router.use((err, req, res, next) => {
  console.error('Erreur middleware d\'upload:', err);
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ message: 'Fichier trop volumineux, maximum 5MB autorisé' });
    }
    return res.status(400).json({ message: `Erreur d'upload: ${err.message}` });
  }
  return res.status(500).json({ message: 'Erreur de serveur lors de l\'upload' });
});

module.exports = router; 