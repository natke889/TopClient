#! /bin/bash

# ==============================================================================
# Extension template for NetApp Harvest Manager (HEM)
#
# Adapt this script to collect counter data and send to Graphite server
#
# HOW TO USE:
# Template includes 4 ready-to-use functions:
#   - PrintHelp       Outputs detailed usage info
#   - LoadParameters  Loads parameters from CLI/env variables, opens Log
#   - Write2Log       Writes message to log or prints to console (in test mode)
#   - Send2Graphite   Sends metric to Graphite server
# The following function needs to be written (almost from scratch)
#   - RunTheTask      Should collect counter data and format them into metric
#                     strings (as Graphite leafs)
#
# Script can be run either as a background process (normally by HEM) or in the
# foreground (mainly for testing and debugging). Parameters are read from either
# from environment variables or command-line arguments, if both are available
# command-line arguments will be used.
#
# Metrics will not be sent to Graphite when running in test mode ("-t")
#
# For a list of required parameters and available options, run with "-h"
# (You might want to change in LoadParameters what parameters should be
# required)
#
# Authors:	Georg Mey, Vachagan Gratian. (c) NetApp 2019
#
# ==============================================================================


export MY_PROJECT="NetApp Harvest Extension"
export MY_NAME=`basename $0`
export TEST=false


Main() {

    # Load our parameters from env variables or CLI
    LoadParameters $@

    # Print basic info about session
    if [ "$TEST" = "true" ] ; then
        Write2Log warning "Starting session in test mode, logs are forwarded to console and no metrics will be sent to Graphite"
    else
        Write2Log debug "Started extension session normally with the new script"
    fi

    # Run the task: collect counters and send to Graphite
    # TODO: currently this is an incomplete function and you need to expand it yourself!
    RunTheTask

    # We are done if we reached this far
    Write2Log debug "Session ended normally"
    exit 0
}


# ==============================================================================
# function:	    RunTheTask
# parameter:	-none-
# purpose:	    Get data and send to Graphite
# ==============================================================================
RunTheTask() {
		Write2Log debug "start sample"
		sshpass -p ${_HARVEST_PASSWORD} \
		ssh -o StrictHostKeyChecking=no \
		-l ${_HARVEST_USERNAME}  ${_HARVEST_HOSTNAME} \
		"set d; statistics start -object top_client -sample-id sample_111 -sort-key total_ops" 2>/dev/null
		sleep 10
		Write2Log debug "stop sample"
		sshpass -p ${_HARVEST_PASSWORD} \
		ssh -o StrictHostKeyChecking=no \
		-l ${_HARVEST_USERNAME}  ${_HARVEST_HOSTNAME} \
		"set d; statistics stop  -sample-id sample_111" 2>/dev/null
		sleep 3
		Write2Log debug "check sample status"
		STATUS=$(sshpass -p ${_HARVEST_PASSWORD} \
		ssh -o StrictHostKeyChecking=no \
		-l ${_HARVEST_USERNAME}  ${_HARVEST_HOSTNAME} \
		"set d; statistics samples show -fields sample-status" 2>/dev/null | grep Ready)
		Write2Log debug "$STATUS"
		Write2Log debug "before while"
		while [ -z "${STATUS}" ]; do
			STATUS=$(sshpass -p ${_HARVEST_PASSWORD} \
			ssh -o StrictHostKeyChecking=no \
			-l ${_HARVEST_USERNAME}  ${_HARVEST_HOSTNAME} \
			"set d; statistics samples show -fields sample-status" 2>/dev/null | grep Ready)
			Write2Log debug "$STATUS"

			STATUSERROR=$(sshpass -p ${_HARVEST_PASSWORD} \
			ssh -o StrictHostKeyChecking=no \
			-l ${_HARVEST_USERNAME} ${_HARVEST_HOSTNAME} \
			"set d; statistics samples show -fields sample-status" 2>/dev/null | grep Error)
			
			if [ -n "{$STATUSERROR}" ]; then
				STATUS="Error"
			fi
		done
		Write2Log debug "after while when sample Ready state"
		SAMPLES=$(sshpass -p ${_HARVEST_PASSWORD} \
		ssh -o StrictHostKeyChecking=no \
		-l ${_HARVEST_USERNAME}  ${_HARVEST_HOSTNAME} \
		"set d; statistics show -sample-id sample_111 -tab -counter total_ops|vserver_name|protocol -sort-key total_ops" 2>/dev/null | grep cifs | tr . _ | column -t )
		Write2Log debug "$SAMPLES"
		IFS=$'\n'
		for SAMPLE in $SAMPLES; do
			Write2Log debug "in the for"
			SVM=$(echo $SAMPLE | awk ' { print $4 }')
			CLIENT=$(echo $SAMPLE | awk ' { print $1 }')
			TOTAL_OPS=$(echo $SAMPLE | awk ' { print $3 }')
			SVM="${SVM//$'\r'/}"
			CLIENT="${CLIENT//$'\r'/}"
			TOTAL_OPS="${TOTAL_OPS//$'\r'/}"
			# Preconstruct Graphite leaf
			METRIC="$_HARVEST_GRAPHITE_ROOT.protocol.cifs"
			METRIC="$METRIC.svm.$SVM"
			METRIC="$METRIC.client.$CLIENT"
			METRIC="$METRIC.total_ops $TOTAL_OPS.0"
			METRIC="$METRIC $_HARVEST_POLL_EPOCH"
			Write2Log debug "$METRIC"
			#echo "$METRIC"
			# Send metric to Graphite
			Send2Graphite "$METRIC"
		done
		SAMPLES=$(sshpass -p ${_HARVEST_PASSWORD} \
		ssh -o StrictHostKeyChecking=no \
		-l ${_HARVEST_USERNAME}  ${_HARVEST_HOSTNAME} \
		"set d; statistics show -sample-id sample_111 -tab -counter total_ops|vserver_name|protocol -sort-key total_ops" 2>/dev/null | grep nfs | tr . _ | column -t )
		Write2Log debug "$SAMPLES"
		IFS=$'\n'
		for SAMPLE in $SAMPLES; do
			Write2Log debug "in the for"
			SVM=$(echo $SAMPLE | awk ' { print $4 }')
			CLIENT=$(echo $SAMPLE | awk ' { print $1 }')
			TOTAL_OPS=$(echo $SAMPLE | awk ' { print $3 }')
			SVM="${SVM//$'\r'/}"
			CLIENT="${CLIENT//$'\r'/}"
			TOTAL_OPS="${TOTAL_OPS//$'\r'/}"
			# Preconstruct Graphite leaf
			METRIC="$_HARVEST_GRAPHITE_ROOT.protocol.nfs"
			METRIC="$METRIC.svm.$SVM"
			METRIC="$METRIC.client.$CLIENT"
			METRIC="$METRIC.total_ops $TOTAL_OPS.0"
			METRIC="$METRIC $_HARVEST_POLL_EPOCH"
			Write2Log debug "$METRIC"
			#echo "$METRIC"
			# Send metric to Graphite
			Send2Graphite "$METRIC"
		done
		
		
		sshpass -p ${_HARVEST_PASSWORD} \
		ssh -o StrictHostKeyChecking=no \
		-l ${_HARVEST_USERNAME}  ${_HARVEST_HOSTNAME} \
		"set d; statistics sample delete -sample-id sample_111" 2>/dev/null
}


# ==============================================================================
# function:	    Send2Graphite
# parameter:	-none-
# purpose:	    Send a single metric to Graphite
# ==============================================================================
Send2Graphite() {
    Write2Log debug "M=" "$1"
    # Only send if not in test mode
    if [ "$TEST" != "true" ] ; then
        echo "$1" | nc -q 0 $_HARVEST_GRAPHITE_HOST 2003
    fi
}


# ==============================================================================
# function:	    LoadParameters
# parameter:	-none-
# purpose:	    Read and validate parameters from CLI arguments
#               Open Log file if not in test mode
# ==============================================================================
LoadParameters() {

    # Read CLI arguments
    TEMP=`getopt -o htvH:R:G:C:U:P:I:E: --long verbose,test,help,ghost:,groot:,group:,cluster:,user:,password:,installdir:,epoch: \
                 -n "$MY_NAME" -- "$@"`

    # Warn for invalid arguments
    if [ $? != 0 ] ; then
    	echo "$MY_NAME: see online help for details..." >&2
    	PrintHelp
    	exit 1
    fi

    eval set -- "$TEMP"

    # Store loaded parameters
    while true; do

    	case "$1" in

        		-h | --help ) 		PrintHelp; exit 0 ;;
        		-t | --test ) 		TEST=true; shift ;;
        		-v | --verbose ) 	_HARVEST_VERBOSE=true; shift ;;
        		-H | --ghost ) 		_HARVEST_GRAPHITE_HOST="$2"; shift 2 ;;
        		-R | --groot ) 		_HARVEST_GRAPHITE_ROOT="$2"; shift 2 ;;
        		-G | --group ) 		_HARVEST_GROUP="$2"; shift 2 ;;
        		-C | --cluster ) 	_HARVEST_HOSTNAME="$2"; shift 2 ;;
        		-U | --user ) 		_HARVEST_USERNAME="$2"; shift 2 ;;
        		-P | --password ) 	_HARVEST_PASSWORD="$2"; shift 2 ;;
        		-I | --installdir )	_HARVEST_INSTALL_DIR="$2"; shift 2 ;;
        		-E | --epoch ) 		_HARVEST_POLL_EPOCH="$2"; shift 2 ;;
        		-- ) shift; break ;;
        		* ) break ;;

    	esac
    done

    # Check for missing parameters
    # TODO: customize which parameters are mandatory and which not
    MISSING_PARAMETERS=""

    if [ "$_HARVEST_GRAPHITE_HOST"  = "" ] ; then MISSING_PARAMETERS="$MISSING_PARAMETERS,ghost"      ; fi
    if [ "$_HARVEST_GRAPHITE_ROOT"  = "" ] ; then MISSING_PARAMETERS="$MISSING_PARAMETERS,groot"      ; fi
    if [ "$_HARVEST_GROUP"          = "" ] ; then MISSING_PARAMETERS="$MISSING_PARAMETERS,group"      ; fi
    if [ "$_HARVEST_HOSTNAME"       = "" ] ; then MISSING_PARAMETERS="$MISSING_PARAMETERS,cluster"    ; fi
    if [ "$_HARVEST_USERNAME"       = "" ] ; then MISSING_PARAMETERS="$MISSING_PARAMETERS,user"       ; fi
    if [ "$_HARVEST_INSTALL_DIR"    = "" ] ; then MISSING_PARAMETERS="$MISSING_PARAMETERS,installdir" ; fi
    if [ "$_HARVEST_PASSWORD"       = "" ] ; then MISSING_PARAMETERS="$MISSING_PARAMETERS,password"   ; fi
    if [ "$_HARVEST_POLL_EPOCH"     = "" ] ; then MISSING_PARAMETERS="$MISSING_PARAMETERS,epoch"      ; fi

    if [ "$MISSING_PARAMETERS" != "" ] ; then

    	TEXT=${MISSING_PARAMETERS#*,}
    	printf "\n"
    	printf "Missing required parameters: [%s], see -h for details\n" "$TEXT"
    	printf "\n"
    	exit 2
    fi

    # Set verbose to false by default
    if [ "$_HARVEST_VERBOSE" = "" ] ; then _HARVEST_VERBOSE=false ; fi

    # Generate log filename if not running in test mode
    if [ "$TEST" != "true" ] ; then

        _HARVEST_CLUSTER=`echo $_HARVEST_GRAPHITE_ROOT | awk -F"." '{ print $(NF)}'`
        _HARVEST_EXTENSION=`echo $MY_NAME | awk -F"." '{ print $(1)}'`
        LOG_FILE="${_HARVEST_INSTALL_DIR}/log/${_HARVEST_CLUSTER}_netapp-harvest_${_HARVEST_EXTENSION}.log"
    fi
}


# ==============================================================================
# function:	    Write2Log
# parameter:	$1     = level
#               $2..$n = message to write to log
# purpose:	    Write log messages to file. Or, if we have no log file
#               print messages to console
# ==============================================================================
Write2Log() {

    # Uppercase level
	LEVEL=`echo $1 | tr '[:lower:]' '[:upper:]'`

    # Neglect debug messages if not requested
	if [ "$_HARVEST_VERBOSE" = "false" ] && [ "$LEVEL" = "DEBUG" ]; then
		return 1
	else
		TIME_STAMP=`date '+%Y-%m-%d %H:%M:%S'`
		shift

        # Send to log file if we have one
        if [ "$LOG_FILE" != "" ]; then
    		printf "[%s] "    "$TIME_STAMP"   >>$LOG_FILE
    		printf "[%-7.7s] " $LEVEL         >>$LOG_FILE
    		printf "%s\n"     "$*"		      >>$LOG_FILE
        else
            printf "[%s] "    "$TIME_STAMP"
            printf "[%-7.7s] " $LEVEL
            printf "%s\n"     "$*"
        fi
	fi

}


# ==============================================================================
# function:	    PrintHelp
# parameter:	-none-
# purpose:	    show online help
# ==============================================================================
PrintHelp() {

	cat <<EOF_PRINT_HELP

   $MY_PROJECT - $MY_NAME

   usage:

      $MY_NAME [general options] [required options]

   general options:

      -h | --help
      -t | --test
      -v | --verbose

   required options:

      -H | --ghost            Fills environment variable _HARVEST_GRAPHITE_HOST
      -R | --ghroot           Fills environment variable _HARVEST_GRAPHITE_ROOT
      -G | --group            Fills environment variable _HARVEST_GROUP
      -C | --cluster          Fills environment variable _HARVEST_HOSTNAME
      -U | --user             Fills environment variable _HARVEST_USERNAME
      -P | --password         Fills environment variable _HARVEST_PASSWORD
      -I | --installdir       Fills environment variable _HARVEST_INSTALL_DIR
      -E | --epoch            Fills environment variable _HARVEST_POLL_EPOCH

EOF_PRINT_HELP

}


Main $@
