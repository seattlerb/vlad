Vlad the Deployer
    by the Ruby Hit Squad
    http://rubyhitsquad.com/
    http://rubyforge.org/projects/hitsquad/

== DESCRIPTION:
  
Vlad the Deployer is pragmatic application deployment automation,
without mercy. Much like Capistrano, but with 1/10th the
complexity. Vlad integrates seamlessly with Rake, and uses familiar
and standard tools like ssh and rsync.

Impale your application on the heartless spike of the Deployer.

== FEATURES/PROBLEMS:
  
* Full deployment automation stack.
* Supports single server deployment with just 4 variables defined.
* Very few dependencies. All simple.
* Uses ssh with your ssh settings already in place.
* Uses rsync for efficient transfers.
* Run remote commands on one or more servers.
* Syncs files to one or more servers.
* Mix and match local and remote tasks.
* Built on rake. easy.
* Compatible with all of your tab completion shell script rake-tastic goodness.
* Ships with tests that actually pass.
* Engine is under 500 lines of code.
* Super uper simple.
* Does NOT support Windows right now. Coming soon in 1.1.


== SYNOPSIS:

    rake vlad:setup   # first time only
    rake vlad:update
    rake vlad:migrate # optional
    rake vlad:start

== REQUIREMENTS:

* Rake
* Hoe
* Rubyforge
* open4

== INSTALL:

* sudo gem install -y vlad

== SPECIAL THANKS:

* First, of course, to Capistrano. For coming up with the idea and
  providing a lot of meat for the recipes.
* Scott Baron for coming up with one of the best project names evar.
* Bradley Taylor for giving us permission to use RailsMachine recipes sans-LGPL.

== LICENSE:

(The MIT License)

Copyright (c) 2007 Ryan Davis and the rest of the Ruby Hit Squad

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
