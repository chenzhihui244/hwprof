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
	LOGIN_FILE=${1-/etc/login.defs}
	awk '/^PASS_MAX_DAYS/ { if ($2>180) {printf "PASS_MAX_DAYS(%d) violated\n", $2} }' $LOGIN_FILE
}

function shadow_pass_max_days_check {
	SHADOW_FILE=${1-/etc/shadow}
	awk -F: '{ if ($5>180) {printf "user(%s) pass max days (%d) violated\n", $1, $5} }' $SHADOW_FILE
}



#if ! uid_check; then
#	echo "uid_check failed"
#else
#	echo "uid_check ok"
#fi

#echo -e "\n===========\nuid_check\n===========\n"
#uid_check

#pass_max_days_check
shadow_pass_max_days_check
