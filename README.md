# hoerbuch_check

Mit dem Script können Audio Dateien (*.wav) schnell und einfach bzgl. der ersten und letzten 10 Sekunden sowie auf die ACX Verträglichkeit überprüft werden.

Voraussetzung für die Ausführung ist das Vorhandensein von ffmpeg, also ggf. mittels

> brew install ffmpeg

nachinstallieren.

Das Script an sich kann irgenwo liegen, wer's verwenden will sollte sich mit der shell auf unixoiden Betriebssystemn auskennen.

Aufruf:

> ./check.sh [--anfang] [--ende] [Dateiliste *.wav]

Wenn --anfang und --ende weggelassen werden, dann werden sowohl die ersten als auch  die letzten 10 Sekunden der WAV-Datei(en) über den eingebauten Lautsprecher abgespielt.

Wenn die Dateiliste leer ist, dann werden alle Audio Dateien (*.wav) im aktuellen Verzeichnis an- und aus-gelesen.

Die Daten von dem ACX Check werden immer ausgegeben.

Beim Abspielen wird vor dem Anfang ein kurzes Pieps Signal ausgegeben. Das Ende wird durch zwei kurze Piepser angekündigt.

Und jetzt ... viel Erfolg beim Testen

PS: Damit das Script immer zur Verfügung steht liegt es bei mir unter /usr/local/bin (sudo ist Dein Freund). Danach ein rehash und alles ist in Butter ....

# Copyright
Karl-Heinz Welter & claude.ai, 2026-02-04
