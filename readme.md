# Plume Templating Language

[🇫🇷 version](#Français)

## Français
## Table des matières
- [Introduction](#introduction)

## Introduction
Plume est un langage de templating centrée autour de la flexibilité et l'extensibilité, créé pour répondre à des besoins spécifiques de rédaction automatisée et de génération de contenu dynamique, tout en restant intuitif pour les auteurs de documents. 

## Cas d'Usage du Langage

Bien que développé initialement pour la création de supports pédagogiques en HTML/CSS, Plume présente un potentiel d'utilisation dans divers contextes :

- Génération dynamique de rapports ou de documents comportant des éléments récurrents.
- Templating de sites web statiques nécessitant une maintenance et des mises à jour régulières de contenus.
- Automatisation de newsletters ou d’e-mails personnalisés à partir de modèles.
- Génération de code source ou de données de configuration à partir de templates personnalisés.


## Points forts
  - Syntaxe régulière et lisible
  - Variables, arithmétique
  - Structures de controles for/while/if
  - Macros
  - Possibilité d'écrire du code lua directement dans le document
  - Possibilité d'étendre Plume avec des librairies lua

## Installation
Plume est écrit en Lua et compatible avec les versions de 5.1 à 5.4, ainsi que luajit.

## Utilisation basique
Si vous maîtrisez Lua, je vous conseille de directement sauter à la section suivante.

### Syntaxe basique
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
$macro auteur Jean Dupont $end
Cet article a été écrit par $auteur.
```

Sortie :
``` plume
Cet article a été écrit par Jean Dupont
```

Notez l'utilisation du symbole '$' : tout élément de syntaxe commence forcément par lui.
Pour définir une macro, on écrit

``` plume
$macro nom_de_la_macro
  texte de remplacement
$end
```
On peut l'écrire sur une seule ligne, comme dans l'exemple.
Pour utiliser la macro, il suffit de faire :
``` plume
$nom_de_la_macro
```

### Paramètres de macro
Parfois, avoir une macro qui donne toujours le même résultat est insufisant.
Heureusement, on peut ajouter des paramètres à la macro :

Entrée :
``` plume
$macro double(x) $x $x $end
$double(Cette phrase est écrite deux fois)
```

Sortie :
``` plume
Cette phrase est écrite deux fois Cette phrase est écrite deux fois
```

On aurait pu écrire aussi, pour le même résultat, 
``` plume
$macro double(x) $x $x $end
$double(x=Cette phrase est écrite deux fois)
```

Notrez l'usage du '$' devant le x, qui signifie 'ne pas écrire la lettre x, mais le paramètre donné à la macro".

Une macro peut avoir autant de paramètres que vous le voulez. Il suffit de les séparers par des virgules.
Entrée :
``` plume
$macro concat3(x, y, z) $x-$y-$z $end
$concat3(a, b, c)
```

Sortie :
``` plume
a-b-c
```

### Paramètres par défaut
On peut vouloir que certain arguments soient falcutatifs. Si l'utilisateur ne les fournit pas, une valeur par défaut est alors utilisée.
Entrée :
``` plume
$macro prefix_name (word, prefix="M. ")
$prefix_name(Dupont)
$prefix_name(Dupont, Mdm)
```

Sortie :
``` plume
M. Dupont
Mdm Dupon
```

### Inclure un autre fichier
Vous pouvez inclure dans votre document n'importe quel fichier en utilisant les macros $import et $include.

La macro $import sert à inclure des fichier plume, alors que $include copie le contenue d'un fichier sans l'executer.

### Librairies externes
Des utilisateurs peuvent ajouter des fonctionnalités à Plume (cf la section "Utilisation Avancée").
Vous pouvez inclure leur travail dans votre document :
  - Copier leurs fichiers à l'intérieur du dossier "lib" de l'instalation de Plume ou directement à côté de votre document.
  - Ecrire au début de votre fichier : ```$import(nom de la lib)```

### Répéter un bloc de texte
Si vous avez besoin de répéter une ligne ou un bloc de texte, vous pouvez utiliser la construction $for ... $do ... $end.

Entrée :
``` plume
$for i=1, 3 $do
  Ceci est la ligne $i.
$end
```

Sortie :
``` plume
Ceci est la ligne 1.
Ceci est la ligne 2.
Ceci est la ligne 3.
```

## Utilisation avancée
Vous avez découvert les usages basique de Plume. Ils seront suffisant dans beaucoup de cas, mais il est possible de faire beaucoup plus.

Une connaissance du langage Lua aidera grandement à comprendre cette section.

### Fonctionnement de Plume
En interne, Plume transpile le document en un fichier Lua, puis execute ce dernier.
En comprenant comment fonctionnent cette transpilation, vous pouvez faire avec Plume tout ce que vous pouvez faire avec Lua.

### Mode texte, mode lua
Lorsque Plume parcout le document afin de le transpiler, il sépare le code en trois catégories :
  - Les éléments de contrôle (commencant par un '$')
  - Le texte, qui sera affiché tel quel dans la sortie finale.
  - Le code Lua, qui sera gardé tel quel dans le fichier transpilé.

Par exemple, dans le code suivant:
``` plume
$for i=1, 3 $do
  Ceci est une ligne!
$end
```

  - $for, $do et $end sont des éléments de controle. Ils permettent à Plume de créer et de délimiter une boucle "for".
  - "Ceci est une ligne!" est du texte. Il apparaitra sans modification dans le fichier de sortie.
  - "i=1, 3" est le code Lua qui contrôle l'execution de la boucle for. Il sera écrit tel quel dans le code transpilé ; vous pouvez en fait écrire ce que vous voulez à part des éléments de controle. Si vous écrivez du code invalide, ce n'est pas Plume qui affichera un message d'erreur, mais Lua.

### Variables et mots-clefs
Les éléments de contrôle sont soit des mots-clefs (for, function, ...) soit des variables.

Si $i est une variable, ```$i``` écrira la valeur de i dans le fichier de sortie. Si $i contient une fonction, c'est la valeur qu'elle retournera qui sera écrite. Vous pouvez aussi écrire  ```$i()``` (sans espaces entre '$i' et '('!).

Si $i prend des arguments, vous pouvez les indiquer : ```$i(foo, bar)```.

### Structures de contrôle
Avec Plume, vous pouvez utiliser les boucles for et while ainsi que la structure if.
Ils ont tous une construction similaire:
``` plume
$for [lua iterator] $do
  [texte]
$end
```

``` plume
$while [lua condition] $do
  [texte]
$end
```

``` plume
$if [lua condition] $then
  [texte]
$end
```

``` plume
$if [lua condition] $then
  [texte]
$else
  [texte]
$end
```

``` plume
$if [lua condition] $then
  [texte]
$elseif [lua] $then
  [texte]
$end
```

Je vous renvoie vers la documentation Lua pour la syntaxe de [lua condition] et de [lua iterator].

### Executer du code Lua
#### Lua-inline
La syntaxe ```$([code lua])``` permet d'évaluer n'importe quelle expression lua.
Ainsi, ```$(1+5)``` renvera ```2```

Par soucis de légèreté, on peut également utiliser cette syntaxe pour les affectations : ```$(i = 5)``` ou ```$(local i = 5)```

#### Lua-block
Pour exectuer des statements, il faut utiliser la syntaxe
``` plume
$lua
  [lua code]
$end
```

Attention, cela n'écrira rien dans le fichier final.
Pour écrire quelque chose, vous devrez utiliser la fonction plume.write (pour plus de détail, consulter Usage Expert > API)

``` plume
$lua
  plume:write(1+1)
$end
```

Est l'équivalent de 
``` plume
$(1+1)
```
### Déclarer des fonctions
``` plume
$macro name(arguments)
  [text]
$end
```

``` plume
$function name(arguments)
  [lua code]
  return result
$end
```
S'ils n'y a pas d'arguments, les parenthèses sont optionnelles.

Choississez $function uniquement si votre fonction ne contient pas, ou presque, de texte. Sinon, utilisez $macro, éventuellement avec $lua ou $().

Attention : 
``` plume
$function foo(x)
  return "bar" .. x
$end
```
et
``` plume
$(foo = function(x)
  return "bar" .. x
end)
```
Ne sont pas strictement équivalents à cause du support des paramètres nommés (en particulier, toute fonction reçoit tout ses arguments sous forme d'une unique table). Dans le premier cas, Plume s'en occupe automatiquement. Dans le deuxième, c'est à vous de le faire manuellement. (se réfèrer à la section "Utilisation Experte").

### Paramètres positionels, paramètres nommés, valeurs par défaut
I

### Conversion de paramètres
Les paramètres donné à une fonction à travers plume ne sont pas des chaînes de caractères, mais des TokenList. Cela permet une introspection poussée (cf la section "Usage Expert"), mais rend une conversion obligatoire si vous en avez besoin comme nombres ou chaîne de caractère.
Utilisez pour cela TokenList:tostring et TokenList:tonumber.

Par soucis de légèreté, la converstion sera automatique en cas de concaténation ou d'opération arithmétique.

### Ajouter des fichiers externes
#### require
#### import
#### include

## Usage Expert
### Passation de paramètres
### Gestion des espaces
### Modifier la syntaxe
### Token
### TokenList
### API
#### plume:render ()
#### plume:write ()
#### plume:push ()
#### plume:pop ()

## License
Detail the license under which Plume is released.