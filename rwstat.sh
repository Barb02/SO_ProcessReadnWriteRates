#!/bin/bash

if [[ $# < 1 ]] ; then
    echo "Erro, indique o número de segundos que serão usados para calcular as taxas de I/O." >&2; 
    exit 1;
fi

regex='.*'

while getopts "c:" options; do
	case "${options}" in 
		c) 
			regex=${OPTARG}
			;; 
	esac
done

for pid in $(ls -v /proc/ | grep '[0-9]')
do

    if ! [[ -d "/proc/$pid" ]]; then
        continue    
    fi
    
    rchar_before[$pid]=$(cat /proc/$pid/io | sed -n 1p | awk '{print $2}')
    wchar_before[$pid]=$(cat /proc/$pid/io | sed -n 2p | awk '{print $2}')

done

sleep ${@: -1}  # busca o último argumento

for pid in $(ls -v /proc/ | grep '[0-9]')
do

    if ! [[ -d "/proc/$pid" ]]; then
        continue    
    fi

    user=$(ls -l /proc/$pid/io | awk '{print $3}')
    date=$(ls -l /proc/$pid/io | awk '{print $6,$7,$8}')
    #ds = $(date -d 'date' +%s)
    comm=$(cat /proc/$pid/comm )

    rchar_after=$(cat /proc/$pid/io | sed -n 1p | awk '{print $2}')
    wchar_after=$(cat /proc/$pid/io | sed -n 2p | awk '{print $2}')    
    rchar=$((rchar_after-rchar_before[$pid]))
    wchar=$((wchar_after-wchar_before[$pid]))
    
    s+="\n$(printf "%s,%s,%s,%s,%s,%s,%s,%s\n" "$comm" "$user" "$pid" "$rchar" "$wchar" "$(awk "BEGIN {print $rchar/${@: -1}}")" "$(awk "BEGIN {print $wchar/${@: -1}}")" "$date")"

done


t=$(echo -e "$s"  | awk -v reg="$regex" '$1~reg'| sort -t, -nr -k4)
echo -e "COMM,USER,PID,READB,WRITEB,RATER,RATEW,DATE\n$t" | column -s, -t