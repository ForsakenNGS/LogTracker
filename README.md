# LogTracker (WotLK Classic) by Mylaerla-Everlook

Due to legal reasons I currently can't read the log data as before.
There will be an update in the future, but that will still take some time which I can't speed up. 
Until then I implemented an alternative for checking a players capabilities:
- Links to a players logs as URL for Copy&Paste within the LFG-Tool
- Player-Tooltip with the raid progression (kills + hardmodes) displayed for:
  - Player-Tooltips (mouseover)
  - Chat /who links (shift-click name)
  - Online alerts (guild/friends)
  - Manual player lookup

With the command `/lt <playername>` you can manually lookup a players raid progression,
which will also include the details for individual encounters.

In order for the Addon to work (properly) you will (in addition to this addon) need the `LogTracker_BaseData` addon.
