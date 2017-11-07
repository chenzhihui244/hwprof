#!/bin/sh

# getent get username from uid
# getent passwd 0
# more /etc/passwd | awk -F: '{++uid[$3]} END {for(key in uid) print key,"\t",uid[key]}'
# more /etc/passwd | awk -F: '$3==0 {++uid[$3]} END {for(key in uid) print key,"\t",uid[key]}'
# more /etc/passwd | awk -F: 'BEGIN {print "uid\tcount"} {++uid[$3]} END {for(key in uid) print key,"\t",uid[key]}'
# more /etc/passwd | awk -F: '{if ($3 == 0) {++uid[$3]}} END {for(key in uid) print key,"\t",uid[key]}'
# more /etc/passwd | awk -F: '{++uid[$3]} END {for(key in uid) {if(uid[key]>1) {print "uid " key " duped " uid[key] " times"}}}'

function uid_dup_check {
	UID_FILE=${1-/etc/passwd}
	cat $UID_FILE | 
		awk -F: '{++stats[$3]} 
		END {for(uid in stats) 
		{if(stats[uid]>1) {printf "uid(%d) duplicate(%d)\n", 
			uid, stats[uid]; exit 1 }}}'
}

function pass_max_days_check {
	local LOGIN_FILE=${1-/etc/login.defs}
	awk '/^PASS_MAX_DAYS/ { if ($2>180) {printf "PASS_MAX_DAYS(%d) violated\n", $2} }'
		$LOGIN_FILE
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
	awk -F: 'BEGIN {ret=1} ($1==U) && ($5<=E) {ret=0} END {exit ret}' \
		U=$user E=$expire
}

# check user shell, return 0 if match, or return 1
function user_shell_check {
	local user=$1
	local shell=$2
	local CHECK_FILE=${3-/etc/passwd}
	cat $CHECK_FILE |
	awk -F: 'BEGIN {ret=1} ($1==U) && ($7==S) {ret=0} END {exit ret}' \
	U=$user S=$shell
}

# check whether user id locked, return 0 if locked, or return 1
function user_id_lock_check {
	local user=$1
	local SHADOW_FILE=${2-/etc/shadow}
	cat $SHADOW_FILE |
	awk -F: 'BEGIN {ret=1} \
		($1==U) && (($2=="!!") || ($2=="!") || ($2=="*") || ($2=="x") || ($2=="!$")) {ret=0} \
		END {exit ret}' U=$user
}

# check whether user passwd expire setting is ok,
# requirement:
#   expire days < 180, or
#   user id locked, or
#   user shell is /sbin/nologin, or
#   user shell is /bin/false
function user_expire_shell_check {
	local user=${1}
	local nologin_shell="/sbin/nologin"
	local false_shell="/bin/false"

	if user_shadow_pass_max_days_check $user; then
		echo "$user user_shadow_pass_max_days_check ok"
		return 0
	fi

	if user_id_lock_check $user; then
		echo "$user user_id_lock_check ok"
		return 0
	fi

	if user_shell_check $user $nologin_shell ; then
		echo "$user user_shell_check $nologin_shell ok"
		return 0
	fi

	if user_shell_check $user $false_shell; then
		echo "$user user_shell_check $false_shell ok"
		return 0
	fi

	return 1
}

function system_user_passwd_check {
	list=`user_list`
	for u in $list; do
		if user_expire_shell_check $u; then
			echo  "$u ok"
		else
			echo  "$u failed"
		fi
	done
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

#check ssh auth file, return 0 if not exist or empty, or return 1
function system_ssh_auth_check {
	local CHECK_FILE=${1-/root/.ssh/authorized_keys}
	
	[ ! -e $CHECK_FILE ] && return 0
	[[ `cat $CHECK_FILE | wc -l` -eq 0 ]] && return 0
	return 1
}

# check tmout setting in /etc/profile
# return 0 if ok, or return 1
function system_tmout_check {
	local CHECK_FILE=${1-/etc/profile}
	local timeout=${2-1800}

	grep -q "readonly TMOUT" $CHECK_FILE || return 1
	grep -q "export TMOUT" $CHECK_FILE || return 1

	cat $CHECK_FILE | \
	awk -F= 'BEGIN {ret=1} ($1=="TMOUT") && ($2<=TO) {ret=0} END {exit ret}' TO=$timeout && return 0

	return 1
}

# check if ctrl-alt-del target exist, return 1 if exist, or return 0
function ctrlaltdel_check {
	local CHECK_FILE=${1-/usr/lib/systemd/system/ctrl-alt-del.target}

	[ -e $CHECK_FILE ] && return 1 || return 0
}

# check /etc/motd file, return 0 if ok, or return 1
function system_motd_check {
	local CHECK_FILE=${1-/etc/motd}
	#local TMP_FILE=/etc/motd
	local TMP_FILE=/tmp/msg
	cat <<EOF > $TMP_FILE
Huawei's internal systems must only be used for conducting
EOF
	md5sum $CHECK_FILE $TMP_FILE |
	awk '(NR==1) {MD5_CHECK=$1} (NR==2) {MD5_TMP=$1} \
		END { if (MD5_CHECK==MD5_TMP) exit 0; else exit 1 }'
}

function system_umask_check {
	local CHECK_FILE=/etc/login.defs
	cat $CHECK_FILE |
	awk '($1=="UMASK") {GM=substr($2,2,1); OM=substr($2,3,1)} \
	END {if ((GM=="2" || GM=="3" || GM=="6" || GM=="7") && (OM=="2" || GM=="3" || GM=="6" || GM=="7")) \
	exit 0; else exit 1}'
}

# check user's passwd, return 0 if ok, or return 1
function user_passwd_check {
	local user=$1
	local PASSWD_FILE=/etc/passwd
	local SHADOW_FILE=/etc/shadow
	cat $PASSWD_FILE |
	awk -F: 'BEGIN {ret=0} ($1==U) && ($2!="x") {ret=1} END {exit ret}' U=$user || return 1
	cat $SHADOW_FILE |
	awk -F: 'BEGIN {ret=0} ($1==U) && ($2=="") {ret=1} END {exit ret}' U=$user
}

function system_passwd_check {
	list=`user_list`
	for user in $list; do
		user_passwd_check $user
		if [ $? -eq 0 ]; then echo "user $user ok"; else echo "user $user failed"; fi
	done
}

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

#system_user_passwd_check
#system_tmout_check
#ctrlaltdel_check
#system_motd_check
#system_umask_check
system_passwd_check
if [ $? -eq 0 ]; then
	echo "system_passwd_check ok"
else
	echo "system_passwd_check failed"
fi
