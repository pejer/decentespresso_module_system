#	Remember to use ::decent_espresso::modules::<name of module>
#	as namespace for your module.
namespace eval ::decent_espresso::modules::pejer_web_api {
	package require de1_modules 1.0
	#taken from http://wiki.tcl.tk/15244

	package require uri
	package require base64
	package require html

	namespace import ::decent_espresso::modules::settings_set	
	namespace import ::decent_espresso::modules::settings_get
	
	variable open_socket 0
}


# 	The procedure returns info about it
# 	Put the title, description and settings the user can change
# 	along with default values for them, here.
proc ::decent_espresso::modules::pejer_web_api::info {} {
	set info [dict create]
	dict append info "title" "Web API module"
	dict append info "description" "This will start a tiny web server that will server html/css/js as well as an API"
	dict append info "settings" [list port "9005" ]
	return $info
}
#	This runs only when the module is installed. If there is something
#	that needs to be set up once for this module to work properly
#	this is where you do that.
proc ::decent_espresso::modules::pejer_web_api::install {} {
}

proc ::decent_espresso::modules::pejer_web_api::settings_saved {} {
	::decent_espresso::modules::pejer_web_api::close_socket
	::decent_espresso::modules::pejer_web_api::start_socket
}

#	This procedure runs when the module is enabled. This happens
#	either right after it's been installed or, if its already been
#	installed, when the application starts. 
#	
#	If you have a trace command, this is where you'd set that up
proc ::decent_espresso::modules::pejer_web_api::init {} {
	::decent_espresso::modules::pejer_web_api::start_socket
}

proc ::decent_espresso::modules::pejer_web_api::start_socket {} {
	source "[pwd]/modules/pejer_web_api/api.tcl"
	set port [settings_get [namespace current] "port"]
	set ::decent_espresso::modules::pejer_web_api::open_socket [::decent_espresso::modules::pejer_web_api::HTTPD $port "" "" {} {AuthRealm} {
   "" {
     respond $sock 419 "I'm not a teapot..." "I'm a marvelous Espresso machine"
   }
	 "api\/*" {
		 array set req $reqstring
		 set list [list ]
		 foreach {value} [split $req(path) "/"] {
			 lappend list [url-decode $value]
		 }
		 set cmd [lindex $list 1]
		 set proc_to_call "::decent_espresso::modules::pejer_web_api::api::${cmd} [lrange $list 2 end]"
		 if {[catch {eval $proc_to_call} result]} {
		 	respond $sock 500 "$result" "Internal Server Error"
		 }
		 respond $sock 200 $result
	 }
   "*.html" {
		 array set req $reqstring
		 set fd [open "[pwd]/modules/pejer_web_api/www/${req(path)}" r]
		 fconfigure $fd -translation binary
		 set content [read $fd]; close $fd
		 respond $sock 200 $content
   }
   "*.css" {
		 array set req $reqstring
		 set fd [open "[pwd]/modules/pejer_web_api/www/${req(path)}" r]
		 fconfigure $fd -translation binary
		 set content [read $fd]; close $fd
		 respond $sock 200 $content
   }
   "*.js" {
		 array set req $reqstring
		 set fd [open "[pwd]/modules/pejer_web_api/www/${req(path)}" r]
		 fconfigure $fd -translation binary
		 set content [read $fd]; close $fd
		 respond $sock 200 $content
   }
   "module\/*" {
		 array set req $reqstring
		 set list [split $req(path) "/"]
		 set module_name [lindex $list 1]
		 set module_proc [lindex $list 2]
		 set proc_to_call "::decent_espresso::modules::webserver::${module_name}::${module_proc} [lrange $list 3 end]"
		 if {[catch {eval $proc_to_call} result]} {
		 	respond $sock 500 "$result"
		 }
		 respond $sock 200 $result
		}
	}
	]
}

proc ::decent_espresso::modules::pejer_web_api::close_socket {} {
	if { $::decent_espresso::modules::pejer_web_api::open_socket != 0 } {
		close $::decent_espresso::modules::pejer_web_api::open_socket
	}
}

#	When the user chooses to uninstall the module, this procedure
#	is called. Here you remove things you've set up, like trace etc,
# 	that shouldn't be stored or used, once the module is removed.
proc ::decent_espresso::modules::pejer_web_api::uninstall {} {
	::decent_espresso::modules::pejer_web_api::close_socket
}

#taken from http://wiki.tcl.tk/15244
proc ::decent_espresso::modules::pejer_web_api::HTTPD {port certfile keyfile userpwds realm handler} {
 if {![llength [::info commands Log]]} { proc Log {args} { puts $args } }
 namespace eval httpd [list set handlers $handler]
 namespace eval httpd [list set realm $realm]
 foreach up $userpwds { namespace eval httpd [list lappend auths [base64::encode $up]] }
 namespace eval httpd {
   proc respond {sock code body {head "OK"}} {
     puts -nonewline $sock "HTTP/1.0 $code $head\nContent-Type: text/html; charset=utf-8\nConnection: close\n\n$body"
   }
   proc checkauth {sock ip auth} {
     variable auths
     variable realm
     if {[info exist auths] && [lsearch -exact $auths $auth]==-1} {
       respond $sock 401 Unauthorized "WWW-Authenticate: Basic realm=\"$realm\"\n"
       error "Unauthorized from $ip"
     }
   }
   proc handler {sock ip reqstring auth} {
     variable auths
     variable handlers
     checkauth $sock $ip $auth
     array set req $reqstring
     switch -glob $req(path) [concat $handlers [list default { respond $sock 404 "Error" "Not Found"}]]
   }
   proc accept {sock ip port} {
     if {[catch {
       gets $sock line
       set auth ""
       for {set c 0} {[gets $sock temp]>=0 && $temp ne "\r" && $temp ne ""} {incr c} {
         regexp {Authorization: Basic ([^\r\n]+)} $temp -- auth
         if {$c == 30} { error "Too many lines from $ip" }
       }
       if {[eof $sock]} { error "Connection closed from $ip" }
       foreach {method url version} $line { break }
       switch -exact $method {
         GET { handler $sock $ip [uri::split $url] $auth }
         default { error "Unsupported method '$method' from $ip" }
       }
     } msg]} {
       write_file "logfile" "Error: $msg"
     }
     close $sock
   }
 }
 if {$certfile ne ""} {
 package require tls
 ::tls::init \
   -certfile $certfile \
   -keyfile  $keyfile \
   -ssl2 1 \
   -ssl3 1 \
   -tls1 0 \
   -require 0 \
   -request 0
 	 return [::tls::socket -server ::decent_espresso::modules::pejer_web_api::::httpd::accept $port]
 } else {
	 return [socket -server ::decent_espresso::modules::pejer_web_api::::httpd::accept $port]
	}
}