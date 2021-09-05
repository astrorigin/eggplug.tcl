# ================================
# EggPlug - Eggdrop Plugin Manager
# ================================
#
# Requirements
# ============
#
# git
# signify-openbsd
#
# In your eggdrop.conf
# ====================
#
# source eggplug.tcl
# eggplug <git-url> [<signed> [<autoupdate> [<enabled>]]]
# ...
#
# <git-url>: a Git URL (e.g: https://github.com/astrorigin/woobie.tcl)
# <signed>: verify signature or abort (e.g: signed | unsigned | boolean)
# <autoupdate>: pull upstream changes (e.g: autoupdate | noupdate | boolean)
# <enabled>: dont ignore this repo (e.g: enabled | disabled | boolean)
#
# If not mentioned, signed=yes autoupdate=yes and enabled=yes.

namespace eval ::EggPlug {

variable version 0.0.0-dev

variable plugdir eggplug/plugins

proc param_signed { signed } {
    if {[string is boolean -strict $signed]} {
        return $signed
    } elseif {[string equal $signed unsigned]} {
        return 0
    }
    return 1
}

proc param_autoupdate { autoupdate } {
    if {[string is boolean -strict $autoupdate]} {
        return $autoupdate
    } elseif {![string equal $autoupdate autoupdate]} {
        return 0
    }
    return 1
}

proc param_enabled { enabled } {
    if {[string is boolean -strict $enabled]} {
        return $enabled
    } elseif {![string equal $enabled enabled]} {
        return 0
    }
    return 1
}

proc giturl2path { giturl } {
    variable plugdir
    if {[set idx [string first file:// $giturl]] == 0} {
        # local repo
        set path [string range $giturl 7 end]
        return "$plugdir/$path"
    }
    if {[set idx [string first :// $giturl]] != -1} {
        # contains ://
        set path [string range $giturl [expr {$idx + 3}] end]
        return "$plugdir/$path"
    }
    # likely local repo
    return "$plugdir/$giturl"
}

proc disable { dir reason } {
    if {[catch {exec echo "$reason" > "$dir/disable.flag" 2>@1} out]} {
        putlog "EggPlug: fatal error ($out) ($dir) ($reason)"
    } else {
        exec chmod 400 "$dir/disable.flag"
    }
}

proc checksig { dir } {
    if {[catch {exec signify-openbsd -V \
            -p "$dir/key.pub" \
            -x "$dir/git/main.sig" \
            -m "$dir/git/main.tcl"}]} {
        return 0
    }
    return 1
}

proc loadconfig { dir } {
    source "$dir/config.tcl"
    putlog "EggPlug: loaded $dir/config.tcl"
}

proc checkexist { ns varlist } {
    foreach v $varlist {
        if {![info exists [join [list $ns :: $v] {}]]} {
            return 0
        }
    }
    return 1
}

} ;# end namespace EggPlug


proc eggplug { giturl {signed 1} {autoupdate 1} {enabled 1} } {

    # pass if not enabled
    if {![::EggPlug::param_enabled $enabled]} {
        putlog "EggPlug: $giturl disabled, pass"
        return
    }

    set srcdir [::EggPlug::giturl2path $giturl]

    # pass if flagged
    if {[file exists "$srcdir/disable.flag"]} {
        putlog "EggPlug: $srcdir flagged, pass"
        return
    }

    # clone or pull from remote
    set out {}
    if {![file isdirectory "$srcdir/git"]} {
        # clone
        if {[catch {exec git clone $giturl "$srcdir/git" 2>@1} out]} {
            putlog "EggPlug: cant clone $giturl ($out)"
            return
        }
        if {[file exists "$srcdir/git/key.pub"]} {
            # store public key
            file copy "$srcdir/git/key.pub" $srcdir
            exec chmod 400 "$srcdir/key.pub"
            # check signature
            if {![::EggPlug::checksig $srcdir]} {
                ::EggPlug::disable $srcdir "not verified"
                putlog "EggPlug: $giturl not verified, flagged"
                return
            }
        } elseif {[::EggPlug::param_signed $signed]} {
            # unsigned not allowed
            ::EggPlug::disable $srcdir "unsigned"
            putlog "EggPlug: $giturl unsigned, flagged"
            return
        }
    } elseif {[::EggPlug::param_autoupdate $autoupdate]} {
        # pull changes
        set here [pwd]
        if {[catch {cd "$srcdir/git"}]} {
            ::EggPlug::disable $srcdir "cant cd into $srcdir/git"
            putlog "EggPlug: cant cd into $srcdir/git, flagged"
            return
        }
        set res [catch {exec git pull 2>@1} out]
        cd $here
        if {$res} {
            putlog "EggPlug: cant pull from $giturl ($out)"
            return
        }
        if {[file exists "$srcdir/key.pub"]} {
            # check signature
            if {![::EggPlug::checksig $srcdir]} {
                ::EggPlug::disable $srcdir "not verified"
                putlog "EggPlug: $giturl not verified, flagged"
                return
            }
        } elseif {[::EggPlug::param_signed $signed]} {
            # public key missing
            ::EggPlug::disable $srcdir "missing public key"
            putlog "EggPlug: $srcdir missing public key, flagged"
            return
        }
    }
    if {![string is space $out]} {
        set lines [split [string trim $out] \n]
        putlog "EggPlug: $giturl -> $srcdir/git:"
        foreach line $lines {
            putlog "EggPlug: $line"
        }
    }

    # load config file
    if {[file exists "$srcdir/config.tcl"]} {
        ::EggPlug::loadconfig $srcdir
    } elseif {[file exists "$srcdir/git/config.tcl"]} {
        file copy "$srcdir/git/config.tcl" $srcdir
        ::EggPlug::loadconfig $srcdir
    }

    # load the script itself
    if {![file exists "$srcdir/git/main.tcl"]} {
        ::EggPlug::disable $srcdir "missing main.tcl"
        putlog "EggPlug: $srcdir/git missing main.tcl, flagged"
        return
    }
    source "$srcdir/git/main.tcl"
}

putlog "Loaded EggPlug v$::EggPlug::version"

# vi: set sw=4 ts=4 et
