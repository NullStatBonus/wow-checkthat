## Decisions

- The list stores digests in `global.ui.recent`; the plan itself comes from `global.planStore`, so removing a plan in Plans does not break recents.
- The dropdown is a plain button and list (no UIDropDownMenu template), so it works the same on both clients.
