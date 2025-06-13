const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 8889,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Test de connexion
async function testConnection() {
  try {
    const connection = await pool.getConnection();
    console.log('Connexion à la base de données établie avec succès!');
    console.log(`Host: ${process.env.DB_HOST}, Port: ${process.env.DB_PORT}, Database: ${process.env.DB_NAME}`);
    
    // Vérifier si la table users existe
    try {
      const [rows] = await connection.query('SHOW TABLES LIKE "users"');
      if (rows.length === 0) {
        console.error('ATTENTION: La table "users" n\'existe pas dans la base de données.');
        console.log('Veuillez exécuter le script SQL de création de table.');
      } else {
        console.log('La table "users" existe dans la base de données.');
      }
    } catch (err) {
      console.error('Erreur lors de la vérification des tables:', err);
    }
    
    connection.release();
  } catch (err) {
    console.error('ERREUR: Impossible de se connecter à la base de données MySQL:', err);
    console.error('Veuillez vérifier:');
    console.error('1. Que MAMP/MySQL est bien démarré');
    console.error(`2. Que la base de données "${process.env.DB_NAME}" existe`);
    console.error('3. Que les identifiants (user/password) sont corrects');
    console.error(`4. Que le port ${process.env.DB_PORT} est bien celui utilisé par MySQL`);
  }
}

// Exécuter le test de connexion au démarrage
testConnection();

module.exports = pool; 