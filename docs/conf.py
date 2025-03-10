# Configuration file for the Sphinx documentation builder.
#
# This file only contains a selection of the most common options. For a full
# list see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Path setup --------------------------------------------------------------

# If extensions (or modules to document with autodoc) are in another directory,
# add these directories to sys.path here. If the directory is relative to the
# documentation root, use os.path.abspath to make it absolute, like shown here.
#
import os
import sphinx
import sys
import sphinx_rtd_theme
import datetime
import json

with open('package_info.json') as f:
  package_info = json.load(f)
# -- Project information -----------------------------------------------------

project = package_info["name"]
copyright = str(datetime.datetime.now().year)+', '+package_info["author"]
author = package_info["author"]

# The full version, including alpha/beta/rc tags
release = package_info["version"]


# -- General configuration ---------------------------------------------------

# Add any Sphinx extension module names here, as strings. They can be
# extensions coming with Sphinx (named 'sphinx.ext.*') or your custom
# ones.
extensions = [
    'sphinx.ext.mathjax',
    'sphinx.ext.githubpages',
    'sphinx_rtd_theme',
    'sphinx.ext.napoleon',
    'myst_parser',
    'sphinx_design'
]

# Add any paths that contain templates here, relative to this directory.
templates_path = ['_templates']

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = []


# -- Options for HTML output -------------------------------------------------

# The theme to use for HTML and HTML Help pages.  See the documentation for
# a list of builtin themes.
#
html_theme = 'sphinx_rtd_theme'

# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".
html_static_path = ['_static']
html_css_files = ['custom.css']

# -- Extension configuration -------------------------------------------------
html_show_sourcelink = False
html_logo = "img/SuperSONIC_light.png"

html_theme_options = {
    'canonical_url': '',
    'analytics_id': '',  #  Provided by Google in your dashboard
    'logo_only': True,
    'prev_next_buttons_location': 'bottom',
    'style_external_links': False,
    'style_nav_header_background': '#2980B9',
    # Toc options
    'collapse_navigation': True,
    'sticky_navigation': True,
    'navigation_depth': 2,
    'includehidden': True,
    'titles_only': False,
    # Dark mode settings
    'style_switcher': True,
    'dark_mode_theme': 'dark',
}

html_context = {
    'display_github': True,  # Integrate GitHub
    'github_user': 'fastmachinelearning',  # Username
    'github_repo': "SuperSONIC",  # Repo name
    'github_version': 'main',  # Version
    'conf_py_path': '/docs/',  # Path in the checkout to the docs root
}
html_favicon = 'img/SuperSONIC_small.svg'