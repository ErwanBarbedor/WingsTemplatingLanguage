# Plume Template Language

[🇺🇸/🇬🇧](#english) [🇫🇷](#Français)
## English
## Français
## Table of Contents
- [Introduction](#introduction)

## Introduction
J'ai créé Plume afin de rédiger mes supports de cours en html/css. J'avais besoin d'un langage avec une syntaxe claire ne gênant pas la rédaction (jinja est très utile dans certains cas de figure, mais que sa syntaxe est lourde!) mais qui ai la flexibilité d'un vrai langage de programmation (LaTeX est fabuleux, pendant des années j'ai écrit tout mes documents avec, mais c'est extrêmement pénible de l'étendre).

Plutôt que d'inventer un langage de A à Z, avec le temps et la difficulté que cela représente, j'ai choisi de m'appuyer sur Lua, un langage de script établi, à la syntaxe lisible pour les débutants, léger et conçu pour être intégré à d'autres projets.

Ainsi, Plume permet d'utiliser durant l'écriture de vos documents l'ensemble des fonctionnalités de Lua, tout en restant avant tout adapté à la rédaction.

## Features
  - Syntaxe régulière et lisible
  - Variables, arithmétiques
  - Structures de controles for/while/if
  - Macros
  - Possibilité d'écrire du code lua directement dans le document
  - Possibilité d'étendre Plume avec des librairies lua

## Installation
### Fichier Lua
Plume est écrit en Lua et compatible avec les versions 5.1 à 5.4, ainsi que luajit.
Si vous avez Lua d'installé sur votre système, il suffit de télécharger les fichiers plume.lua et plume.sh (ou plume.bat pour windows).
Dans le cas contraire, vous pouvez vous référer à la section suivante.

Ensuite,
``` lua
local plume = require 'plume'

plume:init ()
local render = plume:render [[
  #-- Plume code
]]
print(render:tostring ())
```

Ou alors, pour les utilisateurs de linux
``` shell
set LUA_INTERPRETER= #path to your LUA_INTERPRETER, defaut "luajit"
plume.sh monfichier.plume
```

Et pour ceux de windows:
``` dos
set LUA_INTERPRETER= #path to your LUA_INTERPRETER, defaut "luajit"
plume.bat monfichier.plume
```

### Standalone
Si vous n'avez pas Lua installé sur votre système ou si vous préférez simplement un standalone, 

## Usage (if you don't know lua)
Si vous maîtrisez Lua, je vous conseille de directement sauter à la section suivante.

### Basic Syntax
Tout texte simple sera rendu tel quel.

Entrée:
``` plume
foo
```

Sortie
``` plume
foo
```

### Macros simples
Vous pouvez stocker des bouts de code à l'intérieur de "macros".
Cela est utile, par exemple, si vous utilisez un nom à de nombreuses reprises dans votre document et que vous souhaitez pouvoir le changer rapidement

Entrée :
``` plume
#macro auteur Jean Dupont #end
Cet article a été écrit par #auteur.
```

Sortie :
``` plume
Cet article a été écrit par Jean Dupont
```

Notez l'utilisation du symbole '#' : tout élément de syntaxe commence forcément par lui.
Pour définir une macro, on écrit

``` plume
#macro nom_de_la_macro
  texte de remplacement
#end
```
On peut l'écrire sur une seule ligne, comme dans l'exemple.
Pour utiliser la macro, il suffit de faire :
``` plume
#nom_de_la_macro
```

### Macros avec arguments

### Variables
### Structures de controles
Demonstrate how to use control structures like loops and conditionals within templates.

## Usage (if you don't know lua)

## Contributing
Guidelines for how others can contribute to the Plume project.

## License
Detail the license under which Plume is released.

## Credits
Acknowledge contributors and any inspirations or third-party resources used.

## Contact
How to reach you for support, questions, or collaborations.