#!/bin/bash
source .env
ostype() { echo $OSTYPE | tr '[A-Z]' '[a-z]'; }
export SHELL_PLATFORM='unknown'
case "$(ostype)" in
	*'linux'*	) SHELL_PLATFORM='linux'	;;
	*'darwin'*	) SHELL_PLATFORM='osx'		;;
	*'bsd'*		) SHELL_PLATFORM='bsd'		;;
esac

shell_is_linux() { test $SHELL_PLATFORM = 'linux' || test $SHELL_PLATFORM = 'bsd' ; }
shell_is_osx()   { test $SHELL_PLATFORM = 'osx' ; }
shell_is_bsd()   { test $SHELL_PLATFORM = 'bsd' || test $SHELL_PLATFORM = 'osx' ; }

get_ip() {
	if shell_is_bsd || shell_is_osx ; then
		all_nics=$(ifconfig 2>/dev/null | awk -F':' '/^[a-z]/ && !/^lo/ { print $1 }')
		for nic in ${all_nics[@]}; do
			ipv4s_on_nic=$(ifconfig ${nic} 2>/dev/null | awk '$1 == "inet" { print $2 }')
			for lan_ip in ${ipv4s_on_nic[@]}; do
				[[ -n "${lan_ip}" ]] && break
			done
			[[ -n "${lan_ip}" ]] && break
		done
	else
		# Get the names of all attached NICs.
		all_nics="$(ip addr show | cut -d ' ' -f2 | tr -d :)"
		all_nics=(${all_nics[@]//lo/})	 # Remove lo interface.

		for nic in "${all_nics[@]}"; do
			# Parse IP address for the NIC.
			lan_ip="$(ip addr show ${nic} | grep '\<inet\>' | tr -s ' ' | cut -d ' ' -f3)"
			# Trim the CIDR suffix.
			lan_ip="${lan_ip%/*}"
			# Only display the last entry
			lan_ip="$(echo "$lan_ip" | tail -1)"

			[ -n "$lan_ip" ] && break
		done
	fi

	echo "${lan_ip-N/a}"
	return 0
}

ipaddr="$(get_ip)"
touch previous_ip.txt
prev_ipaddr=$(cat previous_ip.txt)
if [ "$ipaddr" != "$prev_ipaddr" ]; then
	curl --header "Access-Token: $ACCESS_TOKEN" \
		--header 'Content-Type: application/json' \
		--data-binary "{\"body\":\"updated: ${ipaddr}\", \"title\":\"dlbox ip address\", \"type\":\"note\"}" \
		--request POST \
		https://api.pushbullet.com/v2/pushes
	notified=$?
	if [ $notified -eq 0 ]; then
		echo $ipaddr > previous_ip.txt
	fi
fi

