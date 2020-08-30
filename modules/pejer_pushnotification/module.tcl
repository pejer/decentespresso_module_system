namespace eval ::decent_espresso::modules::pejer_pushnotification {
	package require de1_modules 1.0
	package require rest
	package require tls
	http::register https 443 ::tls::socket
	namespace import ::decent_espresso::modules::settings_set
	namespace import ::decent_espresso::modules::settings_get
	
	variable previous_state 0
	variable previous_espresso_ready 0
	
}

# 	The procedure returns info about it
# 	Put the title, description and settings the user can change
# 	along with default values for them, here.
proc ::decent_espresso::modules::pejer_pushnotification::info {} {
	set info [dict create]
	dict append info "title" "Push notifications"
	dict append info "description" "This module provides push notifications"
	dict append info "settings" [list apikey "" notification_service "prowl" application "" actions {start sleep ready}]
	return $info
}
#	This runs only when the module is installed. If there is something
#	that needs to be set up once for this module to work properly
#	this is where you do that.
proc ::decent_espresso::modules::pejer_pushnotification::install {} {
	#trace add execution god_shot_save {leave} ::decent_espresso::modules::pejer_twitter::action_god
}

proc ::decent_espresso::modules::pejer_pushnotification::init {} {
	# Lets listen to the state variable and look for changes!
	trace add execution update_de1_state {leave} ::decent_espresso::modules::pejer_pushnotification::state_change	
	set ::decent_espresso::modules::pejer_pushnotification::previous_state $::de1_num_state($::de1(state))
	set ::decent_espresso::modules::pejer_pushnotification::previous_espresso_ready $::de1_substate_types($::de1(substate))
}

#	When the user chooses to uninstall the module, this procedure
#	is called. Here you remove things you've set up, like trace etc,
# 	that shouldn't be stored or used, once the module is removed.
proc ::decent_espresso::modules::pejer_pushnotification::uninstall {} {
	trace remove execution update_de1_state {leave} ::decent_espresso::modules::pejer_pushnotification::state_change	
}

proc ::decent_espresso::modules::pejer_pushnotification::settings_saved {} {
}

proc ::decent_espresso::modules::pejer_pushnotification::state_change {command-string code result op} {
	# compare with 
	set transition "$::decent_espresso::modules::pejer_pushnotification::previous_state => $result"
	switch -- $transition {
		"Sleep => Idle" {
			if {[::decent_espresso::modules::pejer_pushnotification::should_trigger "start"] != 1} {
				return;
			}
			::decent_espresso::modules::pejer_pushnotification::send_notification "ON"
			if {[::decent_espresso::modules::pejer_pushnotification::should_trigger "ready"] == 1} {
				# trace the temp
				trace add execution start_text_if_espresso_ready {leave} ::decent_espresso::modules::pejer_pushnotification::espresso_ready
			}
		}
		"GoingToSleep => Sleep" {
			if {[::decent_espresso::modules::pejer_pushnotification::should_trigger "sleep"] != 1} {
				return;
			}
			::decent_espresso::modules::pejer_pushnotification::send_notification "OFF"
			trace remove execution start_text_if_espresso_ready {leave} ::decent_espresso::modules::pejer_pushnotification::espresso_ready
		}
	}
	set ::decent_espresso::modules::pejer_pushnotification::previous_state $::de1_num_state($::de1(state))
}

proc ::decent_espresso::modules::pejer_pushnotification::send_notification {message} {
	set qparams [::decent_espresso::modules::pejer_pushnotification::api_params $message]
	::rest::simple [dict get $qparams url] [dict get $qparams params] {dict create method "post"}
}

proc ::decent_espresso::modules::pejer_pushnotification::api_params {message} {
	set params [dict create]
	
	set service [settings_get [namespace current] "notification_service"]
	
	switch -- $service {
		"prowl" {
			set url "https://api.prowlapp.com/publicapi/add"
			dict append params "apikey" [settings_get [namespace current] "apikey"]
			dict append params "application" [settings_get [namespace current] "application"]
			dict append params "event" $message
		}
	}
	return [dict create "url" $url "params" $params]
}

proc ::decent_espresso::modules::pejer_pushnotification::espresso_ready {command-string code result op} {
	if {$result == "START" && [::decent_espresso::modules::pejer_pushnotification::should_trigger "ready"] == 1} {
		trace remove execution start_text_if_espresso_ready {leave} ::decent_espresso::modules::pejer_pushnotification::espresso_ready	
		::decent_espresso::modules::pejer_pushnotification::send_notification "READY"
	}
}

proc ::decent_espresso::modules::pejer_pushnotification::should_trigger {action_to_trigger} {
	set ret 0
	if {[lsearch [settings_get [namespace current] actions] $action_to_trigger] >= 0} {
		set ret 1
	}
	return $ret
}