pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Música e vídeo tocando (players MPRIS: Spotify, navegadores, mpv com plugin…). O player mostrado
// é o que está tocando; sem nenhum tocando, o último que tocou; sem esse, o primeiro da lista.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer _last: null
    readonly property MprisPlayer player: {
        const list = players
        const playing = list.find(p => p.isPlaying)
        if (playing) return playing
        if (_last && list.includes(_last)) return _last
        return list.length > 0 ? list[0] : null
    }
    onPlayerChanged: if (player && player.isPlaying) _last = player

    readonly property bool present: player !== null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property string identity: player?.identity ?? ""

    // "Artista – Título", ou só o título (vídeos e rádios costumam vir sem artista)
    readonly property string line: artist !== "" && title !== "" ? artist + " – " + title : (title || identity)

    // o Quickshell não avisa quando a posição anda: pede a leitura uma vez por segundo enquanto toca
    Timer {
        running: root.playing
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function next() { if (player && player.canGoNext) player.next() }
    function previous() { if (player && player.canGoPrevious) player.previous() }

    // 75 → "1:15"; 3725 → "1:02:05"
    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0))
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, r = s % 60
        const pad = n => (n < 10 ? "0" : "") + n
        return h > 0 ? h + ":" + pad(m) + ":" + pad(r) : m + ":" + pad(r)
    }
}
