# Jambaar — document de conception (version 0.1)

*Titre provisoire. « Jambaar » signifie « les braves » en wolof.*

Un jeu d'action et de récit à la troisième personne. On y suit un jeune tirailleur sénégalais de 1939 à 1944 : de la Médina de Dakar aux champs de bataille de France, puis le retour.

---

## 1. Intention

- **Raconter une histoire peu montrée** : celle des soldats d'Afrique de l'Ouest engagés dans la Seconde Guerre mondiale.
- **Respecter les faits et les personnes.** Le jeu ne glorifie pas la guerre. Il montre le courage, la camaraderie, la peur, les injustices du système colonial, et la mémoire.
- **Alterner** des scènes de vie (famille, quartier, voyage, lettres) et des missions de combat. Le joueur doit s'attacher aux personnages avant de les voir partir au front.
- **Langues** : français et wolof (sous-titres), avec quelques mots de bambara, pulaar et sérère selon les personnages. Les tirailleurs venaient de toute l'AOF.

## 2. Personnage principal

**Demba**, 19 ans, de la Médina. Il aide son oncle à l'atelier de couture, joue au football sur la place et parle français parce qu'il est allé à l'école. Il est mobilisé à l'automne 1939.

Personnages secondaires (fictifs, inspirés de profils historiques) :
- **Sergent Mamadou** : vétéran, ancien de 14-18 par son père, protecteur et exigeant.
- **Kouyaté** : Malien, griot, raconte des histoires le soir et chante.
- **Ousmane** : son ami d'enfance, mobilisé avec lui.
- **Sa mère, Aïda**, et sa sœur **Khady**, à qui il écrit (lettres lues entre les chapitres).

## 3. Structure en chapitres

> Les dates et lieux viennent de faits historiques. Les personnages et les situations précises sont fictifs. Chaque chapitre devra être relu par un historien avant la publication.

| # | Chapitre | Période | Type de jeu | Contenu |
| --- | --- | --- | --- | --- |
| 0 | **Médina, 1939** | septembre 1939 | Exploration, récit | Vie du quartier, mobilisation annoncée, adieux à la famille. On réutilise la ville de Dakar de Boy Galsen, adaptée à l'époque. |
| 1 | **Le départ** | hiver 1939-40 | Récit | Camp d'instruction, le port de Dakar, la traversée en bateau. Lettres. |
| 2 | **La Somme, juin 1940** | mai-juin 1940 | Combat | Défense d'un village face à l'offensive allemande, puis retraite. Tension, infériorité en matériel. |
| 3 | **La débâcle** | juin 1940 | Récit + infiltration | Encerclement. On évoque les crimes commis contre des tirailleurs prisonniers (par exemple à Chasselay, le 19-20 juin 1940) **sans scène jouable de massacre** : par la narration et le souvenir. |
| 4 | **Frontstalag** | 1940-1943 | Infiltration, récit | Captivité dans un camp de prisonniers en France (les tirailleurs y étaient gardés), entraide et évasion. |
| 5 | **Provence, août 1944** | août 1944 | Combat | Débarquement de Provence (15 août 1944) et libération de Toulon avec la 1re Armée française. |
| 6 | **Le blanchiment** | automne 1944 | Récit | Les tirailleurs sont retirés du front et remplacés par de jeunes recrues françaises, au moment où la victoire approche. |
| 7 | **Thiaroye** | 1er décembre 1944 | Récit (non jouable en combat) | Retour au Sénégal. Au camp de Thiaroye, d'anciens prisonniers réclament leurs soldes et sont tués par des troupes françaises. La fin est un hommage et un appel à la mémoire. |

**Épilogue** : un texte et des photos d'archives libres de droits sur les tirailleurs, les chiffres connus et les lieux de mémoire (le monument « Demba et Dupont » à Dakar, le Tata sénégalais de Chasselay, le cimetière de Thiaroye).

## 4. Mécaniques de jeu

**Exploration et récit** (chapitres 0, 1, 6, 7)
- Marcher, parler aux personnages (système de dialogue déjà fait dans Boy Galsen), petites tâches.
- Lettres : écrites et lues à voix haute entre les chapitres.
- Moments de vie au front : le thé, les chants, une partie de cartes.

**Combat** (chapitres 2, 4, 5)
- Fusil d'époque (MAS 36 ou Berthier), visée à l'épaule, recharge, grenades.
- **Couverture** : murets, maisons, haies, véhicules.
- Ordres simples à l'escouade : suivre, tenir la position, se replier.
- Ennemis contrôlés par une IA : patrouilles, couverture, contournement.
- Santé « à l'ancienne » avec infirmier (pas de régénération magique).
- **Pas de violence gratuite** : pas de démembrement, pas de sang excessif.

**Infiltration** (chapitres 3, 4) : se cacher, distraire, s'évader.

## 5. Direction artistique

- Couleurs : ocres et poussière pour Dakar, verts et gris pour la France, lumière dorée pour la Provence.
- Uniformes : tenue kaki et **chéchia rouge** (couvre-chef emblématique des tirailleurs), casque Adrian au combat.
- Musique : kora et chants mandingues (Kouyaté), mêlés à une musique d'orchestre sobre.

## 6. Ce qu'on réutilise de Boy Galsen

- Le moteur Godot, la caméra à la 3ᵉ personne, les commandes et la manette.
- Les personnages réalistes, leur habillage et le système d'animation (y compris le reciblage).
- Le système de dialogues et de missions (fichier JSON).
- La ville de Dakar (OpenStreetMap), à adapter à 1939 : retirer les tours modernes, ajouter des bâtiments d'époque.
- Les véhicules et la conduite (camions militaires à la place des taxis).

## 7. Ressources à trouver

| Besoin | Piste |
| --- | --- |
| Fusils MAS 36, Berthier, Lebel | Sketchfab (CC BY), à vérifier un par un |
| Casque Adrian, chéchia, uniformes | Modélisation sur mesure ou Sketchfab |
| Soldats allemands génériques (sans insignes nazis) | Sketchfab ; les symboles nazis sont interdits ou restreints dans plusieurs pays, on les évite |
| Animations de soldat (viser, tirer au fusil, s'accroupir, ramper) | Mixamo (gratuit, compte Adobe) et la bibliothèque actuelle |
| Villages français, Toulon 1944 | Kits modulaires CC0 (Quaternius, Kenney) et OpenStreetMap |
| Bateau de transport, camions | Sketchfab |
| Archives (photos) | Domaine public : ECPAD, Archives nationales, Gallica (licences à vérifier) |

## 8. Points de vigilance

- **Rigueur historique** : faire relire les chapitres par un historien spécialiste (ouvrages de référence : Myron Echenberg, Julien Fargettas, Armelle Mabon sur Thiaroye, Raffael Scheck sur les massacres de 1940).
- **Respect des familles et de la mémoire** : consulter des associations d'anciens combattants et de descendants.
- **Thiaroye** est un sujet encore débattu et douloureux : on le traite avec sobriété, sans combat jouable.
- **Classification** : PEGI 16 probable (violence de guerre réaliste).

## 9. Première version jouable (objectif)

1. **Chapitre 0 court** : Demba dans la Médina, trois dialogues, l'annonce de la mobilisation, les adieux.
2. **Chapitre 2 court** : défense d'un village de la Somme, avec un fusil, de la couverture, une escouade et des vagues d'ennemis.
3. Les menus, les lettres entre les chapitres et la sauvegarde.
