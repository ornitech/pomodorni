# Changelog

## [1.1.0](https://github.com/ornitech/pomodorni/compare/v1.0.0...v1.1.0) (2026-03-31)


### Features

* add activity nudge settings to SettingsView ([e6c2c81](https://github.com/ornitech/pomodorni/commit/e6c2c81b170297a06700132c0b170b3f91c75956))
* add ActivityMonitor with basic start/stop lifecycle ([3fb00f2](https://github.com/ornitech/pomodorni/commit/3fb00f2985df4604ca94c9d01057f3b8442c2f90))
* add ActivityProvider protocol and mock ([417ff49](https://github.com/ornitech/pomodorni/commit/417ff49429b84d3e1f49874889d51130eb1cc3af))
* add commit-msg hook for conventional commits ([916c971](https://github.com/ornitech/pomodorni/commit/916c971b2930efb60eebfd7e2a473c90c04938d3))
* add NudgeView and NudgePanel for activity nudge popup ([e902904](https://github.com/ornitech/pomodorni/commit/e902904a0a5f5d36e09a7465c8efbde079dff7b7))
* add release-please workflow for managed releases ([42747e5](https://github.com/ornitech/pomodorni/commit/42747e56b129a7a7f2dd63a15b9c38b38b8c1320))
* add SystemActivityProvider with NSEvent global monitoring ([122ad39](https://github.com/ornitech/pomodorni/commit/122ad39daad9a18315ce68ccacf2d9a3edbb4a23))
* Apple code signing and break-specific activity nudges ([fb29016](https://github.com/ornitech/pomodorni/commit/fb290169a611b9a0d5bf10ac6bd238d74df846f0))
* derive version bumps from conventional commit types ([6b14cf8](https://github.com/ornitech/pomodorni/commit/6b14cf886e68ae435991cf5bb35d44825eba06c0))
* rewrite release workflow for tag-triggered builds ([d54a048](https://github.com/ornitech/pomodorni/commit/d54a04843d09aacc6945a804b6fb12325e126e4f))
* wire ActivityMonitor and NudgePanel into AppDelegate ([3820099](https://github.com/ornitech/pomodorni/commit/3820099d069c81e2df4cbc706e88298ecc3d573e))


### Bug Fixes

* nudge when session completed, not just when idle ([383f5be](https://github.com/ornitech/pomodorni/commit/383f5be34ca2276080808f539663b0f08fa00d43))
* show context-aware nudge message for breaks ([aa6cb6d](https://github.com/ornitech/pomodorni/commit/aa6cb6daa6bc72d9d1905c68de676efc2193c111))
