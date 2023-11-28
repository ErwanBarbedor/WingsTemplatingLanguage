# Wings Templating Language

[🇫🇷 version](#Français)
## Table des matières
- [Introduction](#introduction)

## Introduction
Wings est un langage de templating centrée autour de la flexibilité et l'extensibilité, créé pour répondre à des besoins spécifiques de rédaction automatisée et de génération de contenu dynamique, tout en restant intuitif pour les auteurs de documents. 

## Cas d'Usage du Langage

Bien que développé initialement pour la création de supports pédagogiques en HTML/CSS, Wings présente un potentiel d'utilisation dans divers contextes :

- Génération dynamique de rapports ou de documents comportant des éléments récurrents.
- La personnalisation de sites web statiques ayant besoin de mises à jour fréquentes.
- L'automatisation de newsletters ou de courriels personnalisés à partir de modèles établis.
- La création de code source ou de fichiers de configurations sur la base de templates personnalisables.


## Points forts
- Une syntaxe cohérente et claire.
- La gestion de variables et les opérations arithmétiques.
- Des structures de contrôle comme les boucles for/while et les conditions if.
- La définition et l'utilisation de macros.
- L'intégration de code Lua directement dans les templates.
- La possibilité d'enrichir Wings avec des bibliothèques Lua supplémentaires.


## Installation
Wings est écrit en Lua et compatible avec les versions de 5.1 à 5.4, ainsi que luajit.

## Apprendre Wings

Si vous ne connaissez pas le langage Lua ou souhaitez juste des informations simples sur Wings, suivez ce [tutoriel](doc/fr/tutorial-luabeginner.md)

Pour un tutoriel un peu plus avancé : [ici](doc/fr/tutorial.md) puis [ici](doc/fr/tutorial-expert.md).

Pour se renseigner l'API [c'est ici](doc/fr/api.md)


## Performances
Wings est certainement plutôt lent :
  - Etape de transpilation
  - Appel de macro plutôt lourd
  - Lua n'est pas très bon avec les chaînes de caractère

Dans le futur, je ferais des tests pour avoir une idée claire des performances de Wings, et si besoin de l'optimiser.

## Futures fonctionnalités
### Prioritaires
  - Vérication effectués par le transpiler :
    - Est-ce qu'il y a bien un #end pour chaque #for / #if / ...
    - Est-ce qu'il y a bien un #then après un #if, et non un #do...
    - Est-ce que les noms de macros / variables sont des identifiants lua valides
  - Modifier les exentions par défauts des fichiers wings

### Non prioritaires
  - Permettre à l'utilisateur de modifier la syntaxe de Wings
  - Donner un moyen simple d'utiliser des librairires lua externes
  - Déclarer des macros locales
  - Mots-clefs #do et #repeat
  - Rendre l'usage des TokenList flexible
  - Réfléchir aux performances et, si besoin

### En réflexion
  - Permettre à l'utilisateur d'étendre la syntaxe du transpileur (exemple : ```#alias oldname newname```) autrement que via des macros.
  - Nouvelle structure ```#raw ... #end```
  - Gestion des espaces. Les garder tous? Les supprimer? Un juste milieu?
  - Gestion des caractères à échapper.

## License
Wings est distribuée sous license GNU/GPL.