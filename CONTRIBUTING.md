# Contributing

## Workflow

1. Keep changes within one feature or a clearly shared foundation concern.
2. Put business rules in domain/application code, not widgets.
3. Add tests at the lowest useful layer and widget tests for behavior or semantics.
4. Run formatting, analysis, and all tests before review.
5. Update documentation only for behavior that exists.

```sh
dart format .
flutter analyze
flutter test
```

## Naming and branding

Use brand-neutral professional names for packages, files, types, services, routes, storage keys, analytics, infrastructure, documentation, and tests. The temporary display name is read from the single branding configuration source. A future rebrand must require configuration and asset changes only.

## Dependencies

Prefer Flutter/Dart APIs. Before adding a package, verify maintenance, platform support, license, security posture, and compatibility on pub.dev. Hide vendor SDKs behind an application-owned interface when replacement is plausible.

## Reviews

Review changes for authorization assumptions, sensitive-data handling, bounded data access, keyboard and screen-reader usability, text scaling, contrast, failure states, logging hygiene, and test coverage.

Authentication changes must keep credentials and tokens out of presentation/application state and logs. Never clear a potentially valid persisted session for connectivity, timeout, or generic server failures. A server-confirmed invalidation, explicit logout, or verified deletion is required.

Catalog changes must keep filtering, sorting, recommendation ranking, and pagination in repository/data-source contracts. Do not fetch complete catalogs, sort large collections during widget builds, or use eager widget children for potentially large results. Preserve opaque cursors and bounded page sizes.
