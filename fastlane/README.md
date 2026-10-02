fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios status

```sh
[bundle exec] fastlane ios status
```

TestFlight에 올라간 최신 빌드 번호를 보여 준다 (읽기 전용)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

빌드 번호를 올리고 TestFlight에 업로드한다

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

스토어 문구와 스크린샷만 올린다

### ios submit

```sh
[bundle exec] fastlane ios submit
```

최신 빌드를 붙여 심사에 제출한다

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
