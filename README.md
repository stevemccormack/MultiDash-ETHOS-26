<p align="center">
  <img src="MultiDash/MultiDash.png" alt="MultiDash logo" width="360">
</p>

MultiDash is an experimental telemetry dashboard built specifically for ETHOS 26. It provides configurable live telemetry, battery display, fuel display, session timing, custom telemetry fields, and a post-flight/session summary with min/max statistics and color-coded status feedback. Theoretically, this dashboard should be able to evolve to work with any protocol on any ETHOS 26 radio.

Current status: MultiDash is still highly experimental. Layout, behavior, and configuration options may change in future releases. Use at your own risk.

## System Requirements

ETHOS 26.1.0 RC4 or later

## Tested Hardware

FrSky X18  
FrSky X18RS

Partially simulator-tested on:

FrSky Twin Lite  
FrSky X20

## Widget Size Note

MultiDash has only been tested using the large ETHOS widget size that keeps the normal ETHOS top/bottom system bars visible, including model and battery/status information. It has not been tested with other widget sizes or with the larger/fullscreen-style widget layout that blocks or replaces the normal ETHOS model and battery/status areas. Layout issues may occur outside the tested widget size.

## Screenshots

### Main Dashboard

![Main dashboard](docs/screenshots/main-dashboard.png)

### In-Flight Dashboard

![In-flight dashboard](docs/screenshots/in-flight-dashboard.png)

### Post-Flight Summary

![Post-flight summary](docs/screenshots/post-flight-summary.png)

## Features

Configurable live telemetry dashboard  
Battery display with per-cell scaling  
Fuel display / fuel mode  
Fuel percentage support  
Current display  
RPM display  
Link quality / RSSI-style display  
Four configurable telemetry fields  
Session timer  
Arm switch support  
Normal or reversed arm switch logic  
Configurable arming delay  
In-flight screen  
Post-flight/session summary  
Min/max statistics  
Color-coded status feedback  
Per-model settings  
Optional model image/logo support  
Separate language builds for smaller Lua files  
Refactored widget settings menu  
Automatic telemetry detection

## RC4 Notes

RC4 is a major refactor on the entire widget, the way it works and the files. It now consists of multiple smaller files instead of one large one. Languages can be found at the far bottom of the widget settings.

## Major Changes in RC4

Added universal RC4 install package
 Added Telemetry 4 back to the main screen
 Added Telemetry 4 back to widget settings
 Improved and downsized language system from RC1
 Continued cleanup and optimization
 Minor layout and stability improvements

## Included RC3 Language Builds

English  
Czech  
German  
Spanish  
French  
Italian  
Polish  
Portuguese  
Chinese Simplified  
Chinese Traditional

## Suggested First Setup

After adding MultiDash to an ETHOS screen, configure:

Battery or fuel source  
Cell count, if using battery mode  
Fuel percentage source, if using fuel mode  
Link quality / RSSI source  
Current source  
RPM source, if used  
Custom telemetry fields, if used  
Arm switch  
Arm switch direction  
Battery or fuel thresholds

## Default Battery Thresholds

Default battery thresholds are per-cell:

| Setting | Default |
|---|---:|
| Low | 3.45V |
| Mid | 3.75V |
| High | 4.15V |

## Status Labels

Post-flight/session status labels include:

OK :)  
WARN  
BAD :(  
INFO

## Final Notes / Disclaimer

MultiDash is still highly experimental. It has not been tested across all ETHOS 26 radios, telemetry systems, receivers, protocols, widget sizes, or model types. Layout, behavior, and configuration options may change in future releases. Please message me with any issues you run into. Include as much detail as possible, such as your radio model, ETHOS version, receiver/protocol, telemetry sources used, screenshots if available, and steps to reproduce the issue.

Use at your own risk and verify all telemetry values before relying on them.

## Credits

MultiDash was created and developed by Steven McCormack.

This project is experimental and is being developed for FrSky's ETHOS 26. It takes inspiration from Rob Thomson's Lua scripts for Rotorflight and DashX.

## License

This project is released under the GNU General Public License.

See the LICENSE file for details.
