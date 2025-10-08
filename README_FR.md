<p align="center">
  🌐 <b>Langue :</b>
  <a href="README.md">中文</a> |
  <a href="README_EN.md">English</a> |
  <b>Français</b>
</p>

---


# KuaiJi  

## Introduction

**KuaiJi** est une application iOS pour **partage de dépenses (système AA)** et **gestion personnelle des comptes**.  
Objectif simple : en finir avec la calculatrice lors des sorties, voyages ou colocations entre amis.  

Le projet est développé entièrement en **Swift + SwiftUI**, fonctionne **sans serveur**,  
mais permet tout de même la synchronisation des comptes via **Bluetooth / Wi-Fi**,  
offrant une expérience de partage *« pseudo-décentralisée »*.  
> En réalité, le développeur ne voulait simplement pas payer les **99 $ de frais Apple**. ~~(10 $ collectés auprès des amis pour l’instant)~~

> Donc pas de CloudKit — la comptabilité décentralisée s’impose !

---

## Fonctionnalités

| Module | Description |
|---------|-------------|
| **Saisie des dépenses** | Ajout rapide via saisie vocale ou manuelle, avec catégories et étiquettes. |
| **Partage entre amis** | Modes de partage : AA, j’invite, il invite, ou répartition personnalisée. |
| **Synchronisation locale** | Partage des comptes par Bluetooth ou Wi-Fi, sans connexion requise. |
| **Stockage local** | Toutes les données restent sur ton appareil, confidentialité garantie. |
| **Vue statistique** | Visualisation mensuelle et annuelle des tendances et répartitions. |
| **Identité décentralisée** | Chaque utilisateur possède un ID unique pour l’appairage inter-appareils. |

---

## Mode d’emploi

1. Télécharger ou cloner le projet  
   ```bash
   git clone https://github.com/GuoRan7771/KuaiJi_IOSApp.git
   cd KuaiJi_IOSApp
   
2. Ouvrir avec **Xcode** (`.xcodeproj` ou `.xcworkspace`)
3. Exécuter sur simulateur ou appareil réel

   > La synchronisation sur appareil réel nécessite l’accès Bluetooth / Wi-Fi
4. Créer un compte partagé et inviter des amis
5. Commencer à enregistrer les dépenses, laisser l’app faire les calculs et profiter de la tranquillité 😌

---

## Notes du développeur

> « Je l’ai codée pour m’amuser, et pourtant ça marche vraiment 😎 »

* “Full-stack” signifie ici que j’ai tout fait avec l’aide forcée d’une IA.
* Pas sur l’App Store à cause de la “politique de tarification décentralisée” : **pas de 99 $**.
* Avant, je ne connaissais que Python et Tkinter ; l’UI d’Apple, c’est un Tkinter de luxe.

---

## Mises à jour récentes

### Changement d’interface du compte partagé (2025-10-06)

Toutes les informations sur une seule page  
Correction d’un bug sur le clic de catégorie  
Ajout de l’export/import complet pour sauvegarde et migration  
Correction de l’accès rapide au compte par Raccourcis  

### Nouvelle fonction : ajout rapide (2025-10-05)

Appui long sur l’icône de l’app pour ajouter une dépense dans le compte par défaut
Correction des erreurs de traduction

---

## Licence

Licence MIT — utilisation libre, mais aucune garantie en cas de perte de données.

---
