#!/bin/bash

if [[ $# < 1 ]] ; then
    echo "Erro, indique o número de segundos que serão usados para calcular as taxas de I/O." >&2; 
    exit 1;
fi

regex='.*'
user_regex='.*'
lines=$(($(ls -v /proc/ | grep '[0-9]' | wc -l) * 2)) # multiplicar por 2 só para caso sejam abertos processos a meio
column=4 # coluna para dar sort  
reverse=1

while getopts "wrc:u:p:" options; do
  case "${options}" in 
    c) 
			regex=${OPTARG}
			;;
		u)
			user_regex=${OPTARG}
			;;
		p)
			lines=${OPTARG}
			;;
    w)
      column=5
      if [[ $reverse -eq 1 ]];then   # temos de dar reverse no -w pois o $reverse é 1 by default
        reverse=0
      else
        reverse=1
      fi
      ;;
    r)
      if [[ $reverse -eq 1 ]];then
        reverse=0
      else
        reverse=1
      fi
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
    
    s+="\n$(echo -e "$comm,$user,$pid,$rchar,$wchar,$(awk "BEGIN {print $rchar/${@: -1}}"),$(awk "BEGIN {print $wchar/${@: -1}}"),$date")"
    
done

format=$(echo -e "$s" | awk -F "," -v reg="$regex" -v user="$user_regex" 'match($1, reg) && match($2, user)')

#sorting

if [[ $reverse -eq 1 ]];then
  format=$(echo -e "$format" | sort -n -t, -k $column,$column)
else
  format=$(echo -e "$format" | sort -nr -t, -k $column,$column)
fi

format=$(echo -e "$format" | head -n $lines)

echo -e "COMM,USER,PID,READB,WRITEB,RATER,RATEW,DATE\n$format" | column -s, -t
