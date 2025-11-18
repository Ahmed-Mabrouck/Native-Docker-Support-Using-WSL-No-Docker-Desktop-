# Native Docker Support Using WSL No Docker Desktop
This is a complete guide to configure your docker on Windows machines using WSL without Docker Desktop for better performance and license issue for enterprise.

## Install Latest Version of Ubuntu WSL2 from Microsoft Store

```powershell
wsl --list --online
wsl --install -d <DistroName>
```

Replace `<DistroName>` with the latest Ubuntu distro.

For more details follow this official tutorial: 🔗 [Install WSL | Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/install)

## Install Docker on Your WSL2

### Setup Docker's apt repository

```bash
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

### Install Docker's Packages

```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Verify Successful Installation by Running hello-world Image

```bash
sudo docker run hello-world
```

For more details follow this official tutorial: 🔗 [Ubuntu | Docker Docs](https://docs.docker.com/engine/install/ubuntu/)

## Configure Docker to Run as Service within WSL Startup

### Configure Docker to Run without sudo

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
```

### Verify Successful Configurations to Run without Sudo

```bash
docker run hello-world
```

### Make Sure that systemd Service Manager Is Enabled

#### Run The Following Bash Command

```bash
cat /etc/wsl.conf
```

#### Make Sure that the File Contains the Following Lines (Mainly at The Top of The File)

````bash
[boot]
systemd=true
````

:exclamation: If The File Does not Contain The Above Lines (Most Probably Will Contain Them) or the file is not created, Create it and add them to the top of the file.

#### Add Docker as Services to systemd Service Manager

````bash
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
````

For more details follow this official tutorial: 🔗 [Post-installation steps | Docker Docs](https://docs.docker.com/engine/install/linux-postinstall/)

## Configure Docker Host to Be Exposed for Remote Connections

### Update Docker Daemon to Listen on TCP 2375

#### Run this Bash Command to Update Docker systemd Service

````bash
sudo systemctl edit docker.service
````

#### Add the Following Block to the docker.service File then Save It to 

````
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375
````

### Restart Docker Daemon and systemd Service 

#### Run this Bash Command to Reload Docker Daemon and Restart systemd Service

````bash
sudo systemctl daemon-reload
sudo systemctl restart docker.service
````

:exclamation: You can make sure that the service is up and running by running `sudo systemctl status docker.service` and make sure there is no error in the log.

## Configure Windows Host Machine to Connect Remotely to WSL Docker Host

### Test Connectivity

#### :link: Navigate to the Following URL from Your Windows Host Machine: 

````code
http://localhost:2375/version
````

#### You Should Receive a JSON Response Contains Informaton about You WSL Docker (Info varies, success response is the core)

````json
{"Platform":{"Name":"Docker Engine - Community"},"Components":[{"Name":"Engine","Version":"28.3.3","Details":{"ApiVersion":"1.51","Arch":"amd64","BuildTime":"2025-07-25T11:34:09.000000000+00:00","Experimental":"false","GitCommit":"bea959c","GoVersion":"go1.24.5","KernelVersion":"6.6.87.2-microsoft-standard-WSL2","MinAPIVersion":"1.24","Os":"linux"}},{"Name":"containerd","Version":"1.7.27","Details":{"GitCommit":"05044ec0a9a75232cad458027ca83437aae3f4da"}},{"Name":"runc","Version":"1.2.5","Details":{"GitCommit":"v1.2.5-0-g59923ef"}},{"Name":"docker-init","Version":"0.19.0","Details":{"GitCommit":"de40ad0"}}],"Version":"28.3.3","ApiVersion":"1.51","MinAPIVersion":"1.24","GitCommit":"bea959c","GoVersion":"go1.24.5","Os":"linux","Arch":"amd64","KernelVersion":"6.6.87.2-microsoft-standard-WSL2","BuildTime":"2025-07-25T11:34:09.000000000+00:00"}
````

### Download Docker CLI Tools on Your Windows Host Machine (Choose the version that matches your WSL Docker version)

🔗 [Index of win/static/stable/x86_64/](https://download.docker.com/win/static/stable/x86_64/)

### Extract the Downloaded Archive to any Desired Path and Add this Path to Your PATH Environment Variable on Your Windows Host Machine

### Create a New Docker Context to Connect to WSL Docker through TCP

````bash
docker context create wsl --docker host={WSL_DOCKER_HOST} --description "WSL remote context"
````
Replace `{WSL_DOCKER_HOST}` with one of the following options (only one of them will work according to network configurations):
- [x] tcp://localhost:2375 
- [x] tcp://[::1]:2375
      
### Configure Docker to Use wsl Context

````bash
docker context use wsl
````

### Make Sure The Context Successfully Selected

#### Run the Following Bash Command

````bash
docker context ls
````

#### Make Sure that the Output Is as Follows (an (*) at wsl which means it is currently selected)

````bash
NAME      DESCRIPTION                               DOCKER ENDPOINT                  ERROR
default   Current DOCKER_HOST based configuration   npipe:////./pipe/docker_engine
wsl *     WSL context                               tcp://localhost:2375
````

### Test Connectivity to Remote WSL Docker Endpoint

#### Execute the Following CMD/PowerShell Command a New Terminal Window

````powershell
docker ps
````

#### The Output Should Be as Follows (Containers list info varies, no errors with heads as follows is O.K)

````powershell
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
````

:exclamation: If one WSL host did not work you have to revert back to default context, remove wsl context and repeat the context creation steps using the other one.

:exclamation: If both WSL hosts did not work, make sure that your WSL and Docker service are running and healthy.

For more details follow this official tutorial: 🔗 [Docker contexts | Docker Docs](https://docs.docker.com/engine/manage-resources/contexts/)

## Optional: Add Docker Compose Support on Your Windows Machine

### Download Docker Compose V2 Plugin Your Windows Host Machine (Chooe Your Desired Version)

🔗 [Releases · docker/compose · GitHub](https://github.com/docker/compose/releases)

### Execute the Following Command to Create Docker Compose Plugin Default Directory

````powershell
mkdir $env:USERPROFILE\.docker\cli-plugins -Force
````
### Put the Downloaded Executable to the Created Directory then Rename it to be docker-compose.exe

### Make Sure Docker Compose Successfull Installation
#### Execute the Following Command in a New Terminal Window
````powershell
docker compose version
````
#### Make Sure The Output Is as Follows (Version number varies, you should receive the downloaded version with no errors)

````powershell
Docker Compose version v2.40.3
````

### 🔥 Congratulations; Now You Can Use Docker Natively in Your Windows Machine without Docker Desktop

## ⭐ Bonus Part: Run Your WSL Machine on Your Windows Startup to Match Native Experience

### You Can Run the PowerShell Script in That Repo Called: 📁 WSL-Delayed-Startup-with-KeepAlive.ps1 that can achieve the following:

1. Runs WSL instance on user logon event with a delay (configurable delay can be updated from the file) to eliminate effect on your Windows machine booting performance.
2. It runs an inifite wait process to pin WSL process running until you shut it down manually.
3. It uses Windows Scheduled Tasks to do this job

❓The script is well-documented and you can ask for help for any updates.
