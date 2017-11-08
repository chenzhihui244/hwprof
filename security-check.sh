#!/bin/sh

function system_uid_dup_check {
	UID_FILE=${1-/etc/passwd}
	cat $UID_FILE | 
	awk -F: 'BEGIN {ret=0} \
	{++stats[$3]} 
	END {for(uid in stats) {if(stats[uid]>1) ret=1}; exit ret}'
}

function pass_max_days_check {
	local LOGIN_FILE=${1-/etc/login.defs}
	awk 'BEGIN {ret=1} \
	/^PASS_MAX_DAYS/ { if ($2<=180) {ret=0} } \
	END {exit ret}' $LOGIN_FILE
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

# check whether user passwd expiry setting is ok,
# requirement:
#   expire days < 180, or
#   user id locked, or
#   user shell is /sbin/nologin, or
#   user shell is /bin/false
function user_expire_shell_check {
	local user=${1}
	local nologin_shell="/sbin/nologin"
	local false_shell="/bin/false"

	user_shadow_pass_max_days_check $user && return 0
	user_id_lock_check $user && return 0
	user_shell_check $user $nologin_shell && return 0
	user_shell_check $user $false_shell && return 0
	return 1
}

function system_user_passwd_check {
	list=`user_list`
	for u in $list; do
		user_expire_shell_check $u || return 1
	done
	return 0
}

# FIXME: minlen>8
function minilen_minclass_check {
	local CHECK_FILE=${1-/etc/pam.d/system-auth}
	cat $CHECK_FILE |
	awk ' BEGIN {ret=1}
	/^password/ && /requisite/ && /pam_pwquality\.so/ && /dcredit=0/ && /ucredit=0/ && /ocredit=0/ && /lcredit=0/ && /minclass=3/ && /minlen=/ \
	{for(i=1;i<=NF;i++) {if ($i ~ /minlen=/) {day=substr($i,8); if(day>=8) ret=0}}}
	END {exit ret} '
}

# FIXME: remember>5
function remember_check {
	local CHECK_FILE=${1-/etc/pam.d/system-auth}
	cat $CHECK_FILE |
	awk ' BEGIN {ret=1}
	/^password/ && /sufficient/ && /pam_unix\.so/ && /remember=/ \
	{for(i=1;i<=NF;i++) {if ($i ~ /remember=/) {day=substr($i,10); if(day>=5) ret=0}}}
	END {exit ret} '
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
	awk -F= 'BEGIN {ret=1} ($1=="TMOUT") && ($2<=TO) {ret=0} END {exit ret}' TO=$timeout
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
Huawei's internal systems must only be used for conducting Huawei's business or for purposes authorized by Huawei management.Use is subject to audit at any time by Huawei management.
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
	awk -F: 'BEGIN {ret=1} ($1==U) && ($2=="x") {ret=0} END {exit ret}' U=$user || return 1
	cat $SHADOW_FILE |
	awk -F: 'BEGIN {ret=1} ($1==U) && ($2!="") {ret=0} END {exit ret}' U=$user
}

# check system passwd setting, return 0 if ok, or return 1
function system_passwd_check {
	list=`user_list`
	for user in $list; do
		user_passwd_check $user || return 1
		#if [ $? -eq 0 ]; then echo "user $user ok"; else echo "user $user failed"; fi
	done
}

# check shadow file permission, return 0 if ok, or return 1
function system_shadow_perm_check {
	local SHADOW_FILE=${1-/etc/shadow}
	ls -l $SHADOW_FILE |
	awk '{if ((substr($1,4,1) == "-") && (substr($1,6,5) == "-----")) exit 0; else exit 1}'
}

# check shadow file encryption setting, return 0 if ok, or return 1
function system_shadow_encryption_check {
	local CHECK_FILE=${1-/etc/pam.d/system-auth}
	cat $CHECK_FILE |
	awk 'BEGIN {ret=1} \
	($1=="password") && ($2=="sufficient") && ($3=="pam_unix.so") \
	{if ($0 ~ /sha512 shadow/) ret=0; if ($0 ~ /md5 shadow/) ret=1} \
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
		[[ ${perm:2:8} == "--------" ]] || return 1
	fi
	return 0
}

function system_root_perm_check {
	perm=`ls -la / | awk '($9=="."){print $1}'`
	[[ ${perm:8:1} == "w" ]] && return 1 || return 0
}

function system_usr_perm_check {
	perm=`ls -l / | awk '($9=="usr"){print $1}'`
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

function system_log_rotate_check {
	local CHECK_FILE=${1-/etc/logrotate.conf}

	cat $CHECK_FILE |
	awk 'BEGIN {MOK=1; ROK=1} \
	$0 ~ /^monthly$/ {MOK=0}; \
	$0 ~ /^weekly$/ {MOK=1}; \
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
	[[ `ls -l $CHECK_FILE | awk '{print $3}'` == "root" ]] || return 1
	perm=`ls -l $CHECK_FILE | awk '{print $1}'`
	[[ ${perm:1:9} == "rw-r--r--" ]] || return 1
}

# check if service exists, return 1 if exist, or return 0
function service_check {
	SERVICE=$1
	systemctl list-units -t service | grep -q ${SERVICE} && return 1
	systemctl list-unit-files | grep -q ${SERVICE} && return 1
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
	($1=="Protocol") {if($2>=2) ret=0} \
	END {exit ret}'
}

function ssh_pam_check {
	local CHECK_FILE=${1-/etc/ssh/sshd_config}
	cat $CHECK_FILE |
	awk 'BEGIN {ret=1} \
	($1=="UsePAM") {if($2=="yes") ret=0} \
	END {exit ret}'
}

function ftp_anonymous_check {
	local CHECK_FILE=${1-/etc/vsftpd/vsftpd.conf}

	[ -e $CHECK_FILE ] || return 0
	cat $CHECK_FILE |
	awk -F= 'BEGIN {ret=1} \
	($1=="anonymous_enable") {if(toupper($2)!="YES") ret=0} \
	END {exit ret}'
}

# return 0 if userlist_deny=NO, or return 1
function ftp_userlist_deny_no_check {
	CHECK_FILE=${1-/etc/vsftpd/vsftpd.conf}
	cat $CHECK_FILE |
	awk -F= 'BEGIN {ret=1} \
	($1=="userlist_deny") {if(toupper($2)=="NO") ret=0} \
	END {exit ret}'
}

function ftp_root_check {
	local ULIST_FILE=/etc/vsftpd/user_list

	grep -q "^root$" /etc/vsftpd/ftpusers || return 1

	if ftp_userlist_deny_no_check; then
		grep -q "^root$" $ULIST_FILE && return 1
	else
		grep -q "^root$" $ULIST_FILE || return 1
	fi
	return 0
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

do_check system_uid_dup_check
do_check pass_max_days_check
do_check minilen_minclass_check
do_check remember_check
do_check system_user_passwd_check
do_check system_ssh_auth_check
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
do_check service_check bootps
do_check service_check pure-ftpd
do_check service_check pppoe
do_check service_check sendmail
do_check service_check zebra
do_check service_check isdn
do_check system_synccookies_check
do_check system_icmp_check
do_check system_redirect_check
do_check system_hosts_equiv_check
do_check ssh_protocol_version_check
do_check ssh_pam_check
do_check ftp_root_check
do_check ftp_anonymous_check
