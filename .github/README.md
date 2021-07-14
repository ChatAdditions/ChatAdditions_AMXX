<h1 align="center">
  <a href="https://github.com/ChatAdditions/ChatAdditions_AMXX/releases"><img src="https://user-images.githubusercontent.com/18553678/125533850-6771c07f-021f-4882-b395-7d68d2679513.png" width="500px" alt="Chat Additions"></a>
</h1>

<p align="center">AMXModX plugin chat control tool with rich functionality and API.</p>

<p align="center">
  <a href="https://github.com/ChatAdditions/ChatAdditions_AMXX/releases/latest">
    <img src="https://img.shields.io/github/downloads/ChatAdditions/ChatAdditions_AMXX/total?label=Download%40latest&style=flat-square&logo=github&logoColor=white"
         alt="Build status">
    <a href="https://github.com/wopox1337/ChatsAdditions_AMXX/actions">
    <img src="https://img.shields.io/github/workflow/status/wopox1337/ChatsAdditions_AMXX/Build/master?style=flat-square&logo=github&logoColor=white"
         alt="Build status">
    <a href="https://github.com/wopox1337/ChatsAdditions_AMXX/releases">
    <img src="https://img.shields.io/github/v/release/wopox1337/ChatsAdditions_AMXX?include_prereleases&style=flat-square&logo=github&logoColor=white"
         alt="Release">
    <a href="https://www.amxmodx.org/downloads-new.php">
    <img src="https://img.shields.io/badge/AMXModX-%3E%3D1.9.0-blue?style=flat-square"
         alt="AMXModX dependency">
    <a href="https://github.com/wopox1337/ChatsAdditions_AMXX/discussions">
    <img src="https://img.shields.io/badge/discussions-on%20github-informational?style=flat-square&logo=googlechat"
         alt="Discussions">
</p>
      
<p align="center">
  <a href="#about">About</a> •
  <a href="#installation">Installation</a> •
  <a href="#updating">Updating</a> •
  <a href="#features">Features</a> •
  <a href="#wiki">Wiki</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#credits">Credits</a> •
  <a href="#support">Support</a> •
  <a href="#license">License</a>
</p>

---

## About
Chat Additions is a set of tools for managing voice as well as text chat, for your HLDS server. 
Allows you to fully or selectively limit the player to use any chat (voice, general, team, admin).
Modular system, allows you to use only the necessary tasks capabilities, thereby saving server resources.
Rich API capabilities allow the system to connect any functionality (work with player statistics, automation of decisions on blocking).

      
      
      
      
## Installation
- [Download the latest](https://github.com/ChatAdditions/ChatAdditions_AMXX/releases/latest) stable version from the release section.
- Extract the `cstrike` folder to the root folder of the HLDS server;
- Compile all plugins (`*.sma`) from the folder `scripting/` with your preferred compiler ([`v1.9`](https://www.amxmodx.org/downloads-new.php) or [`v1.10`](https://www.amxmodx.org/downloads-new.php?branch=master))
- Put compiled plugins (`.amxx`) into `plugins/`;
- Activate the plugins you need in [`configs/plugins-ChatAdditions.ini`](../cstrike/addons/amxmodx/configs/plugins-ChatAdditions.ini):
```ini
 ; A core plugin for control different types of chat.
ChatAdditions_Core.amxx     debug

 ; Storage choose (disable not used storages)
 ; IMPORTANT: you must leave ONLY ONE plugin to manage the storage.
CA_Storage_SQLite.amxx      debug ; SQLite storage provider
; CA_Storage_CSBans.amxx      debug ; CSBans (MySQL) storage provider
; CA_Storage_GameCMS.amxx     debug ; GameCMS (MySQL) storage provider

 ; Extensions
CA_Mute.amxx                debug ; Players can choose who they can hear.
CA_Addon_DeathMute.amxx     debug ; Alive players don't hear dead players after 5 secs
CA_Gag.amxx                 debug ; Manage player chats for the admin

 ; IMPORTANT: Place you chat manager below (Chat RBS plugins, Lite Translit, Colored Translit etc..)
 ; Most chat managers are not written using the correct chat handling,
 ;  for this reason player messages may not be blocked.
 ;  It is necessary to place the chat manager below the chat blocking plugins,
 ;  to avoid blocking problems.
; chat_rbs.amxx
; crx_chatmanager.amxx
; lite_translit.amxx
; colored_translit.amxx
```
- Configure the plugins you activated in [`configs/plugins/ChatAdditions/`](../cstrike/addons/amxmodx/configs/plugins/ChatAdditions/).
  - **IMPORTANT**: If you are using a MySQL storage system, fill in the correct data for the CVar's:
      - `ca_storage_host` (**required**)
      - `ca_storage_user` (**required**)
      - `ca_storage_pass` (**required**)

- Check if all plugins are running correctly and in the correct order with the command `amxx list`.

## Updating

## Features
      
## Wiki
Do you **need some help**? Check the _articles_ from the [wiki](https://github.com/ChatAdditions/ChatAdditions_AMXX/wiki).

## Contributing
Got **something interesting** you'd like to **share**? Learn about [contributing](CONTRIBUTING.md).

## Credits

## Support
Reach out to me at one of the following places:

## License
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
 Copyright © Sergey Shorokhov
