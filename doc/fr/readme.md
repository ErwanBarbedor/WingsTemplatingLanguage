# Wings Templating Language

## Introduction

Wings est un langage de template "logicfull" intégrant lua dans sa syntaxe.

Je l'utilise principalement dans le projet Plume (lien à venir), qui permet d'écrire des documents en utilisant la puissance du html+css.

Wings est actuellement en cours de développement et absolument pas prêt à être utiliser en production.
Un tutoriel et une documentation extensive sont en cours de rédaction.

## Note de conception
Un langage "de template" vise à permettre à l'utilisateur d'écrire son texte de la manière la plus fluide possible.
Pour structurer son document et gagner du temps, il contient parfois quelques éléments logiques (macro, boucles ou autres éléments de programations...), mais écrire un programme complet est souvent fastidieux : un langage de template n'est pas fait pour ça.

A l'opposé, un langage de programmation "classique" est conçu pour contrôler le flux d'instructions de la manière la plus efficace possible (du point vue d'une certaine philosophie de programmation).
Il permet de représenter des données brutes, du texte pour ce qui nous intéresse ici, mais il serais souvent laborieux d'écrire un document texte en python ou autre.

L'objectif de Wings est d'atteindre le juste milieu des deux mondes : mettre le texte au centre de la syntaxe, mais permettre sans coût (ou presque) l'utilisation de la pleine puissance d'un langage de programmation.

Plutôt de créer un dialecte entier à partir de 0, Wings transpile en lua dont il reprend donc toutes les fonctionnalités.

## Principe concret
Lorsque Wings parcourt le document afin de le transpiler, il sépare le code en trois catégories :
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

## Principale limitation
  Si on peut écrire avec Wings à peu près tout ce qu'on peut écrire en lua (au prix d'une syntaxe légèrement plus lourde), attention au point suivant : par défaut, tout texte écrit est collecté puis retourné.
  Il n'y a donc pas de contrôle par l'utilisateur sur la valeur de retour du programme, ni (dans la plupart des cas) sur la valeur de retour d'une fonction.

  Je n'ai pas encore trouvé de manière élégante de régler ce problème, mais ce n'est pas une gêne majeure.

## License
Wings est distribuée sous license GNU/GPL.