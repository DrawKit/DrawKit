Building the Site
=================

This web site is built using a collection of open source tools.

Install Homebrew
----------------

Homebrew_ is a package manager for Mac OS X. With Homebrew installed getting the required tools onto your Mac is much easier.

.. _Homebrew: http://brew.sh

To install Homebrew run this command in your Terminal.app ::

  ruby -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go)"

Install the Tools
-----------------

With Homebrew installed, get the following tools ::
  
  brew install doxygen
  brew install graphviz
  pip install sphinx
  pip install breathe

doxygen_
  doxygen extracts the documentation from the source code and turns it into browsable content.

graphviz_
  graphviz is used by doxygen and sphinx to create diagrams. The class hierarchy diagrams are create by the graphviz tool dot.

sphinx_
  sphinx turns the documentation you are reading now into a collection of web pages. The documentation is written in  reStructuredText_ so it can be transformed into various useful formats for distribution, including this web site.

breathe_
  breathe provides a link between sphinx and doxygen. Sphinx was built for the python language and it does not parse Objective-C. doxygen does parse Objective-C and breath lets sphinx stand on the shoulders of doxygen.

.. _doxygen: http://www.doxygen.org
.. _graphviz: http://www.graphviz.org
.. _sphinx: http://sphinx-doc.org
.. _reStructuredText: http://docutils.sourceforge.net/rst.html
.. _breathe: https://github.com/michaeljones/breathe

Building
--------

With all the tools installed, you can build the document with the commands ::

  cd documentation
  make html

Building will take a few moments and the output will appear in the _build folder. The _build/html/ folder is published to the `DrawKit web site`__.

.. __: http://drawkit.github.io

.. note::
  A `.nojekyll` file is needed to allow github.io to `serve contents from folders beginning with underscore`__ (_).
.. __: https://help.github.com/articles/files-that-start-with-an-underscore-are-missing

.. http://docutils.sourceforge.net/docs/user/rst/quickref.html
.. https://github.com/mitsuhiko/flask-sphinx-themes