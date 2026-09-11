# Build identification

Pester uses Apple's two standard version fields:

- `MARKETING_VERSION` is the release version, such as `0.4.2`.
- `CURRENT_PROJECT_VERSION` is the incrementing build number.

The app displays both together, such as `0.4.2-0014`. The displayed value comes from the built app bundle, so it identifies what is actually installed on the phone.

Increment `CURRENT_PROJECT_VERSION` for every installable code build, even when the release version stays the same. Keep the build number numeric in Xcode; Pester pads it to four digits for display. Do not reuse a build number for a different installed build.

Before committing a release branch, compare the Xcode project version/build settings with the Build value shown in the app. Release branches may use the same release version while the build number advances across smaller commits.
