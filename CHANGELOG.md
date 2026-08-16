# Changelog

Section headings must match `MARKETING_VERSION` in the project — the release
workflow looks up release notes by this heading.

## 5.0.1

- Fix bugs
- Update pictures
- Add test
- Update actions for build

## 5.0.0

- Custom level indicators instead of the system ones: GPU load with the stats
  window open dropped from 70% to 8%
- Migrated to Swift 6 with complete concurrency checking
- New "Show external ip address" option — the external address lookup can be
  turned off
- Sensors and GPU load are polled only while the stats window is open
- Fixed OSD placement on its first appearance
- Fixed the empty process list on the first chart open
- Manual update check is no longer blocked by the scheduled one

## 4.7.0

- Fan readings restored
