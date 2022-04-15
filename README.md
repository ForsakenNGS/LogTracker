# LogTracker (TBC Classic) by Mylaerla-Everlook

Provides the current warcraftlogs rankings for players within the game.
Currently those are displayed for:
- Player-Tooltips (mouseover)
- Chat /who links (shift-click name)
- Online alerts (guild/friends)

The tooltip / description contains the up-to-date content (currently BT/Hyjal and ZA)
with the number of killed/total bosses and the allstars rating for each spec.

Player log data is stored within a separate data plugin split by region:
- `LogTracker_BaseData` (Contains the current phases and server <-> region mappings)
- `LogTracker_CharacterData_EU` (Player data for Europe-Servers)
- `LogTracker_CharacterData_U`S (Player data for US-Servers)
- `LogTracker_CharacterData_CN` (Player data for China-Servers)
- `LogTracker_CharacterData_KR` (Player data for Korean-Servers)
- `LogTracker_CharacterData_TW` (Player data for Taiwan-Servers)

In order for the Addon to work (properly) you will (in addition to this addon)
need the `LogTracker_BaseData` and the `LogTracker_CharacterData_*` of your respective region(s).
