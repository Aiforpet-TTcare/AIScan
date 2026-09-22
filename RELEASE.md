# AIScan release process

Prepare each release on a review branch based on the current public `main`.
Preserve that repository's history. Do not replace it with an orphan commit or
force-push a new history. Each version tag identifies one immutable combination
of public Swift source, resources, Core binaries, and release metadata.

## Prepare the candidate

1. Select a new patch version, such as `3.0.12`, and confirm that its tag does not
   already exist locally or remotely. Never move or reuse a published tag.
2. Apply only the reviewed public changes. If Core changes, package newly built
   device and simulator XCFramework slices from the exact reviewed source and
   retain the source/build/artifact verification record with the release evidence.
   Keep development-only source, credentials, customer details, local paths, and
   internal build records out of the public tree.
3. Keep `AIScan.podspec`, the `Package.swift` version comment, installation
   examples, and `CHANGELOG.md` aligned. Candidate notes must not claim completed
   verification or publication before those steps finish.
4. Review the complete diff against public `main`, including binary and resource
   changes. Submit the public branch for review through the normal pull-request
   process.

`scripts/stage_public_release.sh` is a historical clean-export helper. It is not
the publication path for updates to the established public repository; do not
push its replacement history over the existing public branch.

## Verify before tagging

- Run the public XCTest suite and consumer builds for Swift Package Manager and
  CocoaPods. Check both simulator and device builds and the iOS 13 deployment
  boundary.
- Validate the podspec and install the candidate in a CocoaPods consumer. Inspect
  its installed resource bundle and resolve all seven guide animations at runtime.
  Swift Package Manager consumers must resolve the same resources.
- Exercise legacy dictionary/direct-JSON result handling, structured-accessor
  migration, absent guide fallback, first capture, retry, a fresh second scan,
  temporary presentation, and the questionnaire deadline after slow uploads.
- Run resource, privacy manifest, Core public-header, distribution-boundary,
  publishable-key, and public-release-tree audits. Check the final release tree
  and history for credentials and development-only material.
- Verify Core slice contents and final artifact hashes against the release build
  evidence. A previous version's provenance cannot validate a rebuilt binary.
- Record each check's actual outcome. Report device or host-integration acceptance
  testing that remains outstanding; do not describe untested customer behavior as
  fixed.

## Publish

After review and required checks pass, integrate the release branch through the
normal public branch process without rewriting history. Create a fresh `3.0.12`
tag on the verified release commit and push it. Publish release notes describing
the fixes and any consumer migration requirements.

Fetch the published tag into a clean checkout and verify that the source,
podspec version, bundled resources, and Core hashes match the candidate. Resolve
the exact published tag through both installation paths before declaring the
release available. A Git-tag CocoaPods installation does not depend on trunk
publication; only claim a trunk release if it was separately published and checked.

## Rollback

Consumers can pin the preceding exact release and restore their saved lockfile.
To correct a published SDK release, revert the faulty change on a new public
branch and publish another patch version after verification. Never delete,
replace, or reuse an existing version tag.
