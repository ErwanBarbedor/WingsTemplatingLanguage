# Wings Templating Language

[🇫🇷 version](doc/fr/readme.md)

## Introduction

Wings is a "logicfull" templating language that integrates Lua into its syntax.

I mainly use it in the Plume project (link to come), which allows writing documents using the power of HTML+CSS.

Wings is currently under development and absolutely not ready for production use.
A tutorial and extensive documentation are being written.

## Design Note
A "templating" language aims to allow the user to write their text as fluidly as possible.
To structure their document and save time, it sometimes contains a few logical elements (macros, loops, or other programming elements...), but writing a complete program is often laborious: a templating language is not meant for that.

Conversely, a “classic” programming language is designed to control the flow of instructions as efficiently as possible (from the point of view of certain programming philosophy).
It allows representing raw data, text for what we're interested in here, but it would often be cumbersome to write a text document in Python or the like.

The goal of Wings is to reach the sweet spot between the two worlds: putting text at the center of the syntax, but allowing with little to no cost the use of the full power of a programming language.

Instead of creating an entire dialect from scratch, Wings transpiles into Lua, thus borrowing all its features.

## Concrete Principles
When Wings scans the document to transpile it, it separates the code into three categories:
  - Control elements (starting with a '#')
  - Text, which will be displayed as-is in the final output.
  - The Lua code, which will be kept as-is in the transpiled file.

For example, in the following code:
``` wings
#for i=1, 3 #do
  This is a line!
#end
```

  - #for, #do, and #end are control elements. They enable Wings to create and delimit a "for" loop.
  - "This is a line!" is text. It will appear without alteration in the output file.
  - "i=1, 3" is the Lua code that controls the execution of the for loop. It will be written as-is in the transpiled code; you can in fact write whatever you want. If you write invalid code, it will not be Wings that displays an error message, but Lua.

## Main Limitation
  While you can write with Wings almost anything that you can write in Lua (at the price of a slightly heavier syntax), bear in mind the following point: by default, all written text is collected and then returned.
  There is therefore no control by the user over the program's return value, nor (in most cases) over the return value of a function.

  I have not yet found an elegant way to solve this issue, but it is not a major inconvenience.

## License
Wings is distributed under the GNU/GPL license.