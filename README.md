[Uploading MultiDash_RC1_release_notes_with_screenshots.md…]()
MultiDash is the first release candidate of an experimental telemetry dashboard built specifically for FrSky ETHOS 26. It provides configurable live telemetry, battery display, session timing, custom telemetry fields, and a post-flight/session summary with min/max statistics and color-coded status feedback.

![Main dashboard](assets/screenshots/main-dashboard.png)

![In-flight dashboard](assets/screenshots/inflight-dashboard.png)

![Post-flight summary](assets/screenshots/post-flight-summary.png)


Theoretically, this dashboard should be able to evolve to work with any protocol on any ETHOS 26 radio.

**System Requirements:**
ETHOS 26.1.0 RC4 or later

This release is focused on basic usability, layout testing, and proving the dashboard workflow on real ETHOS hardware, with more than one person using it to help find and squash bugs.

Tested Hardware
FrSky X18
FrSky X18RS
Partially simulator-tested on FrSky Twin Lite
Partially simulator-tested on FrSky X20
Installation

Copy the entire MultiDash folder to your ETHOS scripts/widgets folder. The models folder is included because MultiDash stores per-model settings there.

**Final Notes/Disclaimer:**

MultiDash is still **_highly experimental_**. It has not been tested across all ETHOS 26 radios, telemetry systems, receivers, protocols, or model types. Layout, behavior, and configuration options may change in future releases.

Please message me with any issues you run into. Include as much detail as possible, such as your radio model, ETHOS version, receiver/protocol, telemetry sources used, screenshots if available, and steps to reproduce the issue.

Use at your own risk and verify all telemetry values before relying on them.
