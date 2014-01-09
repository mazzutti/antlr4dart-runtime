**ANTLR 4 runtime for Dart**

#### Description

Fully-featured ANTLR 4 runtime library for Dart.

ANTLR (ANother Tool for Language Recognition) is a tool that is used to 
generate code for performing a variety of language recognition tasks: 
lexing, parsing, abstract syntax tree construction and manipulation, tree 
structure recognition, and input translation. The tool operates similarly 
to other parser generators, taking in a grammar specification written in 
the special ANTLR metalanguage and producing source code that implements 
the recognition functionality.

While the tool itself is implemented in Java, it has an extensible design 
that allows for code generation in other programming languages. To implement 
an ANTLR language target, a developer may supply a set of templates written 
in the StringTemplate ([http://www.stringtemplate.org](http://www.stringtemplate.org)) language.

This dart lib is a complete implementation of the majority of features
ANTLR provides for other language targets, such as Java and CSharp. It 
contains a dart runtime library that collects classes used throughout the 
code that the modified ANTLR4 ([https://github.com/tiagomazzutti/antlr4dart](https://github.com/tiagomazzutti/antlr4dart)) generates.

#### Usage

1. Write an ANTLR4 grammar specification for a language:

  ```
  grammar SomeLanguage;
  
  options {
    language = Dart;    // <- this option must be set to Dart
  }
  
  top: expr ( ',' expr )*
     ;
  
  // and so on...
  ```

2. Run the [ANTLR4](https://github.com/tiagomazzutti/antlr4dart) tool with the `java -jar path/to/antlr-<VERSION>-with-dart-support.jar` command to generate output:

  ```
  $> java -jar path/to/antlr-{VERSION}-with-dart-support.jar [OPTIONS] lang.g
  # creates:
  #   langParser.dart
  #   langLexer.dart
  #   lang.tokens
  ```

   alternatively, you can do:

  ``` 
  $> export CLASSPATH=path/to/path/to/antlr-{VERSION}-with-dart-support.jar:$CLASSPATH
  
  $> java org.antlr.v4.Tool [OPTIONS] $grammar
  ```

   NOTES: 
   * Replace *VERSION* with the version number currently used in [ANTLR4](https://github.com/tiagomazzutti/antlr4dart), or your own build of ANLTR4;
   * Probably you will need to edit the `@header{}` section in your grammar:
   
    Use 
      ```
      @header {
        library your_library_name;
        import 'package:antlr4dart/antlr4dart.dart';
      }
      ```
      if the code should be generated in a dedicated Dart library. 
    
    Use 
      ```
      @header {
        part of your_library_name;
        // no import statement here, add it to the parent library file 
      }
      ```
      if the  code should be generated as part of another library. 

      *More samples can be found in the [antlr4dart](https://github.com/tiagomazzutti/antlr4dart) test folder.*

3. Make sure your `pubspec.yaml` includes a dependency to `antlr4dart`:

`antlr4dart` is hosted on pub.dartlang.org, the most simple dependency statement is therefore:
```
dependencies:
  antlr4dart: any
```
   
   Alternatively, you can add a dependency to antlr4dart's GitHub repository: 
```
dependencies:
  antlr4dart: 
    git: git@github.com:tiagomazzutti/antlr4dart-runtime.git 
```

4. Try out the results directly:

```
import "package:antlr4dart/antlr4dart.dart";
import "SomeLanguageLexer.dart";
import "SomeLanguageParser.dart";

main() {
  var input = 'some text to be parsed...';
  var source = new StringSource(input);
  var lexer = new SomeLanguageLexer(source);
  var tokens = new CommonTokenSource(lexer);
  var parser = new SomeLanguageParser(tokens);

  var result = parser.<entry_rule>();    
  // ...
}
```
