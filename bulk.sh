#!/bin/bash
clear
bulkuser() {
    CYAN="\e[1;36m"
    GREEN="\e[1;32m"
    RED="\e[1;31m"
    YELLOW="\e[1;33m"
    RESET="\e[0m"
    IP=$(cat /etc/IP)

    generate_random_pass() {
        local type=$1
        local length=$2
        if [[ $type -eq 1 ]]; then
            local chars=( {0..9} )
        elif [[ $type -eq 2 ]]; then
            local chars=({a..z} {0..9})
        elif [[ $type -eq 3 ]]; then
            local chars=({a..z} {A..Z} {0..9})
        fi
        local str=""

        for ((i = 0; i < $length; i++)); do
            local rand_idx=$((RANDOM % ${#chars[@]}))
            str+="${chars[$rand_idx]}"
        done

        echo "$str"
    }

    check_username() {
        awk -F : ' { print $1 }' /etc/passwd > /tmp/users
        local rep=0
        if grep -Fxq "$1" /tmp/users; then
            local rep=1
        fi
        echo "$rep"
    }

    tput setaf 7
    tput setab 4
    tput bold
    printf "${CYAN}%30s%s%-15s\n" "BULK_USER"
    tput sgr0
    echo ""

    echo -ne "${YELLOW}Constant phrase for username (EX. opiran --> opiran01, opiran02, ... )${RESET}: "
    read constant_phrase

    if [[ -z $constant_phrase ]]; then
        echo ""
        tput setaf 7
        tput setab 1
        tput bold
        echo ""
        echo "Empty constant phrase."
        echo ""
        tput sgr0
        exit 1
    fi

    echo -ne "\033[1;32m How Many Users Do You Want To Create (It Must be > 0):\033[1;37m "
    read num

    if [[ -z $num ]] || ! [[ $num =~ ^[0-9]+$ ]]; then
        echo ""
        tput setaf 7
        tput setab 1
        tput bold
        echo ""
        echo "Invalid number of users."
        echo ""
        tput sgr0
        exit 1
    fi

    echo -ne "\033[1;32m Active Days (It Must be > 0):\033[1;37m "
    read days

    if [[ -z $days ]] || ! [[ $days =~ ^[0-9]+$ ]]; then
        echo ""
        tput setaf 7
        tput setab 1
        tput bold
        echo ""
        echo "Empty or invalid number of days."
        echo ""
        tput sgr0
        exit 1
    fi

    echo -ne "\033[1;32m A) Active Days Starts Immediately\033[1;37m "
    echo -ne "\033[1;32m B) Active Days After First Login\033[1;37m "
    read active_option

echo -ne "\033[1;32m Choose Password Option:\033[1;37m "
    echo -e "\n\033[1;32m 1) Random Password for Each User"
    echo -ne "\033[1;32m 2) Constant Password for All Users\033[1;37m "
    read password_option

    if [[ "$password_option" == "1" ]]; then
        echo -ne "\033[1;32m Enter Password Length (It must be > 0):\033[1;37m "
        read password_length

        if [[ -z "$password_length" ]] || ! [[ "$password_length" =~ ^[0-9]+$ ]]; then
            echo ""
            tput setaf 7
            tput setab 1
            tput bold
            echo ""
            echo "Invalid password length."
            echo ""
            tput sgr0
            exit 1
        fi
    else
        echo -ne "\033[1;32m Enter Constant Password for Users:\033[1;37m "
        read -s password
        echo ""
    fi

    echo "Host,Username,Password,Limit,Exp,Type" >/tmp/bulkusers

    for ((i = 1; i <= $num; i++)); do
        username="${constant_phrase}$(printf "%02d" $i)"

        if [[ "$password_option" == "1" ]]; then
            password=$(generate_random_pass 3 "$password_length")
        fi

        pass=$(perl -e 'print crypt($ARGV[0], $ARGV[1])' "$password" "$password")
        useradd -M -s /bin/false -p "$pass" "$username" >/dev/null 2>&1
        echo "$password" >/etc/VPSManager/senha/"$username"

        if [[ "$active_option" == "B" ]]; then
            # Active days start after first login
            info_date="+$days days"
            chage -d 0 -E "$(date '+%Y-%m-%d' -d "+$days days")" "$username"
        else
            # Active days start immediately
            info_date="+$days days"
        fi

        echo "$username $limit $info_date 0 $active_option" >>/root/usuarios.db
        echo "$IP $username $password $limit $info_date $active_option" >>/tmp/bulkusers

        if [[ "$active_option" == "B" ]]; then
            # Save the first login timestamp for users with active days starting after first login
            mkdir -p "/root/firstlogin"
            echo "$(date '+%s')" >"/root/firstlogin/$username"
        fi
    done

    output="/root/bulkusers-$(date '+%Y-%m-%d-%H-%M-%S')"
    column -t -s $',' /tmp/bulkusers >$output
    echo ""
    printf "${GREEN}The list is saved in $output, and also in the main-database /root/usuarios.db for a Possible backup.${RESET}\n"
    echo -e "\033[0;32m─────────────────────────────────────────────────────────────\033[0m"
    echo -e "\033[1;37m  ㅤ      ─────────── OPIRAN PANEL ───────────  \033[0m"
    echo -e "\033[0;31m─────────────────────────────────────────────────────────────\033[0m"
    echo -e "\033[1;37m                      USER LISTS "
    echo -e "\033[0;31m─────────────────────────────────────────────────────────────\033[0m"
    # Check if the /root/bulkusers-* files exist
    if ls /root/bulkusers-* 1>/dev/null 2>&1; then
        echo -e "\033[1;37mBulk User list:\033[0m"

        # Concatenate all the bulk users files and display them
        cat /root/bulkusers-* | column -t -s ','
    else
        echo -e "\033[1;31mNo bulk users have been created yet.\033[0m"
    fi

    echo -e "\033[0;31m─────────────────────────────────────────────────────────────\033[0m"

    # Decrement remaining days after first login
    database="/root/usuarios.db"
    temp_file="/tmp/t_t_t"

    for ((i = 1; i <= $num; i++)); do
        username="${constant_phrase}$(printf "%02d" $i)"
        status="$(grep -w "$username" "$database" | cut -d' ' -f4)"
        days="$(grep -w "$username" "$database" | cut -d' ' -f3)"
        active_option="$(grep -w "$username" "$database" | cut -d' ' -f6)"

        if [[ $status -eq 0 && "$active_option" == "B" ]]; then
            first_login_file="/root/firstlogin/$username"
            if [[ -f "$first_login_file" ]]; then
                first_login=$(cat "$first_login_file")
                current_time=$(date '+%s')
                seconds_passed=$((current_time - first_login))
                seconds_in_day=$((60 * 60 * 24))
                remaining_days=$((days - (seconds_passed / seconds_in_day)))
                if [[ $remaining_days -le 0 ]]; then
                    remaining_days=0
                fi
                awk -v usr="$username" -v rem_days="$remaining_days" 'BEGIN{FS=OFS=" "}{$4 = ($1 == usr ? 1 : $4); if ($4 == 1) $5 = rem_days}1' "$database" >"$temp_file" && mv "$temp_file" "$database"
                expiration=$(date "+%Y-%m-%d" -d "+$remaining_days days")
                chage -E "$expiration" "$username"
            fi
        fi
    done
}
# Call the function
bulkuser
