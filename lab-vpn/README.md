# Lab VPN

A macOS 13+ menu bar app for managing Homebrew WireGuard tunnels. Build with `./build.sh` and open `dist/Lab VPN.app`. It appears as a shield in the menu bar. If the WireGuard commands are missing, install them with `brew install wireguard-tools`.

1. Open the shield menu and choose **Manage Profiles… → Add → Home Lab**.
2. Save the profile and choose **Copy Public Key**.
3. On Warden, edit **VPN → WireGuard → Peers → MacBook Air**. Confirm its Allowed IPs includes `10.150.99.3/32`, replace that peer’s public key with the copied key, then save and apply.
4. From the home network, choose **Connect** in Lab VPN and approve the macOS administrator prompt. **Tunnel up** reports a local interface. Open `https://10.150.10.1` to confirm you can reach Warden.
5. Choose **Disconnect** to stop the tunnel. Quitting the app leaves an active tunnel up. Reopen the app to disconnect it.

The profile manager also accepts WireGuard configuration files and supports creating, editing, and deleting profiles. It supports standard interface and peer fields, including multiple peers, and rejects shell hooks and routing overrides. Profiles are saved in Keychain. During connection, `wg-quick` reads a temporary configuration with restricted permissions that is removed after the operation. Keep the app at a stable path to make Keychain access consistent.

Run `./test.sh` to verify profile validation and Homebrew key generation.

## Password-free controls

Choose **Enable Password-Free Controls…** in the shield menu and approve the macOS administrator prompt. The installer registers a launchd service and installs root-owned copies of the WireGuard tools and Bash. The service accepts only validated Lab VPN tunnel requests from the macOS account that installed it. Profile keys remain in Keychain and are sent to the service over its local socket only when connecting.

The service keeps the tool versions bundled with the app at setup. Homebrew upgrades alone do not update its copies.
