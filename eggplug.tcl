# EggPlug - Eggdrop Plugin Manager

namespace eval ::EggPlug {

variable version 0.0.0

variable plugdir eggplug/plugins

proc giturl2path { giturl } {
    variable plugdir
    set giturl [string tolower $giturl]
    if {[set idx [string first :// $giturl]] == -1} {
        return "$plugdir/$giturl"
    }
    set path [string range $giturl [expr {$idx + 3}] end]
    return "$plugdir/$path"
}

proc checkexist { ns varlist } {
    foreach v $varlist {
        if {[llength [info vars [join [list $ns :: $v] {}]]] == 0} {
            return 0
        }
    }
    return 1
}

} ;# end namespace EggPlug


proc eggplug { giturl {enabled 1} } {

    if {!$enabled} { return }

    set srcdir [::EggPlug::giturl2path $giturl]

    # clone or pull from remote
    if {![file isdirectory "$srcdir/git"]} {
        set out [exec git clone --depth=1 $giturl "$srcdir/git" 2>@1]
    } else {
        set here [pwd]
        cd "$srcdir/git"
        set out [exec git pull 2>@1]
        cd $here
    }
    set out [string trim $out]
    putlog "EggPlug: $giturl -> $srcdir/git:\n$out"

    # load config file
    if {[file exists "$srcdir/config.tcl"]} {
        source "$srcdir/config.tcl"
        putlog "EggPlug: loaded $srcdir/config.tcl"
    } elseif {[file exists "$srcdir/git/config.tcl"]} {
        file copy "$srcdir/git/config.tcl" $srcdir
        source "$srcdir/config.tcl"
        putlog "EggPlug: loaded $srcdir/config.tcl"
    }

    # load the script itself
    source "$srcdir/git/main.tcl"
}

putlog "Loaded EggPlug v$::EggPlug::version"

# vi: set sw=4 ts=4 et
