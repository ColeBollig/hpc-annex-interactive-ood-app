# Open OnDemand Interactive Application Sharing

Instructions for installing interactive application(s) for Open OnDemand.
This documentation assumes there is an interactive application that lives
in a GitHub repository such as [HTCondor's HPC Annex Launcher](https://github.com/ColeBollig/hpc-annex-interactive-ood-app).
Full details on Open OnDemand's Interactive Applications can be found in
the [OnDemand Documentation](https://osc.github.io/ood-documentation/latest/how-tos/app-development/app-sharing.html).

> [!NOTE]
> All interactive application installation occurs on the host running
> Open OnDemand.

## System Installation

### Administrator Steps

1. Ensure OnDemand in configured to show interactive applications on
   the dashboard. Check to make sure ```- “interactive apps"``` exists
   in the **nav bar** section of the default configuration file
   ```/etc/ood/config/ondemand.d/default.yml```.
2. Clone git repository to ```/var/www/ood/apps/sys```
3. Set linux permissions of the cloned repository directory
    1. ```755``` sharing with all users
    2. ```750``` for sharing with a specific linux user group (optional)
4. [Optional] Set the linux user group of the repository
5. To update the application simply do a ```git pull```.

> [!NOTE]
> Be sure to check and reset directory file permissions/ownership
> as needed after updating.

#### Example: Installing for all users

```
sudo git clone https://github.com/ColeBollig/hpc-annex-interactive-ood-app /var/www/ood/apps/sys/htcondor-annex-launcher
sudo chmod 755 /var/www/ood/apps/sys/htcondor-annex-launcher
```

#### Example: Installing for specific user group

```
sudo git clone https://github.com/ColeBollig/hpc-annex-interactive-ood-app /var/www/ood/apps/sys/htcondor-annex-launcher
sudo chmod 750 /var/www/ood/apps/sys/htcondor-annex-launcher
sudo chgrp group_name /var/www/ood/apps/sys/htcondor-annex-launcher
```

#### Example: Updating interactive application

```
sudo cd /var/www/ood/apps/sys/htcondor-annex-launcher
sudo git pull
cd /var/www/ood/apps/sys
ls -l .
```

### User Steps

1. Restart web server if needed (connection running prior to application
   installation)
    1. Click **(?) Help** drop down in the upper right of dashboard
       navigation bar
    2. Click **Restart Web Server**
2. Click **Interactive Apps** drop down on dashboard navigation bar
3. Click desired interactive application (**HTC Annex**)

## Personal User Installation

> [!NOTE]
> Open OnDemand does not have an official way of allowing users to install
> their own interactive applications. This method takes advantage of interactive
> application development functionality in Open OnDemand.

> [!WARNING]
> This will allow users to create/install whatever interactive applications
> they desire.

### Adminstrator Steps

> [!NOTE]
> This needs to be done for each user to grant installation access.
> Recommend automating somehow (e.g. puppet) if needed.

1. Create directory for the specific linux user under ```/var/www/ood/apps/dev/```
2. Change directory to new directory
3. Create symlink for ```/home/<user>/ondemand/dev``` to ```gateway```

#### Example: Enable user cabollig for app development

```
sudo mkdir -p /var/www/ood/apps/dev/cabollig
cd /var/www/ood/apps/dev/cabollig
sudo ln -s /home/cabollig/ondemand/dev gateway
```

### User Steps

1. Clone git repository into directory under ```/home/<user>/ondemand/dev```
2. Restart web server if needed (connection running prior to application
   installation)
    1. Click **(?) Help** drop down in the upper right of dashboard
       navigation bar
    2. Click **Restart Web Server**
2. Click **</> Develop** drop down in the upper right of dashboard
   navigation bar
3. Click **My Sandbox Apps (Development)**

#### Example: User application installation

```
cd ~/ondemand/dev
git clone https://github.com/ColeBollig/hpc-annex-interactive-ood-app
```
