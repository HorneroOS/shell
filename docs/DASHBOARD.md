# Dashboard home

The dashboard home is an instrument panel: every module is a `panel`
frame with a 1 px `rule` border, radius `small` (3) and a channel eyebrow,
bound to real services only.

## Media deck

The media module reads like a cassette deck or a mixer channel:

- A sunken square **cover well** (1 px `rule`, radius 3) with the track
  art.
- The **stereo spectrum** on either side of the well: the left channel
  grows out to the left, the right channel to the right, lowest band at
  the bottom. 3 px `phosphor` segments; the hot zone (top 15 %) turns
  `signal` amber. The data is real: the shell captures the default sink
  monitor in stereo and runs one stereo cava plan for the deck.
- An amber **peak-hold tick** per band: it holds for 600 ms, then falls
  and never drops below the live level (VU ballistics: 30 ms attack,
  300 ms decay).
- Identity (title, artist, player), the transport, and a **tape counter**
  (`03:14 / 05:02`, Plex Mono tabular digits) over the segmented seek
  meter.
- With no player the well says **NO SIGNAL**, the columns stay dark and
  Javi dozes in the well (when the mascot is on).

No radial bars, no arc around the cover, no animated art.

### Cost

The spectrum is drawn by one `SpectrumMeter` scene-graph item per channel.
It only steps and repaints while something moves and sleeps once every
band has settled. The deck holds the stereo sampler only while a player is
playing and the dashboard is open, so a paused or idle deck costs no
frames and no audio processing.

### Settings

Control Center > Dashboard > Media deck. Each value persists in
`dashboard.media` in `shell.json` and has a reset:

| Setting | Key | Default |
| --- | --- | --- |
| Stereo spectrum | `dashboard.media.spectrum` | on |
| Peak-hold ticks | `dashboard.media.peakHold` | on |
| Bands per channel (8-24) | `dashboard.media.bands` | 12 |
| Javi dozes when nothing plays | `dashboard.media.javi` | on |

The spectrum is motion, so it is not drawn when motion is off (Gaming mode,
`appearance.reducedMotion`, or the system reduced-motion preference). Javi
also needs the mascot (Appearance > Atmosphere).

## Composition

Control Center > Dashboard > Layout, `dashboard.composition`, with a
reset. The open dashboard follows the choice live.

| Choice | Layout |
| --- | --- |
| Console (default) | The clock (display numerals and a seconds ruler) and the station on top, calendar and resources below, a thin weather strip across the bottom, and the media deck as the tall hero on the right spanning every row. |
| Classic | The earlier even grid: station, clock and weather on top, calendar and resources below, the media deck as a strip at the bottom. |
| Compact | Classic without the media deck. |

Every frame keeps radius 3 and its channel eyebrow (`01 · CLOCK`, ...);
hierarchy comes from size and position, not rounding. Gaps between frames
are `spacing.normal` (12 at scale 1). Frames are declared in reading order,
so keyboard focus follows it.

The seconds ruler under the console clock has 60 hairline ticks, every
fifth taller; the elapsed ones are `signal` amber. It steps once a second
and never sweeps.
