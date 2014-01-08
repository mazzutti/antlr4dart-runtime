**ANTLR 4 runtime for Dart**

#### DESCRIPTION

Fully-featured ANTLR 4 runtime library for Dart.

ANTLR (ANother Tool for Language Recognition) is a tool that is used to generate
code for performing a variety of language recognition tasks: lexing, parsing,
abstract syntax tree construction and manipulation, tree structure recognition,
and input translation. The tool operates similarly to other parser generators,
taking in a grammar specification written in the special ANTLR metalanguage and
producing source code that implements the recognition functionality.

While the tool itself is implemented in Java, it has an extensible design that
allows for code generation in other programming languages. To implement an
ANTLR language target, a developer may supply a set of templates written in the
StringTemplate ([http://www.stringtemplate.org](http://www.stringtemplate.org)) language.

This dart lib is a complete implementation of the majority of features
ANTLR provides for other language targets, such as Java and CSharp. It contains
a dart runtime library that collects classes used throughout the code that
the modified ANTLR4 ([https://github.com/tiagomazzutti/antlr4dart](https://github.com/tiagomazzutti/antlr4dart)) 
generates.

#### USAGE

1. Write an ANTLR4 grammar specification for a language:

  ```antlr
  grammar SomeLanguage;
  
  options {
    language = Dart;    // <- this option must be set to Dart
  }
  
  top: expr ( ',' expr )*
     ;
  
  // and so on...
  ```

2. Run the [ANTLR4](https://github.com/tiagomazzutti/antlr4dart) tool with the `java -jar path/to/antlr-<VERSION>-complete.jar.jar` command to generate output:

  ```bash
  $> java -jar path/to/antlr-<VERSION>-complete.jar.jar [OPTIONS] lang.g
  # creates:
  #   langParser.dart
  #   langLexer.dart
  #   lang.tokens
  ```

   alternatively, you can do:

  ```bash 
  $> export CLASSPATH=path/to/path/to/antlr-<VERSION>-complete.jar:$CLASSPATH
  
  $> java org.antlr.v4.Tool [OPTIONS] $grammar
  ```

   NOTES: 
   * Replace *VERSION* with the version number currently used in [ANTLR4](https://github.com/tiagomazzutti/antlr4dart), or your own build of ANLTR4;
   * Probably you will need to edit the `@header{}` section in your grammar:
   
       Use 
        ```antlr
        @header {
          library your_library_name;
          import 'package:antlr4dart/antlr4dart.dart';
        }
        ```
       if the code should be generated in a dedicated Dart library. 
    
       Use 
        ```antlr
        @header {
          part of your_library_name;
          // no import statement here, add it to the parent library file 
        }
        ```
       if the  code should be generated as part of another library. 

       *More samples can be found in the [antlr4dart](https://github.com/tiagomazzutti/antlr4dart) test folder.*

3. Make sure your `pubspec.yaml` includes a dependency to `antlr4dart`:

   `antlr4dart` is hosted on pub.dartlang.org, the most simple dependency statement is therefore
```yaml
  dependencies:
    antlr4dart: any
```
   
   Alternatively, you can add a dependency to antlr4dart's GitHub repository: 
```yaml
  dependencies:
    antlr4dart: 
      git: git@github.com:tiagomazzutti/antlr4dart.git 
```

4. Try out the results directly:

```dart
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

### LICENSE

This license applies to all parts of antlr4dart-runtime that are not 
externally maintained libraries. 

Copyright 2014, the antlr4dart-runtime project authors. All rights 
reserved. Redistribution and use in source and binary forms, with or 
without modification, are permitted provided that the following 
conditions are met:

  * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above
    copyright notice, this list of conditions and the following
    disclaimer in the documentation and/or other materials provided
    with the distribution.
  * Neither the name of antlr4dart-runtime team. nor the names of its
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
