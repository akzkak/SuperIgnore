### TODO Features:

### Fix Bugs:

### Known problems:



Audit of v1.4.8, including the staged cancel-message changes. I made no code changes. Items are ranked from most to least important. A few depend on 1.12 client internals I couldn't check here; those are marked **(verify)**.

## High
## Medium
## Low–Medium (performance)

14. Every chat message is processed once per chat frame. Each pass does:
    - a linear `SI_BannedGetIndex` scan (the list is "unlimited");
    - a full `table.sort` plus `IgnoreList_Update` on each auto-block;
    - a linear scan of the whole session log in `SI_LogAdd` and in `SI_LogHasName` (per row).

    A name→index hash map would fix this.
15. **Chat-bubble `OnUpdate` allocates tables every frame** (`{WorldFrame:GetChildren()}`, `{GetRegions()}`) for 5 seconds after each blocked message. It also hides anyone else's bubble with the same text in that window.

## Low (correctness and edge cases)

16. **Localized format strings aren't escaped.** `SI_StringFindPattern` doesn't escape Lua magic characters and doesn't handle `%1$s` positional arguments, so the system-message matching breaks on some locales.
17. **The addon empties the server-side ignore list** (`SI_ReplaceOldIgnores`), and this can't be undone. Other clients lose all ignores, and the server no longer filters anything. Mail and AFK/DND auto-replies from ignored players aren't covered.
18. **Timed ignores only expire lazily**, inside the name filter with a 60-second gate. Every expiry at login prints an "is no longer being ignored" line.
19. **The selected row points at a different player after re-sorting.** `SI_AddIgnore_New` sorts the list but doesn't update `BannedSelected` (`SI_BannedChangeDuration` does).
20. **Reason truncation can split a UTF-8 character** (`string.sub` byte cut, [SuperIgnore.lua:914](SuperIgnore.lua:914)), which shows a garbage glyph.
21. **An extra sound plays on every unit-popup click.** The post-hook calls `PlaySound("UChatScrollButton")` for every button, not just Ignore ([SuperIgnore.lua:1731](SuperIgnore.lua:1731)).
22. **Typo `agr3`** at [SuperIgnore.lua:1090](SuperIgnore.lua:1090). It passes a nil global; harmless today only because arg3 is unused.
23. **`SI_DelNameFilter` and `SI_DelChatFilter` remove entries while iterating**, which skips the next element if the same filter is registered twice.
24. **Whisper-unignore also fires for name-filter matches.** It "unignores" snowflake-filtered players, but the filter keeps blocking their replies.
25. **The timed durations in the right-click duration menu never show a checkmark.**

## Low (hygiene)

26. **Dead code:**
    - `SI_FrameCreateButton` (which also creates a global frame named after the button text)
    - `SI_BannedSetName`
    - `SI_LastIgnoreListButton`
    - `local name = channel` in `SI_SendChatMessage_New`
    - the unused slot 3 in ban entries
27. **The `.toc` lists `mod_03`–`mod_09`, which don't exist.**
28. **Hardcoded values:**
    - `1..20` in `SI_EnableIgnoreListRightclick` (should be `IGNORES_TO_DISPLAY`)
    - the insert positions in `UnitPopupMenus` (4, 8, 5, 10), which can clash with other addons
    - the loop to 5 in `FriendLib:CheckParty` (a party has at most 4 other members)
29. **Text typos:**
    - "because are ignoring" in `ChatBlocked`
    - the Latin-1 mojibake in FilterLib's `spacestrip` character class
30. **Pfui skin registration can happen twice.** `SI_SkinDetect` runs on both `ADDON_LOADED` and `PLAYER_LOGIN` and may call `pfUI:RegisterSkin` both times.
31. **The version number is duplicated** in the `.toc` and `SuperIgnore.lua`.
32. **Namespace:** about 100 `SI_*` globals, and `type` is used as a local variable name.
33. **FilterLib's word list is marked "Stolen from SpamMeNot"** with no license or attribution in the repo.