namespace eval ::decent_espresso::modules::pejer_web_api::api {

	proc list_profiles { } {
		return [compile_json {list} [profile_directories]]		
	}

	proc profile { {new_profile {0}}} {
		if {$new_profile != 0} {
			
			if {$::de1_num_state($::de1(state)) != "Idle"} {
				return "Not updating profile while machine is in state $::de1_num_state($::de1(state))"
			}
			
			# hm, get the list of profiles
			# figure out what number this is
			# set the current_profile_number to that *sneaky*
			# then preview/load the profile :p
			set profiles [profile_directories]
			if {[lsearch -exact $profiles $new_profile] == -1} {
				return "No profile by that name"
			}
			set ::current_profile_number [lsearch -exact $profiles $new_profile]
			set temp_current_context $::de1(current_context)
			set ::de1(current_context) "settings_1"
			preview_profile
			save_settings_to_de1
			save_settings
			profile_has_changed_set_colors
			set ::de1(current_context) $temp_current_context

			return "OK"
			#return "OK: $new_profile ( $::current_profile_number ) $profiles $new_profile $new_number [lindex $profiles 14]"
		}
		return $::settings(profile_filename)	
	}

	proc state { {new_state {0}}} {
		if {$new_state != 0} {
			set new_state [string tolower $new_state]
			set current_state $::de1_num_state($::de1(state))
			switch -- $new_state {
				"sleep" {
					if {$current_state != "Sleep"} {
						start_sleep
					}
				}
				"start" {
					if {$current_state != "Idle"} {
						start_idle
					}
				}
				"stop" {
					if {$current_state != "Idle" && $current_state != "Sleep"} {
						page_show off
						start_idle
					}
				}
			}
			return "OK"
		}
		return $::de1_num_state($::de1(state))
	}
	
	proc status { } {
		# depending on the current state, we supply different type of data
		set return [dict create]
		set json_structure {dict state string}
		dict set return "state" $::de1_num_state($::de1(state))
		switch -- $::de1_num_state($::de1(state)) {
			"Idle" {
				dict set return "profile" $::settings(original_profile_title)
				dict set return "espresso_count" $::settings(espresso_count)
				dict set return "steaming_count" $::settings(steaming_count)
				dict set return "bean_brand" $::settings(bean_brand)
				dict set return "bean_type" $::settings(bean_type)
				dict set return "bean_notes" $::settings(bean_notes)
				dict set return "roast_date" $::settings(roast_date)
				dict set return "roast_level" $::settings(roast_level)
				dict set return "skin" $::settings(skin)
			}
			"Espresso" {
				foreach key [list "espresso_elapsed" "espresso_pressure" "espresso_weight" "espresso_flow" "espresso_flow_weight" "espresso_temperature_basket" "espresso_temperature_mix"] {
					#dict append ret "$key" [::${key} range 0 end]
					append json_structure " ${key} list"
					dict set return $key [split [::${key} range 0 end] " "]
				}
			}
		    "Sleep" {
			}
		    "GoingToSleep" {
			}
		    "Busy" {
			}
		    "Steam" {
			}
		    "HotWater" {
			}
		    "ShortCal" {
			}
		    "SelfTest" {
			}
		    "LongCal" {
			}
		    "Descale" {
			}
		    "FatalError" {
			}
		    "Init" {
			}
		    "NoRequest" {
			}
		    "SkipToNext" {
			}
		    "HotWaterRinse" {
			}
		    "SteamRinse" {
			}
		    "Refill" {
			}
		    "Clean" {
			}
		    "InBootLoader" {
			}
		    "AirPurge" {
			}
		}
		append json_structure " * string"
		return [compile_json $json_structure $return]
	}
}
