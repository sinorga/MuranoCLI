#########################
MuranoCLI Developer Guide
#########################

=========================
Introduction to MuranoCLI
=========================

Login example
-------------

Use MuranoCLI to logon for the first time.::

    $ murano login
    No Murano user account found; please login
    User name: user@domain.tld
    Couldn't find password for user@domain.tld
    Password: XXXX

MuranoCLI creates two files in your home directory.::

    $ cat ~/.murano/config 
    [user]
    name = user@domain.tld

    $ cat ~/.murano/passwords
    ---
    bizapi.hosted.exosite.io:
      user@domain.tld: "XXXXXXXXXXXXXXXX"

    $ murano login --show-token
    XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

Create a business
-----------------

FIXME: Show the ``murano init`` command.

Work on a business
------------------

View a list of businesses you've created.::

    $ murano business list
    +------------------+-------+--------------------+
    | bizid            | role  | name               |
    +------------------+-------+--------------------+
    | abcdef1234567890 | owner | Business Name      |
    | 1234567890abcdef | admin | ACME IoT           |
    +------------------+-------+--------------------+

Pick a business to work on.::

    # From the `murano business list` list:
    $ murano config business.id abcdef1234567890

MuranoCLI will remember the business you've chosen.::

    $ cat /exo/clients/exosite/.murano/config
    [business]
    id = ct7rmoz3hu34ygb9

MuranoCLI options
-----------------

To see all options that MuranoCLI *really* supports, make a dump.

.. code-block:: bash

    $ murano config --dump

    [tool]
    verbose = false
    debug = false
    ...

============================
Developer Setup Instructions
============================

Fork and clone the project
--------------------------

Fork the project into your account. Visit:

https://github.com/exosite/MuranoCLI.git

After forking, clone your repo and set its upstream.

NOTE: This guide assumes you are working out of the directory,
``/exo/clients/exosite``.

.. code-block:: bash

    cd /exo/clients/exosite

    git clone git@github.com:{username}/MuranoCLI.git

    cd MuranoCLI

    git remote add upstream git@github.com:exosite/MuranoCLI.git
    # Add other developers' repos. E.g.,
    git remote add tadpol git@github.com:tadpol/MuranoCLI.git
    git remote add landonb git@github.com:landonb/MuranoCLI.git

Checkout a branch
-----------------

Checkout an existing branch...

.. code-block:: bash

    git checkout feature/ticket_name_and_number

... or create a new branch.

.. code-block:: bash

    # Create a new topic branch.
    git checkout -b feature/totally_awesome
    # Push the new topic branch and setup remote tracking [-u].
    git push -u origin feature/totally_awesome

Rebase when merging co-workers' changes
---------------------------------------

While working on your branch, you'll want to periodically grab
changes from other folks. So long as you're the only one working
on your branch, rebase your work to keep the git history sane.

.. code-block:: bash

    git fetch upstream
    git checkout feature/murcli
    git rebase upstream/feature/okami
    git push origin feature/murcli

NOTE: Do not rebase onto a branch being actively worked on by
other people, like ``master`` or ``develop``, or you'll screw
up everybody's histories and force people to clone anew.

Beware of Ruby Version Management
---------------------------------

To build and run the code, you might be able to run whatever
ruby is currently installed. But you'll probably eventually
run into problems with different ruby projects using different
versions of different libraries. So you'll probably want to
use a ruby version manager, such as
`Ruby Version Manager <https://rvm.io/>`__,
or `chruby <https://github.com/postmodern/chruby>`__
or `rbenv <https://github.com/rbenv/rbenv>`__.

- If you're having problems building or running MuranoCLI,
  ``gem env`` is a good way to see how the ruby environment
  variables are set.

  - One important setting to check is the gem directory.
    This should be somewhere writable by your user, like $HOME.
    E.g.,

    ``$ ruby -rubygems -e 'puts Gem.user_dir'``

    ``/home/user/.gem/ruby/2.3.0``

  - Other interesting environs:

    ``GEM_HOME``, ``GEM_PATH``, and ``GEM_ROOT``.

Example ``chruby`` usage
^^^^^^^^^^^^^^^^^^^^^^^^

If you use ``chruby``, tell it what version of ruby you want:

.. code-block:: bash

    cd /exo/clients/exosite/MuranoCLI
    echo "ruby-2.3" > .ruby-version

(You can also do this for ``rvm``, which recognizes the
same ``.ruby-version`` files.)

Now tell chruby to load the version of ruby you want:

.. code-block:: bash

    cd /exo/clients/exosite/MuranoCLI
    chruby $(cat .ruby-version)

Install dependencies
--------------------

To install the project, you'll need 
`bundler
<https://github.com/bundler/bundler>`__.

Run these commands once from any directory:

.. code-block:: bash

    gem install bundler

    gem install rspec

    gem install byebug

Prepare MuranoCLI
-----------------

Install the gems listed in the MuranoCLI Gemfile:

.. code-block:: bash

    cd /exo/clients/exosite/MuranoCLI
    bundle install --path $(ruby -rubygems -e 'puts Gem.dir') --with test

Build and Install MuranoCLI
---------------------------

Build and install the Gem locally to your local gem directory.

.. code-block:: bash

    cd /exo/clients/exosite/MuranoCLI

    rake build

    gem install \
        -i $(ruby -rubygems -e 'puts Gem.dir') \
        pkg/MuranoCLI-$( \
            ruby -e 'require "/exo/clients/exosite/MuranoCLI/lib/MrMurano/version.rb"; \
            puts MrMurano::VERSION').gem

Prepare to Test
---------------

Create Config File
^^^^^^^^^^^^^^^^^^

So the tests know what Business to use, setup a config file.

([lb] also likes to see what ``murano`` and ``curl`` calls happen,
so I enable ``curldebug`` and redirect the verbose output to a file,
``curlfile``.)

::

    [user]
    name = user@exosite.com

    [net]
    host = bizapi.hosted.exosite.io

    [business]
    id = xxxxxxxxxxxxxxxx

    [tool]
    #curldebug = false
    curldebug = true

    curlfile = "/exo/clients/exosite/MuranoCLI/curldebug.out"

Save the file outside the MuranoCLI repo, e.g., to
``/exo/clients/exosite/.murano.test``

Set Environs
^^^^^^^^^^^^

You'll need to setup a few environs first.

You could simply export the values explicitly::

    export MURANO_CONFIGFILE="/exo/clients/exosite/.murano.test"
    export MURANO_PASSWORD="XXXXXXXXXXXXXXXX"

Or you could do something fancier using MuranoCLI to find them, e.g.,::

    cat > test-murano.sh << EOF
    cat #!/bin/bash
    export MURANO_CONFIGFILE="$(pwd)/.murano.test"
    MURANO_USER=`murano password current`
    MURANO_HOST=`murano config net.host`
    export MURANO_PASSWORD=`ruby -ryaml -e "puts YAML.load_file(File.join(Dir.home,'.murano','passwords'))['$MURANO_HOST']['$MURANO_USER']"`
    echo "Testing using ${MURANO_USER}@${MURANO_HOST} with PWD ${MURANO_PASSWORD} and CFG ${MURANO_CONFIGFILE}"
    rspec "$@"
    EOF

    chmod 755 test-murano.sh
    ./test-murano.sh

Cleanup Solutions
^^^^^^^^^^^^^^^^^

Before running tests, or if tests are interrupted, delete all solutions
under your business.

.. code-block:: bash

    cd /exo/clients/exosite/MuranoCLI

    rake test_clean_up

Run Tests
---------

Run All Rspec Tests
^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    rspce

Run Single Rspec Test
^^^^^^^^^^^^^^^^^^^^^

E.g.,

.. code-block:: bash

    rspec ./spec/cmd_syncup_spec.rb

Run Tagged Rspec Test
^^^^^^^^^^^^^^^^^^^^^

The test might look like::

    it "status", :not_in_okami do

And running it would look like::

    rspec --tag '~not_in_okami' ./spec/cmd_syncup_spec.rb

Run Specific "Example" from Rspec Test
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Run just one test within a file.

The test file might look like::

    RSpec.describe 'murano status', :cmd, :needs_password do
      ...
      context "with ProjectFile" do
        ...
        it "status" do
            ...

And you could run just that test with::

    rspec ./spec/cmd_status_spec.rb -e "murano status with ProjectFile status"

Run All Tests and Capture Colorful Output to HTML
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    sudo apt-get install aha

    rspec --format html \
        --out report/index-$( \
            ruby -e 'require "/exo/clients/exosite/MuranoCLI/lib/MrMurano/version.rb"; \
            puts MrMurano::VERSION').html 
        --format documentation \
        --tag '~not_in_okami' \
    | aha --black > MuranoCLI.rspec.html

Rerun Failing Tests
^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    rspec --tag '~not_in_okami' --only-failures

Uninstall MuranoCLI
-------------------

E.g.,

.. code-block:: bash

    gem uninstall MuranoCLI --version 3.0.0.alpha.2

    gem uninstall MuranoCLI --version 2.2.4.alpha

