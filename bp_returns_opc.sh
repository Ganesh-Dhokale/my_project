#!/bin/sh
#################################################################################
#
# 2015 (c) The Bank of New York Mellon, Securities Lending
#
# File Name:    	bp_returns_opc.sh
# Description:		Invoker/Wrapper for bin bp_returns.sh.
# Author : 			Aman
# Created Date:		July 18 2017
# Assumptions
# ===========
# 1. This file is inside $TPMB_HOME/bin folder.
# 2. The necessary folder structure is present
#################################################################################

opcdir=`dirname $0`
. ${opcdir}/profile.sh
. ${TPMB_HOME}/etc/bp_returns_env.sh
log_dt=`getLogFileDateYMD`


TPMBLOG=${TPMB_OUTPUT}/bp_returns_${log_dt}.log
export TPMBLOG=${TPMB_OUTPUT}/bp_returns_${log_dt}.log
log_debug "==== Entered bp_returns_opc.sh ====">>${TPMBLOG}

#log_debug "This script is now being called from ESP job.">>${TPMB_HOME}/opc/log/bp_returns_opc.log
#exit 0

log_debug "Checking for holiday trigger to see whether it's a holiday!">>${TPMBLOG}
if [ -f "${SKIP_HOLIDAY_TRG}" ]
then
	log_debug "Bingo! Found holiday trigger ${SKIP_HOLIDAY_TRG} for bp returns. Script will exit as its a holiday.Exiting...">>${TPMBLOG}
	exit 0
else
	log_debug "Calling returns.sh">>${TPMBLOG}
	sh ${TPMB_BIN}/bp_returns.sh>>${TPMBLOG} 2>&1
fi
