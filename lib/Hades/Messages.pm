###################################
#                                 #
#   |   |,---.    | Apr 2016      #
#   |---||---|,---|,---.,---.     #
#   |   ||   ||   ||---'`---.     #
#   `   '`   '`---'`---'`---'     #   
#               revok.com.br      #
#                                 #
###################################
package Hades::Messages;

use strict;

use constant {
	HADES_MESSAGE_ID => "Hades Message",


	######################################
	#
	#	Server -> Client
	#
	######################################

	S_GAMEGUARD_REPLY => 100,

	# auth errors
	S_AUTH_REQUIRED => 101,
	S_AUTH_INVALID => 102,
	S_AUTH_BANNED => 103,
	S_AUTH_EXPIRED => 104,

	# data errors
	S_RO_USERNAME_REQUIRED => 200,
	S_RO_USERNAME_INVALID => 201,

	# state errors
	S_REQUEST_QUEUE_FULL => 500,
	S_NO_SLOT_AVAILABLE => 501,
	S_BUSY_CLIENT_ERROR => 502,
	S_REQUEST_TIMED_OUT => 503,

	###
	# commands replies
	###

	# bounding
	S_UNBOUNDED => 600,
	S_UNBOUND_NO_EFFECT => 601,

	S_BOUND_SUCESSFUL => 605,
	S_BOUND_FAILED_NO_SLOT => 606,

	S_SLOT_AVAILABLE_REPLY => 650,
	S_NO_SLOT_AVAILABLE_REPLY => 651,

	S_SERVER_SUMMARY => 800,

	S_TEXT => 999,
	
	######################################
	#
	#	Client -> Server
	#
	######################################

	C_GAMEGUARD_QUERY => 1000,

	###
	# commands
	###

	# bounding
	C_UNBOUND_REQUEST => 1600,

	C_BOUND_REQUEST => 1605,

	C_QUERY_SLOT_AVAILABLE => 1650,

	# metadata
	C_QUERY_SERVER_SUMMARY => 1800
};

1;
