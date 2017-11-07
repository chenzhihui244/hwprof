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

# check system passwd setting, return 0 if ok, or return 1
function system_passwd_check {
	list=`user_list`
	for user in $list; do
		user_passwd_check $user
		if [ $? -eq 0 ]; then echo "user $user ok"; else echo "user $user failed"; fi
	done
}

# check shadow file permission, return 0 if ok, or return 1
function system_shadow_perm_check {
	local SHADOW_FILE=${1-/etc/shadow}
	ls -l $SHADOW_FILE |
	awk '{if ((substr($1,4,1) != "-") || (substr($1,6,5) != "-----")) exit 1; else exit 0}'
}

# check shadow file encryption setting, return 0 if ok, or return 1
function system_shadow_encryption_check {
	local CHECK_FILE=${1-/etc/pam.d/system-auth}
	cat $CHECK_FILE |
	awk 'BEGIN {ret=0} \
	($1=="password") && ($2=="sufficient") && ($3=="pam_unix.so") \
	{if ($0 ~ /md5 shadow/) ret=1; if ($0 !~ /sha512 shadow/) ret=1}
	END {exit ret}'
}

# check whether rhosts file exist, return 0 if no exist, or return 1
function system_rhosts_check {
	local CHECK_FILE=${1-/root/.rhosts}
	[ -e $CHECK_FILE ] && return 1 || return 0
}

# check netrc file, return 0 if ok, or return 1
function system_netrc_check {
	local CHECK_FILE=${1-/root/.netrc}
	if [ -e $CHECK_FILE ]; then
		perm=`ls -l $CHECK_FILE | awk '{print $1}'`
		echo "${perm:3}"
		[[ ${perm:1} != "-------" ]] || return 1
	fi
	return 0
}

function system_root_perm_check {
	perm=`ls -la / | awk '($9=="."){print $1}'`
	[[ ${perm:8:1} == "w" ]] && return 1 || return 0
}

function system_usr_perm_check {
	perm=`ls -l / | awk '($9=="usr"){print $1}'`
	echo $perm
	[[ ${perm:8:1} == "w" ]] && return 1 || return 0
}

function system_etc_perm_check {
	perm=`ls -l / | awk '($9=="etc"){print $1}'`
	echo $perm
	[[ ${perm:8:1} == "w" ]] && return 1 || return 0
}

function system_var_log_perm_check {
	perm=`ls -l /var | awk '($9=="log"){print $1}'`
	[[ ${perm:8:1} == "w" ]] && return 1 || return 0
}

function system_tmp_perm_check {
	perm=`ls -l / | awk '($9=="tmp"){print $1}'`
	echo $perm
	[[ ${perm:1:9} == "rwxrwxrwt" ]] && return 0 || return 1
}

function system_snmpd_perm_check {
	CHECK_FILE=/etc/snmp/snmpd.conf
	if [ -e $CHECK_FILE ]; then
		perm=`ls -l $CHECK_FILE | awk '{print $1}'`
		#echo $perm
		[[ ${perm:3:1} != "-" ]] && return 1
		[[ ${perm:5:5} != "-----" ]] && return 1
	fi
	return 0
}

function ssh_login_retries_check {
	CHECK_FILE=/etc/ssh/sshd_config
	
	grep -q "^MaxAuthTries 2$" $CHECK_FILE
}

# check /etc/rsyslog.conf, ok return 0, or return 1
function system_rsyslog_check {
	CHECK_FILE=/etc/rsyslog.conf

	cat $CHECK_FILE |
	awk 'BEGIN {TEST1=1; TEST2=1} \
	($1 ~ /^\*\.info;mail\.none;authpriv\.none\>/) && ($2 ~ /\<var\/log\/messages$/) {TEST1=0}; \
	($1 ~ /^authpriv\.\*/) && ($2 ~ /\<var\/log\/secure$/) {TEST2=0} \
	END {if ((TEST1==0) && (TEST2==0)) exit 0; else exit 1}'
}

function system_wtmp_check {
	test -e /var/log/wtmp
}

function system_messages_check {
	test -e /var/log/messages
}

function system_secure_check {
	test -e /var/log/secure
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

function system_log_rotate_check {
	local CHECK_FILE=${1-/etc/logrotate.conf}

	cat $CHECK_FILE |
	awk 'BEGIN {MOK=1; ROK=1} \
	$0 ~ /^monthly$/ {MOK=0}; \
	($1=="rotate") && ($2>=3) {ROK=0}; \
	$0 ~ /{/ {exit 0} \
	END {if((MOK==0) && (ROK==0)) exit 0; else exit 1}'
}

# check wtmp config at /etc/logrotate.conf, return 0 if ok
function system_wtmp_rotate_check {
	local CHECK_FILE=${1-/etc/logrotate.conf}

	cat $CHECK_FILE |
	awk 'BEGIN {FOUND=1; MOK=1; ROK=1} \
	$0 ~ /^\/var\/log\/wtmp {$/ {FOUND=0}; \
	($1=="monthly") {if (FOUND==0) MOK=0}; \
	($1=="rotate") && ($2>=3) {if (FOUND==0) ROK=0}; \
	$0 ~ /}/ {if (FOUND==0) exit 0} \
	END {if((MOK==0) && (ROK==0)) exit 0; else exit 1}'
}

function system_host_check {
	local CHECK_FILE=${1-/etc/host.conf}

	grep -q "nospoof on" $CHECK_FILE
}

function system_export_check {
	CHECK_FILE=/etc/exports
	[[ -e $CHECK_FILE ]] || return 1
	perm=`ls -l $CHECK_FILE | awk '{print $1}'`
	[[ ${perm:1:9} == "rw-r--r--" ]] || return 1
}

# check if service exists, return 1 if exist, or return 0
function service_check {
	SERVICE=$1
	systemctl list-units -t service | grep ${SERVICE} > /dev/null 2>&1 && return 1
	systemctl list-unit-files | grep ${SERVICE} > /dev/null 2>&1 && return 1
	return 0
}

function system_synccookies_check {
	CHECK_FILE=${1-/etc/sysctl.conf}

	awk -F= 'BEGIN {ret=1} \
	($1 ~ /^net\.ipv4\.tcp_syncookies/) {if ($2==1) ret=0} \
	END {exit ret}' $CHECK_FILE
}

function system_icmp_check {
	CHECK_FILE=${1-/etc/sysctl.conf}

	awk -F= 'BEGIN {ret=1} \
	($1 ~ /^net\.ipv4\.icmp_echo_ignore_broadcasts/) {if ($2==1) ret=0} \
	END {exit ret}' $CHECK_FILE
}

function system_redirect_check {
	CHECK_FILE=${1-/etc/sysctl.conf}

	awk -F= 'BEGIN {ret=1} \
	($1 ~ /^net\.ipv4\.conf\.all\.accept_redirects/) {if ($2==0) ret=0} \
	END {exit ret}' $CHECK_FILE
}

function system_hosts_equiv_check {
	[[ -e /etc/hosts.equiv ]] && return 1 || return 0
}

function ssh_protocol_version_check {
	local CHECK_FILE=${1-/etc/ssh/sshd_config}
	cat $CHECK_FILE |
	awk 'BEGIN {ret=1} \
	($1=="Protocol") {if($2==2) ret=0} \
	END {exit ret}'
}

function ssh_pam_check {
	local CHECK_FILE=${1-/etc/ssh/sshd_config}
	cat $CHECK_FILE |
	awk 'BEGIN {ret=1} \
	($1=="UsePAM") {if($2=="yes") ret=0} \
	END {exit ret}'
}

function do_check {
	echo -e "\n======================"
	if ! eval "$@"; then
		echo >&2 "Check failed \"$@\""
		exit 1
	else
		echo >&2 "Check OK \"$@\""
	fi
	echo -e "======================\n"

}

#if ! uid_check; then
#	echo "uid_check failed"
#else
#	echo "uid_check ok"
#fi

#echo -e "\n===========\nuid_check\n===========\n"
#uid_check

do_check minilen_minclass_check
do_check remember_check
do_check exprie_time_check
do_check system_user_passwd_check
do_check system_tmout_check
do_check ctrlaltdel_check
do_check system_motd_check
do_check system_umask_check
do_check system_passwd_check
do_check system_shadow_perm_check
do_check system_shadow_encryption_check
do_check system_rhosts_check
do_check system_netrc_check
do_check system_root_perm_check
do_check system_usr_perm_check
do_check system_var_log_perm_check
do_check system_tmp_perm_check
do_check system_snmpd_perm_check
do_check ssh_login_retries_check
do_check system_rsyslog_check
do_check system_wtmp_check
do_check system_messages_check
do_check system_secure_check
do_check system_log_rotate_check
do_check system_wtmp_rotate_check
do_check system_host_check
do_check system_export_check
do_check service_check sendmail
do_check service_check pppoe
do_check service_check zebra
do_check service_check isdn
do_check system_synccookies_check
do_check system_icmp_check
do_check system_redirect_check
do_check system_hosts_equiv_check
do_check ssh_protocol_version_check
do_check ssh_pam_check
