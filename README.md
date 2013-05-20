Instrumentator
==============
This is my take on the [NewRelic ruby metaprogramming coding challenge](https://gist.github.com/samg/5b287544800f8a6cddf2).To illustrate it's working properly, I found this [test suite](https://gist.github.com/samg/6ea0a0ba5702824075ab) here.

General Approach
----------------
It seems that 'alias_method_chaining' with instrumentation to count the call counts makes the most sense. This is easy for standard lib classes that are already defined before the inclusion of the instrumentation. The trick is, instrumenting classes that are defined after the instrumentation is included. To instrument those, we need to take advantage of Ruby's hooks for things like:
* Module#included
* Module#prepended (Ruby 2.0)
* Module#extended
* Class#inherited
* Module#method_added
* BasicObject#singleton_method_added

This effectively gives us all the notification that something has been added that we might need to instrument.

Supported Ruby versions
-----------------------
* PASSED ruby-2.0.0-p195
* PASSED ruby-2.0.0-p0
* PASSED ruby-1.9.3-p362
* PASSED ruby-1.9.3-p327
* PASSED ruby-1.9.3-p194

Noted differences in Ruby versions
----------------------------------
* Speed: Ruby 2.0 seems to be significantly faster than 1.9
* Ruby 2.0 supports Module.prepend which is like Module.include, except the Module methods is called before the prepended Class
* Ruby 2.0 Module.const_get supports A::B syntax where 1.9 does not

TODO items
----------
- I have not figured out how to gracefully support 'test_integer_addition'. I know I could do something hacky like save the original Fixnum#+ off before I install the instrumented one but that doesn't seem right.

      plus = Fixnum.instance_method(:+)
      plus.bind(@call_count).call(1)


