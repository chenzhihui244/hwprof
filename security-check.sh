#!/bin/sh

# getent get username from uid
# getent passwd 0
# more /etc/passwd | awk -F: '{++uid[$3]} END {for(key in uid) print key,"\t",uid[key]}'
# more /etc/passwd | awk -F: '$3==0 {++uid[$3]} END {for(key in uid) print key,"\t",uid[key]}'
# more /etc/passwd | awk -F: 'BEGIN {print "uid\tcount"} {++uid[$3]} END {for(key in uid) print key,"\t",uid[key]}'
# more /etc/passwd | awk -F: '{if ($3 == 0) {++uid[$3]}} END {for(key in uid) print key,"\t",uid[key]}'
# more /etc/passwd | awk -F: '{++uid[$3]} END {for(key in uid) {if(uid[key]>1) {print "uid " key " duped " uid[key] " times"}}}'

function uid_check {
	UID_FILE=${1-/etc/passwd}
	cat $UID_FILE | 
		awk -F: '{++stats[$3]} 
		END {for(uid in stats) 
		{if(stats[uid]>1) {printf "uid(%d) duplicate(%d)\n", 
			uid, stats[uid]}}}'
}

function pass_max_days_check {
	local LOGIN_FILE=${1-/etc/login.defs}
	awk '/^PASS_MAX_DAYS/ { if ($2>180) {printf "PASS_MAX_DAYS(%d) violated\n", $2} }' $LOGIN_FILE
}

# return user list
function user_list {
	local CHECK_FILE=${1-/etc/passwd}
	awk -F: '{ print $1 }' $CHECK_FILE
}

# check user pass_max_days definition in shadow file
# return 0 if less then 180, return 1 else
function user_shadow_pass_max_days_check {
	local user=$1
	local SHADOW_FILE=${2-/etc/shadow}
	local expire=${3-180}

	cat $SHADOW_FILE |
	awk -F: 'BEGIN {ret=0} ($1==U) && ($5>E) {ret=1} END {exit ret}' \
		U=$user E=$expire
}

function user_shell_check {
	local user=$1
	local shell=$2
	local CHECK_FILE=${3-/etc/passwd}
	cat $CHECK_FILE |
	awk -F: 'BEGIN {ret=1} ($1==U) && ($7==S) {ret=0} END {exit ret}' \
	U=$user S=$shell
}

function user_expire_shell_check {
	local user=${1}
	local nologin_shell="/sbin/nologin"
	local false_shell="/bin/false"
	if user_shadow_pass_max_days_check $u; then
		if ! user_shell_check $user $nologin_shell ; then
			if ! user_shell_check $user $false_shell; then
				return 0
			fi
		fi
	fi
	return 1
}

# return user list whose expire days > 180
function shadow_pass_max_days_list {
	local SHADOW_FILE=${1-/etc/shadow}
	cat $SHADOW_FILE | awk -F: '$5>180 {print $1}'
}

function minilen_minclass_check {
	local CHECK_FILE=${1-/etc/pam.d/system-auth}
	cat $CHECK_FILE |
	awk ' BEGIN {ok=0}
	/dcredit=0/ && /ucredit=0/ && /ocredit=0/ && /lcredit=0/ && /passworld/ && /requisite/ && /pam_pwquality.so/ && /minclass=3/ && /minlen=8/ { ok=1 }
	END { if (ok==1) {print "OK"} else {print "FAILED"} } '

	#cat $CHECK_FILE | awk '{ if (($1=="password") && ($2=="requisite") && ($3=="pam_pwquality.so")) 
	#{ printf "echo %s\n", $6 } }' | sh 
}

function remember_check {
	local CHECK_FILE=${1-/etc/pam.d/system-auth}
	cat $CHECK_FILE |
	awk ' BEGIN {ok=0}
	/password/ && /sufficient/ && /remember=5/ {print "check ok"; exit 0}
	END {if (ok==1) {print "check OK"} else {print "check FAILED"} } '
}

#function user_shell_check {
#	local CHECK_FILE=${1-/etc/passwd}
#	cat $CHECK_FILE |
#	awk -F: '/\/sbin\/nologin/ || /\/bin\/sync/ {print $1}'
#}

function exprie_time_check {
	local CHECK_FILE=${1-/etc/passwd}
	local expire_user_list=`shadow_pass_max_days_list`
	for u in $expire_user_list; do
		cat $CHECK_FILE |
		awk -F: '(($7 !~ /\/sbin\/nologin/) && ($7 !~ /\/bin\/false/)) && ($1 ~ USERNAME) \
		{ printf "user(%s) expire days > 180\n", $1 }' \
		USERNAME=$u
	done
}

function exprie_time_check1 {
	local user_list=`user_shell_check`
	local SHADOW_FILE=${1-/etc/shadow}

	for i in $user_list; do
		echo $i
		awk -F: '$1 ~ USERNAME {print $0}' USERNAME=$i $SHADOW_FILE
		#awk -F: '{if ($1==USERNAME) {print $0}}' USERNAME=$i $SHADOW_FILE
		#awk -F: -v USERNAME=sync '{if ($1==USERNAME) {print USERNAME}}' USERNAME=sync $SHADOW_FILE
	done
}

#if ! uid_check; then
#	echo "uid_check failed"
#else
#	echo "uid_check ok"
#fi

#echo -e "\n===========\nuid_check\n===========\n"
#uid_check

#pass_max_days_check
#shadow_pass_max_days_list
#minilen_minclass_check
#remember_check
#exprie_time_check
list=`user_list`
for u in $list; do
	#if user_shadow_pass_max_days_check $u; then
	if user_expire_shell_check $u; then
		echo  "$u ok"
	else
		echo  "$u failed"
	fi
done

