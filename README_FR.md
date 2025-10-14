<p align="center">
  <b>Langue / Language / 语言 :</b>
  <b>Français</b> |
  <a href="README.md">English</a> |
  <a href="README_CN.md">中文</a>
</p>

---
# KuaiJi  

## Présentation

**KuaiJi** est une application iOS conçue pour la **gestion des dépenses partagées (AA)** et la **comptabilité personnelle**.  
L’objectif est simple :  
1. Ne plus jamais avoir à sortir la calculatrice pour savoir qui doit quoi après un dîner, un voyage ou une colocation.  
2. Gérer facilement ses finances personnelles et ses comptes.

Le projet est entièrement développé en **Swift pur avec SwiftUI**, sans serveur, fonctionnant **entièrement en local**,  
tout en permettant la synchronisation des données via **Bluetooth / Wi-Fi**, offrant ainsi une expérience de partage « pseudo-décentralisée ».  

> Le développeur a tout simplement refusé de payer les 99 USD de frais annuels du programme Apple Developer. ~~(10 USD ont déjà été collectés auprès des amis…)

> Impossible donc d’utiliser CloudKit : la comptabilité est devenue décentralisée !

---

## Points forts

| Module | Description |
|---------|--------------|
| **Comptes personnels et partagés** | Ajout rapide de dépenses, saisie vocale ou manuelle, catégorisation et étiquettes. |
| **Partage des dépenses** | Répartition automatique (AA), repas offerts, répartition personnalisée. |
| **Synchronisation locale** | Partage de comptes via Bluetooth ou Wi-Fi, sans connexion ni identifiant. |
| **Stockage local pur** | Toutes les données sont enregistrées sur l’appareil, garantissant la confidentialité. |
| **Vue statistique** | Visualisation des tendances mensuelles et annuelles, répartition par catégorie. |
| **Multilingue** | Anglais, Français, Chinois. |

---

## Comment l’utiliser
### Méthode 1 (simple) :  
Consultez ce dépôt : [https://github.com/GuoRan7771/Guo_s_Apps](https://github.com/GuoRan7771/Guo_s_Apps)

### Méthode 2 (plus technique, pour développeurs) :  

1. Cloner l’intégralité du projet.  
2. Ouvrir le dossier dans **Xcode**.  
3. Exécuter sur simulateur ou appareil réel.  

   > Les fonctions de synchronisation sur appareil réel nécessitent l’autorisation Bluetooth / Wi-Fi.

---

## Notes du développeur

* C’est mon tout premier projet, réalisé de A à Z — code, interface et distribution — sans expérience préalable, donc je suis déjà très satisfait.  
* L’application n’est pas publiée sur l’App Store, car je pratique une « stratégie de tarification décentralisée ».  
  Elle sera peut-être disponible plus tard quand j’aurai du temps et 99 USD à investir.  
* Avant cela, je n’avais étudié qu’un peu de Python avec Tkinter ; SwiftUI, c’est un peu le Tkinter d’Apple !

---

## Mises à jour récentes

### Suspension des nouvelles fonctionnalités, corrections uniquement (14/10/2025)

### Grande mise à jour (10/10/2025)

 - Nouveau **compte personnel** : gestion des comptes, enregistrements, statistiques, transferts internes, exportation et réinitialisation CSV.  
 - Mise à jour des **paramètres** : réglages pour le compte personnel, page d’accueil par défaut pour la section partagée.  
 - Ajustements **UI**.  
 - **Raccourcis** : accès direct au compte personnel.

### Changements dans l’interface du compte partagé (06/10/2025)

 - Plus besoin d’ouvrir une page séparée pour les transferts : tout est visible sur un seul écran.  
 - Correction d’un bug sur la sélection des catégories.  
 - Ajout d’une fonction complète d’exportation et d’importation de données pour la sauvegarde et la migration.  
 - Correction d’un problème empêchant l’ouverture rapide du compte par défaut via **Raccourcis**.

### Nouvelle fonctionnalité : saisie rapide (05/10/2025)

 - Appui long sur l’icône de l’application pour accéder directement à l’écran de saisie du compte par défaut.  
 - Correction d’erreurs de traduction.

---

## Licence

**Licence MIT** — utilisation libre, mais aucune garantie en cas de perte de données.
