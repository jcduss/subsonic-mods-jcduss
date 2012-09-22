# Subsonic with VLC Player

This is the webapp of the [Subsonic music streamer][subwebsite], with an added 'VLC Remote Player' player technology type.

# Release information

This mod is based on version 4.6 of the subsonic webapp.

You will find a deployable subsonic.war file under dist/.

# Compatibility

Browser, displaying the subsonic web interface

- Works with recent versions of Firefox, Chrome, Safari (iPad)
- Does not work with IE apparently

VLC media player, on the device playing music
- Tested with versions 0.8.1, 0.9, 1.0.x
- Latest versions of VLC (2.0.X) have not yet been tested

# Bugs
- When loading a server playlist or random songs to the VLC player, the player playlist is loaded twice to VLC
- The breadcrumb links displayed when browsing a collection displays a 'Music' link at the top level : this is broken (subsonic bug?)
- Volume and start/stop controls are somewhat unstable, yet functional

# Features

More information [in the Subsonic Mods forum][[subforumvlc]]


[subwebsite]: http://subsonic.org/.
[subforumvlc]: http://forum.subsonic.org/forum/viewtopic.php?f=8&t=8674
