# Phone-host setup and uptime

Terhux executes in Termux on the Android phone. GitHub carries requests and results but does not keep the phone worker alive. Follow this setup on the phone; changes in this document alone cannot change Android settings remotely.

## 1. Install and prepare Termux

- Install Termux from a trusted distribution source and install the Termux:Boot add-on from the **same signing source**.
- Open Termux:Boot once after installation so Android registers the add-on.
- Keep the phone powered on and connected to the internet. For reliable long-running operation, leave it charging when practical.
- Install the tools the bridge needs in Termux (at minimum Git and the utilities used by the repository scripts), and configure GitHub authentication in Termux without placing credentials in the repository.
- Clone Terhux to the path expected by the scripts: `~/terhux/repo`.

## 2. Start the bridge

In Termux:

```bash
cd ~/terhux/repo
git pull --ff-only
chmod +x ./*.sh
./terhux-start.sh
```

The supervisor and watcher keep polling GitHub; the supervisor requests a Termux wake lock when `termux-wake-lock` is installed. The normal polling interval is five seconds (`TERHUX_INTERVAL` can override it for `terhux-watch.sh`).

## 3. Start automatically after a reboot

Termux:Boot runs executable scripts placed in `~/.termux/boot/`. After opening Termux:Boot once, install the repository's boot script:

```bash
mkdir -p ~/.termux/boot
cp ~/terhux/repo/boot/start-terhux ~/.termux/boot/start-terhux
chmod +x ~/.termux/boot/start-terhux
```

Then reboot the phone and check `~/terhux/repo/logs/boot.log` and `~/terhux/repo/logs/supervisor.log` after Termux is available. Official instructions: [Termux:Boot](https://github.com/termux/termux-boot).

## 4. Allow background operation

Android settings vary by manufacturer and version. In the phone's app settings for Termux (and Termux:Boot, if shown):

- Set battery use to **Unrestricted** / **Don't optimize** or the equivalent.
- Allow background activity and background data.
- Enable the manufacturer's **Auto-start** / **Allow background launch** option if present.
- Do not force-stop Termux; a force-stopped app may not restart until opened manually.
- Keep Wi-Fi/mobile data available in the background and disable any battery saver setting that pauses Termux.

A wake lock reduces CPU suspension while the process is running; it cannot prevent shutdown, loss of network, OEM task killing, app force-stop, or all Android power-management behavior. No phone-hosted service can be available while the phone itself is offline.

## 5. Verify from GitHub

Submit an `ACTION=terhux-runner-version` request using the format in [AI_BRIDGE.md](../AI_BRIDGE.md). When the bridge is healthy, the phone consumes the request and writes `results/<id>.result`. If no result appears, check the phone's logs, network connection, GitHub authentication, and Android background restrictions.

## Operational and security notes

- The process runs under the Termux app's Android user, not as Android root.
- The phone is the only execution host in this setup; if it is offline, no request is processed until it reconnects.
- Keep the GitHub repository private and grant write access only to trusted AI agents. `APPROVED=true` in a request is not a separate human approval step.
- Build/install actions may run code from project dependencies or `package.json`; do not use them on untrusted project content or while exposing credentials to the process.
- Results are stored in Git history. Do not return secrets through command output.
