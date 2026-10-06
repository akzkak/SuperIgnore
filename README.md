# SuperIgnore
- Unlimited ignore list size
- Temporary (timed) ignores
- Ignore only in selected chat channels
- Uses default WoW interface and /ignore command
- You can add an ignore "reason"
- Can show ignored messages in GUI
- Works with Prat, WIM and WhisperFu
- Automatically matches the [pfUI](https://github.com/brues-code/pfUI) look when pfUI is installed
- Uses pfUI's player class color for hover highlights when its skin is active

**Default Ignore Time** starts at **Ask** on fresh installs. This first dropdown
option lets you choose a duration and optional reason
when ignoring a player. The popup starts at **Forever**, uses the same theme as
the SuperIgnore panels, and adds the ignore only after you press **Accept** (or
Enter). **Cancel** or Escape closes it without adding the player. Automated
blocks retain their configured durations.

Choose **Ignore** or **Spam** in the popup. Ignore uses your configured ignore
filters. Spam hides that player's channel messages, including World,
General, Trade and LookingForGroup, even if public-channel filtering is disabled.
Whispers, party/raid, guild/officer, battleground chat, Say/Yell, emotes, trades,
duels and invitations remain available. Whispering a player on the Spam list does not
remove them from that list. Both modes support the same durations and reasons.

The ignore list groups players under **Ignore** and **Spam**, with
counts for each section. Right-click an entry to switch its mode. Existing saved
ignores remain in Ignore mode.

The **Ignore Settings** section applies to Ignore mode only. Players on the Spam
list always have their channel messages hidden, while private and group messages
remain visible. The whisper settings also apply only to Ignore mode.

## Chat Commands

The /ignore command is modified so you can include an ignore reason:

	/ignore Name REASON

## Modules
- Included modules can filter names & messages:

#### [ChatSanitizer](https://github.com/Aviana/ChatSanitizer)
- Blocks spam and advertisements

#### Custom Filter
- Create your own list of banned phrases
- Players writing these phrases will be temporarily blocked

## Preview
<img width="802" height="581" alt="WoW_26-09-26 (12)" src="https://github.com/user-attachments/assets/cd64350d-f74d-4f7b-ab73-cd50d38cc39f" />
<img width="802" height="581" alt="WoW_26-09-26 (11)" src="https://github.com/user-attachments/assets/98b788bf-bd36-41a6-8e46-d21b3a045140" />
