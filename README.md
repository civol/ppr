# Ppr

Ppr (Preprocessor in Ruby) is a library for preprocessing a text with macro written in the ruby language.

Ppr has the following features:
 * Support of the full Ruby language for the macros.
 * Possibility to change the keywords defining the macros - this can be useful to avoid conflicts with the contents of the text being preprocessed -
 * Execution of the macros in a sandbox to limit the effects of malicious code inserted in the input stream to preprocess (**do consult** the [disclaimer](#Disclaimer) section about this topic).

__Note__:

Ppr is somewhat similar to the C preprocessor (cpp), but is mainly meant to be used for code generation. For that purpose, and contrary to cpp, loops and recursion are possible. This render Ppr much more flexible, but also less safe to use: it might enter into an infinite loop whereas this is strictly impossible with cpp.

## Disclaimer

Even if the macro are executed in a sandbox environment, in the current state, I cannot guarantee their safety. Moreover, the `.load` and `.require` macros give read access to the disk.

Therefore **do not use Ppr with root (administrator) privilege**, and **do not allow the execution of Ppr by a server (web or other)** without the strictest caution.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ppr'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ppr

## Usage

### using Ppr

You can use Ppr in a ruby program by loading `ppr.rb` in your ruby file:

```ruby
require 'ppr.rb'
```

Then, build a new preprocessor by instantiating `Ppr::Preprocessor` as follows:

```ruby
ppr = Ppr::Preprocessor.new
```

This preprocessor preprocesses the text provided as `input` stream and put the result in an `output` stream as follows:

```ruby
ppr.preprocess(input,output)
```

For the command above, the `input` stream can be any object which provides the `each_line` enumerator, and the `output` stream can be any object which provides the `<<` operator for concatenating a string.

Parameters can be passed to the preprocessor when building it using a hash associating names (string or symbol) to values. These parameters will the accessible from the macros as instance variables.
For instance, the following code will create a new preprocessor with `hey` parameter set to "Hello" and `one` parameter set 1. Then, the code of the macros will have access to them through the `@hey` and the `@one` instance variables.

```ruby
ppr = Ppr::Preprocessor.new({"hey" => "Hello", "one" => 1})
```

The keywords defining the macros can also be redefined when building a new preprocessor by passing through the constructor named arguments. For instance, the following code will rename the `.def` keyword to `.DEFINE`:

```ruby
ppr = Ppr::Preprocessor.new(defm: ".DEFINE")
```

The expansion operator `:<` (please refer to the next section) too can also be redefined when building a preprocessor through the `expand` name argument.

The list of the named arguments used for redefining a preprocessor is as follows:

| named argument | redefined keyword |
| :------------- | :---------------- |
| apply          | .do               |
| applyR         | .doR              |
| define         | .def              |
| defineR        | .defR             |
| assign         | .assign           |
| loadm          | .load             |
| requirem       | .require          |
| ifm            | .if               |
| elsem          | .else             |
| endifm         | .endif            |
| endm           | .end              |
| expand         | :<                |
| glue           | ##                |



### Rules for writing a macro

Macros can be described on a single line or on multiple lines.

The syntax of a one-line macro is the following:

```ruby
<keyword> <name> '(' <arguments> ')' <code of the macro without any new line>
```

The syntax of a multi-line macro is the following:

```ruby
<keyword> <name> '(' <arguments> ')'
<code of the macro>
'.end'
```

In the above descriptions:
  * `<keyword>` is a keyword indicating the beginning of a macro (such keywords are described in the following section).
  * `name` is an identifier string indicating the name of the macro. If the macro does not require a name, `<name>` must be omitted.
  * `<arguments>` is a comma-separated list of arguments passed to the code of the macro, each argument being an identifier string. Only the `.def` and the `.defR` macros support arguments, for the other kind of macros `'(' <arguments> ')'` must be omitted.
  * `.end` is the keyword closing a multi-line macro and must be on a separate line.

*NB*: an identifier string is an alphanumerical string starting with an alphabetic character (the `_` character is considered to be an alphabetical character).

The code of a macro is standard ruby where the `File`, `Dir` classes, the `open` and the `system` methods and the `` `command` `` construct are deactivated. Expanding a macro consists then in executing its ruby code. When the macro has arguments, they are used as standard ruby local variables referring to `String` objects.

For producing the text to be added to the output stream, the `:<` operator has to be used as follows:

```ruby
:< <expression>
```

In the code above, `<expression>` can be any ruby expression. However, you must notice that the expression will be converted to a string (through the `to_s` method) before being added to the output stream.

### The different macros of Ppr

 * __`.do`__: defines an unnamed macro that is expand on place and whose result is not preprocessed again.

 * __`.doR`__: defines an unnamed macro that is expanded on place and whose result is preprocessed again.
 
 * __`.def`__: defines a named macro that is expanded each time its name is encountered in the text and whose expansion results are not preprocessed again. 

 * __`.defR`__: defines a named macro that is expanded each time its name is encountered in the text and whose expansion results are preprocessed again.

 * __`.assign`__: defines a named macro this is expanded on place and whose result is assigned to the instance variable corresponding to the name of the macro. This is the only kind of macro which can set an instance variable accessible to the other macros.

 * __`.load`__: defines an unnamed macro whose expansion result is the name of a file whose contents is pasted on place.

 * __`.require`__: defines an unnamed macro whose expansion result is the name of a file whose contents is pasted on place provided it has not been already required.

 * __`.if`__: defines an unnamed macro whose expansion result is evaluated as a boolean value. If the result is true, the following text is preprocessed until an `.else` or an `.endif` keywords are met. In this case, the code between the `.else` keyword (if any) and the `.endif` keyword is ignored. If the result is false, the following text is skipped until an `.else` or an `.endif` keywords are met. Then, the text following the `.else` keyword (if any) is preprocessed.

*N.B.*: 
 * the `.if` macro supports nesting.
 * the syntax of the `.if` macro is identical to the other kind of macros. However, it applies to the conditional only. The part following the conditional and until the `endif` keyword are considered as out of the macro.
 * the `.end`, the `.else` and `.endif` keywords are to be on a separate line.


### Invoking a `.def` or `.defR` macro

Macros of the `.def` and `.defR` kinds are not expanded on place, but are expanded wherever their name is invoked in the input text using the following syntax:

```ruby
<name>'('<arguments>')'
```
In the code above, `<name>` is the name of the macro to invoke and `<arguments>` is a comma-separated list of strings where `\` is used as escape character. If the are no arguments, the parenthesis can be omitted.

*NB*: any character of a string argument is taken into account literally. For instance, its possible to have an argument consisting only of spaces.

An invocation of a macro will only be recognized if the name is not included in a larger identifier. For instance, assuming that the macro named `foo` has been defined, it will be recognized and expanded in `foo bar` but not in `foobar` nor in `barfoo`. In order to recognize macros within larger keywords, the glue operator (`##`) must be used as follows:

```
<name>##<text>
<text>##<name>
<text0>##<name>##<text1>
```

In each of the above three cases, `<name>` is the name of a macro to invoke, `<text>`, `<text0>`, `<text1>` are some text to be glued to the macro expansion result. When preprocessed, macro `<name>` will be recognized and expanded, and the glue operators will be removed.

When the `##` are to be displayed just before or after a macro invocation, they are to be escaped using the `\` character as follows:

```text
<name>\##<text>
<text>\##<name>
<text0>\##<name>\##<text1>
```
   

### Examples

* __.do__ example:
  ```ruby
  Example 1:
  .do
     :< "Hello world!"
  .end
  ```
  Is expanded to:
  ```text
  Example 1:
  Hello world!
  ```

* __.def__ example:
  ```ruby
  Example 2:
  .def hello(world)
     :< "Hello #{world}!"
  .end
  hello(Foo)
  hello( Bar )
  ```
  Is expanded to:
  ```text
  Example 2:
  Hello Foo!
  Hello  Bar !
  ```
* __.doR__ example:
  ```ruby
  Example 3:
  .def hello(world) :< "Hello #{world}!"
  .doR
     :< "hello(WORLD)"
  .end
  ```
  Is expanded to:
  ```text
  Example 3:
  Hello WORLD!
  ```
* __.defR__ example:
  ```ruby
  Example 4:
  .defR sum(num)
     num = num.to_i
     if num > 2 then
        :< "(+ sum(#{num-1}) #{num} )"
     else
        :< "(+ 1 2 )"
     end
  .end
  Some lisp: sum(5)
  ```
  Is expanded to:
  ```text
  Example 4:
  Some lisp: (+ (+ (+ (+ 1 2 ) 3 ) 4 ) 5 )
  ```
* __.assign__ example:
  ```ruby
  Example 5:
  .assign he :< "Hello"
  .do :< @he + " world!\n"
  .def hehe :< @he+@he
  hehe
  ```
  Is expanded to:
  ```text
  Example 5:
  Hello world!
  HelloHello
  ```
* __.load__ example:
  assuming the content of the file named `foo.inc` is `foo and bar`
  ```ruby
  Example 6:
  .load :< "foo.inc"
  .def foo :< "FooO"
  .load :< "foo.inc"
  ```
  Is expanded to:
  ```text
  Example 6:
  foo and bar
  FooO and bar
  ```
* __.require__ example:
  assuming the content of the file named `foo.inc` is `foo and bar`
  ```ruby
  Example 7:
  .require :< "foo.inc"
  .def foo :< "FooO"
  .require :< "foo.inc"
  ```
  Is expanded to:
  ```text
  Example 7:
  foo and bar
  ```
* __.if__ example:
  ```ruby
  Example 8:
  .if :< (1 == 1)
  .def is :< "IS"
  This is true.
  .else
  This is false.
  .endif
  .if :< (1 == 0)
  This is really true.
  .else
  This is really false.
  .endif
  ```
  Is expanded to:
  ```text
  Example 8:
  This IS true.
  This IS really false.
  ```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/civol/ppr.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


## To do

* Add support to default value for arguments in the `.def` and `.defR` macros.
* Address some potential performance issues for the safer execution context of the macro.
* Improve the detection of errors when the `.if` macro is used.

## Acknowledgement

The sandbox used for executing the macros is inspired from *safe\_ruby* by Uku Taht available at https://github.com/ukutaht/safe\_ruby and https://rubygems.org/gems/safe_ruby/.
