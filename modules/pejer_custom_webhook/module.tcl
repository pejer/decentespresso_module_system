namespace eval ::decent_espresso::modules::pejer_custom_webhook {
	package require de1_modules 1.0
	package require rest
	package require uuid
	namespace import ::decent_espresso::modules::settings_set
	namespace import ::decent_espresso::modules::settings_get
}

# set up this module
proc ::decent_espresso::modules::pejer_custom_webhook::init {} {
	# Finally - lets call this hook at the appropriate time
	trace add execution save_this_espresso_to_history {leave} ::decent_espresso::modules::pejer_custom_webhook::action_shot
	trace add execution god_shot_save {leave} ::decent_espresso::modules::pejer_custom_webhook::action_god
}

proc ::decent_espresso::modules::pejer_custom_webhook::install {} {
	settings_set [namespace current] "action_shot_last_shot" ""
}

proc ::decent_espresso::modules::pejer_custom_webhook::uninstall {} {
	trace remove execution save_this_espresso_to_history {leave} ::decent_espresso::modules::pejer_custom_webhook::action_shot
	trace remove execution god_shot_save {leave} ::decent_espresso::modules::pejer_custom_webhook::action_god
}

# Info about this module
proc ::decent_espresso::modules::pejer_custom_webhook::info {} {
	set info [dict create]
	dict append info "title" "Custom Webhook"
	dict append info "description" "For certain actions, this will send a GET-request with a JSON-body of data that you then can parse"
	set uuid [::uuid::uuid generate]
	dict append info "settings" [list url "http://127.0.0.1" token [::uuid::uuid generate] ]
	return $info
}

proc ::decent_espresso::modules::pejer_custom_webhook::settings_saved {} {
}


proc ::decent_espresso::modules::pejer_custom_webhook::action_god {command-string code result op} {
	set data [dict create]
	lappend data clock [clock seconds]
    lappend data god_espresso_pressure [::espresso_pressure range 0 end]
    lappend data god_espresso_temperature_basket [::espresso_temperature_basket range 0 end]
    lappend data god_espresso_flow [::espresso_flow range 0 end]
    lappend data god_espresso_flow_weight [::espresso_flow_weight range 0 end]
    lappend data god_espresso_elapsed [::espresso_elapsed range 0 end]
    lappend data god_espresso_flow [::espresso_flow range 0 end]
    lappend data god_espresso_flow_weight [::espresso_flow_weight range 0 end]
	
	set requestdata [dict create]
	lappend requestdata type "god"
	lappend requestdata data $data

	set jsondata [compile_json {dict type string data {dict clock string god_espresso_pressure list god_espresso_temperature_basket list god_espresso_flow list god_espresso_flow_weight list god_espresso_elapsed list god_espresso_flow list god_espresso_flow_weight list} * dict} $requestdata]

	catch {
		set url [settings_get [namespace current] "url"]
		
		set headers [dict create]
		set reqToken [dict create]

		lappend reqToken Token [settings_get [namespace current] "token"]
		lappend headers "headers" $reqToken

		set res [rest::get $url [] $headers $jsondata]
	}	
}


proc ::decent_espresso::modules::pejer_custom_webhook::action_shot {command-string code result op} {
	set dirs [lsort -dictionary [glob -tails -directory "[homedir]/history/" *.shot]]
	set file [lrange $dirs end end]
	if {[settings_get [namespace current] "action_shot_last_shot"] != $file} {
		# Read it
		set hookdata [read_file "history/$file"]
		dict unset hookdata machine cmdstack

		# Convert it to json
		set shotdata [dict create]
		lappend shotdata type "shot"
		lappend shotdata data $hookdata
		
		set jsondata [compile_json {dict type string data {dict clock string espresso_elapsed list espresso_pressure list espresso_weight list espresso_flow list espresso_flow_weight list espresso_temperature_basket list espresso_temperature_mix list settings {dict advanced_shot {list dict}} machine {dict version {dict} cmdstack {list dict}}} * dict} $shotdata]

		# send it to the active service
		catch {
			set url [settings_get [namespace current] "url"]
			
			set headers [dict create]
			set reqToken [dict create]

			lappend reqToken Token [settings_get [namespace current] "token"]
			lappend headers "headers" $reqToken

			set res [rest::get $url [] $headers $jsondata]
		}
		settings_set [namespace current] "action_shot_last_shot" $file	
	}
}
