# phomo2sce

## What is phomo2sce?
**phomo2sce** is a sound-change translator that converts an input (PhoMo 3 format) and translates and outputs it in SCE format.

## Usage
You can use phomo2sce to output a translation of a PhoMo newline-separated file of rules. You must specify the filename with the flag `-f`.
```
ruby phomo2sce.rb -f <filename> [-l]
```
Alternatively you can use the `-r` flag to specify a single rule to translate.
```
ruby phomo2sce.rb -r a/e/_# [-l]
```
The `-l` flag on both of these examples is the literal flag. If present it will stick to literal SCE syntax when translating (that is, no stylised insertion/deletion/movement rules).

## Ruleset Testing
The additional Phomo2SceTest class can be used test whether a certain file of newline-separated PhoMo rules will translate into SCE as expected by testing it against a target file.
```
ruby p2stest.rb sample.txt goal.txt [-l]
```
This will go through all the PhoMo rules in `sample.txt`, translate them to SCE and then check the translation against the rule given in `goal.txt`. Again, the optional `-l` flag will force it to translate to non-stylised SCE.
