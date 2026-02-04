# hoerbuch_check

Mit dem Script können Audio Dateien schnell bzgl. der ersten und letzten 10 Sekunden sowie auf die ACX Verträglichkeit überprüft werden.

Voraussetzung für die Ausführung ist das Vorhandensein von ffmpeg, also ggf. mittels

brew install ffmpeg

nachinstallieren.

Das Script an sich kann irgenwo liegen, wer's verwenden will sollte sich mit der shell auf unixoiden Betriebssystemn auskennen.

Aufruf:

./check.sh [--anfang] [--ende] <Liste der Dateien>

Wenn --anfang und --ende weggelassen werden, dann werden sowohl die ersten und die letzten 10 Sekunden über den eingebauten <lautsprecher abgespielt.

Wenn die Dateiliste leer ist, dann werden alle Audio Dateien im aktuellen Verzeichnis an- und aus-gelesen.

Die Daten von dem ACX Check werden immer ausgegeben.

Beim Abspielen wird for dem Anfang ein kurzes Pieps Signal ausgegeben. Das Ende wird durch zwei kurze Piepser angekündigt.

Und jetzt ... viel Erfolg beim Testen

PS: ´damit das script immer zur Verfügung steht liegt es bei mir unter /usr/local/bin (sudo ist Dein Freund). Danach ein rehash und alles ist in Butter ....

# Copyright
Karl-Heinz Welter & claude.ai, 2026-02-04
