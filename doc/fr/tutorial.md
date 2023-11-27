
# Wings - Utilisation avancée
Vous avez découvert les usages basique de Wings. Ils seront suffisant dans beaucoup de cas, mais il est possible de faire beaucoup plus.

Une connaissance du langage Lua aidera grandement à comprendre cette section.

## Fonctionnement de Wings
En interne, Wings transpile le document en un fichier Lua, puis execute ce dernier.
En comprenant comment fonctionnent cette transpilation, vous pouvez faire avec Wings tout ce que vous pouvez faire avec Lua.


## Mode texte, mode lua
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

## Variables et mots-clefs
Les éléments de contrôle sont soit des mots-clefs (for, function, ...) soit des variables.

Si i est une variable lua, ```#i``` écrira la valeur de i dans le fichier de sortie. Si i contient une fonction, c'est la valeur qu'elle retournera qui sera écrite. Vous pouvez aussi écrire  ```#i()``` (sans espaces entre '#i' et '('!).

Si i prend des arguments, vous pouvez les indiquer : ```#i(foo, bar)```.

## Structures de contrôle
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

## Executer du code Lua
### Lua-inline
La syntaxe ```#([code lua])``` permet d'évaluer n'importe quelle expression lua.
Ainsi, ```#(1+5)``` renvera ```6```

Par soucis de légèreté, on peut également utiliser cette syntaxe pour les affectations : ```#(i = 5)``` ou ```#(local i = 5)```

### Lua-block
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

## Déclarer des fonctions
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

## Paramètres positionels, paramètres nommés, valeurs par défaut
I

## Conversion de paramètres
Les paramètres donné à une fonction à travers wings ne sont pas des chaînes de caractères, mais des TokenList. Cela permet une introspection poussée (cf la section "Usage Expert"), mais rend une conversion obligatoire si vous en avez besoin comme nombres ou chaîne de caractère.
Utilisez pour cela TokenList:tostring et TokenList:tonumber.

Par soucis de légèreté, la converstion sera automatique en cas de concaténation ou d'opération arithmétique.

## Structure begin
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

## Ajouter des fichiers externes
### require
### import
### include
## Echapper des caractères
Il n'y a pas de caractère d'échappement en Wings.
Si cela vous pose vraiment problème, deux solutions:
- Mettre le texte fautif dans un fichier et utiliser ```#include```
- Utilier une structure lua-inline : ```#("#for")```
