# Wings - Usage simple

## Syntaxe basique
Tout texte écrit sans commande spéciale sera produit tel quel dans le document final.


Entrée:
``` wings
foo
```

Sortie
``` wings
foo
```

## Macros simples
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

## Paramètres de macro
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

## Paramètres par défaut
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

## Inclure un autre fichier
Vous pouvez inclure dans votre document n'importe quel fichier en utilisant les macros #import et #include.

La macro #import sert à inclure des fichier wings, alors que #include copie le contenue d'un fichier sans l'executer.

## Librairies externes
Des utilisateurs peuvent ajouter des fonctionnalités à Wings (cf la section "Utilisation Avancée").
Vous pouvez inclure leur travail dans votre document :
  - Copier leurs fichiers à l'intérieur du dossier "lib" de l'instalation de Wings ou directement à côté de votre document.
  - Ecrire au début de votre fichier : ```#import(nom de la lib)```

## Répéter un bloc de texte
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