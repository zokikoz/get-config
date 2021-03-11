English | [Русский](./README-ru.md)

# get-config
Gets configurations of network devices via telnet session

Script is designed to poll various managed network devices (switches, routers, firewalls, etc.) in order to automatically collect their configuration. Connection to devices is carried out using a telnet connection, which is implemented through the [Net::Telnet](https://github.com/ruby/net-telnet) class.

## Installation
You need to install [Ruby](https://www.ruby-lang.org/en/documentation/installation/)

and [Net::Telnet](https://github.com/ruby/net-telnet) class via gem library:
```
$ gem install net-telnet
```

## Usage
### Configuration
The script consists of two files: executable **[get-conf.rb](./get-conf.rb)** and included **[templates.rb](./templates.rb)**.
The **[templates.rb](./templates.rb)** file contains templates for polling devices.
At the beginning of the **[get-conf.rb](./get-conf.rb)** file is the main configuration block. By default, no changes are required.
```ruby
CONFIG = {
  archv_dir: 'archive',    # Path to the directory where the configuration archive is stored
  pool_file: %w[pool.yml], # Device pool filename, when using multiple files, separate them with a space
  pswd_file: 'pswd.yml',   # Filename that contains credentials for accessing devices.
  error_log: 'errors.log'  # Log file path
}.freeze
```
On first launch, two files are created in [YAML](https://en.wikipedia.org/wiki/YAML) format : **pool.yml** and **pswd.yml**.

**pool.yml** file must specify all devices that will be polled in the following form:
``` yaml
---
- :name: device1     # Device name, used as filename that stores the configuration in archive directory (REQUIRED)
  :host: 192.168.1.1 # IP address or host name for telnet connection (REQUIRED)
  :type: cisco_user  # Device type, matches the name of the template (method) from templates.rb (REQUIRED)
  :port: 23          # Port for telnet access (default 23)
  :user: username    # Login (default used from pswd.yml)
  :pswd: password    # Password (default used from pswd.yml)
  :esif: gi2/0       # EtherSwitch interface for cisco_es device type (default gi2/0)
  :logs: device.log  # Device polling log file (not used by default)
  :pgrp: devices     # Password group name from pswd.yml file
- :name: device2     # Next device
  :host: 192.168.1.2
  :type: juniper
```
Required parameters: ```:name: :host: :type:```

The **pswd.yml** file contains credentials (logins/passwords) for accessing devices:
``` yaml
---
- :user: username # Default username if not set in pool.yml (REQUIRED) 
  :pswd: password # Default password if not set in pool.yml (REQUIRED)
  :type: default  # Do not change, defines the default authorization (REQUIRED)
- :user: username
  :pswd: password
  :type: juniper  # Authorization to access a specific device type or group :pgrp: from pool.yml
- :user: username
  :pswd: password
  :type:          # Authorization to access multiple types of devices
  - cisco_user
  - cisco_enable
```

The username and password specified in **pool.yml** have the highest priority. If they are not specified in **pool.yml**, and there is authorization for a certain type of devices in the **pswd.yml** file, then the login/password from **pswd.yml** is used for these devices.

If the device type is not found in **pswd.yml**, the default authorization (```:type: default```) is used.

Also, it is possible to define a password group ```:pgrp:``` in **pool.yml**, which will correspond to ```:type:``` in **pswd.yml**. It should be noted that if authorization is set for a device type, then the password group in **pswd.yml** must be higher than the authorization by device type in order to have priority.

It is possible to separately use ```:user:``` and ```:pswd:``` in **pool.yml**. If one of the parameters is not specified, it will be taken from **pswd.yml**.

### Execution
When the script starts, a directory with the name in the form of the current date is created in the archive directory (by default **./archive**). If such directory is already created, a new one is created with a timestamp. If configured multiple device pools, subdirectories with pool names are created.

Devices are polled in the order specified in **pool.yml**. Configuration files are saved in the archive directory. Errors occurred during device polling are saved in the log file (by default **./errors.log**)

[Templates.rb](./templates.rb) defines device type templates for polling them via telnet. Templates are in form of methods using the [Net::Telnet](https://github.com/ruby/net-telnet) class commands. If necessary, it is possible to add new templates (methods). In the current version, the following types of network devices are specified:

- omnistack_enable - Alcatel OmniStack LS enable password login
- omnistack_user - Alcatel OmniStack LS username/password login
- omniswitch - Alcatel OmniSwitch
- cisco_user - Cisco username/password login
- cisco_enable - Cisco enable password login
- cisco_noenable - Cisco no enable password required (privilege level 15)
- cisco_es - Cisco EtherSwitch module
- cisco_asa - Cisco ASA
- hp_super - HP super password login
- hp_nosuper - HP no super password required (user privilege 3)
- hp_user - HP username/password login
- h3c_nosuper - H3C/3Com no super password
- h3c_user - H3C/3Com username/password login
- juniper - Juniper
- dlink_new - D-Link new cisco-like style CLI (15xx)
- dlink_old - D-Link old own style CLI (12xx/32xx/35xx)
- eltex - Eltex
- extreme - Extreme
- riverstone - Riverstone
