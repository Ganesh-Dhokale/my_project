#!/bin/sh -
#################################################################################
#
# 2015 (c) The Bank of New York Mellon, Securities Lending
#
# File Name:    	bp_returns.sh
# Description:		Caller to worker script.
# Author : 			Aman
# Created Date:		July 18 2017
# Assumptions
# ===========
# 1. This file is inside $TPMB_HOME/bin folder.
# 2. The necessary folder structure is present
#################################################################################


#=================================
# Functions
#=================================

ScriptIntervalChecker(){
        log_debug "Entered ScriptIntervalChecker" 
        typeset currentTime=`date +\%H\%M`
        OIFS=$IFS
        IFS='|'
        endTimes=$1
        for endTime in $endTimes
        do
                log_debug "The endtimes value : ${endTime}"
                tscriptStartTime=`echo ${endTime} |cut -d '-' -f1` 
                tscriptEndTime=`echo $endTime |cut -d '-' -f2` 
                typeset scriptStartTime=`echo "${tscriptStartTime}" | sed 's/://g'`
                typeset scriptEndTime=`echo "${tscriptEndTime}" | sed 's/://g'`
                log_debug "Interval Start : ${scriptStartTime} Interval End : ${scriptEndTime} Current time : ${currentTime}" 
                if [ $currentTime -le $scriptEndTime ] && [ $currentTime -ge $scriptStartTime ]
                then
                        log_debug "Current time falls between Interval Start/End time" 
                        return 0
                fi
        done
        log_debug "Current time does not fall between the specified start/end times"
        IFS=$OIFS
        return 1
}

#=================================
# Main Program
#=================================
echo "==== Entered script : bp_returns.sh on `date`===="

# Step 1 - Initialize variables
. /global2/COMMON/bin/common_functions.sh
. /global2/COMMON/bin/common_oracle_function.sh
. ${TPMB_HOME}/etc/bp_returns_env.sh

log_debug "=== Step 1 - Finished environment setup===" 

setup_common

## 2. Look before you Leap!
## 2A. Check if trigger(s) is present. Exit if not present.
log_debug "=== Step -2.A Check if trigger(s) is present. Exit if not present.===" 
miss_trg=0
for missing_trg in ${ABORT_IF_MISSING_TRIGGER[*]}
do
	log_debug "ABORT_IF_MISSING_TRIGGER ${ABORT_IF_MISSING_TRIGGER[*]}"
	if [ ! -z  ${missing_trg} ];then
		log_debug "Trigger to check is - $missing_trg"
		if [ ! -f ${missing_trg} ];then
			log_debug "Trigger is not present for ABORT_IF_MISSING_TRIGGER- $missing_trg. Exiting..."
			miss_trg=1
			break
		else
			log_debug "Trigger $missing_trg is present. Continuing the process."
		fi
	fi	
done

if [ ${miss_trg} -eq 1 ]
then
    
	#sendMail "${TPMB_ADMIN}" "${B_P_RETURN_E} ${MISSING_TRIGGER_FILE_SUBJ} exiting on ${formattedDate}"  "${MISSING_TRIGGER_FILE_BODY} File: $missing_trg .Email generated from $0 "
	${TPMB_BIN}/SendMail.sh "${B_P_RETURN_E} ${MISSING_TRIGGER_FILE_SUBJ} exiting on ${formattedDate}" "${FROM}" "${TO}" "${MISSING_TRIGGER_FILE_BODY} File: $missing_trg .Email generated from $0" 
    RUN_MODE="X"
	log_debug "run mode for ABORT_IF_MISSING_TRIGGER is - ${RUN_MODE}. Exiting script..."
	exit 0
fi

## 2B. Check trigger(s)  is present. Exit if present.
log_debug "=== Step -2B. Check trigger(s)  is present. Exit if present. ===" 
pres_trg=0
for present_trg in ${ABORT_IF_PRESENT_TRIGGER[*]}
do
	log_debug "ABORT_IF_PRESENT_TRIGGER ${ABORT_IF_PRESENT_TRIGGER[*]}"
	typeset sysCurrentTime=`date +\%H\%M`
	typeset abort_if_time_exceeds=`echo "${ABORT_IF_TIME_EXCEEDS}" | sed 's/://g'`
	if [ ! -z  ${present_trg} ] && [ -f ${present_trg} ]
	then
		log_warning "ABORT_IF_PRESENT_TRIGGER trigger found - ${present_trg}. Now checking if current time is greater than or equal to ABORT_IF_TIME_EXCEEDS param. "
		if [ ! -z ${abort_if_time_exceeds} ] &&  [ ${sysCurrentTime} -ge ${abort_if_time_exceeds} ]
		then
			log_warning "Current time - ${sysCurrentTime}, is greater than ABORT_IF_TIME_EXCEEDS - ${ABORT_IF_TIME_EXCEEDS}. Exiting script..."
			pres_trg=1
			break
		else
			log_debug " ABORT_IF_PRESENT_TRIGGER trigger(s) is/are present  but current time, ${sysCurrentTime}, is not greater than or equal to ABORT_IF_TIME_EXCEEDS, ${ABORT_IF_TIME_EXCEEDS}.  Continuing script..."
		fi
	fi	
done

if [ ${pres_trg} -eq 1 ]
then
    
	#sendMail "${TPMB_ADMIN}" "${B_P_RETURN_E} ${PRESENT_TRIGGER_FILE_SUBJ} exiting on ${formattedDate}"  "${PRESENT_TRIGGER_FILE_BODY} .Email generated from $0 "
	${TPMB_BIN}/SendMail.sh "${B_P_RETURN_E} ${PRESENT_TRIGGER_FILE_SUBJ} exiting on ${formattedDate}" "${FROM}" "${TO}" "${PRESENT_TRIGGER_FILE_BODY} .Email generated from $0" 
    RUN_MODE="X"
	log_debug "run mode for ABORT_IF_PRESENT_TRIGGER is - ${RUN_MODE}. Exiting script..."
	exit 0
fi


log_debug "=== Step 3 - Check for lock file and create one if not found. ===" 
#Step 3 - Check for lock file and create one if not found.
log_trace "Checking lock file for  returns."
if [ -f ${LCKFILE} ]
then 
    log_error "${LCKFILE} is present. Another  returns  process is running. Aborting process...  Verify that this is not an old instance of the lock file."
	#sendMail "${TPMB_ADMIN}" "${B_P_RETURN_E} : Lock file present for ${SCRIPT_NAME}  process."  "Lock file found - ${LCKFILE}.\nVerify whether this is due to another instance of ${SCRIPT_NAME} <b>${RETURN_TYPE}</b> process is currently executing or if this is an old lock file that must be removed.\nPlease verify that we received/processed ${RETURN_TYPE} returns today.Exiting!!! .Email generated from $0 "
	${TPMB_BIN}/SendMail.sh "${B_P_RETURN_E} : Lock file present for ${SCRIPT_NAME}  process." "${FROM}" "${TO}" "Lock file found - ${LCKFILE}.\nVerify whether this is due to another instance of ${SCRIPT_NAME} <b>${RETURN_TYPE}</b> process is currently executing or if this is an old lock file that must be removed.\nPlease verify that we received/processed ${RETURN_TYPE} returns today.Exiting!!! .Email generated from $0" 
    exit 1
fi
#Step 3.1 - Creating lock file.
log_debug "=== Step 3.A - Creating lock file.===" 
log_trace "Lock file is not present for returns. Creating one."
touch ${LCKFILE}
loopcnt=0

#Step 4 - Going into infinite loop.
log_debug "=== Step 4 - Going into infinite loop. ===" 
while :
do

#Step 4.1 - Load environment variables.
log_debug "=== Step 4.1 - Load environment variables. ===" 
. ${TPMB_ETC}/bp_returns_env.sh
	setup_common	
	#Step 4.2 - Script should not sleep for the first time.
	log_debug "=== Step 4.2 - Script should not sleep for the first time. ===" 
	if [ ${loopcnt} -ne 0 ]
	then
		log_debug "====Sleep for ${SLEEP_TIME} seconds."	
		sleep ${SLEEP_TIME}
	fi
	loopcnt=`expr ${loopcnt} + 1`
	
	currTime=`date +\%H\%M`
    log_debug "currTime is =${currTime}="
    if [ ${currTime} -ge ${SCRIPT_EXIT_TIME} ]
    then
            log_debug  "Exiting ${SCRIPT_NAME}. Reached SCRIPT_EXIT_TIME ${SCRIPT_EXIT_TIME}."
           	#sendMail "${TPMB_ADMIN}" "${B_P_RETURN_W} Exiting ${SCRIPT_NAME} script as script end time has reachedon ${formattedDate}"  "End Time for Conduit Returns reached.End time set to ${SCRIPT_EXIT_TIME}. \n Email generated from $0 "
			${TPMB_BIN}/SendMail.sh "${B_P_RETURN_W} Exiting ${SCRIPT_NAME} script as script end time has reachedon ${formattedDate}" "${FROM}" "${TO}" "End Time for Conduit Returns reached.End time set to ${SCRIPT_EXIT_TIME}. \n Email generated from $0" 
			break 
    fi


	#Step 4.3 - Calling execution mode checker.
	log_debug "=== Step 4.3 - Calling execution mode checker. ===" 
	Emc_result=`executionModeChecker ${TPMBLOG}`
	log_debug "The return value of executionModeChecker() : ${Emc_result}"
	#Below code compares the Execution mode returned by executionModeChecker() method
	if [ ${Emc_result} == "P" ]
	then
		log_debug "The execution mode checker is in pause mode. Executing next loop."
		continue
	elif [ ${Emc_result} == "X" ]
	then
		log_error "${EMAIL_SUB_ENV} Warning: ${SCRIPT_NAME} exited on ${dt} as execution mode = X. This process will need to be rescheduled manually to start it back again."
		#sendMail "${TPMB_ADMIN}" "${B_P_RETURN_W} Exiting ${SCRIPT_NAME} exited for B+ Returns on ${formattedDate}"  "${SCRIPT_NAME} exited for B+ Returns on ${dt} as execution mode = X. This process will need to be rescheduled manually to start it back again. \n Email generated from $0 "
		${TPMB_BIN}/SendMail.sh "${B_P_RETURN_W} Exiting ${SCRIPT_NAME} exited for B+ Returns on ${formattedDate}" "${FROM}" "${TO}" "${SCRIPT_NAME} exited for B+ Returns on ${dt} as execution mode = X. This process will need to be rescheduled manually to start it back again. \n Email generated from $0" 
		log_debug "Removing lock and exxiting process..."
		rm -f ${LCKFILE}
		break
	fi

	
	# Step 4.4 - Check if ${G1_UDT_FILENAME} is already present in ${G1_IN_DIR}.
	log_debug "=== Step 4.4 Checking if ${G1_UDT_FILENAME} is already present in ${G1_IN_DIR}. If present then will exit with error mail. ==="
	if [ -f ${G1_IN_DIR}/${G1_UDT_FILENAME} ]
	then
		log_debug "${G1_UDT_FILENAME} is already present in ${G1_IN_DIR} for Returns  process...Exiting the script!."
		subject="${G1_UDT_FILENAME} is already present in ${G1_IN_DIR}"
		body="${G1_UDT_FILENAME} is already present in ${G1_IN_DIR} for Returns process. Please check if it's a previous file...Exiting the script!."
		#sendMail "${TPMB_ADMIN}" "${B_P_RETURN_E} ${subject}"  "${body}. \n Email generated from $0 "
		${TPMB_BIN}/SendMail.sh "${B_P_RETURN_E} ${subject}" "${FROM}" "${TO}" "${body}. \n Email generated from $0" 
		exit 1
	fi

	#Step 4.5 - Call Flow Utils to load returns from DB2 to Oracle.
	log_debug "=== Step 4.5 Calling java process ...load returns from DB2 to Oracle --START ==="
	launchFlowUtil ${FEED_NAME} tpmb
	flowUtils_src_status=$?
	
	if [ ${flowUtils_src_status} -ne 0 ]
	then
		log_debug "flowutil.sh executed with error. Returned with status " ${flowUtils_src_status}
		#sendMail "${TPMB_ADMIN}" "${B_P_RETURN_E} occured while executing launchFlowUtil for ${SCRIPT_NAME} - on ${formattedDate} "  "Error occured with status -  $flowUtils_status while executing launchFlowUtil for B+ returns . Please check java log for more details. \n This process needs to be start back again manually. \n Email generated from $0 "
		${TPMB_BIN}/SendMail.sh "${B_P_RETURN_E} occured while executing launchFlowUtil for ${SCRIPT_NAME} - on ${formattedDate}" "${FROM}" "${TO}" "Error occured with status -  $flowUtils_status while executing launchFlowUtil for B+ returns . Please check java log for more details. \n This process needs to be start back again manually. \n Email generated from $0" 
		log_debug "Process is exiting error in java layer with status :  ${flowUtils_src_status}"
		exit 1;
	else	
		log_debug "flowutil.sh with arguments ${FEED_NAME},tpmb executed..Finished."
	fi
	log_debug "Calling java process ...load returns from DB2 to Oracle --ENDS"
	
#exit 0 # for testing purpose only
	log_debug " #########-----4.6 Starting to call the CREST and DOM process -----######### "
	#Looping through each return time intervals.
	for sub_process in ${SUB_PROCESS[*]}
	do	
		log_debug "Fetching all the configuration for the return type :$sub_process"
		setup_${sub_process}
		log_debug "Returns type -> $RETURN_TYPE"
		log_debug "Interval is -> $RETURN_TIME_INTERVALS"
		log_debug "Checking that current time falls between given intervals for $RETURN_TYPE return type."
		ScriptIntervalChecker ${RETURN_TIME_INTERVALS}
		interval_status=$?
		if [ ${interval_status} -eq 0 ]
		then
			log_debug "Current time falls between script interval- $interval for $RETURN_TYPE."
				
						
			# Step 4.7 -Checking if data is present for spooling and creating the dat file
			log_debug "=== 4.7 Checking if data is present for spooling and creating the dat file ==="
			log_debug "Count check Query : ${COUNT_QUERY}"
			cnt_rec=`getTableRecords "${COUNT_QUERY}"`
			status_cnt_rec=$?
			log_debug "Count recived is : ${cnt_rec} and status form DB : ${status_cnt_rec}"
								
			if [ ${cnt_rec} -gt 0 ]
			then
					log_debug " --- 4.7.1 Holding the records to be spooled --- "
					log_debug "Hold query --> $HOLD_QUERY"				
					update_notify=`runDMLQuery "${HOLD_QUERY}"`
					status_notify=$?
					log_debug "status form DB for the update notify : ${status_notify}"
			
					if [ ${status_notify} -ne 0 ]
					then
							log_debug "====Error while updating the table query used -->${HOLD_QUERY}"
							#sendMail "${TPMB_ADMIN}" "${B_P_RETURN_E} Error occured while updating the TPMB.RETURNS table. ${SCRIPT_NAME} - on ${formattedDate} "  "Error while updating updating the TPMB.RETURNS table. Exiting Process .. \n This process needs to be start back again manually. \n Email generated from $0 "
							${TPMB_BIN}/SendMail.sh "${B_P_RETURN_E} Error occured while updating the TPMB.RETURNS table. ${SCRIPT_NAME} - on ${formattedDate} " "${FROM}" "${TO}" "Error while updating updating the TPMB.RETURNS table. Exiting Process .. \n This process needs to be start back again manually. \n Email generated from $0" 
							exit -1
					fi

							
					log_debug "--- 4.7.2 Calling the spool sql to create the dat file ---"					
					final_out_filename=${RETURN_OUTPUT_FILE_G1}_`getDateVariable`".DAT"
					
					log_debug "Spool file used --> ${RETURN_SPOOL_FILE}"
					log_debug "$RETURN_TYPE g1 out file to be created --> ${final_out_filename}"
				
					s_val=`spoolToFile ${RETURN_SPOOL_FILE} ${final_out_filename}` 
					s_status=$?
					log_debug "The return value: $s_val and Run status:$s_status"
					
					log_debug "--- 4.7.3 Check if the spooling was succesfuly completed ---"
					if [ ${s_status} -ne 0 ]
					then
						log_debug "*******Error while creating spool file ${final_out_filename} as G1 format using ${RETURN_SPOOL_FILE} *******"
						#sendMail "${TPMB_ADMIN}" "${B_P_RETURN_E} Error occured while creating G1 upload file format. ${SCRIPT_NAME}.. - on ${formattedDate} "  "Error while creating spool file `basename ${final_out_filename}` as G1 format using `basename ${RETURN_SPOOL_FILE}`. Return Value:$s_val and Status:$s_status.Exiting Process.\n E-mail generated from $0." 
						${TPMB_BIN}/SendMail.sh "${B_P_RETURN_E} Error occured while creating G1 upload file format. ${SCRIPT_NAME}.. - on ${formattedDate} " "${FROM}" "${TO}" "Error while creating spool file `basename ${final_out_filename}` as G1 format using `basename ${RETURN_SPOOL_FILE}`. Return Value:$s_val and Status:$s_status.Exiting Process.\n E-mail generated from $0." 
						exit -1
					fi

				log_debug "Starting G1 uploding for the ${sub_process}"
				log_debug "Parameter passed are as follows"
				log_debug "Return type : ${sub_process}"
				log_debug "KTLOG_PREFIX : ${KTLOG_PREFIX}"
				log_debug "KTEXTERN_NAME :${KTEXTERN_NAME} "
				log_debug "Final out file created from spool file :${final_out_filename}"
				
				log_debug "--- 4.7.4 calling the script returns_upload.sh ---"
				sh ${TPMB_HOME}/bin/returns_upload.sh ${sub_process} ${KTLOG_PREFIX} ${KTEXTERN_NAME} ${final_out_filename}
				if [ $? -ne 0 ]
				then
					log_debug "global one upload for S{sub_process} had error while uploading . Returned with status " ${?}
					#sendMail "${TPMB_ADMIN}" "${B_P_RETURN_E} Error occured while updating the TPMB.RETURNS table. ${SCRIPT_NAME} - on ${formattedDate} "  "Error while updating updating the TPMB.RETURNS table. Exiting Process .. \n This process needs to be start back again manually. \n Email generated from $0 "
					${TPMB_BIN}/SendMail.sh "${B_P_RETURN_E} Error occured while updating the TPMB.RETURNS table. ${SCRIPT_NAME} - on ${formattedDate} " "${FROM}" "${TO}" "Error while updating updating the TPMB.RETURNS table. Exiting Process .. \n This process needs to be start back again manually. \n Email generated from $0." 
				else	
					log_debug "executing the ${TPMB_HOME}/bin/returns_upload.sh process is completed ..Finished."
				fi					

				log_debug "updating the record after the dat file creation"
				log_debug "--- 4.7.5 Mark all the records to completed once they are uploaded to G1 .. ---"
					log_debug "UPDATE query --> $UPDATE_QUERY"				
					update_notify=`runDMLQuery "${UPDATE_QUERY}"`
					status_notify=$?
					log_debug "status form DB for the update notify : ${status_notify}"
			
					if [ ${status_notify} -ne 0 ]
					then
							log_debug "====Error while updating the table query used -->${UPDATE_QUERY}"
							#sendMail "${TPMB_ADMIN}" "${B_P_RETURN_E} Error occured while executing executing the ${TPMB_HOME}/bin/returns_upload.sh  for ${SCRIPT_NAME}..- on ${formattedDate} "  "Error occured while exuting the Return process : S{sub_process} in ${SCRIPT_NAME}. Email generated from $0."
							${TPMB_BIN}/SendMail.sh "${B_P_RETURN_E} Error occured while executing executing the ${TPMB_HOME}/bin/returns_upload.sh  for ${SCRIPT_NAME}..- on ${formattedDate} " "${FROM}" "${TO}" "Error occured while exuting the Return process : S{sub_process} in ${SCRIPT_NAME}. Email generated from $0." 
							exit -1
					fi
					
				log_debug "Going for next B+ returns type to execute..."
				log_debug "Sleep for ${SLEEP_TIME} for next process to begin"
				sleep ${SLEEP_TIME}
				
			else
				log_debug "No data to upload ..for the Return type $RETURN_TYPE"
				log_debug "Going for next B+ returns type to execute..."
			fi
			
		else
			log "Current time doesn't falls between script interval- $interval for $RETURN_TYPE.Continuing the script."
			continue
		fi		
	done
	log_debug "#########----- Call to CREST and DOM process ends -----#########"
	
done

#Step 5 - Remove lock file
if [ -f ${LCKFILE} ]; then
  rm -f ${LCKFILE}
  if [ $? -eq 0 ]; then
    log_debug "lock file, ${LCKFILE} removed."
  fi
fi

#Step 6 - Log exit message
log_debug "Exiting ${SCRIPT_NAME}"
	
