# AAFORP - Application de Gestion Sportive

## À propos
AAFORP est une application de gestion pour centre sportif permettant la gestion des équipements, terrains, cours, et réservations.

## Installation

### Configuration du backend

1. Naviguer dans le dossier backend :
   ```
   cd backend
   ```

2. Installer les dépendances :
   ```
   npm install
   ```

3. Configurer la base de données :
   - Créer une base de données MySQL nommée "aaforp"
   - Importer le fichier `aaforp.sql` dans votre base de données
   - Copier le fichier `.env.example` en `.env` et mettre à jour les informations de connexion

4. Mettre à jour la structure de la base de données (si nécessaire) :
   ```
   node run_db_update.js
   ```

5. Démarrer le serveur :
   ```
   npm start
   ```

### Configuration du frontend Flutter

1. Naviguer dans le dossier racine du projet
2. Installer les dépendances Flutter :
   ```
   flutter pub get
   ```
3. Lancer l'application :
   ```
   flutter run
   ```

## Fonctionnalités

### Gestion des utilisateurs
- Inscription et connexion
- Profils utilisateurs
- Gestion des rôles (admin, user)

### Gestion des équipements
- Ajouter, modifier et supprimer des équipements
- Visualiser l'inventaire
- Suivre la disponibilité

### Gestion des terrains
- Ajouter, modifier et supprimer des terrains
- Horaires d'ouverture
- Visualiser la disponibilité

### Gestion des cours
- Ajouter, modifier et supprimer des cours
- Gérer les horaires
- Assigner des terrains aux cours

### Réservations
- Réserver des équipements
- Réserver des terrains
- S'inscrire aux cours

## Administration

Pour accéder aux fonctionnalités d'administration:
1. Connectez-vous avec un compte ayant les droits d'administration
2. Accédez au tableau de bord admin depuis le menu principal

## Mise à jour de la base de données

Si vous rencontrez des problèmes avec la structure de la base de données lors de l'ajout d'équipements, de cours ou de terrains, vous pouvez mettre à jour la structure en exécutant :

```
cd backend
node run_db_update.js
```

Ce script vérifiera et corrigera automatiquement les colonnes manquantes ou mal nommées dans la table equipment.

## Résolution des problèmes

### Problèmes de connexion à la base de données
- Vérifier que le serveur MySQL est en cours d'exécution
- Vérifier les informations de connexion dans le fichier `.env`
- S'assurer que les ports ne sont pas bloqués par un pare-feu

### Problèmes avec l'API
- Vérifier que le serveur backend est en cours d'exécution
- Vérifier les logs du serveur pour identifier les erreurs
- Vérifier que l'URL de l'API dans l'application Flutter est correcte
