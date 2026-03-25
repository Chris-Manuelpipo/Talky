# Tâches Non Implémentées - Talky

> Document généré le 23 mars 2026
> Destiné à l'équipe de développement Talky

---

## 📋 Vue d'ensemble

Ce document recense l'ensemble des fonctionnalités manquantes identifiées lors de l'analyse du projet. Chaque fonctionnalité est détaillée avec :
- **Description** : Explication claire de la fonctionnalité
- **Priorité** : Haute (⭐⭐⭐), Moyenne (⭐⭐), Basse (⭐)
- **Complexité** : Estimée en jours de développement (1-2 = Faible, 3-5 = Moyenne, 5+ = Élevée)

---

## 📱 MESSAGES

### 1. Traduction automatique des messages

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐⭐ Haute |
| **Complexité** | 5+ jours (Élevée) |
| **Phase** | Phase 4 - Fonctionnalité phare |

#### UI (Interface Utilisateur)

- [ ] **Toggle original/traduit** : Bouton dans les bulles de message pour basculer entre le texte original et la traduction
- [ ] **Indicateur de langue** : Badge显示 la langue détectée du message
- [ ] **Menu de traduction** : Options pour traduire vers une langue spécifique

#### Logique (Backend)

- [ ] **Intégration API Google Cloud Translation** : Configuration et appels API
- [ ] **Détection automatique de langue** : Utilisation de l'API pour identifier la langue source
- [ ] **Mise en cache des traductions** : Stockage local pour éviter les appels API redondants
- [ ] **Gestion des erreurs** : Fallback si l'API échoue

---

### 2. Mode Confidentiel / Messages éphémères

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐⭐ Haute |
| **Complexité** | 5+ jours (Élevée) |
| **Phase** | Phase 5 - Fonctionnalité phare |

#### UI (Interface Utilisateur)

- [ ] **Timer visuel** : Affichage du temps restant avant suppression sur chaque message
- [ ] **Indicateur mode confidentiel** : Icône/badge visible sur les conversations en mode privé
- [ ] **Paramètres de durée** : Options de temps (30s, 1min, 5min, 1h, 24h)
- [ ] **Bloqueur de screenshots** : Overlay de sécurité (détection système)

#### Logique (Backend)

- [ ] **Chiffrement AES** : Implémentation du chiffrement de bout en bout
- [ ] **Suppression automatique** : Cron job ou trigger pour supprimer les messages expirés
- [ ] **Blocage screenshots** : Intégration native (platform channel)
- [ ] **Gestion des permissions** : Qui peut activer ce mode

---

### 3. Réponses aux messages (Citation)

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐ Moyenne |
| **Complexité** | 2 jours (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Affichage du message cité** : Prévisualisation du message parent au-dessus de la réponse
- [ ] **Mise en forme distinctive** : Style visuel différent (couleur, bordure, indentation)
- [ ] **Navigation** : Clic sur le message cité pour remonter à la conversation originale
- [ ] **Bouton répondre** : Action dans le menu contextuel des messages

#### Logique (Backend)

- [ ] **Stockage référence message parent** : Champ `replyTo` dans le modèle de message
- [ ] **Récupération des messages cités** : Requête pour afficher le contexte
- [ ] **Gestion des messages supprimés** : Affichage "Message supprimé" si le parent n'existe plus

---

### 4. Suppression de messages pour tous

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐ Moyenne |
| **Complexité** | 1 jour (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Option dans le menu message** : "Supprimer pour tout le monde" vs "Supprimer pour moi"
- [ ] **Confirmation dialog** : Avertissement avant suppression irréversible
- [ ] **Indicateur visuel** : Le message devient "Message supprimé" pour les deux parties

#### Logique (Backend)

- [ ] **Suppression Firestore** : Suppression du document dans la collection messages
- [ ] **Permissions** : Vérification que l'utilisateur est l'expéditeur
- [ ] **Notifications de suppression** : Mise à jour en temps réel pour le destinataire
- [ ] **Règles de sécurité** : Validation Firestore



---

### 5. Modification des messages

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐ Moyenne |
| **Complexité** | 1 jour (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Option dans le menu message** : "Modifier"
- [ ] **Indicateur visuel** : Le message a un badge 'modifié'

#### Logique (Backend)

- [ ] **Modification Firestore** :Modification du document dans la collection messages
- [ ] **Permissions** : Vérification que l'utilisateur est l'expéditeur 
- [ ] **Règles de sécurité** : Validation Firestore

### 5. Bloquer un contact 


## 👥 GROUPES

### 1. Gestion avancée des membres (admin, modérateurs)

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐ Moyenne |
| **Complexité** | 3 jours (Moyenne) |

#### UI (Interface Utilisateur)

- [ ] **Badges de rôles** : Indicateurs visuels (Admin, Modérateur, Membre)
- [ ] **Panneau de gestion** : Écran admin pour gérer les membres (Ajouter, Retirer, Nommer modérateur )
- [ ] **Actions de modération** : Promouvoir, rétrograder, exclure
- [ ] **Liste des membres avec filtres** : Tri par rôle, recherche

#### Logique (Backend)

- [ ] **Rôles dans Firestore** : Collection `groupRoles` ou champ dans `groupMembers`
- [ ] **Permissions granulaires** : Différents niveaux d'accès
- [ ] **Historique des actions** : Log des changements de rôles
- [ ] **Notifications** : Alertes aux membres concernés

---

### 2. Informations détaillées du groupe

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐ Basse |
| **Complexité** | 2 jours (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Écran infos groupe** : Vue complète des détails (Déjà implémentée partiellement)
- [ ] **Médias partagés** : Galerie photos/vidéos du groupe(Déjà mais le design pourrait etre amélioré)
- [ ] **Fichiers partagés** : Documents et autres fichiers
- [ ] **Statistiques** : Nombre de messages, membres actifs

#### Logique (Backend)

- [ ] **Agrégation médias groupe** : Requête sur les messages de type média
- [ ] **Indexation** : Cache des métadonnées pour performance
- [ ] **Pagination** : Chargement progressif des médias

---

### 3. Photo de profil et description du groupe

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐ Basse |
| **Complexité** | 2 jours (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Formulaire de création de groupe** : Champs pour ajouter une photo de profil et description
- [ ] **Limitation de taille** : (Optionnel) 
#### Logique (Backend)

- [ ] **Agrégation médias groupe** : 
---

## 📊 STATUT

### 1. Réponse vocale aux statuts

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐ Moyenne |
| **Complexité** | 3 jours (Moyenne) |

#### UI (Interface Utilisateur)

- [ ] **Bouton micro** : Dans la visionneuse de statuts
- [ ] **Interface d'enregistrement** : Indicateur visuel d'enregistrement
- [ ] **Prévisualisation audio** : Lecture avant envoi
- [ ] **Envoi comme message** : Le statut vocal devient un message dans la conversation

#### Logique (Backend)

- [ ] **Enregistrement audio** : Utilisation du package `record` ou équivalent
- [ ] **Upload vers Storage** : Firebase Storage pour les fichiers audio
- [ ] **Création du message** : Insertion dans Firestore

---

### 2. Menu actions statuts (suppression, partage)

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐ Basse |
| **Complexité** | 1 jour (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Menu contextuel** : Options au long press sur un statut
- [ ] **Supprimer** : Suppression du statut
- [ ] **Partager** : Partage vers une conversation
- [ ] **Voir les vues** : Liste des personnes ayant vu le statut

#### Logique (Backend)

- [ ] **Actions Firestore** : Suppression du document statut
- [ ] **Historique des vues** : Mise à jour du nombre de vues

---

## 📞 APPELS

### 1. Détails d'appel dans l'historique

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐ Moyenne |
| **Complexité** | 2 jours (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Feuille modal infos** : Affichage des détails de l'appel
- [ ] **Durée de l'appel** : Temps de conversation
- [ ] **Date et heure** : Timestamp formaté
- [ ] **Statut** : Reçu, passé, manqué

#### Logique (Backend)

- [ ] **Récupération métadonnées** : Données stockées dans l'appel history
- [ ] **Calcul de durée** : Différence entre start et end time

---

### 2. Actions sur l'historique (supprimer, rappeler)

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐ Basse |
| **Complexité** | 1 jour (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Menu contextuel** : Actions au long press sur un item
- [ ] **Supprimer** : Retirer de l'historique
- [ ] **Rappeler** : Initier un nouvel appel
- [ ] **Suppression multiple** : Sélection de plusieurs appels

#### Logique (Backend)

- [ ] **Gestion historique Firestore** : Suppression document
- [ ] **Synchronisation** : Mise à jour temps réel

---

### 3. Haut parleur lors des appels 

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐ Basse|
| **Complexité** | 1 jour (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Bouton Haut parleur** : Dans l'écran d'appel' 
#### Logique (Backend)

- [ ] **A vérifier**

---

### 4. Inviter un contact sur Talky

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐ Moyenne |
| **Complexité** | 2 jours (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Bouton invitation** : Dans l'écran de nouveaux appels
- [ ] **Formulaire d'invitation** : Entrée du numéro ou email
- [ ] **Message d'invitation personnalisé** : Possibilité de rédiger un message

#### Logique (Backend)

- [ ] **Envoi SMS/Email** : Intégration avec un service d'envoi (Twilio, Firebase Invites) 
- [ ] **Deep linking** : Lien pour télécharger l'app

---

## ⚙️ PARAMÈTRES

### 1. Paramètres de notification push

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐ Moyenne |
| **Complexité** | 2 jours (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Toggle sons** : Activer/désactiver les sons de notification
- [ ] **Toggle vibrations** : Activer/désactiver les vibrations
- [ ] **Toggle prévisualisation** : Afficher le contenu du message
- [ ] **Options avancées** : Groupe de notifications, priorité

#### Logique (Backend)

- [ ] **Configuration FCM** : Mise à jour des préférences dans Firestore
- [ ] **Personnalisation par conversation** : Permissions spécifiques
- [ ] **Gestion des canaux** : Android notification channels

---

### 2. FAQ / Aide

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐ Basse |
| **Complexité** | 1 jour (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Liste questions/réponses** : Interface de navigation
- [ ] **Recherche** : Filtrer les questions par mot-clé
- [ ] **Catégories** : Organisation par thème

#### Logique (Backend)

- [ ] **Contenu statique** : Chargement depuis les assets ou distant
- [ ] **API distante** : Possibilité de mettre à jour sans déploy

---

### 3. Changer de numéro de téléphone 

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐⭐ Haute |
| **Complexité** | 2 jours (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Écran de récupération** : Saisie de l'email
- [ ] **message de confirmation ou email** : Code OTP par sms ou par mail
- [ ] **Nouveau muméro** : Formulaire de création
- [ ] **Confirmation** : Succès de la réinitialisation

#### Logique (Backend)

- [ ] **Reset Firebase Auth** : Utilisation de `sendPasswordResetEmail`
- [ ] **Validation du token** : Vérification du lien
- [ ] **Journalisation** : Suivi des demandes de reset

---

### 4. Mode fantôme (Ghost) avancé

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐ Moyenne |
| **Complexité** | 3 jours (Moyenne) |

#### UI (Interface Utilisateur)

- [ ] **Option masquage statut lecture** : "Vu" non affiché
- [ ] **Option masquage "en ligne"** : Indicateur de présence caché
- [ ] **Option masquage "dernière connexion"** : Horodatage caché
- [ ] **Panneau de contrôle** : Gestion centralisée des options

#### Logique (Backend)

- [ ] **Présence conditionnelle** : Mise à jour des champs Firestore
- [ ] **Règles de confidentialité** : Filtrage des données retournées
- [ ] **Personnalisation par contact** : Options différentes par conversation

---

### 5. Verrouillage biométrique

| Aspect | Détails |
|--------|---------|
| **Priorité** | ⭐⭐ Moyenne |
| **Complexité** | 2 jours (Faible) |

#### UI (Interface Utilisateur)

- [ ] **Toggle sécurité** : Dans les paramètres
- [ ] **Écran de verrouillage** : Affiché au lancement de l'app
- [ ] **Options de déverrouillage** : Biométrique, code PIN fallback

#### Logique (Backend)

- [ ] **Intégration local_auth** : Package Flutter pour authentification locale
- [ ] **Verrouillage de l'app** : Contrôle d'accès à l'ensemble de l'application
- [ ] **Stockage sécurisé** : Credentials dans le secure storage

---

## 📊 Récapitulatif des priorités

### ⭐⭐⭐ Haute Priorité

- [ ] Traduction automatique des messages
- [ ] Mode confidentiel / Messages éphémères
- [ ] Changer de numéro de téléphone 

### ⭐⭐ Moyenne Priorité

- [ ] Réponses aux messages (Citation)
- [ ] Suppression de messages pour tous
- [ ] Gestion avancée des membres
- [ ] Réponse vocale aux statuts
- [ ] Détails d'appel dans l'historique
- [ ] Inviter un contact sur Talky
- [ ] Paramètres de notification push
- [ ] Mode fantôme (Ghost) avancé
- [ ] Verrouillage biométrique

### ⭐ Basse Priorité

- [ ] Informations détaillées du groupe
- [ ] Menu actions statuts
- [ ] Actions sur l'historique (supprimer, rappeler)
- [ ] FAQ / Aide

---

## 🔧 Notes techniques

### Dépendances à ajouter (estimation)

```yaml
dependencies:
  flutter_localizations: ^0.18.0
  intl: ^0.18.0
  translate: ^2.0.0           # Traduction
  encrypt: ^5.0.3             # Chiffrement AES
  local_auth: ^2.1.8         # Biométrique
  flutter_secure_storage: ^9.0.0  # Stockage sécurisé
  record: ^5.0.4              # Enregistrement audio
  firebase_dynamic_links: ^5.0.0  # Invitations
```

### Architecture recommandée

- **Provider/Riverpod** pour la gestion d'état
- **Repository pattern** pour l'accès aux données
- **Services** pour la logique métier
- **Models** pour les données

---

## 📅 Plan de développement suggéré

1. **Sprint 1** : Mot de passe oublié, Réponses aux messages
2. **Sprint 2** : Suppression pour tous, Détails d'appel, Actions historique
3. **Sprint 3** : Mode fantôme, Verrouillage biométrique, Notifications push
4. **Sprint 4** : Gestion membres groupe, Réponse vocale statuts
5. **Sprint 5** : Traduction automatique (phase 1 - API)
6. **Sprint 6** : Mode confidentiel (phase 1 - UI, chiffrement basique)
7. **Sprint 7** : Mode confidentiel (phase 2 - sécurité avancée)

---

*Document créé pour l'équipe de développement Talky*