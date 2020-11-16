Script created to resolve latest version of forge modules and their
dependencies using forge API.
It notifies on not found and/or deprecated modules.

Limitations: 
- It only resolves Forge versions, cannot read git modules
- It retrieves latest version and assign it to each modules,
so dependencies with specific versions won't be matched
- Lines not matching Forge modules might end up out of order

Usage: forge\_resolve\_version.rb -i /path/to/original/Puppetfile [-o /path/to/new/Puppetfile]

```
★ lmacchi@lmacchi-mbp-7295b 15:19:00 ~> ./forge_resolve_version.rb -i Puppetfile -o new_pf
#### Go get some tea while I process the Puppetfile ####


#### These modules have been upgraded ####
Module puppetlabs-stdlib -  -> 6.5.0
Module puppetlabs-translate -  -> 2.2.0
Module puppetlabs-concat -  -> 6.2.0
Module saz-ssh - 3.0.1 -> 6.2.0
Module puppetlabs-apache - 1.11.0 -> 5.6.0
Module puppetlabs-puppetserver_gem -  -> 1.1.1
Module puppetlabs-resource_api -  -> 1.1.0
Module puppet-staging - 2.2.0 -> 3.2.0
Module puppetlabs-pwshlib -  -> 0.5.1
Module puppetlabs-powershell - 1.0.6 -> 4.0.0


#### These modules have been added ####
Module puppetlabs-stdlib 6.5.0
Module puppetlabs-translate 2.2.0
Module puppetlabs-concat 6.2.0
Module puppetlabs-puppetserver_gem 1.1.1
Module puppetlabs-resource_api 1.1.0
Module puppetlabs-pwshlib 0.5.1


#### Modules not found and removed from Puppetfile ####
blah-bleh


#### Deprecated modules removed from Puppetfile ####
wdijkerman-zabbix

#### Your Puppetfile is now available at new_pf ####
```
