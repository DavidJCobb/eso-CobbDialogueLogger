# eso-CobbDialogueLogger
 A basic mod that logs dialogue and subtitles to a LibAddonMenu panel, in UESP-suitable format

This add-on logs dialogue and subtitles to a textbox in a LibAddonMenu2 panel, after reformatting them to fit UESP conventions. This means:

* Paragraph breaks are replaced with a single HTML BR tag.
* Dialogue is italicized and wrapped in quotation marks, unless the first character is a double-quote or an angle bracket.
* Subtitles identify the speaker in bold, and italicize and quote the line.

The add-on does not auto-format dialogue trees; if multiple dialogue options are presented, then the add-on will list them all and then generate a separate log entry for whichever one you pick.

The add-on does not save any captured text; the log will be wiped if you /reloadui, log out, exit the game, CTD, etc..

Co-opting LibAddonMenu2 for non-settings-menu behavior is both difficult and annoying (which I suppose is understandable), so the log may not reliably update when you open the panel. An update button is presented to alleviate this.

The textbox should have its maximum length set to something like a million characters but I'd still recommend copying and clearing its content periodically.

This add-on is provided under Creative Commons 0, i.e. it's public domain or the closest legal equivalent.