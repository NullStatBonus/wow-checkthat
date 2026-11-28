# Census manifests

`ct.py census` writes one file per client build here (`<client>-<build>.json`). They stay local: Git ignores them, because they also hold the tester's list of loaded addons and the globals those addons set.
`ct.py offline` reads them to split the nil-read report into names the build has and names it lacks.
When a test needs part of a manifest, parse that part into its own file, review it, and commit only that file.
