## 2.2

* Method call

Just need to add define_method and define_singleton_method.

Singleton_method is for mostly class methods but also object-specific
methods [weird].

Only difference on C side is to stash the singleton_class for 'target'
and use singleton_class instead of class on the 'self'.
We expect the 'self' to be the actual object / the class object.  But the
lookup must go through the singleton hierarchy.

Key test is that a class method and an instance method do not alias.

Probably nix that entire cache thing - too tricksy.

TODO
* Doc comment for define_method
* Write test for inheritance case
* On to singleton stuff
* Refactor all the C-side code.
* Example/docs (but really want to do in context of custom objects)

* Swift implementations of classes

define_class - name [parse ::s?]
             - inherits_from [default Object]
             - under [default nil]

define_module - name [parse ::s?]
              - under [default nil]

include_module - add module methods to a class, ancestors class->module
prepend_module - add module methods to a class, ancestors module->class

extend_object - add module methods to the singleton class of an object
                FFS.  Usually the 'object' is a class, and this means
                'add the class methods of a module to the class methods
                 of this thing'
                So you would do
                myClass = define_class("My")
                myClass.include(module: someModule) // get instance stuff
                myClass.extend(module: someModule) // get class stuff
                === myClass.singleton_class.include(module: someModule)



## Other

Optimize GC interaction

Crashiness
* Policy or something to avoid crashes in operators

Dynamic callable -- will need to write the Swift patch myself though...
