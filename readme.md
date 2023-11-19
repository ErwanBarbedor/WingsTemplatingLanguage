# Plume Template Language

[🇫🇷 version](#Français)
## Table of Contents
- [Introduction](#introduction)

## Introduction
I created Plume in order to write my course materials in html/css. I needed a language with a clear syntax that would not hinder the writing process (jinja is very useful in some cases, but its syntax is cumbersome!) but which also had the flexibility of a real programming language (LaTeX is fabulous, for years I've written all my documents with it, but it's extremely tedious to extend).

Rather than inventing a language from scratch, with the time and difficulty that entails, I chose to rely on Lua, an established scripting language, with syntax that is readable for beginners, lightweight, and designed to be embedded in other projects.

Thus, Plume allows you to use all the features of Lua during the writing of your documents, while remaining primarily suited to writing.

## Features
  - Regular and readable syntax
  - Variables, arithmetic
  - Control structures for/while/if
  - Macros
  - Ability to write Lua code directly in the document
  - Ability to extend Plume with Lua libraries

## Installation
### Lua File
Plume is written in Lua and is compatible with versions 5.1 to 5.4, as well as Luajit.
If you have Lua installed on your system, simply download the plume.lua and plume.sh files (or plume.bat for Windows).
Otherwise, you can refer to the following section.

Next,
``` lua
local plume = require 'plume'

plume:init()
local render = plume:render[[
  #-- Plume code
]]
print(render:tostring())
```

Or, for Linux users
``` shell
set LUA_INTERPRETER= #path to your LUA_INTERPRETER, default "luajit"
plume.sh my_file.plume
```

And for Windows users:
``` dos
set LUA_INTERPRETER= #path to your LUA_INTERPRETER, default "luajit"
plume.bat my_file.plume
```

### Standalone
If you don’t have Lua installed on your system or if you simply prefer a standalone,

## Usage (if you don't know lua)
If you are proficient in Lua, I advise you to skip directly to the next section.

### Basic Syntax
Any simple text will be rendered as is.

Input:
``` plume
foo
```

Output:
``` plume
foo
```

### Simple Macros
You can store snippets of code inside "macros".
This is useful, for example, if you use a name many times in your document and you want to be able to change it quickly.

Input:
``` plume
#macro author Jean Dupont #end
This article was written by #author.
```

Output:
``` plume
This article was written by Jean Dupont
```

Note the use of the '#' symbol: all syntax elements always start with it.
To define a macro, you write:

``` plume
#macro macro_name
  replacement text
#end
```
It can be written on a single line, as in the example.
To use the macro, just do:
``` plume
#macro_name
```

### Macros with Arguments

### Variables
### Control Structures
Demonstrate how to use control structures like loops and conditionals within templates.

## Usage (if you don't know lua)

## Contributing
Guidelines for how others can contribute to the Plume project.

## License
Detail the license under which Plume is released.

## Français
## Table des matières
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
Plume est écrit en Lua et compatible avec les versions 5.1 à 5.4, ainsi que luajit.
Si lua n'est pas installé sur votre système, téléchargez le ici.
Maintenant, il suffit de télécharger les fichiers plume.lua et plume.sh (ou plume.bat pour windows).

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

### Importer un fichier

### Utiliser lua
#lua et #function

## Usage (if you know lua)

### Philosophie de Plume
### Structures de controle
### function
### Fonctionnement technique de plume
#### Gestion des espaces
La plupart des langages sont assez indiférents aux espaces, mais pour information voici comment Plume les traite:
  - Les espaces au début et à la fin des lignes sont supprimés
  - Un saut de ligne est effectué une fois par ligne contenant du texte 


require et dofile

plume:transpile (code, optns)
plume:render (code, optns)

plume:pop ()
plume:push ()
plume:write ()

plume:TokenList ()
plume:Token ()

## Contributing
Guidelines for how others can contribute to the Plume project.

## License
Detail the license under which Plume is released.