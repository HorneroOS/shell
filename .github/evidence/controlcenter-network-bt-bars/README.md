# Control Center Network/Bluetooth recomposition, Bars, Companion and review pass — evidence (agent F)

Offscreen software renders (Qt `offscreen`, real shell services and theme
roles, isolated XDG tree; not desktop captures, not QA-VM). `ClippingRectangle`
is shimmed to `Rectangle` in a scratch copy because it does not grab
offscreen. Themes: `night`, `day`, `hc` (Signal High Contrast).

`horneroctl` is stubbed to "not available", the isolated config has no
`shell.json` (shell defaults), and there is no Bluetooth adapter or Wi-Fi
radio, so Bluetooth and Wi-Fi show their honest empty/unavailable states.
Not committed: Network, Ethernet, VPN and Launcher renders, because the
offscreen shell reads the host's NetworkManager devices, VPN provider and
installed applications and would publish them.
