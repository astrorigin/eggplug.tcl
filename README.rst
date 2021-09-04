================================
EggPlug - Eggdrop Plugin Manager
================================

**EggPlug** is a tool for users of the Eggdrop IRC robot. It automates the
tasks of downloading, installing and updating third-party scripts found on
the internet, and hosted in public Git repositories.

At the end of your eggdrop configuration file, where you would usually
list and *source* all the scripts you want to load, you do this::

    # Just load the plugin manager
    source eggplug.tcl
    # Then, download, update and start the following scripts
    eggplug https://github.com/astrorigin/woobie.tcl

Done.

..
