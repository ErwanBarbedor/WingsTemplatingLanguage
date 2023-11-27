# Wings Templating Language

[🇫🇷 version](#Français)

## Français
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

## Utilisation basique
Pour ceux qui débutent en Lua ou qui ne sont pas familiers avec les langages de scripting, veuillez suivre cette section. Les utilisateurs expérimentés en Lua peuvent passer directement à la section avancée.


### Syntaxe basique
Tout texte écrit sans commande spéciale sera produit tel quel dans le document final.


Entrée:
``` wings
foo
```

Sortie
``` wings
foo
```

### Macros simples
Les macros permettent d'encapsuler et de réutiliser des fragments de texte ou de code. Elles sont particulièrement utiles lorsque vous avez besoin de répéter certaines parties d'un document et que vous voulez préserver la facilité de maintenance, comme lorsqu'il est nécessaire de modifier un élément répandu à travers le document.

Exemple d'utilisation d'une macro simple :
Entrée :
``` wings
#macro auteur Jean Dupont #end
Cet article a été écrit par #auteur.
```

Sortie :
``` wings
Cet article a été écrit par Jean Dupont
```

Il est à noter que tous les éléments de la syntaxe Wings commencent par le symbole dièse (#). Pour définir une macro, on utilise la forme suivante :

``` wings
#macro nom_de_la_macro
  texte de remplacement
#end
```

Cette macro peut être déclarée sur une ligne unique, comme montré dans l'exemple précédent. Pour utiliser la macro dans votre texte, vous écrivez simplement :

``` wings
#nom_de_la_macro
```

### Paramètres de macro
Une macro statique peut s'avérer limitée pour certains besoins. Heureusement, Wings permet l'ajout de paramètres aux macros pour une plus grande flexibilité :

Exemple avec des paramètres :

Entrée :
``` wings
#macro double(x)
  #x #x
#end
#double(Cette phrase est écrite deux fois)
```

Sortie :
``` wings
Cette phrase est écrite deux fois Cette phrase est écrite deux fois
```

Une alternative pour le même résultat serait :

``` wings
#double(x=Cette phrase est écrite deux fois)
```

Il est important de remarquer l'emploi du dièse (#) devant le "x", qui indique qu'il ne s'agit pas d'afficher le caractère "x", mais bien la valeur associée au paramètre de la macro.

Une macro peut contenir de multiples paramètres, il suffit de les séparer par des virgules.

Exemple avec plusieurs paramètres :

Entrée :
``` wings
#macro concat3(x, y, z) #x-#y-#z #end
#concat3(a, b, c)
```

Sortie :
``` wings
a-b-c
```

### Paramètres par défaut
On peut vouloir que certain arguments soient falcutatifs. Si l'utilisateur ne les fournit pas, une valeur par défaut est alors utilisée.
Entrée :
``` wings
#macro prefix_name (word, prefix=M.)
  #prefix #word
#end
#prefix_name(Dupont)
#prefix_name(Dupont, Mdm)
```

Sortie :
``` wings
M. Dupont
Mdm Dupont
```

### Inclure un autre fichier
Vous pouvez inclure dans votre document n'importe quel fichier en utilisant les macros #import et #include.

La macro #import sert à inclure des fichier wings, alors que #include copie le contenue d'un fichier sans l'executer.

### Librairies externes
Des utilisateurs peuvent ajouter des fonctionnalités à Wings (cf la section "Utilisation Avancée").
Vous pouvez inclure leur travail dans votre document :
  - Copier leurs fichiers à l'intérieur du dossier "lib" de l'instalation de Wings ou directement à côté de votre document.
  - Ecrire au début de votre fichier : ```#import(nom de la lib)```

### Répéter un bloc de texte
Si vous avez besoin de répéter une ligne ou un bloc de texte, vous pouvez utiliser la construction #for ... #do ... #end.

Entrée :
``` wings
#for i=1, 3 #do
  Ceci est la ligne #i.
#end
```

Sortie :
``` wings
Ceci est la ligne 1.
Ceci est la ligne 2.
Ceci est la ligne 3.
```

## Utilisation avancée
Vous avez découvert les usages basique de Wings. Ils seront suffisant dans beaucoup de cas, mais il est possible de faire beaucoup plus.

Une connaissance du langage Lua aidera grandement à comprendre cette section.

### Fonctionnement de Wings
En interne, Wings transpile le document en un fichier Lua, puis execute ce dernier.
En comprenant comment fonctionnent cette transpilation, vous pouvez faire avec Wings tout ce que vous pouvez faire avec Lua.


### Mode texte, mode lua
Lorsque Wings parcout le document afin de le transpiler, il sépare le code en trois catégories :
  - Les éléments de contrôle (commencant par un '#')
  - Le texte, qui sera affiché tel quel dans la sortie finale.
  - Le code Lua, qui sera gardé tel quel dans le fichier transpilé.

Par exemple, dans le code suivant:
``` wings
#for i=1, 3 #do
  Ceci est une ligne!
#end
```

  - #for, #do et #end sont des éléments de controle. Ils permettent à Wings de créer et de délimiter une boucle "for".
  - "Ceci est une ligne!" est du texte. Il apparaitra sans modification dans le fichier de sortie.
  - "i=1, 3" est le code Lua qui contrôle l'execution de la boucle for. Il sera écrit tel quel dans le code transpilé ; vous pouvez en fait écrire ce que vous voulez. Si vous écrivez du code invalide, ce n'est pas Wings qui affichera un message d'erreur, mais Lua.

D'où le code Lua:
```lua
wings:push ()


-- line 1 : #for i=1, 3 #do
for i=1, 3 do

    -- line 2 : Ceci est une ligne!
    wings:write 'Ceci est une ligne!'
    wings:write '\n'

-- line 3 : #end
end


return wings:pop ()
```

### Variables et mots-clefs
Les éléments de contrôle sont soit des mots-clefs (for, function, ...) soit des variables.

Si i est une variable lua, ```#i``` écrira la valeur de i dans le fichier de sortie. Si i contient une fonction, c'est la valeur qu'elle retournera qui sera écrite. Vous pouvez aussi écrire  ```#i()``` (sans espaces entre '#i' et '('!).

Si i prend des arguments, vous pouvez les indiquer : ```#i(foo, bar)```.

### Structures de contrôle
Avec Wings, vous pouvez utiliser les boucles for et while ainsi que la structure if.
Ils ont tous une construction similaire:
``` wings
#for [lua iterator] #do
  [texte]
#end
```

``` wings
#while [lua condition] #do
  [texte]
#end
```

``` wings
#if [lua condition] #then
  [texte]
#end
```

``` wings
#if [lua condition] #then
  [texte]
#else
  [texte]
#end
```

``` wings
#if [lua condition] #then
  [texte]
#elseif [lua condition] #then
  [texte]
#end
```

Je vous renvoie vers la documentation Lua pour la syntaxe de [lua condition] et de [lua iterator].

### Executer du code Lua
#### Lua-inline
La syntaxe ```#([code lua])``` permet d'évaluer n'importe quelle expression lua.
Ainsi, ```#(1+5)``` renvera ```6```

Par soucis de légèreté, on peut également utiliser cette syntaxe pour les affectations : ```#(i = 5)``` ou ```#(local i = 5)```

#### Lua-block
Pour exectuer des statements, il faut utiliser la syntaxe
``` wings
#lua
  [lua code]
#end
```

Attention, cela n'écrira rien dans le fichier final.
Pour écrire quelque chose, vous devrez utiliser la fonction wings.write (pour plus de détail, consulter Usage Expert > API)

``` wings
#lua
  wings:write(1+1)
#end
```

Donne le même résultat que
``` wings
#(1+1)
```

### Déclarer des fonctions
``` wings
#macro name(arguments)
  [text]
#end
```

``` wings
#function name(arguments)
  [lua code]
  return result
#end
```
S'ils n'y a pas d'arguments, les parenthèses sont optionnelles.

Choississez #function uniquement si votre fonction ne contient pas, ou presque, de texte. Sinon, utilisez #macro, éventuellement avec #lua ou #().

Attention : 
``` wings
#function foo(x)
  return "bar" .. x
#end
#foo(bar)
```
et
``` wings
#(foo = function(x)
  return "bar" .. x
end)
#foo(bar)
```
Ne sont pas équivalents (le deuxième causera même une erreur), à cause du support des paramètres nommés : dans le premier cas, Wings s'en occupe automatiquement. Dans le deuxième, c'est à vous de le faire manuellement. (se réfèrer à la section "Utilisation Experte").

### Paramètres positionels, paramètres nommés, valeurs par défaut
I

### Conversion de paramètres
Les paramètres donné à une fonction à travers wings ne sont pas des chaînes de caractères, mais des TokenList. Cela permet une introspection poussée (cf la section "Usage Expert"), mais rend une conversion obligatoire si vous en avez besoin comme nombres ou chaîne de caractère.
Utilisez pour cela TokenList:tostring et TokenList:tonumber.

Par soucis de légèreté, la converstion sera automatique en cas de concaténation ou d'opération arithmétique.

### Structure begin
Prenons une macro ```document```, censé contenir l'intégralité de votre texte.
Plutôt que d'écrire
``` wings
#document(
  ...
)
```
Ce qui est peu lisible en cas d'imbrication et interdit l'usage des virgules (en effet, les virgules seront comprises comme des séparateurs de paramètre), il est possible d'utiliser la synaxe suivante:
``` wings
#begin document
  ...
#end
```

Si document a besoin de d'autres paramètres :

``` wings
#begin document(arg1, arg2, ...)
  ...
#end
```

Tout ce qui se situe entre #begin et #end sera considéré comme le premier argument.

### Ajouter des fichiers externes
#### require
#### import
#### include
### Echapper des caractères
Il n'y a pas de caractère d'échappement en Wings.
Si cela vous pose vraiment problème, deux solutions:
- Mettre le texte fautif dans un fichier et utiliser ```#include```
- Utilier une structure lua-inline : ```#("#for")```

## Usage Expert
### Passation de paramètres
### Gestion des espaces
### Modifier la syntaxe
### Token
### TokenList
### API
#### wings:transpile ()
#### wings:render ()
#### wings:write ()
#### wings:push ()
#### wings:pop ()

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