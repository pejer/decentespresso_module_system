namespace eval ::decent_espresso::modules::pejer_twitter {
	package require de1_modules 1.0
	package require de1_utils
	package require de1_vars 1.0
	namespace import ::decent_espresso::modules::settings_set
	namespace import ::decent_espresso::modules::settings_get
	
	variable traces [dict create\
		shot "save_this_espresso_to_history {leave} ::decent_espresso::modules::pejer_twitter::action_shot"\
		god "god_shot_save {leave} ::decent_espresso::modules::pejer_twitter::action_shot"\
		state "update_de1_state {leave} ::decent_espresso::modules::pejer_twitter::action_state"\
		rating "save_espresso_rating_to_history {leave} ::decent_espresso::modules::pejer_twitter::action_shot"
	]
	
	variable check_twitter_feed 0
	variable twitter_responses [dict create \
		"whats up?" [list "Not much, just chillin'" "Taking it slow" "I'm currently sleeping..."]\
		"turn on" [list "okidoki, mister" "Done. Now get of my back"]
	]
}


# 	The procedure returns info about it
# 	Put the title, description and settings the user can change
# 	along with default values for them, here.
proc ::decent_espresso::modules::pejer_twitter::info {} {
	set info [dict create]
	dict append info "title" "Twitter – tweet stuff"
	dict append info "description" "This module will tweet certain actions"
	dict append info "settings" [list consumer_key "" consumer_secret "" token "" token_secret "" actions {shot god} allowed_users {henrik_pejer}]
	return $info
}
#	This runs only when the module is installed. If there is something
#	that needs to be set up once for this module to work properly
#	this is where you do that.
proc ::decent_espresso::modules::pejer_twitter::install {} {
	#trace add execution god_shot_save {leave} ::decent_espresso::modules::pejer_twitter::action_god
	settings_set [namespace current] "action_shot_last_shot" " "
	settings_set [namespace current] "last_mentions_id" 1
}

proc ::decent_espresso::modules::pejer_twitter::init {} {
	# include the necessary libraries
	foreach lib_file [list "twitoauth.tcl" "twitlib.tcl"] {
		source [file join "./modules/pejer_twitter/twitter_lib/${lib_file}"]
	}
	
	::decent_espresso::modules::pejer_twitter::save_new_twitter_values

	set ::twitlib::last_id 1
	set ::twitlib::last_mentions_id [settings_get [namespace current] "last_mentions_id"]

	set ::twitlib::oauth_token [settings_get [namespace current] token]
	set ::twitlib::oauth_token_secret [settings_get [namespace current] token_secret]

	::decent_espresso::modules::pejer_twitter::setup_trace
	::decent_espresso::modules::pejer_twitter::check_feed
}

proc ::decent_espresso::modules::pejer_twitter::setup_trace {} {
	set hooks [settings_get [namespace current] "actions"]
	foreach {key trace} $::decent_espresso::modules::pejer_twitter::traces {
		if {[lsearch $hooks $key] >= 0} {
			eval "trace add execution $trace"
		}
	}
}

proc ::decent_espresso::modules::pejer_twitter::teardown_trace {} {
	foreach {key trace} $traces {
		eval "trace remove execution $trace"
	}
}
proc ::decent_espresso::modules::pejer_twitter::save_new_twitter_values {} {	
	# set the twitter variables
	set ::twitlib::oauth_consumer_key [settings_get [namespace current] consumer_key]
	set ::twitlib::oauth_consumer_secret [settings_get [namespace current] consumer_secret]
	set ::twitlib::oauth_token [settings_get [namespace current] token]
	set ::twitlib::oauth_token_secret [settings_get [namespace current] token_secret]
}

#	When the user chooses to uninstall the module, this procedure
#	is called. Here you remove things you've set up, like trace etc,
# 	that shouldn't be stored or used, once the module is removed.
proc ::decent_espresso::modules::pejer_twitter::uninstall {} {
}

proc ::decent_espresso::modules::pejer_twitter::settings_saved {} {
	::decent_espresso::modules::pejer_twitter::save_new_twitter_values
}

proc ::decent_espresso::modules::pejer_twitter::action_shot {command-string code result op} {
	set dirs [lsort -dictionary [glob -tails -directory "[homedir]/history/" *.shot]]
	page_show "espresso_3"
	after 500
	set file [lrange $dirs end end]
	if {[settings_get [namespace current] "action_shot_last_shot"] != $file} {
		settings_set [namespace current] "action_shot_last_shot" $file
		
		set listofgraphs [list $::pressure_chart_widget $::flow_chart_widget $::temperature_chart_widget]
		set listofimages [list]
		set imageHeight 0
		set imageWidth 0
		foreach graph $listofgraphs {
			set canvId $graph
			#canvas_show $canvId
			package require canvas::snap
			package require img::window
		
			set retVal [catch {image create photo -format window -data $canvId} ph]
			lappend listofimages $ph
			if { $imageWidth < [image width $ph]} {
				set imageWidth  [image width $ph];
			}
			set imageHeight [expr {$imageHeight + [image height $ph]}]
		}		
		# create an image with the combined height of all the graphs
		set screendump [image create photo -format png -height $imageHeight -width $imageWidth]
		set imageYstart 0
		foreach img $listofimages {
			$screendump copy $img -to 0 $imageYstart
			set imageYstart [expr {$imageYstart + [image height $img]}]
		}
		
		if {[catch {::twitlib::query $::twitlib::upload_url [list media_data [::base64::encode [$screendump data -format png]]] POST} twit_upload_response]} {
			return
		}
		
		set tweet "Shot $::settings(espresso_count) // $::settings(bean_brand) // $::settings(bean_type)"

		
		if {$::settings(espresso_enjoyment) != ""} {
			append tweet "\nScore: $::settings(espresso_enjoyment)"
		}
		if {$::settings(espresso_notes) != ""} {
			append tweet "\n$::settings(espresso_notes)"
		}
		
		set status_data [list status $tweet media_ids [dict get $twit_upload_response media_id_string]]
		
		if {[catch {::twitlib::query $::twitlib::status_url $status_data} result]} {
		}

	}
}

proc ::decent_espresso::modules::pejer_twitter::action_state {command-string code result op} {
	switch -- $result {
		"Sleep" {
			set ::decent_espresso::modules::pejer_twitter::check_twitter_feed 1
		}
		default {
			set ::decent_espresso::modules::pejer_twitter::check_twitter_feed 0
		}
	}
}

proc ::decent_espresso::modules::pejer_twitter::check_feed {} {
	if {$::decent_espresso::modules::pejer_twitter::check_twitter_feed != 1} {
		after 1000 ::decent_espresso::modules::pejer_twitter::check_feed
		return
	}
	set mentions [::twitlib::get_unseen_mentions]
	set allowed_mentions [settings_get [namespace current] allowed_users]

	foreach mention $mentions {
		# Lets only allow mentions from _some_ ppl
		if {[lsearch $allowed_mentions [dict get $mention screen_name]] < 0} {
			continue
		}
		
		set message [string tolower [string range [dict get $mention full_text] 14 end]]
		set response "@[dict get $mention screen_name] "
		switch -- $message {
			"whats up?" {
				append response [::decent_espresso::modules::pejer_twitter::random_element_from_list [dict get $::decent_espresso::modules::pejer_twitter::twitter_responses "whats up?"]]
			}
			"turn on" {
				::start_idle
				append response [::decent_espresso::modules::pejer_twitter::random_element_from_list [dict get $::decent_espresso::modules::pejer_twitter::twitter_responses "turn on"]]
			}
			"status" {
				append response "\n"
				foreach {text settings_key} [list "Num cups" "espresso_count" "Water volume" "water_volume" "Bean brand" "bean_brand" "Bean type" "bean_type" "Notes" "bean_notes" "Coffee weight" "grinder_dose_weight" "Desired shot weight" "final_desired_shot_weight"] {
					if {$::settings($settings_key) != ""} {
						append response "${text}: $::settings($settings_key)\n"
					}
				}
			}
		}
		
		if {[catch {::twitlib::query $::twitlib::status_url [list status $response in_reply_to_status_id [dict get $mention id]]} result]} {
		}
	}
	# store last seen id so we don't repeat ourselfs
	settings_set [namespace current] "last_mentions_id" $::twitlib::last_mentions_id
	after 60000 ::decent_espresso::modules::pejer_twitter::check_feed
}

proc ::decent_espresso::modules::pejer_twitter::random_element_from_list {list} {
    lindex $list [expr {int(rand()*[llength $list])}]
}

proc ::decent_espresso::modules::pejer_twitter::web {first {second {second}} {third {third}}} {
	#set ret [dict create]
	set ret "{";
	set dict_setting ""
	foreach key [list "espresso_elapsed" "espresso_pressure" "espresso_weight" "espresso_flow" "espresso_flow_weight" "espresso_temperature_basket" "espresso_temperature_mix"] {
		#dict append ret "$key" [::${key} range 0 end]
		#append dict_setting "${key} list "
		append ret "\"${key}\":\[[join [split [::${key} range 0 end] " "] ","]\],"
	}
	return "[string trimright $ret ","]}"
	#return [compile_json {dict ${dict_setting}* list} $ret]
}