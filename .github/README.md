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
  <a href="#requirements">Requirements</a> •
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

## Requirements
- HLDS installed;
- [ReGameDLL](https://github.com/s1lentq/ReGameDLL_CS) installed;
- Installed AMXModX ([`v1.9`](https://www.amxmodx.org/downloads-new.php) or [`v1.10`](https://www.amxmodx.org/downloads-new.php?branch=master));
    - Installed [ReAPI](https://github.com/s1lentq/reapi) module; 
      
## Installation
- [Download the latest](https://github.com/ChatAdditions/ChatAdditions_AMXX/releases/latest) stable version from the release section.
- Extract the `cstrike` folder to the root folder of the HLDS server;
- Compile all plugins (`*.sma`) from the folder `scripting/` with your preferred compiler ([`v1.9`](https://www.amxmodx.org/downloads-new.php) or [`v1.10`](https://www.amxmodx.org/downloads-new.php?branch=master))
- Put compiled plugins (`*.amxx`) into `amxmodx/plugins/` folder on the HLDS server.
- Check if all plugins are running correctly and in the correct order with the command `amxx list`.

## Updating
- Compile all (`*.sma`) files with the actual files from the `/scripting/include/` folder;
- Put compiled plugins (`*.amxx`) into `amxmodx/plugins/` folder on the HLDS server;
- Restart the server (command `restart` or change the map);
- Make sure that the versions of the plugins are up to date with the command `amxx list`.

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
