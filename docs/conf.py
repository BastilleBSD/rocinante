# -- Project information -----------------------------------------------------

project = 'Rocinante'
copyright = '2021-2025, Christer Edwards'
author = 'Christer Edwards'
release = '1.1.0.20251218'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = ['sphinx_rtd_theme','sphinx_rtd_dark_mode']

templates_path = ['templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output
html_theme = 'sphinx_rtd_theme'
html_static_path = ['static']
html_logo = 'static/rocinante.jpeg'
html_theme_options = {
    'collapse_navigation': True,
    'flyout_display': 'hidden',
    'includehidden': True,
    'language_selector': True,
    'logo_only': False,
    'navigation_depth': 4,
    'prev_next_buttons_location': 'bottom',
    'sticky_navigation': True,
    'style_external_links': False,
    'style_nav_header_background': 'white',
    'titles_only': False,
    'vcs_pageview_mode': '',
    'theme_switcher': True,
    'default_mode': 'auto',
    'version_selector': True,
}
