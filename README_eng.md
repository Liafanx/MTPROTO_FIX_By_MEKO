<div align="center">
  
# MTPROTO FIX By MEKO 

<img width="300" height="300" alt="Без имени-1" src="https://github.com/user-attachments/assets/8decca32-f96a-4b00-9e6c-1bf16bf94d33" />


---
[![Latest Release](https://img.shields.io/github/v/release/Mekotofeuka/MTPROTO_FIX_By_MEKO?color=neon)](https://github.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/releases/latest) [![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) [![Stars](https://img.shields.io/github/stars/Mekotofeuka/MTPROTO_FIX_By_MEKO?style=social)](https://github.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/stargazers) [![Forks](https://img.shields.io/github/forks/Mekotofeuka/MTPROTO_FIX_By_MEKO?style=social)](https://github.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/network/members) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/pulls)

</div>

<p align="center">
  · <a href="#Quick-start">Installation in 1 click</a> · <a href="https://github.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/blob/main/docs.md">Documentation</a> · <a href="#How-does-the-fix-work">How does it work?</a> · <a href="#Possible-problemswhy-might-it-not-work-for-me">Problem solving</a> ·
</p>

<div align="center">
  
**A full-fledged all-in-one tool for working with proxies**:

**Allows you to conveniently work in a couple of clicks** with **TELEMT and MTPROTO.ZIG**, supporting most of the necessary commands for interaction:
Installation, update, rollback, configuration, config changes, log viewing without entering any commands.

⭐️One of our old fixes was adopted by TELEMT⭐️
  
</div>

---

<div align="center">
👇 Have a problem? Write in the chat - we'll help 👇
</div>
<p align="center">
  <a href="https://t.me/meko_mtprotofix">
    <img src="https://github.com/user-attachments/assets/4a2a1ee5-cd30-4714-9a8b-0d02dc8cae1d" width="350" height="130"/>
  </a>
</p>


**Helps solve in 1 click** the problem that appeared since June 4, **when the Telegram client cannot connect to the mtproto proxy server**. The fix is made for the server side and clients do not need to install/change anything.

**Symptoms**: Connection may hang, take a long time to establish, or be unstable during the initial TCP stage, with further blocking of client access to the server for 2 minutes after the first connection.

**Tested on: Telemt 3.4.18 and 3.4.22, MTProto.zig 1.9.0, Mtg, MTProtoProxy, JSMTProxy**

This script is used for servers with MTPROTO - (telemt, mtproto zig, etc.), fixes the problem of slow initial TCP client connections, unlike the previously created and popular SYN limit fixes in the community **it has a number of advantages**:
- Fast connection in <3-8 sec. (Original SYN Limit: >10-20 sec.) even with a large number of users
- **One port for iOS/Android/MacOS/Desktop** etc.
- Media loads at almost the same speed as before
- **Installs in one click**
<div align="center">
<img width="550" height="400" alt="image" src="https://github.com/user-attachments/assets/4268e1aa-7941-4676-9f80-13fd2f3b4803" />
<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/3296a6c6-c097-4e5a-bd05-7c9f64154f79" />
<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/64dd8fe0-c8ee-4b6d-8ee8-b02782f556cd" />

</div>

## Quick start:

**Attention, this script is paid, price: 1 ⭐ on the repository**

1. **Install/update our script**:
```Bash
curl -fsSL https://raw.githubusercontent.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/main/install.sh | sudo bash
```
2. **Install standard Telemt** version 3.4.22 or 3.4.18 and below, also as an **alternative** you can install "**MTPROTO.zig**"
   > (all proxies can be installed through our script menu, it is not necessary to install them on the server in advance)
4. Apply our fix to the proxy by pressing **[1] Install SYN FIX** in the main menu
5. **Disable built-in MSS and SYN** from the telemt config by pressing **[5]** (if it was already added to the telemt config on the server earlier)
6. Check the SNI via button **[7]** in the menu, or via the bot @Sni_checker_bot, you need to select a domain that shows: 🟢 Marker: NO. Otherwise, there will be problems for iOS users.
7. If you are using a self-signed certificate, make sure that OpenSSL 3.5 and higher is installed on the server, otherwise there will similarly be problems for iOS users. If it is not possible to install OpenSSL 3.5 and higher, then use any popular domain instead of a self-signed one that gives "🟢 Marker: NO."
8. Done.

- **Additionally**:
Button **3** will perform basic server optimization for the proxy, in a number of tests it performed better - faster, more stable, less resource-intensive.

**Open the menu**:
```Bash
mekopr
```

# How does the fix work:

Applies a set of rules to the server that divides devices into 2 types - **ios** and **non-ios** and applies its own limit to each
- Layer 1 - Checks if the device is iOS or not.
  - If yes - Leave the device on the first layer and apply rules specifically for iOS to it.
  - If no - Go to the second layer and apply the second layer rules for all devices.

**More detailed description**
- Solves the problem of dead connections for iOS/Android
  - Problem: the mobile client is minimized, after which the socket does not close cleanly, causing the server to hold a dead connection and when the client returns it gets stuck on the dead socket.
  - The script makes the dead connection break in a couple of minutes, instead of several hours. When the client returns from the background, it immediately sees "socket dead" and reconnects without hanging.
- Solves the TCP handshake problem, which is cut off using technical traffic restriction measures
  - The script limits the frequency of incoming SYN to 1.1/sec from one IP, since technical measures restrict TCP connections only if there are >1 per second.
- iOS separately
  - iOS has different connection patterns compared to Android and Desktop. In one limit they interfere with each other. Separating by ports is of course a solution, but a crutch one. Our fix separates these clients by iOS fingerprint, so clients of any devices can sit on one port without any extra hassle.
- 54/minute (not 1 sec)
  - In iptables, the hashlimit module does not support milliseconds. 54/minute = 1.1 sec per connection. The 100 ms margin is needed to eliminate the error that occurs during instant Reject, which leads to blocking of the connection from your device to the mtproto server for 2 minutes.
- REJECT instead of DROP
  - DROP simply terminates the client's connection without notifying it, causing timeouts (3-5 sec) -> retries with longer pauses -> longer delay. REJECT with RST, on the other hand, terminates the connection giving an instant response to the client about the termination, causing the client to try to reconnect without waiting, which makes the connection to Telegram much faster.
- There is simply no need for MSS in this build, so the script has a function to disable it. If you leave a rule or config setting with MSS or another SYN limit option, media and speed will still be reduced, so it is recommended to comment/delete them from the server before applying the fix.

**If you want to dive deeper into this topic, you can read our documentation:
· <a href="https://github.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/blob/main/docs.md">Documentation (click)</a> ·**

# How to make a proxy from the Russian Federation directly, with a working MiddleProxy (useful for those who use the "sponsor channel")

This manual describes a method for running a proxy directly on a server from which access to ME/DC Telegram servers is restricted. Works with android/ios/desktop
1. Install MTPROTO ZIG
```Bash
curl -fsSL https://raw.githubusercontent.com/sleep3r/mtproto.zig/main/deploy/bootstrap.sh | sudo bash
```
```Bash
sudo mtbuddy install --port 443 --domain rutube.ru --no-tcpmss --middle-proxy --yes
```
2. Install the MEKO script
```Bash
curl -fsSL https://raw.githubusercontent.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/main/install.sh | sudo bash
```
3. Skip the information about Telemt, the script menu opens, press **1** and press y
4. Connect to the proxy and use it

## Possible problems ("why might it not work for me?")

- Possibly the port/IP/subnet was already blocked earlier and needs to be replaced (often a proxy that doesn't work on 443 works fine on 9443 for example.)
- When using the v2 fix, which identifies the device by TTL + Length, when connecting from iOS, the connection passing from your device to the server may pass through a number of load balancers, the TTL becomes greater than the specified limit, which is not uncommon, causing the script to ultimately identify the device as desktop/android rather than an iPhone, in which case you need to use the v3 fix.
- When using any other fix or the v3 version, which identifies iOS by its full fingerprint (byte order) or the fix that identifies devices by TTL+Length, rather than limiting MSS (splitting packets, which leads to deterioration of media loading), you need to make sure that the domain used for Fake TLS supports the post-quantum hybrid key exchange algorithm combining the classic elliptic curve. You can check this using the built-in domain check function (works on OS with OpenSSL 3.5 and above) or via the bot: @Sni_checker_bot by sending it the domain. If the selected domain does not support this - with a high probability after an attempt to connect from iOS, a block will be triggered and the connection will fail.
  - A number of popular domains that have and do not have support for this algorithm:

  ❌ vk.com, github.com, habr.com, yandex.ru, steamcommunity.com, amazon.com, microsoft.com, amazonaws.com, mail.ru, dzen.ru, linkedin.com, live.com, office.com, amazon.com, azure.com, bing.com, github.com, fastly.net, netflix.com, sharepoint.com, skype.com, gandi.net, cloud.microsoft, yahoo.com, msn.com, tiktok.com, roblox.com, spotify.com, adobe.com, ntp.org, myfritz.net, qq.com, baidu.com, nginx.org, windows.com, yandex.net, tiktokv.com, mozilla.org, nic.ru, opera.com, samsung.com, sentry.io

  ✅ cloudflare.com, rutube.ru, my.aeza.ru, wb.ru, ozon.ru, steamcommunity.com, youtube.com, apple.com, openai.com, anthropic.com, meta.com, facebook.com, x.com, wikipedia.org, stackoverflow.com, rust-lang.org, crates.io, docs.rs, instagram.com, fbcdn.net, twitter.com, googletagmanager.com, whatsapp.net, doubleclick.net, googleusercontent.com, appsflyersdk.com, wordpress.org, digicert.com, youtu.be, pinterest.com, goo.gl, x.com, whatsapp.com, icloud.com, googlesyndication.com, cloudflare.net, googledomains.com, wa.me, chatgpt.com, vimeo.com, zoom.us, workers.dev, cloudflare-dns.com, wordpress.com, reddit.com, 

## ⭐ Support the project

**MEKO fix** — was created in free time for the community.  
Your support will help in conducting further tests ;)

**You can support the project by starring ⭐ this repository (at the top right of this page)**

💰 **Cryptocurrency:**  

[<img width="300" height="300" alt="image" src="https://github.com/user-attachments/assets/b910c839-ec45-486d-b7f0-05da8de41b74" />
](https://t.me/send?start=IVlaFvgWdkxH)

from **0.1 USDT**

USDT TRC20
<code>
TGmBaRYmQwSyC6sRaumaMf9CbEuVAk4Eff
```Bash
USDT BEP20
```
0x2AF1581aA7b696Ca28C70B5D29756Da3ca577D65
</code>

TON(GRAM)
```Bash
UQDdT8vtR5DmbwzNvMUiNQnwxlbkFq4ypE2_UzIm6bQ88DbU
```


You can also support me by using my service:

[<img width="300" height="300" alt="MEKO bot" src="https://github.com/user-attachments/assets/8db41a95-79f2-40d6-9777-50b6ffb6fa48" />](https://t.me/projectmeko_bot)


<a href="https://star-history.com/#Mekotofeuka/MTPROTO_FIX_By_MEKO&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Mekotofeuka/MTPROTO_FIX_By_MEKO&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Mekotofeuka/MTPROTO_FIX_By_MEKO&type=Date" />
   <img alt="Stars History" src="https://api.star-history.com/svg?repos=Mekotofeuka/MTPROTO_FIX_By_MEKO&type=Date" />
 </picture>
</a>



## Special thanks for contributions to the development:
[![Contributors](https://contrib.rocks/image?repo=Mekotofeuka/MTPROTO_FIX_By_MEKO)](https://github.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/graphs/contributors)
- [@CryZFix](https://github.com/CryZFix/)
- [@Bxhost](https://github.com/bxhost)
- [@Liafanx](https://github.com/Liafanx)
- https://assyoucandy.github.io/telemt-server-guide/telemt-keepalive-guide.html
- https://h1de0x.github.io/telemt-tune/

## Original proxy repositories
- Telemt https://github.com/telemt/telemt
- Mtproto.zig https://github.com/sleep3r/mtproto.zig
