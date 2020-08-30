package provide de1_modules 1.0

namespace eval decent_espresso::modules {
	namespace export settings_set
	namespace export settings_get
	::load_settings
	# set up neede vars
	if {[info exists ::settings(modules_installed)] != 1} {
		set ::settings(modules_installed) [list]
	}
	if {[info exists ::settings(modules_enabled)] != 1} {
		set ::settings(modules_enabled) [list]
	}
	::save_settings
	
	variable sourced_modules [list]
}

# can we handle the saving of settings with this?
proc ::decent_espresso::modules::settings_set { module name value } {
	set ::settings([::decent_espresso::modules::settings_create_key $module $name]) $value
	::save_settings
}


proc ::decent_espresso::modules::settings_get { module name } {
	if {[ifexists ::settings([::decent_espresso::modules::settings_create_key $module $name])] == ""} {
		return ""
	}
	return $::settings([::decent_espresso::modules::settings_create_key $module $name])
}

proc ::decent_espresso::modules::settings_create_key { module name } {
	return "module_storage${module}::${name}"
}

proc modules_load_enabled {} {
	foreach {module} $::settings(modules_enabled) {
		module_init $module
	}
}

proc module_install { name } {
	set modules_installed $::settings(modules_installed)
	if {[module_is_installed $name] == 0} {
		module_load_module $name
		eval "::decent_espresso::modules::${name}::install"
		lappend modules_installed $name
		set ::settings(modules_installed) $modules_installed
	}
	::save_settings
}

# how to handle removing something from this list... its _complicated_ :p
proc module_uninstall { name } {
	if {[module_is_installed $name] == 1} {
		if {[llength $::settings(modules_installed)] == 1} {
			set ::settings(modules_installed) [list]
		} else {
			set modules_installed $::settings(modules_installed)
		    set idx [lsearch -exact $modules_installed $name]
		    set modules_installed [lreplace $modules_installed $idx $idx]
			set ::settings(modules_installed) $modules_installed
		}
		if {[llength $::settings(modules_enabled)] == 1} {
			set ::settings(modules_enabled) [list]
		} else {
			set modules_enabled $::settings(modules_enabled)
		    set idx [lsearch -exact $modules_enabled $name]
		    set modules_enabled [lreplace $modules_enabled $idx $idx]
			set ::settings(modules_enabled) $modules_enabled
		}
		module_remove_settings_for_module $name
		eval "::decent_espresso::modules::${name}::uninstall"
	}
	::save_settings
}

proc module_remove_settings_for_module { name } {
	array unset ::settings "module_storage::decent_espresso::modules::${name}::*"
}

proc module_is_installed { name } {
	set modules_installed $::settings(modules_installed)
	if {[lsearch $modules_installed $name] == -1} {
		return 0
	} else {
		return 1
	}
}

proc module_init { name } {
	module_load_module $name
	eval "::decent_espresso::modules::${name}::init"
}

proc module_enable { name } {
	set modules_enabled $::settings(modules_enabled)
	if {[lsearch $modules_enabled $name] == -1} {
		lappend modules_enabled $name
		set ::settings(modules_enabled) $modules_enabled
		::save_settings
	}
}

proc module_load_module { name } {
	if {[lsearch $::decent_espresso::modules::sourced_modules $name] == -1} {
		source [file join "./modules/${name}/module.tcl"]
		lappend ::decent_espresso::modules::sourced_modules $name
	}
}

proc module_get_module_info { name } {
	module_load_module $name 
	set modinfo [eval "::decent_espresso::modules::${name}::info"]
	return $modinfo
}
# Dude! This is probably not the best place for this,
# but lets keep it here, at the moment.
proc compile_json {spec data} {
    while [llength $spec] {
        set type [lindex $spec 0]
        set spec [lrange $spec 1 end]

        switch -- $type {
            dict {
                lappend spec * string

                set json {}
                foreach {key val} $data {
                    foreach {keymatch valtype} $spec {
                        if {[string match $keymatch $key]} {
                            lappend json [subst {"$key":[
                                compile_json $valtype $val]}]
                            break
                        }
                    }
                }
                return "{[join $json ,]}"
            }
            list {
                if {![llength $spec]} {
                    set spec string
                } else {
                    set spec [lindex $spec 0]
                }
                set json {}
                foreach {val} $data {
                    lappend json [compile_json $spec $val]
                }
                return "\[[join $json ,]\]"
            }
            string {
                if {[string is double -strict $data]} {
                    return $data
                } else {
                    return "\"$data\""
                }
            }
            default {error "Invalid type"}
        }
    }
}


proc url-decode str {
    # rewrite "+" back to space
    # protect \ from quoting another '\'
    set str [string map [list + { } "\\" "\\\\"] $str]

    # prepare to process all %-escapes
    regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1} str

    # process \u unicode mapped chars
    return [subst -novar -nocommand $str]
}


# procedures regarding gui

proc module_list_modules_listbox {} {
	set widget $::globals(module_list_listbox)
	$widget delete 0 99999

	set cnt 0
	set ::current_skin_number 0
	foreach d [modules_directories_list] {
		
		$widget insert $cnt [translate $d]
		incr cnt
	}
	
	set ::current_module_list_selection 0
	$widget selection set $::current_module_list_selection
}


proc modules_directories_list {} {
	if {[info exists ::modules_directories_cache] == 1} {
		return $::modules_directories_cache
	}
	set dirs [lsort -dictionary [glob -tails -directory "[homedir]/modules/" *]]
	#puts "skin_directories: $dirs"
	set dd {}
	set de1plus [de1plus]
	foreach d $dirs {
		lappend dd $d		
	}
	set ::modules_directories_cache [lsort -dictionary -increasing $dd]
	return $::modules_directories_cache
}

array set ::module_info {
	title {Select module}
	description {}
	installed 0
	settings {}
	install_button_text "Install"
}

proc modules_module_info_reset {} {
	array set ::module_info {
		title {Select module}
		description {}
		installed 0
		settings {}
		install_button_text "Install"
	}
}

proc modules_module_info { {data_type "0"} } {
	if {$::de1(current_context) != "settings_5"} {
		return 
	}

	set w $::globals(module_list_listbox)
	if {[$w curselection] == ""} {
		$w selection set $::current_module_list_selection
	}
	
	set selected_module [lindex [modules_directories_list] [$w curselection]]
	# lets load info about the module and display that!
	set module_info [module_get_module_info $selected_module]
	set ::module_info(title) [dict get $module_info title]
	set ::module_info(description) [dict get $module_info description]
	if {[module_is_installed $selected_module] == 0} {
		set ::module_info(installed) 0
		set ::module_info(install_button_text) "Install"
	} else {
		set ::module_info(installed) 1
		set ::module_info(install_button_text) "Uninstall"	
	}
		
	set module_settings ""
	# parse them settings before we do anything with them
	foreach {key value} [dict get $module_info settings] {
		if {[::decent_espresso::modules::settings_get ::decent_espresso::modules::$selected_module $key] != ""} {
			set value [::decent_espresso::modules::settings_get ::decent_espresso::modules::${selected_module} ${key}]
		}
		append module_settings "$key $value\n"
	}
	
	set ::module_info(settings) $module_settings
		
	update_onscreen_variables
	if { $data_type != "0"} {
		return $::module_info($data_type)
	}
}

proc module_install_button_action {} {
	set w $::globals(module_list_listbox)
	if {[$w curselection] == ""} {
		$w selection set $::current_module_list_selection
	}
	
	set selected_module [lindex [modules_directories_list] [$w curselection]]
	# if module is _not_ installed - install it!
	if {[module_is_installed $selected_module] == 0} {
		module_install $selected_module
		module_init $selected_module
		module_enable $selected_module
		module_save_button_action
	} else {
		module_uninstall $selected_module
	}
	::save_settings
	modules_module_info
}

proc module_save_button_action {} {
	set w $::globals(module_list_listbox)
	if {[$w curselection] == ""} {
		$w selection set $::current_module_list_selection
	}
	
	set selected_module [lindex [modules_directories_list] [$w curselection]]
	set lines [split [string trim $::module_info(settings) " \n"] "\n"]
	foreach line $lines {
		set key [string trim [string range $line 0 [string first " " $line] ] " "]
		set value [string trim [string range $line [string first " " $line] 99999] " "]	
		::decent_espresso::modules::settings_set "::decent_espresso::modules::$selected_module" $key $value		
	}
	eval "::decent_espresso::modules::${selected_module}::settings_saved"
	modules_module_info
}
modules_load_enabled