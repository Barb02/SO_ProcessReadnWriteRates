#!/bin/bash

if [[ $# < 1 ]] ; then
    echo "Erro, indique o número de segundos que serão usados para calcular as taxas de I/O." >&2
    exit 1
fi

if ! [[ "${@: -1}" =~ ^[0-9]+$ && ${@: -1} > 0 ]]; then  # verificar se o ultimo argumento é um int
    echo "O último argumento tem de ser um inteiro positivo" >&2
    exit 1
fi


regex='.*'
user_regex='.*'
lines=$(($(ls -v /proc/ | grep '[0-9]' | wc -l) * 2)) # multiplicar por 2 só para caso sejam abertos processos a meio
column=4 # coluna para dar sort  
reverse=1
data_minima=0
data_maxima=$(( (2**63)-1 )) # maior int
pid_minimo=0
pid_maximo=$(( (2**63)-1 )) # maior int

while getopts ":wrc:u:p:s:e:m:M:" options; do
  case "${options}" in
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
    c) 
      regex=${OPTARG}
      ;;
    u)
      user_regex=${OPTARG}
      ;;
    p)
      lines=${OPTARG}
      ;;
    s)
      data_minima=$(date -d "${OPTARG}" +%s)
      ;;
    e)
      data_maxima=$(date -d "${OPTARG}" +%s)
      ;;
    m)
      pid_minimo=${OPTARG}
      ;;
    M)
      pid_maximo=${OPTARG}
      ;;
    ?) 
          echo "Opção inválida"
          exit 1
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
    date_seconds=$(date +%s -d "$date")
    comm=$(cat /proc/$pid/comm )

    rchar_after=$(cat /proc/$pid/io | sed -n 1p | awk '{print $2}')
    wchar_after=$(cat /proc/$pid/io | sed -n 2p | awk '{print $2}')    
    rchar=$((rchar_after-rchar_before[$pid]))
    wchar=$((wchar_after-wchar_before[$pid]))
    
    if [[ $comm =~ $regex && $user =~ $user_regex && $date_seconds -ge $data_minima && $date_seconds -le $data_maxima && $pid -ge $pid_minimo && $pid -le $pid_maximo ]];then  
      format+="\n$(echo -e "$comm;$user;$pid;$rchar;$wchar;$(awk "BEGIN {print $rchar/${@: -1}}");$(awk "BEGIN {print $wchar/${@: -1}}");$date")"
    fi
done

#format=$(echo -e "$s" | \
#         awk -F "," -v reg="$regex" -v user="$user_regex" -v data_minima="$data_minima" -v data_maxima="$data_maxima" -v pid_minimo="$pid_minimo" -v pid_maximo="$pid_maximo" \
#         '{"date -d \""$8"\" +%s" | getline date; \
#         if (match($1, reg) && match($2, user) && date >= data_minima && date <= data_maxima && $3 >= pid_minimo && $3 <= pid_maximo) {print } }')


if [[ $reverse -eq 1 ]];then
  format=$(echo -e "$format" | sort -n -t ";" -k $column,$column)
else
  format=$(echo -e "$format" | sort -nr -t ";" -k $column,$column)
fi

echo -e "COMM;USER;PID;READB;WRITEB;RATER;RATEW;DATE$format" | head -n $(($lines+1)) | column -s ";" -t
