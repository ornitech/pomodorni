# Changelog

## [1.3.1](https://github.com/ornitech/pomodorni/compare/v1.3.0...v1.3.1) (2026-04-05)


### Bug Fixes

* resolve dependencies before tests in pre-commit hook ([#18](https://github.com/ornitech/pomodorni/issues/18)) ([5332b5e](https://github.com/ornitech/pomodorni/commit/5332b5e6d94278679b3702688d65a14430179ed6))

## [1.3.0](https://github.com/ornitech/pomodorni/compare/v1.2.3...v1.3.0) (2026-04-05)


### Features

* distinguish break-due nudge from break-active nudge ([#17](https://github.com/ornitech/pomodorni/issues/17)) ([4e26ce3](https://github.com/ornitech/pomodorni/commit/4e26ce3eb1731b06a2d00ceccf5d4cbe53c5d419))


### Bug Fixes

* use explicit inside-out signing for Sparkle framework ([#14](https://github.com/ornitech/pomodorni/issues/14)) ([67ae131](https://github.com/ornitech/pomodorni/commit/67ae1312648d3825a15d6ee4a67d270fa6cef1a2))

## [1.2.3](https://github.com/ornitech/pomodorni/compare/v1.2.2...v1.2.3) (2026-03-31)


### Bug Fixes

* prevent silent codesign failures and notarytool hangs ([#12](https://github.com/ornitech/pomodorni/issues/12)) ([7755e69](https://github.com/ornitech/pomodorni/commit/7755e696abcaf79506d91a8a491b08775e0685fe))

## [1.2.2](https://github.com/ornitech/pomodorni/compare/v1.2.1...v1.2.2) (2026-03-31)


### Bug Fixes

* sign all executables inside Sparkle.framework ([#10](https://github.com/ornitech/pomodorni/issues/10)) ([c28bb38](https://github.com/ornitech/pomodorni/commit/c28bb38932d47412cd46996d03baacf19daf66f8))

## [1.2.1](https://github.com/ornitech/pomodorni/compare/v1.2.0...v1.2.1) (2026-03-31)


### Bug Fixes

* sign nested code objects for notarization ([#8](https://github.com/ornitech/pomodorni/issues/8)) ([e525bbd](https://github.com/ornitech/pomodorni/commit/e525bbdd43e25a1f68e1b54f54c4acfd863dd909))

## [1.2.0](https://github.com/ornitech/pomodorni/compare/v1.1.0...v1.2.0) (2026-03-31)


### Features

* add codesigning workflow and break-specific nudges ([#7](https://github.com/ornitech/pomodorni/issues/7)) ([19be5e1](https://github.com/ornitech/pomodorni/commit/19be5e1ced740f2d8cd7e2d19aa59150c3aa3bfd))

## [1.1.0](https://github.com/ornitech/pomodorni/compare/v1.0.0...v1.1.0) (2026-03-31)


### Features

* add activity nudge settings to SettingsView ([1918f52](https://github.com/ornitech/pomodorni/commit/1918f52aafb0b1365307cd32253e950d015e28e3))
* add ActivityMonitor with basic start/stop lifecycle ([62f4f62](https://github.com/ornitech/pomodorni/commit/62f4f629aa4cb6a3c8aa4a493c61154d76213252))
* add ActivityProvider protocol and mock ([04b8f79](https://github.com/ornitech/pomodorni/commit/04b8f79d3044705d16dea66fd0a30e053b72a29b))
* add commit-msg hook for conventional commits ([4b14cb7](https://github.com/ornitech/pomodorni/commit/4b14cb77ec2e97e5e90d644dbf3f403a49c6d8e2))
* add NudgeView and NudgePanel for activity nudge popup ([ccf63f5](https://github.com/ornitech/pomodorni/commit/ccf63f5d9b0aa6b9f8a57e6c155a1a2e374d8a59))
* add release-please workflow for managed releases ([86231a9](https://github.com/ornitech/pomodorni/commit/86231a9ec19ea96becf113d9704cb05b60b0c9cb))
* add SystemActivityProvider with NSEvent global monitoring ([8f7ce17](https://github.com/ornitech/pomodorni/commit/8f7ce171df0608e25e4f0e5b04d8c9d584974410))
* derive version bumps from conventional commit types ([2f4cd93](https://github.com/ornitech/pomodorni/commit/2f4cd93da9990dcf55839bb00775d7d198b2632c))
* rewrite release workflow for tag-triggered builds ([236a42d](https://github.com/ornitech/pomodorni/commit/236a42defb8c81af80288033d9bd91b0cff968c7))
* wire ActivityMonitor and NudgePanel into AppDelegate ([457da07](https://github.com/ornitech/pomodorni/commit/457da074a84ee047d1ef846915318624a1eaec99))


### Bug Fixes

* nudge when session completed, not just when idle ([6a3ec4d](https://github.com/ornitech/pomodorni/commit/6a3ec4d8f2a3749abed0c08c401aafc81e0b2666))
* show context-aware nudge message for breaks ([492bc91](https://github.com/ornitech/pomodorni/commit/492bc916a881549f16accfd097a2744ffd18a514))
