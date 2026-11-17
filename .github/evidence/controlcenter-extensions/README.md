# Extensions pane compatibility chips, detail headers — evidence (W4c, agent C)

Offscreen software renders (Qt `offscreen`; `ClippingRectangle` shimmed to
`Rectangle` in a scratch copy because it does not grab offscreen; isolated
XDG tree). The Extensions pane lists the first five real entries of the
HorneroOS/plugins catalogue (revision shown in the render) via a stub
`horneroctl` that only serves that file; the catalogue reports no
`schemaVersion`, so each row honestly shows "PluginKit: not reported".
Audio pane renders were not committed: the offscreen shell read the host's
live PipeWire graph and showed real device names.
Themes: night, day, hc.
