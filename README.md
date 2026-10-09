# Nachtwache — Fireteam-Survival im Stil von „Cabin Fever“

Ein verlassener Hof bei Nacht, Regen und Nebel – und darunter ein geheimes Labor der Helix Corporation. Dein Trupp seilt sich aus dem Helikopter ab, hält das Farmhaus gegen die Infizierten und gegen Helix' Eliteeinheit C.R.U., holt die Forscherin Nadja aus dem Keller und fliegt sie aus. Du kämpfst mit zwei Bots (**Viper**, **Scorpion**, später auch **Raven**) oder zu zweit im **Koop** über das Netzwerk. Entwickelt mit **Godot 4.7.2**, GDScript und dem **Forward+-Renderer** (volumetrischer Nebel). Karte, Hände und Effekte entstehen im Code; Schrotflinten, Pistolen, Scharfschützengewehr, Granatwerfer, Minigun, Helikopter und Hack-Modul per Blender-Skript; Gegner, P90, Honey Badger, UMP45, die Soldaten, Nadja und die Händlerin sind deine Modelle aus `assets/models`. Die Animationen kommen von Mixamo, Sounds und Stimmen von ElevenLabs.

## Starten

- **SPIELEN.cmd** startet das Spiel, **IN_GODOT_OEFFNEN.cmd** öffnet den Editor. Beide suchen Godot neben dem Spielordner, unter `D:\Games\AI Games\` und in deinen Downloads. Liegt Godot woanders, trage den Pfad oben in der Liste der Dateien ein.
- Das Spiel läuft standardmäßig mit **Direct3D 12** (damit OBS es als Spiel aufnehmen kann). Zeigt das Bild Fehler oder friert es ein, nimm **SPIELEN_VULKAN.cmd**.
- Oder: im Godot-Projektmanager **Importieren** → `project.godot` → **F5**.
- **Mac:** `SPIELEN.command` – siehe den Abschnitt „Auf dem Mac“.
- **EINSTELLUNGEN** (im Hauptmenü und in der Pause): Lautstärke für alles, für Musik, Effekte und Stimmen, die **3D-Auflösung** (mit wie vielen Bildpunkten das 3D-Bild gerechnet wird: 100, 85, 70, 60, 50 oder 40 % – kleiner läuft schneller, die Anzeigen bleiben scharf), **Vollbild**, die Mausempfindlichkeit und eine Übersicht aller Tasten. Was du dort einstellst, gilt auch beim nächsten Start.

Die Hauptszene ist `scenes/main.tscn`. Die Karte wird von `scripts/cabin.gd` erzeugt und erscheint auch im 3D-Editor; Änderungen am Skript siehst du nach erneutem Öffnen der Szene.

## Steuerung

| Taste | Aktion |
|---|---|
| WASD | Bewegen |
| Maus | Umsehen |
| Linke Maustaste halten | Schießen. M14, SVD, Doppelbüchse und M107 geben **pro Klick einen Schuss** ab |
| Rechte Maustaste halten | Zielen über Kimme und Korn |
| R | Nachladen (die Schrotflinte lädt Patrone für Patrone; ein Schuss bricht das Laden ab) |
| Shift (beim Vorwärtslaufen) | Sprinten |
| Leertaste | Springen (geduckt: aufstehen) |
| C | **Ducken**, an und aus: Du bist niedriger und langsamer, die Waffe streut und tritt 30 % weniger. Hinter hüfthoher Deckung sehen dich Soldaten nicht, und was sie trotzdem schießen, geht in die Deckung. Sprinten oder die Leertaste richten dich auf |
| E | Station / Waffenshop benutzen, Teammitglied, Mitspieler oder Nadja aufhelfen |
| F | Taschenlampe |
| 1 / 2 / 3 / Mausrad | **Primärwaffe / Sekundärwaffe / schwere Waffe** – mehr trägst du ohne Waffengurt nicht (siehe „Waffen-Plätze“). Mit Gurten wechselt die Taste zwischen den Waffen ihrer Art; das Mausrad geht alle durch. Beim Wechsel blendet das Spiel kurz ein, was du trägst |
| Q | **Heilspritze:** gibt sofort 30 Lebenspunkte zurück (nie über 100) und braucht dann 8 Sekunden, bis sie wieder bereit ist. Immer dabei, kostet nichts; die Kachel unten rechts zählt die Sekunden herunter |
| V | **Nahkampf:** ein Schlag mit der Waffe. Wer direkt vor dir steht, wird einen Schritt zurückgeworfen und taumelt knapp zwei Sekunden. Kleiner Schaden, alle 0,85 Sekunden möglich. Schwere Soldaten werden nur kurz aufgehalten, den Crusher bewegt nichts |
| 4 / 5 / 6 | Befehl an das Team: Position halten / bei mir bleiben / frei bewegen (**X** hält ebenfalls) |
| G / T / H / B | Splittergranate / Blendgranate / **Molotowcocktail** / Claymore (aus dem Shop). Wurfkörper: **Taste halten** zeigt die Flugbahn und wo sie aufschlägt, **loslassen** wirft. Kurz antippen wirft sofort. Mit einem Wurfkörper in der Hand kannst du nicht schießen |
| E halten | Auftragsgegenstand benutzen (Code bergen, Generator starten, Sicherung, Kiste, Hack-Modul anbringen oder neu starten) |
| Leertaste / Enter / Mausklick | Die Ankunft per Helikopter am Anfang überspringen |
| N | In der Pause die nächste Runde sofort starten |
| Esc | Pausieren / fortsetzen (im Koop läuft das Spiel weiter) |
| F11 oder Alt + Enter | Vollbild (auch als Knopf im Menü; am Mac gehört F11 dem System) |
| F2 | Testhilfe: aktuelle Runde sofort abschließen |
| F1 | Nur im **Testraum**: das Testmenü öffnen und schließen |

## Dein Auftrag

Unter dem Hof liegt ein geheimes Labor der **Helix Corporation** – des Konzerns, der den Ausbruch verursacht hat und ihn jetzt vertuscht. Dein Trupp wird per Helikopter abgesetzt, hält das Farmhaus gegen die Infizierten und findet heraus, was Helix hier getrieben hat. **Colonel Coleman** führt euch über Funk.

### Die Geschichte einer Nacht

| Schritt | Was passiert |
|---|---|
| **Ankunft** | Der Helikopter schwebt über dem Landeplatz, der Trupp seilt sich ab (Zwischensequenz, mit der Leertaste zu überspringen). Vom Landeplatz geht es zum Haus |
| **Runde 1 – 3** | Am Anfang ist nur ein Teil des Hauses offen. Nach Runde 1 öffnen sich weitere Räume im Erdgeschoss, nach Runde 3 die Treppen ins Obergeschoss |
| **Hinweise** | Jeder erfüllte Auftrag ist ein Hinweis. Nach dem dritten ist klar: Die Forscherin **Nadja** sitzt im Labor unter dem Haus, und der Zugang ist versiegelt. (Spätestens vor Runde 6 finden Colemans Leute das auch ohne euch heraus.) |
| **Das Hack-Modul** | In der nächsten Runde wirft der Helikopter eine Kiste mit dem Hack-Modul in den Hof. Kiste öffnen (**E halten**), zur Kellertür im Haus, Modul anbringen (**E halten**) und verteidigen, bis der Hack durch ist. Das Modul **fällt zwischendurch aus** – von selbst oder weil die Infizierten es zerschlagen – und muss dann mit **E** neu gestartet werden |
| **Das Labor** | Der Keller ist offen. Unten steht Nadja hinter Panzerglas und gibt euch einen eigenen Auftrag (Festplatten sichern). In dieser Runde kommt oben der erste, noch nicht ausgewachsene Crusher |
| **Nadjas Tür** | Zwei Runden nach dem Keller kommt das Modul an ihre Tür. Jetzt greifen Infizierte **und C.R.U.** gleichzeitig an, die C.R.U. sprengt den Versorgungstunnel als zweiten Weg ins Labor, und das Modul fällt zweimal aus. Währenddessen erzählt Nadja über die Lautsprecher, was Helix getan hat |
| **Evakuierung** | Nadja ist frei – der Hauptauftrag ist erfüllt. Die nächste Runde ist die letzte: Bringt sie zum Landeplatz und haltet ihn, bis der Helikopter unten ist. Der Crusher kommt dazu; die Infizierten sind in dieser Runde 30 % weniger als sonst in Runde 10, und während ihr auf den Helikopter wartet, drängt weniger nach. Nadja hält deutlich mehr aus als ein Bot (260 statt 100 Lebenspunkte), und die Angreifer gehen zuerst auf die los, die schießen – auf sie nur, wenn sie viel näher steht. Geht sie doch zu Boden, hilf ihr mit **E** auf; liegt sie 30 Sekunden, ist die Nacht verloren. Stehen alle am Helikopter, ist sie gewonnen |

Die Nacht dauert damit acht oder neun Runden (neun, wenn ein früher Auftrag misslingt); die letzte zählt für die Bestenliste immer als Runde 10. Ohne die Geschichte (Karten ohne Labor, automatische Tests) bleibt es bei zehn Runden bis zum Helikopter.

Die Infizierten kommen aus dem Wald über den offenen Rand des Hofs (der Zaun rundherum ist weg) – immer von der Seite des Hofs, auf der du gerade bist – und dringen durch **Vordertür, Hintertür, Seitentür und das Loch in der Küchenwand** ins Haus ein (durch die Seitentür erst, wenn das Kaminzimmer offen ist). Über die **Treppe im Haus** und die **Außentreppe zum Balkon** kommen sie auch ins Obergeschoss, sobald es offen ist. Durch Fenster und über Geländer kannst du schießen, durchklettern kann niemand.

### Runden und Aufträge

Nicht jede Runde ist gleich. Ab Runde 3 würfelt das Spiel für jede Nacht neu aus, was kommt:

| Runde | Was passiert |
|---|---|
| Normale Welle | die Mischung aus der Tabelle unten |
| **Horde** | deutlich mehr Mauler in kürzeren Abständen |
| **Mutanten** | wenige Infizierte, dafür fast nur Spezialgegner |
| **C.R.U.** (ab Runde 4) | kaum Infizierte, dafür ein ganzer Trupp Helix-Soldaten |
| **Infizierte + C.R.U.** (ab Runde 4) | beides zugleich |
| **Hinterhalt** (ab Runde 5) | mitten in einer Runde kommt ein kleiner C.R.U.-Trupp aus dem Wald |

Dazu kommen **Aufträge** an zufälligen Orten (Marker mit Entfernung auf dem Bildschirm, Liste oben links). Sie bringen Vorrat, Score und einen Hinweis; solange einer offen ist, kommen weiter Infizierte nach.

| Auftrag | Was zu tun ist |
|---|---|
| **Zugangscodes bergen** | Die toten Helix-Forscher liegen von Beginn der Nacht an auf dem Hof, einer im Obergeschoss des Farmhauses. Beim Auftrag blinkt bei zwei oder drei von ihnen die Marke auf dem Rücken: hingehen und **E halten**. Zeitlimit |
| **Generator verteidigen** | Generator mit **E** starten und 80 Sekunden am Laufen halten. Die Infizierten greifen ihn an; fällt er aus, muss ihn jemand neu starten |
| **Strom wiederherstellen** | Stromausfall: alle Lampen aus, bis drei Sicherungskästen wieder eingeschaltet sind. Einer davon kann im Obergeschoss hängen |
| **Versorgungskiste holen** | Abgeworfene Kiste (rote Fackel) erreichen und öffnen: Munition und Verbandszeug |
| **Funkmast einschalten** | Zum Mast im Hof und am Schaltkasten **E halten** |
| **Position halten** | Im markierten Kreis stehen, bis die Anzeige voll ist (45 Sekunden) |
| **Proben bergen** (Nadja) | Wie die Codes, aber für Nadja: die Koffer ihrer toten Kollegen |
| **Festplatten sichern** (Nadja) | Drei Laufwerke im Labor ziehen |

### Gas und Gasmaske

Gas verletzt dich nach drei Sekunden und dann jede Sekunde weiter. Die **Gasmaske** aus dem Shop hält es ab, solange ihr Filter reicht (8, 20, 45 oder 120 Sekunden je nach Stufe); an frischer Luft erholt er sich. Die Restzeit steht unten rechts über den Taschen.

**Das Gas ist kaum zu sehen:** ein blasser, leicht grünlicher Dunst dicht über dem Boden, nur wenig dichter als der Nebel der Nacht. Du erkennst es daran, wo er liegt – und sonst an der Warnung **GIFTGAS**, an einem kurzen Zischen beim ersten Atemzug und, wenn du eine Maske trägst, an der Anzeige **IM GAS · MASKE … s**. Deine Bots rufen es aus, wenn in ihrer Nähe Gas aufquillt.

| Wo | Wann | Was hilft |
|---|---|---|
| **Am Waldrand, jenseits des Hofs** | immer | nicht hingehen. Einen Zaun gibt es dort nicht mehr: Die Grenze ist die Baumreihe und der Dunst davor |
| **Gasbänke im Hof** | ab Runde 2 eine, ab Runde 3 zwei, ab Runde 6 drei gleichzeitig | Dünner Dunst, der sich **ausbreitet**: Eine Bank beginnt als ein Fleck von rund 17 m Breite und wächst alle paar Sekunden um einen weiteren daneben, bis sie aus vier bis sieben Flecken besteht – bis zu 40 m lang. Drei Bänke bedecken zusammen bis zu einem Drittel des Hofs. Eine Bank liegt gut eine Minute, dünnt aus und quillt woanders wieder auf – nie auf dem Landeplatz, nie in Gebäuden und nie direkt auf dir (sie kann aber zu dir hin wachsen). Umgehen, im Haus warten oder mit Maske durchlaufen |
| **Giftnebel über einer Hofseite** | ab Runde 4, manchmal | Eine ganze Seite (Nord, Süd, Ost, West) liegt für die Runde unter demselben dünnen Dunst. In den Gebäuden bist du sicher |
| **Gasalarm im Haus** | ab Runde 4, manchmal, sobald das Obergeschoss offen ist | Zehn Sekunden Warnung, dann steht das **Erdgeschoss** des Farmhauses gut eine halbe Minute unter Gas. **Oben ist die Luft sauber**: rauf auf die Galerie, in die Zimmer oder auf den Balkon – oder Maske auf und unten bleiben. Keller und Nebengebäude bleiben frei |
| **Gas des Medic** | solange er lebt | Flache grüne Schwaden, die um ihn herumkriechen. Maske, Abstand – oder ihn erschießen |
| **Gasgranate des C.R.U. Elite** | wenn er eine wirft | Eine kleine Wolke für rund 13 Sekunden, dichter und besser zu sehen als das Gas im Hof, **auch in Räumen**. Raus aus der Wolke, oder Maske auf |

In den Runden, in denen ein Hack-Modul läuft oder der Helikopter kommt, gibt es keinen Gasalarm im Haus.

### Stimmen

Alle Funksprüche und Rufe sind **auf Englisch vertont** (ElevenLabs), mit Untertitel: **Colonel Coleman** über Funk, **Nadja** über die Laborlautsprecher und später neben dir, **Viper**, **Scorpion** und **Raven** rufen im Gefecht (Nachladen, Abschuss, Spezialgegner, C.R.U., am Boden …) und antworten auf Befehle, die **C.R.U.** ruft sich Kommandos zu – mit vier Stimmen, von denen drei kälter und härter angelegt sind: kurze, flache Sätze, tiefer gelegt und wie durch ein Helm-Funkgerät gesprochen; jeder Soldat behält seine Stimme –, die Händlerin grüßt. **Phantom, Havoc und Ghost** sprechen mit den drei Stimmen, die du für sie angelegt hast: Was sie in euren Funk sagen, klingt wie ein fremdes, enges, übersteuertes Funkgerät; was sie auf dem Hof rufen, ist unbearbeitet. Funksprüche reden nie durcheinander: Kommt einer, während ein anderer läuft, wartet er. Die Texte stehen in `scripts/radio.gd`, die Aufnahmen in `assets/voice/<sprecher>/<stichwort>_<nummer>.ogg`; fehlt eine Aufnahme, erscheint nur der Untertitel (zurzeit hat jede Zeile eine).

### Schwierigkeit und Bestenliste

Im Hauptmenü stellst du mit **STUFE** die Schwierigkeit ein: Leicht, Normal, Schwer, Albtraum. Höhere Stufen machen die Gegner nicht zäher, sondern bringen mehr und schnellere Infizierte, mehr Spezialgegner, härtere Treffer, weniger Fundstücke, höhere Preise, schwächere Heilung, giftigeres Gas, mehr Aufträge und Ereignisse, eine C.R.U., die schneller reagiert, besser trifft und öfter flankiert, ausweicht und wirft, und längere Hacks mit einem Ausfall mehr – und vervielfachen den Score. Die **BESTENLISTE** merkt sich pro Modus und Stufe die zehn besten Einsätze (`user://nachtwache_profile.json`).

### Endlosmodus

Im Hauptmenü schaltet **MODUS** zwischen **GESCHICHTE** und **ENDLOS** um (auch in den Einstellungen unter „Einsatz“). Der Endlosmodus ist von Anfang an spielbar:

- Keine Geschichte, keine Sperren, kein Helikopter: Das ganze Haus und das Labor stehen offen, du startest im Haus.
- **Es gibt keine letzte Runde.** Bis Runde 10 kommen dieselben Angreifer wie sonst; danach wächst jede Runde um 8 % der zehnten, jede zweite bringt einen Crusher, ab Runde 20 jede fünfte einen zweiten. Die Gegner werden mit jeder Runde zäher; schneller werden sie nur bis Runde 20, damit man ihnen noch davonlaufen kann.
- Rundenarten (Horde, Mutanten, C.R.U.), Aufträge, Gas und der Shop zwischen den Runden bleiben, wie sie sind.
- Die Nacht endet, wenn niemand mehr steht. Gewertet wird die erreichte Runde; der Endlosmodus hat **eigene Bestenlisten** je Stufe. Abschüsse und Aufträge zählen für Laufbahn und Fähigkeiten wie sonst.

### Modifikationen

**MODIFIKATIONEN · AN** (Hauptmenü oder Einstellungen, für beide Modi): Jede Runde nach der ersten bringt ein zufälliges Ereignis. Es wird mit der Runde angesagt und steht für die Dauer der Runde oben links. Nie kommt dasselbe zweimal hintereinander; die letzte Runde der Geschichte und Nadjas Tür bleiben, wie sie sind.

| Modifikation | Wirkung | ab Runde |
|---|---|---|
| Doppelte Horde | doppelt so viele Angreifer | 2 |
| Rudel | dreimal so viele Charger, Ripper, Leeches oder Striker wie sonst (mindestens sechs) | 3 |
| Hetzjagd | alle Gegner sind 22 % schneller und schlagen schneller zu | 2 |
| Zähe Brut | alle Gegner halten die Hälfte mehr aus | 2 |
| Blutrausch | jeder Treffer der Gegner tut 40 % mehr weh | 2 |
| Giftnacht | drei Gasbänke mehr, eine Hofseite im Nebel, und das Gas beißt schneller | 2 |
| Helix greift ein | ein C.R.U.-Trupp kommt mitten in der Runde | 4 |
| Schweres Kaliber | ein Crusher mischt sich unter die Horde | 5 |
| Fette Beute | Abschüsse bringen doppelten Vorrat, es fällt mehr Nachschub | 2 |

Mehr als 24 Angreifer sind nie gleichzeitig auf dem Hof (plus drei je Mitkämpfer), egal wie die Stufe und die Modifikation zusammenkommen. Eigene Modifikationen: ein Eintrag in `MODIFIERS` in `scripts/game.gd` – `rules` sind Faktoren auf die Regeln der Schwierigkeitsstufe für diese eine Runde.

### Der Hof

| Ort | Was es dort gibt |
|---|---|
| **Farmhaus, Erdgeschoss** | Große Halle mit Galerie (Waffenshop in der Mitte), Kaminzimmer, Esszimmer, Küche, Treppenhaus, Lagerraum mit **Munition (60)** und **Erste Hilfe (100)** |
| **Farmhaus, Obergeschoss** | Galerie rund um die Halle, vier Zimmer, Balkon mit Außentreppe; im Lagerboden (Nordosten) eine dritte **Munitionsstation**. Hier bist du sicher, wenn unten Gas steht, und manche Aufträge führen hier hinauf |
| **Scheune** (Nordosten) | zweite **Munitionsstation**, Heuboden, Tore an beiden Giebeln |
| **Werkstatt / Garage** (Nordwesten) | **Werkbank**: **E** öffnet ihr Menü mit fünf Linien für jede Waffe, die du trägst (siehe „Werkbank“) |
| **Gästehütte** (Südwesten) | zweite **Erste Hilfe** |
| **Schuppen** (Südosten), Koppel, Brunnen, Gemüsebeet, Straße mit Tor | Deckung und Wege zwischen den Gebäuden |
| **Keller und Labor** (unter dem Haus) | Hinter der Helix-Sicherheitstür unter der Treppe: Kellertreppe, Gang und die Laborhalle – verkleidete Wände, Leuchtbänder, Arbeitsinseln, Spinde mit Schutzanzügen. An der Wand stehen **sechs Serverschränke** (B-01 bis B-06) mit Laufwerksschächten; ringsum **Probentanks, in denen Infizierte in grüner Flüssigkeit hängen** – einer ist geplatzt, die Spuren führen davon weg. Im Westen **Nadjas Isolationsraum** hinter Panzerglas |
| **Versorgungstunnel** | Vom Labor nach Norden zu einem Betonbunker im Hof hinter dem Haus – der zweite Weg ins Labor |
| **Landeplatz** (Südwesten) | Freie Fläche mit Knicklichtern: Hier seilt ihr euch ab, hier landet am Ende der Helikopter |
| **Funkmast** (Südosten) | Gittermast mit Schaltkasten; ist er eingeschaltet, blinkt oben das rote Licht |

**Nicht alles ist von Anfang an offen.** Bretter versperren das Kaminzimmer (samt Seitentür), eine Barrikade die Treppe im Haus, ein Gittertor die Außentreppe; die Kellertür, Nadjas Tür und der Tunnel sind verriegelt. Das Kaminzimmer öffnet sich nach Runde 1, das Obergeschoss nach Runde 3, der Rest durch die Geschichte. Rote Lampen an den Sperren werden grün, wenn der Weg frei ist. Auch die Infizierten kommen nur durch, wo offen ist.

Der **Waffenshop** in der Halle ist **vor der ersten und nach jeder überstandenen Runde geöffnet** (grüne Lampe, Rollladen oben) und **während einer Runde geschlossen**. Die Pause dauert 20 Sekunden; im Solo-Spiel steht die Zeit, solange das Shop-Menü offen ist.

### Die Karte in der Ecke

Oben rechts liegt eine **Karte**: was im Umkreis von 26 Metern um dich ist, von oben gesehen und so gedreht, dass **vorn oben** ist (das „N“ am Rand zeigt nach Norden). Wände, Zäune, Bäume und Möbel sind als Umrisse gezeichnet – im Hof, im Obergeschoss und im Keller jeweils der Plan des Stockwerks, auf dem du stehst.

| Zeichen | Bedeutung |
|---|---|
| weißer Pfeil in der Mitte | du |
| **roter Punkt** | gewöhnlicher Infizierter (Mauler) |
| **gelber Punkt mit Rand** | Spezial-Infizierter (Charger, Ripper, Leech, Striker, Medic); der Crusher ist ein großer |
| **blaues Quadrat** | Soldat der C.R.U.; ein **großes** ist einer der drei Helix-Operatoren (solange er hinter seiner Blendgranate verschwunden ist, fehlt er) |
| grüner Punkt | Viper, Scorpion, dein Koop-Mitspieler (ein Ring, wenn er am Boden liegt) |
| helle Raute | offener Auftrag |

Wer weiter weg ist, als die Karte reicht, sitzt kleiner **am Rand** in seiner Richtung – so findest du den letzten Gegner einer Runde. Wer auf einem **anderen Stockwerk** steht, ist blass. Der **Stalker** erscheint nie auf der Karte. Größe, Reichweite und Farben stehen oben in `scripts/minimap.gd`.

### Infizierte

| Infizierter | Ab Runde | Verhalten |
|---|---|---|
| **Mauler** (fünf Körper: Hazmat-Anzug, Frau, Zivilist, Söldner, Bauarbeiter mit Helm) | 1 | Standardgegner. Schlurft aus dem Nebel und rennt los, sobald er dich bemerkt oder getroffen wird; schlägt, tritt und stößt mit dem Kopf |
| **Charger** | 1 | Fett und schnell. Schwillt in deiner Nähe an und platzt – Brocken, Blut an Boden, Wänden und Decke, Spritzer auf dem Bildschirm. Die Explosion reißt andere Infizierte mit |
| **Ripper** | 3 | Mutierter Hund. Sprintet, **springt dich aus ein paar Metern an** und beißt sich fest. Wenig Leben, aber schnell |
| **Leech** | 4 | Klein und sehr schnell. Springt dich an und klammert sich fest: Du verlierst Leben und kommst nur langsam voran. **E schnell drücken** schüttelt ihn ab; dein Team kann ihn auch herunterschießen |
| **Striker** | 5 | Schlank und schnell. Verliert angeschossen eine explosive Wucherung und lässt beim Tod drei weitere fallen |
| **Medic** | 4 | Der Infizierte mit den Tanks auf dem Rücken. Hält sich hinter den anderen und kommt nicht näher als nötig. Um ihn kriechen flache **grüne Gasschwaden** über den Boden – er selbst bleibt darüber gut zu sehen. Jeder Infizierte, den das Gas berührt, ist sofort und für acht Sekunden **verstärkt**: Er heilt, steckt nur noch gut die Hälfte ein und ist schneller – auch der Crusher. Du erkennst Verstärkte an **grün glühenden Augen, einem grünen Schimmer am Körper und leuchtenden Armen**. Für dich ist das Gas Giftgas. **Zuerst ausschalten**; deine Bots zielen bevorzugt auf ihn |
| **Stalker** | ab 2, außerhalb der Wellen | Gehört zu keiner Runde. Steht in der Ferne, am Fenster oder auf der Galerie und beobachtet – sieht man hin, ist er weg. Sprintet manchmal durchs Bild. Später in der Nacht schleicht er sich an: Er bewegt sich nur, wenn niemand hinsieht, packt zu und verschwindet. Genug Treffer vertreiben ihn; wer ihn über die Nacht ganz erledigt, bekommt 500 Vorrat. Sehr selten steht er direkt vor dir, wenn du den Shop verlässt |
| **Crusher** | 6, 8 und letzte | Der große Blaue. Vor der letzten Runde kommt er mitten in der Runde und ist noch nicht ausgewachsen (gut die Hälfte bzw. drei Viertel seines Lebens); am Ende steht er in voller Größe da. Sehr viel Leben, große Reichweite, kopfschussresistent – und seit v0.18 **fast doppelt so schnell zu Fuß** (2,9 m/s), mit härteren Schlägen (44 statt 34). Hältst du Abstand, **springt er dich an**: aus 5 bis 12 Metern, flach und weit, dorthin, wo du beim Aufkommen sein wirst – er landet gut einen Meter vor dir. **Wo er landet, bebt der Boden:** Wer näher als 4,5 Meter steht, nimmt Schaden, auch wenn ihn der Hieb selbst verfehlt. Ab halbem Leben wird er rasend; beim Tod löst er sich in eine Säurewolke auf |

- **Treffer wirken:** Jeder Treffer reißt den Körper herum, konzentriertes Feuer bringt Infizierte ins Taumeln. Tote fallen je nach Schussrichtung nach hinten, vorn oder zur Seite; es gibt mehrere Todesanimationen pro Richtung.
- **Blut:** Kopfschüsse und schwere Treffer können Kopf oder Arm abreißen, Leichen bluten aus, Blut bleibt an Boden und Wänden.
- Weit entfernte Infizierte **beeilen sich**, damit niemand auf Nachzügler warten muss.
- Abschüsse bringen **Score** und **Vorrat**; Kopfschuss-Kills geben 50 Punkte extra. Jede überstandene Runde bringt 100 Vorrat, **heilt dich vollständig** (auf höheren Stufen weniger: Schwer 80, Albtraum 65 Lebenspunkte) und füllt bei jeder Waffe, die du trägst, **die Hälfte der Reservemunition** wieder auf. Gefallene lassen gelegentlich **Munition** (beige) oder ein **Verbandspäckchen** (grün) fallen.
- Zum **Giftgas** siehe den nächsten Abschnitt: am Waldrand steht es immer, im Hof und im Haus kommt und geht es.

### C.R.U. – Containment Response Unit

Helix' Eliteeinheit: Sie soll Beweise vernichten, Nadja holen und alle ausschalten, die zu viel wissen. Die Infizierten lassen sie in Ruhe (ein Helix-Aerosol tarnt sie), und sie die Infizierten.

- Du erkennst sie im Dunkeln an der **roten Markerlampe** auf der Brust und am **Lichtkegel ihrer Waffenlampe**, der im Nebel steht. Fällt einer, gehen seine Lampen aus.
- Sie **schießen** in Feuerstößen, suchen sich Stellungen mit Deckung und Schusslinie, wechseln sie alle paar Sekunden und rücken geduckt vor.
- **Flankierer** arbeiten sich seitlich um dich herum, angeschlagene Soldaten **ziehen sich zurück** und kommen wieder.
- Pfeifen Kugeln knapp an ihnen vorbei, **werfen sie sich mit einer Rolle zur Seite** – außer der Schuss war schallgedämpft (Honey Badger, UMP45 mit Schalldämpfer). Sie rollen nur, wo auf der ganzen Länge der Rolle Platz und Boden ist: **nie auf einer Treppe**, nie gegen eine Wand oder ein Geländer. (Bis v0.13 trug die Roll-Animation das Modell zusätzlich gut einen Meter vom Körper weg; am Ende sprang es zurück – an einer Wand sah das aus, als rolle der Soldat hinein und tauche wieder auf. Die Animation läuft jetzt auf der Stelle, die Bewegung macht allein der Körper.)
- Sie haben **vier Stimmen** – jeder Soldat behält seine – und **zwölf Arten zu fallen**, je nachdem, woher der Schuss kam.
- Sie werfen **Granaten** auf stehende Ziele (rotes Leuchten, Warnung „GRANATE!“).

| Rolle | Besonderheit |
|---|---|
| Assault | Sturmgewehr, eine Granate |
| Breacher | Schrotflinte, sucht die Nähe |
| Heavy | lange Feuerstöße als Deckungsfeuer, schwer gepanzert, weicht nie aus |
| Marksman | wenige, harte Schüsse aus großer Entfernung, kniet beim Zielen |
| Medic | läuft zu Verwundeten und flickt sie |
| Commander | macht alle in seiner Nähe schneller und genauer; fällt er, ist der Trupp kurz verunsichert |
| Shield | trägt einen mannshohen Schild mit Sichtfenster vor sich her: **von vorn geht keine Kugel durch**, auch kein Kopfschuss. Er rückt langsam vor und **dreht sich nur träge** – lauf an ihm vorbei und schieß ihm in den Rücken oder in die Seite, oder nimm Granaten: eine Explosion geht um den Schild herum. In jedem Trupp ist einer – aber **nie stehen zwei gleichzeitig auf dem Hof**: Solange einer lebt, kommt der nächste ohne Schild, und in die Verstärkung, die Helix an Nadjas Tür nachschiebt, mischt sich keiner mehr |
| Elite | der Soldat mit Kapuze und Gasmaske, deren Gläser orange glühen. Gut zwei Drittel mehr Leben als ein Assault, eine Panzerung, die vier von zehn Treffern schluckt, und eine **AK-47**, die deutlich härter trifft. Statt Splittergranaten wirft er **Gasgranaten**: Wo eine liegen bleibt, steht für rund 13 Sekunden eine kleine Giftwolke – auch im Haus. Ab Runde 5 gehört einer zu jedem vollen C.R.U.-Trupp, in den letzten Runden sind es zwei |

Je höher die Schwierigkeit, desto schneller reagieren sie, desto besser treffen sie und desto öfter weichen sie aus, flankieren und werfen.

### Helix-Operatoren – Phantom, Havoc und Ghost

Drei Elite-Einheiten von Helix, die euch jagen – im Spiel heißen sie **Operatoren**. Du erkennst sie an den **blau leuchtenden Augen**, am eigenen **Lebensbalken** oben im Bild und am großen blauen Quadrat auf der Karte.

| Operator | Waffe | Auftreten |
|---|---|---|
| **Phantom** | schallgedämpfter Karabiner, kurze schnelle Feuerstöße | Schlank, Nachtsichtgerät. Arbeitet sich fast immer um dich herum. Glatt und überheblich |
| **Havoc** | Schrotflinte, kommt nah heran | Der Schwerste der drei, Kapuze, Maske, ein Bein aus Metall. Laut, und es macht ihm Spaß |
| **Ghost** | Gewehr, einzelne gezielte Schüsse aus der Distanz | Kapuze und Gasmaske, langer Mantel. Sagt wenig |

- **Sie sterben nicht.** Ist der Balken leer, brechen sie ab und verschwinden – „… ZIEHT SICH ZURÜCK“, und der Trupp bekommt Vorrat und Punkte dafür.
- **Blendgranate:** Alle 18 bis 28 Sekunden – und sofort, wenn sie viel Leben verlieren – werfen sie eine Blendgranate, verschwinden dahinter und **tauchen woanders wieder auf**, am liebsten in deinem Rücken. Die Warnung „BLENDGRANATE! Wegsehen!“ ist ernst gemeint: Je direkter du hinsiehst und je näher sie platzt, desto länger und greller ist das Bild weiß – bis zu drei Sekunden, dazu ein Pfeifen im Ohr. Wer ihr den Rücken zudreht, bekommt nur ein Viertel ab; hinter einer Wand gar nichts. Bots, die sie sehen, halten gut zweieinhalb Sekunden das Feuer. Solange einer verschwunden ist, kann ihn nichts treffen.
- **Sie kommen dir nach.** Phantom arbeitet auf mittlere Entfernung, Havoc sucht die Nähe, Ghost bleibt eigentlich 20 bis 34 Meter weg. Aber wer sich im Haus verschanzt, wird besucht: Sieht ein Operator sein Ziel länger als fünf Sekunden nicht, rückt er Schritt für Schritt nach – nach einer knappen Viertelminute steht auch Ghost auf fünf bis elf Meter vor dir. Und ist ein Operator der Letzte, der von einer Runde übrig ist, kommt er sofort: Die Runde endet mit einem Duell auf kurze Distanz, nicht mit Versteckspielen.
- **Sie reden.** Über **euren eigenen Funk** (blaue Zeile) – beim Kommen, im Kampf, wenn einer von euch liegt, beim Abhauen.
- Die Infizierten lassen sie in Ruhe, wie die C.R.U. Für deine Fähigkeiten zählen sie als C.R.U.-Soldaten: **Panzerbrechend** und der Rest des Brecher-Wegs wirken auch gegen sie (der Weg „Jäger“ nicht – der ist für Spezial-Infizierte). Kopfschüsse zählen bei ihnen weniger.
- **Wie viele kommen:** in der Geschichte je nach Stufe – Leicht **einer**, Normal **zwei**, Schwer und Albtraum **alle drei** –, aber jeder in einer eigenen Runde, nie zwei gleichzeitig, nie neben einem Crusher und nie in der letzten Runde. Welche es sind, wechselt von Nacht zu Nacht. Im **Endlosmodus** kommt ab Runde 5 alle vier Runden einer, ab Runde 13 kommen zwei zusammen, ab Runde 25 alle drei.
- Eigene Spezialfähigkeiten haben sie noch nicht: Das kommt später.

Die Werte stehen in `TYPES` (`scripts/infected.gd`: Leben), `ROLES` (`scripts/cru_soldier.gd`: Waffe, Panzerung) und oben in `scripts/operator.gd` (Blendgranate, Abstände); der Fahrplan in `OPERATOR_COUNT`, `OPERATOR_ROUNDS` und `OPERATOR_ENDLESS` in `scripts/game.gd`.

### Waffen

#### Waffen-Plätze

Du trägst **eine Primärwaffe, eine Sekundärwaffe und eine schwere Waffe** – Tasten **1**, **2** und **3**.

- Kaufst du eine Waffe, für deren Art kein Platz mehr frei ist, **ersetzt sie eine andere**: Die geht für die **Hälfte ihres Kaufpreises** in Zahlung. **Welche geht, bestimmst du** – unter „DAFÜR GEHT“ stehen alle, die Platz machen können (jede Waffe derselben Art, und mit Gurt auch die zusätzlichen der anderen Arten), jeweils mit dem, was sie einbringt. Vorgeschlagen ist die Waffe dieser Art, die du in der Hand hältst. Munition, Aufsätze und Werkbank-Stufen der alten Waffe sind dann weg.
- **Verkaufen** geht auch ohne Neukauf: Waffe in der Liste oder oben unter „DU TRÄGST“ anklicken, dann **VERKAUFEN** – für die Hälfte des Kaufpreises. Die letzte Waffe gibt der Shop nicht heraus.
- Das M4A4, mit dem jeder anfängt, bringt beim Tausch nichts ein – dafür gibt es das Gewehr im Shop jederzeit kostenlos zurück.
- Der **Waffengurt** (Reiter Ausrüstung, 250 / 400 / 600) schafft Platz für **je eine Waffe mehr, egal welcher Art** – bis zu drei Gurte, also höchstens sechs Waffen. Gurte gelten für die Nacht.

| Waffe | Art | Preis | Magazin | Besonderheit |
|---|---|---|---|---|
| M4A4 | Primär | Startwaffe | 30 | Solide auf jede Entfernung. Ein Modell mit eigenem Magazin, das beim Nachladen sichtbar gewechselt wird, und mit **Kimme und Korn**: Beim Zielen schaust du durch die Lochkimme auf den Kornstift. Nimmt **Aufsätze**; mit einem Visier klappen Kimme und Korn weg |
| AK-47 | Primär | 300 | 30 | Kaliber 7,62: knapp ein Drittel mehr Schaden pro Kugel als das M4A4 und etwas schneller, dafür mehr Rückstoß und Streuung. Das Magazin wird sichtbar gewechselt, und sie nimmt **Aufsätze** |
| G36 | Primär | 450 | 30 | Das beste Sturmgewehr im Regal: **750 Schuss pro Minute**, ein Viertel mehr Schaden pro Kugel als das M4A4, genauer und ruhiger im Rückstoß, 240 Schuss Reserve. Dein eigenes Modell (ein G36C) mit durchsichtigem Magazin, das beim Nachladen sichtbar gewechselt wird, und mit **Kimme und Korn** auf der Tragebügel-Brücke: Beim Zielen steht das Korn in der offenen Kimme genau in der Bildmitte. Eigene Sounds für Schuss, Magazin und Durchladen. Nimmt **Aufsätze** |
| P90 | Primär | 100 | 50 | Sehr schnell, streut mehr |
| UMP45 | Primär | 220 | 25 | Schwere MP: langsamer als die P90, dafür trifft jede Kugel härter. Das Magazin wird sichtbar gewechselt. Nimmt **Aufsätze** (siehe unten) |
| Schrotflinte | Primär | 250 | 6 | Neun Schrotkugeln pro Schuss, zusammen über 200 Schaden: aus der Nähe fällt fast alles mit einer Ladung. Wer sie überlebt, wird **zurückgeworfen** – je näher und je mehr Kugeln treffen, desto weiter (ab etwa zwölf Metern gar nicht mehr; Schilde fangen den Stoß ab, den Crusher bewegt nichts). Wuchtiger Rückstoß, Vorderschaft-Repetieren; volle Wirkung bis acht Meter, ab etwa 25 m fast wirkungslos |
| Honey Badger | Primär | 350 | 30 | Schallgedämpft, präzise, hoher Einzelschaden |
| M14 | Primär | 320 | 20 | **Einzelschuss:** ein Schuss pro Klick, **100 Schaden** – mehr als dreimal so hart wie eine M4A4-Kugel –, sehr genau, und die Kugel **geht durch einen Körper** und trifft den dahinter. Kimme und Korn. |
| Auto-Schrotflinte | Schwer | 500 | 8 | Halbautomatisch mit Kastenmagazin: kein Repetieren, drei Ladungen in der Sekunde, schnelles Nachladen. Jede Ladung schwächer als die der Pump-Flinte und mit weniger Stoß, dafür steht nichts lange, was davor steht. Eigener Schuss-Sound |
| M9 Pistole | Sekundär | 60 | 15 | Leicht und schnell, billige Zweitwaffe |
| .44 Magnum | Sekundär | 220 | 6 | Sechs Schuss, jeder ein Hammer |
| Scharfschützengewehr | Schwer | 450 | 5 | Zielfernrohr (rechte Maustaste), Repetierer; die Kugel geht durch bis zu vier Körper |
| SVD Dragunow | Schwer | 650 | 10 | Das zweite Scharfschützengewehr: **halbautomatisch**, ein Schuss pro Klick ohne Repetieren, zehn Schuss. Pro Treffer schwächer als der Repetierer, dafür rund dreimal so schnell; die Kugel geht durch zwei Körper. **Erst nach Runde 2** im Shop |
| Granatwerfer | Schwer | 900 | 6 | 40-mm-Granaten, zünden beim Aufschlag. Das Geschoss fliegt im **Bogen** und so langsam, dass du ihm nachsehen kannst (gut eine Sekunde für 20 m): Gerade gehalten kommt es nach rund 20 m herunter, für weitere Ziele hältst du höher. Die **rechte Maustaste** zeigt Flugbahn und Einschlagpunkt; der Werfer bleibt dabei neben der Sichtlinie. **Erst nach Runde 4** im Shop |
| Maschinengewehr | Schwer | 800 | 100 | Gurtgefüttert aus einem Kasten unter der Waffe: **100 Schuss und 400 in Reserve**, 700 Schuss pro Minute, etwas mehr Schaden pro Kugel als das M4A4. Dafür streut es aus der Hüfte, und der Kastenwechsel dauert gut vier Sekunden. **Erst nach Runde 3** im Shop |
| Minigun | Schwer | 1500 | 200 | Läuft kurz an und feuert dann 1300 Schuss pro Minute; macht langsam. **Erst nach Runde 6** im Shop |

### Klassenwaffen

Im Shop-Reiter **Klasse**: je eine Waffe pro Weg der Fähigkeiten, alle drei **schwere Waffen**. Kaufen kann sie nur, wer **diesen Weg gewählt und drei Punkte darin** hat (siehe „Fähigkeiten“); im Koop zählt der eigene Weg.

| Waffe | Weg | Preis | Besonderheit |
|---|---|---|---|
| Flammenwerfer | Säuberer | 700 | Ein Feuerstrahl bis zehn Meter, solange du die Taste hältst (Tank für 9 Sekunden, zwei Tanks Reserve). Wen der Strahl trifft, der nimmt Schaden und **brennt zweieinhalb Sekunden weiter**. Feuer geht um Schilde herum |
| Doppelbüchse .600 | Jäger | 650 | Zwei Läufe, zwei Schuss, jeder so hart wie anderthalb Treffer des Scharfschützengewehrs – und **gegen Spezial-Infizierte noch einmal die Hälfte mehr**. Kimme und Korn, kippt zum Laden auf |
| M107 Kaliber .50 | Brecher | 900 | Halbautomatisches schweres Scharfschützengewehr: **schießt von sich aus durch Schilde, ignoriert die Panzerung der C.R.U.** und geht durch bis zu fünf Körper. Fünf Schuss, starker Rückstoß |

### Aufsätze für M4A4, UMP45, AK-47 und G36

In der Shop-Liste **Aufsätze**, für jede dieser Waffen eigens zu kaufen. Die Liste zeigt nur die Teile für die Waffen, die du gerade trägst (darunter steht, welche Waffen überhaupt Aufsätze nehmen). Einmal gekauft, lässt sich ein Teil dort beliebig oft kostenlos anbringen und wieder abnehmen. Pro Platz sitzt immer nur ein Teil auf der Waffe: ein Visier auf der Schiene, ein Schalldämpfer an der Mündung.

| Aufsatz | Preis | Wirkung |
|---|---|---|
| Rotpunktvisier | 120 | Ein **holografisches Visier** (dein Modell): ein Gehäuse mit Haube, durch dessen Fenster du hindurchschaust, darunter die Tasten − und +, an den Seiten die Stellräder, unten die Hebelklemme. Im Fenster ein feiner, matter Leuchtpunkt in einem hauchdünnen Ring – derselbe wie bisher. Das Fenster steht 7 cm über der Schiene und damit über jeder Kimme. Etwas mehr Vergrößerung als über Kimme und Korn, beim Zielen 45 % weniger Streuung Auf dem G36 ist es ein Fünftel kleiner als auf den anderen Gewehren; beim Zielen sieht es gleich aus |
| Zielfernrohr 4× | 260 | Vierfache Vergrößerung. Das Bild füllt fast den ganzen Bildschirm; das Fadenkreuz hat Haltemarken für weite Schüsse. Beim Zielen 65 % weniger Streuung; die Sicht dreht langsamer |
| Schalldämpfer | 180 (AK-47: 200) | Leiser Schuss, kaum Mündungsfeuer, 20 bis 25 % weniger Rückstoß, etwas weniger Streuung, 5 % weniger Schaden – und die C.R.U. weicht deinen Schüssen nicht mehr aus |

### Ausrüstung aus dem Shop

Der Shop hat acht Reiter: **Waffen**, **Pistolen**, **Schwer**, **Klasse**, **Aufsätze**, **Ausrüstung**, **Verbrauch** und **Team**. Hinter dem Tresen steht die Händlerin.

So ist er aufgebaut (seit v0.18):

- **Links die Liste** des Reiters mit Preis oder Zustand (DABEI ✓, GESPERRT, AB RUNDE 4), **rechts das, was du darin anklickst**. Mit den Pfeiltasten gehst du durch die Liste; das Bild rechts folgt.
- **Waffen siehst du als Modell**, das sich langsam hin und her dreht, mit fünf Werten daneben – Schaden, Feuerrate, Magazin und Reserve, Nachladen, Präzision – und dem **Vergleich mit der Waffe, die sie ersetzen würde** (▲ besser, ▼ schlechter).
- **Aufsätze** siehst du schon vor dem Kauf **an der Waffe**.
- **Ausrüstung und Verbrauch** kaufst du direkt in der Zeile (der Preis ist der Knopf); die Zeile zeigt, wie viel du schon hast (●●○○).
- Oben steht, **was du trägst**, nach Tasten sortiert; jede Waffe dort ist ein Knopf, der sie zeigt (zum Verkaufen).
- Nach einem Kauf bleibt alles, wo es war: die Liste springt nicht zurück.

| Gegenstand | Preis | Wirkung |
|---|---|---|
| Splittergranate (G) | 60 | Explodiert nach gut zwei Sekunden, reißt alles im Umkreis mit – auch dich. Bis zu vier |
| Blendgranate (T) | 45 | Betäubt Infizierte, die sie sehen, für einige Sekunden. Bis zu vier |
| Molotowcocktail (H) | 70 | Zerplatzt am ersten, was er trifft – Boden, Wand oder Gegner. Rund sieben Meter Boden brennen neun Sekunden: Gegner darin nehmen viel Schaden und **brennen noch drei Sekunden weiter**, wenn sie herauslaufen. Das Feuer verschont auch dich nicht; deine Bots lässt es in Ruhe. Bis zu drei |
| Claymore (B) | 90 | Mine vor deinen Füßen; zündet, sobald ein Infizierter davor läuft. Bis zu vier |
| Adrenalinspritze | 300 | Rettet dich einmal, wenn dein Leben auf null fällt |
| Schutzweste / Schwere Rüstung | 150 / 300 | 50 bzw. 100 Rüstung; Rüstung fängt 60 % jedes Treffers ab |
| Ballistische Weste | 160 / 260 / 400 | Drei Stufen gegen die C.R.U.: 25, 40 und 55 % weniger Schaden durch ihre Kugeln und Granaten. Verbraucht sich nicht und wirkt zusätzlich zur Rüstung; gegen Infizierte hilft sie nicht. Die Stufe steht neben der Lebensanzeige |
| Waffengurt | 250 / 400 / 600 | Drei Stufen: Platz für je eine Waffe mehr, egal welcher Art (siehe „Waffen-Plätze“) |
| Gasmaske | 150 / 250 / 400 / 600 | Vier Stufen: Filter für 8, 20, 45 und 120 Sekunden im Giftgas; erholt sich an frischer Luft. Wofür sie gut ist, steht unter „Gas und Gasmaske“ |
| Team: Schutzplatten | 180 / 300 / 450 | Drei Stufen: **+30 % Leben je Stufe** für deine beiden Bots (bis 190). Gilt für diese Nacht; nur im Einsatz mit Bots |
| Team: Scharfe Munition | 180 / 300 / 450 | Drei Stufen: **+20 % Schaden je Stufe** für deine beiden Bots (bis +60 %) |

Die Preise gelten für „Normal“ und steigen mit der Schwierigkeit.

### Werkbank

An der Werkbank in der Garage öffnet **E** ein Menü. Links wählst du eine deiner Waffen (die in der Hand ist vorgewählt), rechts stehen **fünf Linien** – jede zeigt, was sie aus der Waffe gemacht hat und was die nächste Stufe bringt:

| Linie | Stufen | Preis | Wirkung |
|---|---|---|---|
| **Schaden** | 3 | je 250 | +10 Schaden pro Schuss und Stufe (bei Schrot auf die Kugeln verteilt); Flammenwerfer und Granatwerfer +15 % je Stufe |
| **Magazin** | 1 | 200 | +50 % Magazin (was der Shop früher als „Größere Magazine“ verkauft hat) |
| **Munition** | 2 | 150 / 220 | +25 % Reservemunition je Stufe, sofort aufgefüllt |
| **Nachladen** | 2 | 180 / 260 | je Stufe 12 % schneller |
| **Stabilität** | 2 | 150 / 220 | je Stufe 15 % weniger Rückstoß |

Jede Linie gilt **nur für diese eine Waffe** und geht mit ihr, wenn du sie verkaufst oder eintauschst. Nicht jede Linie passt zu jeder Waffe (kein größeres Magazin für die Doppelbüchse, keine Stabilität für den Flammenwerfer). Die Zahlen stehen in `UPGRADES` in `scripts/player.gd`.

### Dein Team

Im Solo-Spiel begleiten dich zwei Bots – am Anfang **Viper** (Honey Badger) und **Scorpion** (Schrotflinte). Sie halten ein paar Schritte Abstand, kommen nach, wenn du dich entfernst, schießen selbstständig, laden nach und weichen zurück, wenn ihnen etwas zu nahe kommt. Geht einer zu Boden, hilfst du ihm mit **E** auf; nach 14 Sekunden oder am Rundenende steht er von selbst wieder. **Gehst du selbst zu Boden**, kommt der nächste Bot angerannt und hilft dir auf – verloren ist die Nacht erst, wenn niemand mehr steht.

Befehle für beide Bots: **4** (oder **X**) = Position halten (an der Stelle, auf die du zielst; ein Ring markiert sie), **5** = bei mir bleiben, **6** = frei bewegen (sie suchen sich die Infizierten selbst, bleiben aber in deiner Nähe). Im Shop-Reiter **Team** kannst du sie für die Nacht verstärken: mehr Leben und mehr Schaden, je drei Stufen. Sie bestätigen jeden Befehl und rufen im Gefecht. Für fast alles haben sie mindestens drei verschiedene Sprüche, und sie melden auch: die ersten Infizierten einer Runde, Gas, das in ihrer Nähe aufquillt, eine Granate, die bei ihnen landet, den Medic, einen Schild-Soldaten, einen erlegten Spezial-Infizierten, einen Leech an dir, eigene schwere Verletzungen – und manchmal sagen sie etwas in die Stille zwischen zwei Runden. Mit Team kommen mehr Infizierte. Ohne Bots starten: `SPIELEN.cmd` um ` -- --no-team` ergänzen.

**Am Anfang der Nacht halten sich die Bots zurück:** In Runde 1 machen ihre Schüsse 40 % des vollen Schadens, und sie warten knapp eine Sekunde, bevor sie auf einen neuen Gegner schießen – die ersten Abschüsse gehören dir. Mit jeder Runde legen sie zu, ab Runde 7 sind sie bei voller Stärke (`GREEN_DAMAGE`, `GREEN_WAIT`, `SEASONED_ROUND` in `scripts/teammate.gd`). Die Team-Upgrades aus dem Shop kommen obendrauf.

**Aufträge übernehmen** die Bots erst, wenn du es ihnen mit einer Fähigkeit beigebracht hast (siehe „Fähigkeiten“): Dann läuft der jeweils nächste freie Bot von selbst los, erledigt die Sache etwa halb so schnell wie du und kommt zurück. In der Auftragsliste steht, wer gerade hilft. Mit **4** oder **X** (Position halten) bleiben sie bei dir.

Wer steht und nichts zu bekämpfen hat, **behält seine Blickrichtung** und dreht sich nicht mit dir mit. Willst du dir die Modelle in Ruhe ansehen: **4** oder **X** drücken – dann bleiben sie stehen, auch wenn du nah herangehst (bei „bei mir bleiben“ machen sie dir ab zwei Metern Platz).

**Skins & Trupp** (Hauptmenü): Hier wählst du, wie du selbst aussiehst – so sieht dich dein Koop-Mitspieler, und so seilst du dich am Anfang ab – und welche zwei Bots mitkommen.

| Aussehen | Freigeschaltet | Als Bot wählbar |
|---|---|---|
| Fireteam (das Spielermodell) | von Anfang an | nein |
| Viper, Scorpion | von Anfang an | ja |
| Raven (Honey Badger) | nach dem ersten gewonnenen Einsatz | ja |
| C.R.U.-Rüstung | 40 C.R.U.-Soldaten ausgeschaltet | nein |
| Breacher-Rüstung | 500 Gegner ausgeschaltet | nein |
| **Phantom**, **Havoc**, **Ghost** | den jeweiligen Operator einmal in die Flucht geschlagen (zählt für beide Koop-Spieler) | nein |

Was du selbst trägst, bleibt für die Bots wählbar: Du kannst als Viper spielen und trotzdem Viper im Trupp haben. Zum Ausprobieren lässt sich der Trupp auch beim Start festlegen: `SPIELEN.cmd` um ` -- --squad=raven,viper` ergänzen. Die Zähler stehen in der Laufbahn deines Profils (`user://nachtwache_profile.json`); automatische Testläufe schreiben dort nichts hinein.

### Fähigkeiten

Im Hauptmenü unter **FÄHIGKEITEN** stehen drei Wege. **Deine Punkte kannst du frei auf alle drei verteilen – im Einsatz wirkt aber immer nur einer: der aktive.** Nur seine Fähigkeiten zählen, nur seine Klassenwaffe gibt es im Shop:

| Weg | Schwerpunkt | Fähigkeiten | Klassenwaffe |
|---|---|---|---|
| **Säuberer** | gegen die Masse der Infizierten | mehr Schaden und Kopfschuss-Schaden gegen gewöhnliche Infizierte, schneller nachladen, weniger Schaden durch sie, mehr Reservemunition, **Spürtrupp** (die Bots bergen Zugangscodes, Probenkoffer und Festplatten), **Ausgebrannt** (was dein Flammenwerfer anzündet, platzt harmlos – siehe unten); zuletzt: Gewehrkugeln durchschlagen einen Infizierten | Flammenwerfer |
| **Jäger** | gegen Spezial-Infizierte | mehr Schaden gegen sie und weniger durch sie, der Maskenfilter hält länger, weniger Säureschaden, einen Leech schneller abschütteln, **Techniker** (die Bots schalten Sicherungen und den Funkmast ein und öffnen Versorgungskisten); zuletzt: jeder erlegte Spezial-Infizierte heilt | Doppelbüchse .600 |
| **Brecher** | gegen die Soldaten der C.R.U. | ihre Panzerung hält weniger ab, weniger Schaden durch Kugeln und Granaten, **das Scharfschützengewehr schießt durch den Schild**, **Wachposten** (die Bots halten markierte Stellungen, starten den Generator und starten ihn und das Hack-Modul neu, wenn sie stehen); zuletzt: auch Magnum, AK-47 und **beide Schrotflinten** schießen durch den Schild, mit halbem Schaden (der Stoß der Schrotflinte geht nicht hindurch) | M107 Kaliber .50 |

So funktioniert es:

- Deine Laufbahn ergibt **Erfahrung**: jeder Abschuss 1, jeder Spezial-Infizierte 4, jeder C.R.U.-Soldat 6, jeder Auftrag 60, jede Wiederbelebung 30, jeder gewonnene Einsatz 500. Erfahrung ergibt **Stufen** (Stufe 2 bei 500, Stufe 5 bei 5.000, Stufe 10 bei 22.500), jede Stufe ab der zweiten **einen Punkt**. Was du bisher gespielt hast, zählt schon mit. Nach jedem Einsatz steht auf dem Schlussbild, was er gebracht hat.
- Ein Punkt kauft einen Rang (der Knopf **+** neben der Fähigkeit). Die zweite Reihe eines Wegs öffnet sich ab **drei**, die dritte ab **sieben** Punkten in diesem Weg.
- Ab **drei Punkten** in einem Weg verkauft der Shop dessen **Klassenwaffe** – solange dieser Weg aktiv ist.
- **AKTIVIEREN** auf der Seite der Fähigkeiten schaltet einen Weg scharf – jederzeit im Hauptmenü, kostenlos, und **ohne dass ein Punkt verloren geht**. Der aktive Weg trägt die Marke **AKTIV**; der Hauptmenü-Knopf nennt ihn. Der allererste Punkt, den du vergibst, aktiviert seinen Weg gleich mit.
- Du kannst also einen Weg ganz ausbauen oder zwei zur Hälfte und vor jeder Nacht wählen, welchen du nimmst. Die Punkte in den anderen Wegen ruhen so lange.
- **PUNKTE ZURÜCK · NEU VERTEILEN** nimmt alle Punkte zurück – kostenlos.
- **Ausgebrannt** (Säuberer, zweite Reihe): Solange ein Gegner von **deinem Flammenwerfer** brennt, schadet es dem Trupp nicht, wenn er platzt. Ein **Charger** reißt weiter die Infizierten um sich mit, tut euch aber nichts; die **Wucherungen eines Strikers** fallen verkohlt ab und verglimmen nur. Ist das Feuer aus (zweieinhalb Sekunden nach dem letzten Strahl), ist er wieder gefährlich. Im Koop gilt es für alles, was derjenige mit der Fähigkeit anzündet.
- Bei Stufe 16 ist Schluss: 15 Punkte – so viele wie bisher, genug für (fast) alle Ränge eines Wegs oder für den größeren Teil von zweien (Stufe 16 bei 60.000 Erfahrung).
- Die Punkte stehen in deinem Profil; im Koop hat jeder seine eigenen. Der Hauptmenü-Knopf zeigt, wie viele noch frei sind.

Die Zahlen stehen in `scripts/skills.gd` (`TREES`, `TIER_NEEDS`, `WEAPON_NEEDS`, `WORTH`). `IN_SERVICE := false` nimmt alles wieder außer Betrieb.

## Testraum

Im Hauptmenü unter **TESTRAUM**: der Hof ohne Nacht. Keine Runde beginnt von selbst, das ganze Haus und das Labor stehen offen, es ist hell (kein Nebel, kein Regen, kein Gewitter) – und **nichts davon zählt**: keine Bestenliste, keine Erfahrung, keine Skins. Den Testraum gibt es nur allein, nicht im Koop.

**F1** öffnet und schließt das Testmenü (auch über Esc → TESTMENÜ). Der Raum läuft dahinter weiter.

| Seite | Was du dort tun kannst |
|---|---|
| **GEGNER** | Jede der 19 Gegnerarten per Klick vor dich stellen – dorthin, wo du hinsiehst: alle Infizierten samt Stalker und Crusher, jede Rolle der C.R.U. oder ein **ganzer Trupp**, dazu Phantom, Havoc und Ghost. Einstellbar: **Anzahl je Klick** (1, 3, 5, 10) und **Stärke** wie in Runde 1, 5, 10, 20 oder 30. **EINGEFROREN** lässt alle stehen, wo sie sind – zum Ansehen. **ALLE ENTFERNEN** räumt das Feld. **ECHTE RUNDE STARTEN** (oder Taste N) spielt eine normale Runde der gewählten Stärke wie im Endlosmodus; danach wartet der Testraum wieder |
| **DU & WAFFEN** | **Unendlich Leben** (an: Treffer siehst und hörst du weiter, verlierst aber nichts; aus: fällst du, stehst du sofort wieder). **Munition:** wie im Einsatz, Reserve endlos (du lädst noch nach) oder Magazin endlos – Granaten, Blendgranaten, Molotows und Minen füllen sich mit auf. **ALLE WAFFEN** gibt dir jede Waffe auf einmal (1, 2 und 3 gehen sie der Art nach durch), **VOLLE AUSRÜSTUNG** Rüstung, Platten, Maske, Gurte und Spritze. Den Trupp kannst du dazuholen oder wegschicken. **Waffenshop und Werkbank öffnen sich von überall**, und alles ist frei: auch die Klassenwaffen und die Waffen, die es sonst erst spät in der Nacht gibt |
| **STIMMEN** | Jede der 498 Aufnahmen einzeln abspielen, nach Sprecher sortiert – Phantom, Havoc, Ghost, Coleman, Nadja, Viper, Scorpion, Raven, die vier Stimmen der C.R.U., die Händlerin –, mit dem Text daneben. **ALLE NACHEINANDER** spielt alles, was ein Sprecher hat. Bei Coleman schaltet **KANAL · GEKAPERT** auf den Klang um, den er hat, sobald Nadja aus ihrem Raum ist |
| **WELT** | **Tageslicht** an und aus (aus: die Nacht wie im Einsatz, mit Nebel und Regen), **Tempo** 100, 50 oder 25 %, ein Sprung zu Hof, Halle, Obergeschoss, Labor, Landeplatz oder Scheune, und eine Blendgranate auf dich selbst |

Gerufene Gegner verhalten sich wie im Einsatz: Die Operatoren melden sich im Funk, werfen ihre Blendgranate und ziehen sich zurück, wenn ihr Balken leer ist; ein Crusher springt; die C.R.U. sucht Deckung. Oben links steht, wie viele gerade auf dem Feld sind.

Technisch ist der Testraum eine Endlos-Nacht, die nie beginnt. Alles dazu steht in `scripts/sandbox.gd` (die Listen und Schalter ganz oben), das Menü in `scripts/hud.gd` (`_menu_test`).

## Mission 2 – Die Villa

Im Hauptmenü stehen beide Missionen nebeneinander: **MISSION 1 · HOF 19** und **MISSION 2 · DIE VILLA**. Die gewählte ist hervorgehoben, und „EINSATZ STARTEN“ startet sie. Bei Mission 2 wird dann die zweite Karte aufgebaut (beim ersten Mal dauert das ein paar Sekunden): eine Villa im ummauerten Park, darunter ein versteckter Bahnhof, und am Ende der Gleise eine Forschungsanlage tief unter der Erde. MODUS (Geschichte oder Endlos) und MODIFIKATIONEN gelten nur für Mission 1 und sind bei Mission 2 ausgegraut. Mission 2 gibt es vorerst **nur allein mit dem Trupp**; im Koop wird weiter der Hof gespielt, auch wenn Mission 2 gewählt ist.

Es gibt **keine Runden**. Die Nacht ist ein Weg in Etappen: Oben links steht, wo du bist und was zu tun ist, und eine Markierung („ZIEL“) zeigt die Richtung – im Bild und auf der Karte in der Ecke. Gegner warten in den Räumen vor dir, und solange eine Etappe läuft, kommen weitere von dort, wo gerade niemand hinsieht. Dreimal muss eine Stellung gehalten werden.

| Etappe | Was passiert |
|---|---|
| **Der Park** | Der Helikopter setzt euch auf dem Kies vor der Villa ab (Leertaste, Enter oder Klick überspringt die paar Sekunden). Aus dem Wald kommen Infizierte durch die Breschen der Mauer; wer die Auffahrt hochgeht, trifft die C.R.U., die das Haus hält |
| **Die Villa** | Halle mit zwei Treppen und Galerie, Salon, Bildergalerie, Bibliothek, Küche – das Ziel ist der Speisesaal. Dort öffnet Nadja das Schloss neben dem Spiegel: **haltet ihr den Rücken frei**, bis der Spiegel zur Seite fährt |
| **Der Abstieg** | Eine Betontreppe, zwei Läufe tief, hinunter zu einem Stahltor |
| **Der Bahnhof** | Die C.R.U. hält den Bahnsteig. Ist er frei, verschwindet Nadja durch eine Schleuse, die nur ihr aufgeht – sie hat euch gebraucht, um herzukommen. Phantom, Havoc und Ghost kommen aus dem Depot, die Waffen gesenkt; Ghost räumt den gekaperten Funk frei, und der echte Coleman ist wieder da. Dann: **im Stellwerk den Zug hochfahren und den Bahnsteig halten**, bis er bereit ist |
| **Im Tunnel** | Einsteigen, die Türen schließen, eine Viertelminute Fahrt |
| **Das Terminal** | Das Tor zur Anlage öffnet sich vom Leitstand oben auf der Galerie |
| **Die Verwaltung** | Kontrolle, Büros, Archiv, Server. Das Tor nach Norden hängt an der **Sicherheitszentrale** im Ostflügel |
| **Die Kantine** | Die Anlage riegelt ab, während ihr mittendrin steht: **durchhalten**, bis das System neu startet |
| **Zentralraum B2** | Die große Halle mit Galerie. Die Schleuse zum Forschungstrakt ist stromlos – der **Notstrom** wird im Generatorraum im Technikflügel eingeschaltet |
| **Die Forschung** | Durch die Dekontamination in den Laborgang: Labore hinter Glas, Quarantäne, Kryolager, ein Labor, das unter Wasser steht |
| **Die Eindämmung** | Die Halle am Ende: Der Frachtaufzug ist gerufen – **aushalten**, bis er da ist. Mit ihm endet dieser Abschnitt; wie es unten weitergeht, kommt später |

**Versorgungspunkte** (Munition, Erste Hilfe, Werkbank, Waffenschrank) stehen an der Landezone, am Bahnsteig, im Wachraum hinter dem Terminal und im Zentralraum; die Krankenstation dort hat einen weiteren Verbandsschrank. Vorrat bringen Abschüsse und jeder **Kontrollpunkt** (nach dem Spiegel, am Terminal, im Zentralraum, in der Forschung): Dort wird der Trupp versorgt, und nach einer Niederlage kannst du **AB KONTROLLPUNKT** weitermachen statt von vorn.

Nadja ist bis zum Bahnhof dabei und unbewaffnet wie in Mission 1: Fällt sie, hilf ihr mit E auf – bleibt sie länger als eine halbe Minute liegen, ist der Einsatz gescheitert.

**Was noch Platzhalter ist:** Die Gegner sind die aus Mission 1 (neue Infizierte und Kreaturen der Anlage kommen später), und alles, was Coleman, Nadja und die Operatoren hier sagen, steht nur als Text im Funkfeld – es ist noch nicht aufgenommen. Die Operatoren sind eine kurze Szene, keine Begleiter. C.R.U. und Infizierte bekämpfen einander noch nicht. Der Aufbau der Anlage ist fest, nicht zufällig. Mit dem Frachtaufzug ist Schluss: Einen Endgegner gibt es noch nicht.

Technisch: Die Karte steht in `scripts/hive_map.gd` (Räume, Türen und Einrichtung, Zone für Zone; `scripts/hive_core.gd` baut daraus Wände, Lampen und das Wegenetz), der Ablauf in `scripts/hive.gd` (ganz oben die Etappen, wer wo nachkommt und wie lange gehalten wird). Texturen und ein Teil der Möbel stammen von Poly Haven (CC0; Liste in `assets/hive/CREDITS.md`, `node tools/fetch_assets.js` holt sie neu). Bilder der ganzen Karte macht `--hive-check --capture-dir=<Ordner>`; `--bot-check --bot-mode=villa` lässt einen Bot die Mission durchlaufen.

## Koop zu zweit

1. **Dein Mitspieler braucht dasselbe Spiel.** `KOOP_PAKET_ERSTELLEN.cmd` packt das Projekt samt Godot in `Nachtwache-Koop-Paket.zip` (neben dem Projektordner). Er entpackt die ZIP und startet im Ordner `Nachtwache` die `SPIELEN.cmd`. Beim allerersten Start bereitet Godot die Spieldaten vor – das dauert etwa eine Minute (auf langsameren PCs länger). Hat dein Mitspieler einen **Mac**, baut `KOOP_PAKET_MAC_ERSTELLEN.cmd` stattdessen `Nachtwache-Koop-Paket-Mac.zip` – ohne Godot, das lädt er selbst (siehe „Auf dem Mac“). Bequemer für Updates ist **GitHub** (siehe „Über GitHub“).
2. **Du:** Hauptmenü → **KOOP HOSTEN**. Das Menü zeigt deine Adressen; dort stellst du auch die Stufe ein.
3. **Er:** **KOOP BEITRETEN** → deine Adresse eintragen → **VERBINDEN**. Sobald er verbunden ist, startest du den Einsatz.

**Beide brauchen dieselbe Version** (sie steht unten rechts im Hauptmenü). Seit v0.19 prüft das Spiel das beim Verbinden: Passt es nicht, steht bei beiden in der Lobby **„VERSIONEN PASSEN NICHT ✗ – Du hast v0.19, dein Mitspieler v0.20“**, und der Einsatz lässt sich nicht starten. Wer die ältere hat, holt das Update (siehe „Über GitHub“) und startet neu. Gegenüber v0.18 und älter weiß nur die neuere Seite Bescheid („… eine ältere Version (vor v0.19)“, nach drei Sekunden) – die alte kann es noch nicht sagen; bis v0.18 scheiterte so ein Einsatz einfach stumm.

Über das Internet benutzt das Spiel **UDP-Port 24565**. Beim Eröffnen fragt es den Router per UPnP, ob er den Port zu deinem PC durchlässt, und **das Menü sagt, was der Router geantwortet hat**:

| Das Menü sagt | Bedeutung | Was zu tun ist |
|---|---|---|
| **✓ Der Router hat UDP-Port 24565 für dich geöffnet** | Dein Mitspieler trägt die angezeigte Internet-Adresse ein | nichts – nach dem Einsatz schließt das Spiel den Port wieder |
| **der Router öffnet UDP-Port 24565 NICHT von selbst** | Der Router antwortet, erlaubt deinem PC aber keine eigenen Freigaben. So ist eine **FRITZ!Box** ab Werk eingestellt | einmal im Router einstellen (siehe unten) – oder VPN |
| **nicht direkt erreichbar** | Dein Anschluss hat keine eigene öffentliche IPv4-Adresse (der Anbieter teilt sie) | VPN-Tool, oder dein Mitspieler hostet |
| **keine automatische Freigabe** | Kein Router gefunden, der solche Anfragen annimmt (UPnP aus) | Port von Hand weiterleiten – oder VPN |

**FRITZ!Box einstellen** (einmalig, im Browser unter `http://fritz.box`, mit dem Kennwort der Box): **Internet → Freigaben → Portfreigaben → „Gerät für Freigaben hinzufügen“** und deinen PC auswählen. Dann eine von beiden:

- **Bequem:** den Haken **„Selbstständige Portfreigaben für dieses Gerät erlauben“** setzen, OK, **Übernehmen**. Danach öffnet das Spiel den Port bei jedem Hosten selbst (das Menü zeigt den Haken ✓) und schließt ihn danach wieder. Der Haken erlaubt allerdings jedem Programm auf diesem PC, Ports zu öffnen.
- **Eng:** **„Neue Freigabe“ → Portfreigabe → Anwendung „Andere Anwendung“**, Bezeichnung `Nachtwache`, Protokoll **UDP**, Port an Gerät **24565 bis 24565**, Port extern gewünscht **24565**, Freigabe aktivieren, OK, **Übernehmen**. Dann ist genau dieser eine Port dauerhaft offen; das Menü sagt weiter „nicht von selbst“, die angezeigte Adresse gilt trotzdem.

Die Box fragt bei solchen Änderungen oft nach einer Bestätigung (Taste an der Box drücken). Deine Internet-Adresse wechselt bei den meisten Anschlüssen täglich: Dein Mitspieler trägt jedes Mal die ein, die das Menü gerade zeigt.

**Ohne Router-Einstellung:** Ihr installiert beide ein VPN-Tool (z. B. ZeroTier oder Radmin VPN) und tretet demselben Netz bei; er trägt deine VPN-Adresse ein – sie steht im Menü unter „Im selben Netz / per VPN“. Im selben WLAN/LAN reicht die angezeigte lokale Adresse.

Ob dein Router mitmacht, lässt sich auch ohne Fenster prüfen: `Godot_v4.7.2-stable_win64.exe --headless --path "PFAD_ZU_NACHTWACHE" -- --router-check` schreibt eine Zeile `ROUTER … forward=open` (geöffnet), `refused` (nicht von selbst), `walled` (keine eigene Adresse) oder `none`.

Im Koop ersetzt dein Mitspieler die Bots. **Modus, Stufe und Modifikationen bestimmt der Host**; was eine Runde bringt, wird beiden angesagt. Wer sich duckt, wird auch vom Mitspieler geduckt gesehen. Schlag, Molotow und Flammenwerfer des Gasts rechnet der Host aus – sein Feuer brennt auf beiden Bildschirmen. Beide brauchen dieselbe Version. Die Geschichte läuft für beide: Der Gast sieht dieselben Sperren, Aufträge, Nadja und den Helikopter, und am Ende müssen **beide** mit Nadja am Landeplatz stehen. Vorrat und Score gehören dem Team, jeder hat eigene Waffen und Munition. Wer zu Boden geht, kann vom anderen mit **E** aufgehoben werden und steht nach der Runde wieder; liegen beide, ist die Nacht verloren. Der Host rechnet die Gegner, der Gast sieht sie mit kleiner Verzögerung.

## Über GitHub

Das Projekt liegt als **privates** Repository auf GitHub: `https://github.com/henrywidich-arch/Nachtwache`. Privat heißt: Nur du siehst es – und wen du einlädst. Dein Mitspieler braucht dafür ein kostenloses GitHub-Konto. Du lädst ihn auf der Seite des Repositorys unter **Settings → Collaborators → Add people** ein; er nimmt die Einladung an, die er per E-Mail bekommt.

So holt er sich das Spiel und später jedes Update:

- **Mit GitHub Desktop** (desktop.github.com) – der bequeme Weg: anmelden, **Clone a repository**, `Nachtwache` wählen. Für ein Update genügt später **Fetch origin** und dann **Pull origin**; geladen wird nur, was sich geändert hat.
- **Ohne Programm:** auf der Seite des Repositorys **Code → Download ZIP** und entpacken; der Ordner heißt dann `Nachtwache-main`. Für ein Update lädt er die ZIP neu – jedes Mal alles, rund 590 MB – und Godot bereitet die Spieldaten noch einmal ganz vor.

Weiter geht es wie unter „Auf dem Mac“ ab Punkt 3; Godot braucht er in beiden Fällen. Für den Koop müssen beide **denselben Stand** haben: Nach jedem Update erst holen, dann spielen. Ein Mitspieler mit Windows nimmt weiter `Nachtwache-Koop-Paket.zip`, da ist Godot schon dabei.

Im Repository fehlt nur der Ordner `.godot`: Diesen Zwischenspeicher baut jeder Rechner beim ersten Start selbst.

## Auf dem Mac

Das Spiel ist auch für einen Mac mit Apple-Chip vorbereitet. **Auf einem Mac ausprobiert wurde es noch nicht** – was genau ungeprüft ist, steht unter „Stand und Grenzen“. Klappt der Start per Skript nicht, führt der Weg über Godot (Punkt 4) trotzdem zum Ziel.

1. **Godot 4.7.2 für macOS** von godotengine.org laden (die Standard-Version, nicht .NET) – **genau dieselbe Version wie beim Mitspieler**, sonst startet das Projekt womöglich nicht oder der Koop läuft auseinander. Die geladene Datei entpacken, `Godot.app` in den Ordner **Programme** ziehen und **einmal per Doppelklick öffnen** (macOS fragt beim ersten Mal, ob die App aus dem Internet geöffnet werden darf), dann wieder schließen.
2. Das Spiel von GitHub holen (siehe „Über GitHub“) – oder `Nachtwache-Koop-Paket-Mac.zip` entpacken. Diese ZIP baut auf dem Windows-PC die Datei `KOOP_PAKET_MAC_ERSTELLEN.cmd`: das Projekt ohne die Windows-Startdateien und ohne Godot, rund 590 MB.
3. Im Ordner `Nachtwache` die Datei **`SPIELEN.command`** doppelklicken. Sie sucht Godot 4.7.2 in den Programmen, in den Downloads, auf dem Schreibtisch und neben dem Spielordner. Beim ersten Start bereitet Godot die Spieldaten vor (ein paar Minuten), danach startet das Spiel. Nach einem Update liest sie beim nächsten Start von selbst ein, was neu ist. Das Terminal-Fenster bleibt offen, solange du spielst.
   - Meldet macOS „nicht verifizierter Entwickler“, „kann nicht geöffnet werden“ oder „keine Zugriffsrechte“: das Programm **Terminal** öffnen, `bash ` tippen (mit einem Leerzeichen dahinter), die Datei `SPIELEN.command` ins Terminal-Fenster ziehen und Enter drücken.
4. **Der Weg ohne Skript:** Godot öffnen → **Importieren** → im Ordner `Nachtwache` die Datei `project.godot` wählen → warten, bis Godot alle Dateien eingelesen hat → oben rechts auf **▶** drücken. Die Taste dafür ist am Mac **⌘ B** (unter Windows F5).

Was am Mac anders ist:

- **Vollbild:** F11 gehört macOS (es blendet den Schreibtisch ein). Nimm **Alt + Enter** (⌥ ↩), den Knopf **VOLLBILD** im Menü oder den grünen Knopf am Fenster.
- **F2** (Runde überspringen, nur zum Testen) geht am MacBook nur zusammen mit **Fn**.
- **Eine externe Maus ist dringend empfohlen:** Gezielt wird mit gehaltener rechter Maustaste, das Mausrad wechselt die Waffe. Auf dem Trackpad wechselst du die Waffe mit den Zifferntasten.
- **Wenn es ruckelt:** unten im Menü **3D** kleiner stellen. Auf einem MacBook-Bildschirm startet das Spiel mit 50 %; 40 % ist die kleinste Stufe. Außerdem helfen: im Fenster statt im Vollbild spielen oder das Fenster kleiner ziehen, das Netzteil anstecken, den Stromsparmodus ausschalten, andere Programme schließen. In den ersten Minuten kann es kurz haken, wenn etwas zum ersten Mal zu sehen ist.
- **Koop:** Fragt macOS, ob Godot oder das Terminal **Geräte im lokalen Netzwerk** finden oder **eingehende Verbindungen** annehmen darf, erlaube es – sonst kommt keine Verbindung zustande.
- Die Überschriften stehen in einer anderen Schrift: Die Schablonenschrift von Windows gibt es am Mac nicht.

## Mit OBS aufnehmen

- Quelle **Spielaufnahme** → Modus **„Spezifisches Fenster aufnehmen“** → Fenster „Nachtwache“. Mit dem Standard-Start (Direct3D 12) sollte das direkt funktionieren.
- Alternativ **Fensteraufnahme** (Aufnahmemethode „Windows 10/11“) – die geht mit jedem Renderer.
- **F11** schaltet auf Vollbild; die „Spielaufnahme“ im Modus „Beliebige Vollbildanwendung“ greift dann ebenfalls.

## Hier ändern wir das Spiel weiter

| Datei | Zuständigkeit |
|---|---|
| `scripts/game.gd` | Runden (`ROUNDS`), Score, Shop, Käufe, Pause, Sieg und Niederlage, Team und Team-Befehle, Koop-Lobby |
| `scripts/mission.gd` | Rundenarten (`WAVES`), C.R.U.-Trupp (`SQUAD_ORDER`) und Aufträge (`TASKS`): Planung der Nacht, Gegenstände in der Welt, Geräte, die laufen und ausfallen (`RUNNERS`), Belohnungen |
| `scripts/gas_field.gd` | Gas, das kommt und geht: Gasbänke im Hof (`POCKET_ROUNDS`, `BANK_PATCHES`, `SPREAD_EVERY`), wie dicht und wie sichtbar der Dunst ist (`YARD_HAZE`, `YARD_GLOW` und der Nebel-Shader `HAZE_CODE`), Gasalarm im Erdgeschoss (`FLOOD_SECONDS`) |
| `scripts/story.gd` | Die Geschichte: welcher Schritt in welche Runde fällt, wann sich welcher Bereich öffnet (`AREA_ROUNDS`), Nadja, Helikopter, die Ankunft am Anfang |
| `scripts/helicopter.gd` | Der Helikopter: Rotoren, Lichter, Seile, Motorgeräusch |
| `scripts/radio.gd` | Alle Funksprüche (`LINES`) und Rufe (`BARKS`) auf Englisch, nach Stichwort und Sprecher |
| `scripts/profile.gd` | Schwierigkeitsstufen (`DIFFICULTIES`), Bestenliste, Laufbahn, Skins (`SKINS`) |
| `scripts/cru_soldier.gd`, `scripts/cru_visual.gd` | Die C.R.U.: Rollen (`ROLES`), Stellungswahl, Feuerstöße, Flankieren, Rückzug, Ausweichrolle, Granaten, Sanitäter; ihre Waffen- und Markerlampen (`_fit_lamps`) |
| `scripts/sandbox.gd` | Der **Testraum**: Gegner rufen und einfrieren, unendlich Leben und Munition, alle Waffen, Tageslicht, Tempo, Sprünge – und der Abspieler für jede aufgenommene Zeile |
| `scripts/net_hello.gd` | Ein einziger Gruß beim Verbinden: „Ich bin Version X“. **Diese Datei darf sich nie ändern** – nur dann können zwei verschiedene Versionen einander noch sagen, dass sie verschieden sind. Die Versionsnummer selbst steht in `VERSION` oben in `scripts/net.gd` und ist bei jedem Update hochzuzählen |
| `scripts/operator.gd` | Die Helix-Operatoren Phantom, Havoc und Ghost: Blendgranate, Verschwinden und Wiederkommen, Rückzug statt Tod, ihre Sprüche im Funk |
| `scripts/infected.gd` | Werte und Verhalten aller Gegnertypen (`TYPES`): Leben, Tempo, Schaden, Taumeln, Sprünge, Explosion |
| `scripts/infected_visual.gd` | Modelle, Skelett-Erkennung, Mixamo-Clips (`CLIPS`) samt Übertragung auf alle Skelette, Todesvarianten |
| `scripts/ripper_visual.gd` | Der Hund: eigenes Skelett und eigene Clips |
| `scripts/teammate.gd` | Die Bots (und Nadja, sobald sie frei ist): Folgen mit Abstand, Zielwahl, Schießen, Zurückweichen, Rufe, zu Boden gehen |
| `scripts/soldier_visual.gd` | Aussehen und Animation von Viper, Scorpion, dem Koop-Mitspieler und den weiteren Figuren (`LOOKS`) |
| `scripts/npc_visual.gd` | Figuren, die nur dastehen: die Händlerin, Nadja hinter dem Glas |
| `scripts/net.gd`, `scripts/remote_survivor.gd` | Koop: Verbindung, Abgleich von Gegnern, Spielern, Vorrat und Kisten |
| `scripts/effects.gd` | Blut, abgetrennte Gliedmaßen, Explosionen, Brocken, Striker-Wucherungen, Säurewolke |
| `scripts/cabin.gd` | Der ganze Hof: Farmhaus, Nebengebäude, Wald, Licht, Nebel, Regen, Gas, Laufwege auf zwei Stockwerken, Waffenshop |
| `scripts/mesh_batch.gd` | Fasst Bretter und Bauteile zu wenigen Meshes zusammen |
| `scripts/player.gd` | Bewegung, Waffenwerte und Preise (`WEAPONS`), Aufsätze und was sie an den Werten ändern (`ATTACHMENTS`), Shop-Gegenstände (`GOODS`), Schießen, Nachladen, Werfen, Rüstung, ballistische Weste (`PLATE_SHARES`), Gasmaske |
| `scripts/throwable.gd`, `scripts/claymore.gd` | Granate, Blendgranate und Mine |
| `scripts/weapon_view.gd` | Ego-Ansicht der Waffen samt Händen (`VIEWS` = Position in der Hand), die UMP mit ihren Aufsätzen (`build_ump`, `SIGHTS`) und ihrem Magazinwechsel (`reload_step`) |
| `scripts/hud.gd` | Menüs, Koop-Lobby und Anzeigen |
| `scripts/shop_screen.gd`, `scripts/weapon_show.gd` | Der Bildschirm von Shop und Werkbank (Liste links, Auswahl rechts) und das Bild der Waffe, die sich darin dreht |
| `scripts/minimap.gd` | Die Karte in der Ecke: Größe, Reichweite (`REACH`), Farben und Zeichen |
| `scripts/lab_specimen.gd` | Die Infizierten in den Probentanks des Labors |
| `scripts/sound.gd` | Lädt die Sounds aus `assets/sounds`, Lautstärken (`MIX`), Hall drinnen/draußen |
| `scripts/music.gd` | Die Musik: welche Datei zu welchem Teil der Nacht gehört (`PHASES`), wann gewechselt und wie lange übergeblendet wird |
| `scripts/skills.gd` | Die drei Wege der Fähigkeiten (`TREES`), Erfahrung, Stufen und Punkte, und was jede Fähigkeit bewirkt. `IN_SERVICE` nimmt sie in Betrieb |
| `scripts/verification.gd` | Automatische Prüfungen, Bot-Durchlauf, Koop-Test |
| `SPIELEN.command`, `tools/make_mac_package.js` | Start auf dem Mac (sucht Godot, bereitet beim ersten Mal die Spieldaten vor); der Packer für das Mac-Paket, der `SPIELEN.command` in der ZIP als startbar kennzeichnet |

Gute erste Stellschrauben: `ROUNDS` in `game.gd` (wer in welcher Runde kommt), `TYPES` in `infected.gd` (Leben/Tempo/Schaden), `WEAPONS` in `player.gd` (Schaden, Feuerrate, Preis), `GUNS` und die Abstände `KEEP_AWAY` / `FOLLOW_FAR` in `teammate.gd` und `MIX` in `sound.gd` (Lautstärke jedes Sounds in dB).

In `cabin.gd` stehen benannte Orte in `points` (z. B. `hall`, `barn`, `stairs_bottom`, `cellar_door`, `lab`, `landing`) und die abschließbaren Bereiche in `AREAS` (`lock_all()`, `unlock(bereich)`). Wie Keller, Labor, Tunnel, Sperren und Landeplatz gebaut sind, steht ausführlich (auf Englisch) in `KARTE_PHASE4.md` im Ordner `Nachtwache-Konzept` neben dem Projekt. Neue feste Objekte mit `_prop(...)` oder `_solid(...)` anlegen, dann blockieren sie auch die Laufwege. `tools/map_check.gd` prüft die Karte (Wege von allen Startpunkten zu allen Orten, Treppen, Türen):

```text
Godot_v4.7.2-stable_win64.exe --headless --path "PFAD_ZU_NACHTWACHE" -s res://tools/map_check.gd
```

## Animationen (Mixamo)

- Der gelbe Hazmat-Mauler wurde bei Mixamo automatisch geriggt (`assets/models/mixamo/mauler_hazmat_rig.fbx`). Dazu kommen rund 45 Clips: Zombie-Gänge, Angriffe (Schlag, Tritt, Kopfstoß, Biss), Trefferreaktionen, siebzehn Todesvarianten, die Mutanten-Clips für den Crusher (Gang, Rennen, Schläge, Sprung, Brüllen) und die Soldaten-Clips für die Bots. Gespiegelte Varianten erzeugt das Spiel selbst.
- Die anderen Gegner behalten ihre eigenen Skelette. Beim Start überträgt `infected_visual.gd` jeden Clip auf jedes Skelett: Es erkennt Hüfte, Wirbelsäule, Arme und Beine am Knochenbaum, richtet die Gliedmaßen auf die Mixamo-Grundhaltung aus und stellt die Füße auf den Boden.
- **Neuen Clip einbauen:** bei Mixamo als *FBX, Without Skin, 30 fps* (Laufzyklen mit *In Place*) herunterladen, nach `assets/models/mixamo/` legen, in der `.import`-Datei `nodes/root_scale=100.0` setzen (die anderen Dateien zeigen es) und in `CLIPS` eintragen. **Wichtig:** Bei Mixamo muss dabei die Figur aktiv sein, zu deren Tabelle der Clip kommt – der Hazmat-Mauler für `CLIPS`, Skorpion für `MORE` und für `MOVES` in `soldier_visual.gd`, Viper für deren `CLIPS`. Mixamo merkt sich die zuletzt hochgeladene Figur (derzeit Skorpion).
- **Sechs weitere Stürze (v0.16)** wurden bei Mixamo auf der Figur des Soldaten *Skorpion* erstellt, nicht auf dem Hazmat-Mauler: nach hinten sterben, nach hinten und nach vorn fallen, nach hinten geschleudert werden, vornüber zusammenbrechen und der Kopfschuss von hinten. Ein Clip wird immer auf dem Skelett ausgelesen, für das er erstellt wurde (`MORE` und `MORE_RIG` in `infected_visual.gd`) und dann wie alle anderen auf jedes Skelett übertragen. Zombies und Soldaten haben damit **achtzehn Stürze** (mit den gespiegelten). Welcher gespielt wird, hängt von der Schussrichtung ab (`DEATHS`); ein Kopfschuss von hinten hat eigene Stürze, und ein Treffer, der weit mehr Schaden macht als nötig, **schleudert den Körper meist nach hinten**. Medic, Stalker und Leech dürfen nur die Stürze, bei denen ihr Körper nicht im Boden landet (`deaths` in `KINDS`) – das prüft ein Test an Knochen und Haut jedes Körperbaus.
- Die elf Modelle des Fireteam-Ausbaus (Meshy, ohne Skelett geliefert) wurden in Blender auf rund 30.000 Dreiecke verkleinert und mit einem 22-Knochen-Skelett versehen; die Skripte dafür liegen neben dem Projekt in `Nachtwache-Modelle/phase4/tools` (`run_all.sh`).
- Für v0.7 kamen zehn Clips dazu: seitwärts gehen, ducken, geduckt rennen, Hechtrolle, Granatwurf, am Seil hängen und landen für die Soldaten (`MOVES` in `soldier_visual.gd`), dazu stehen, reden und nervös sein für Nadja und die Händlerin (`CLIPS` in `npc_visual.gd`).
- Die **UMP45** kam als ein einziges Teil ohne Magazin. `Nachtwache-Modelle/ump/make_ump.py` (Blender) bringt sie auf 69 cm, dreht den Lauf nach vorn, legt den Griff auf den Nullpunkt, verkleinert die Texturen auf 2048 und baut das Magazin als eigenes Teil dazu; die Maße für das Spiel stehen in `fertig/SPEC.json` daneben. Visiere und Schalldämpfer entstehen im Code (`_ump_mods` in `weapon_view.gd`).
- Das **G36** kam von Meshy in zwei Dateien: einmal mit Texturen in einem Stück (479.000 Dreiecke) und einmal in fünf Teile zerlegt, aber ohne Texturen (Magazin, Kimme, Korn, Tragebügel, Rest). `Nachtwache-Modelle/g36/make_g36.py` (Blender) nimmt die Formen aus der zerlegten und die Farben aus der texturierten Datei, bringt das Gewehr auf 72 cm und 68.000 Dreiecke, legt den Griff auf den Nullpunkt und baut dazu, was dem Modell fehlte: den Magazinschacht, das obere Ende des Magazins mit einer Patrone und ein Kornblatt, das genau auf der Visierlinie steht. Die Maße stehen in `fertig/SPEC.json` daneben, 33 Kontrollbilder in `preview`. Schrift auf dem Gehäuse ist Fantasie und links gespiegelt, wie von Meshy geliefert.
- Der **Ripper** wurde in Blender geriggt und animiert (`tools/blender_rig_ripper.py`), die **Schrotflinte** komplett per Skript modelliert (`tools/blender_make_shotgun.py`).

## Musik

Im Ordner `assets/music` liegen die Soundtracks. Der Name einer Datei sagt, zu welchem Teil der Nacht sie gehört; gibt es mehrere, wechselt das Spiel ab und blendet beim Übergang weich über.

| Dateiname beginnt mit | Wann es läuft |
|---|---|
| `anfang_` | Hauptmenü, Ankunft und die Pausen zwischen den Runden |
| `welle_` | die frühen Runden |
| `harte_welle_` | ab Runde 5, und immer wenn die C.R.U. oder eine Horde kommt |
| `auftrag_` | solange ein Gerät läuft oder eine Stellung zu halten ist (Hack, Generator, Funkmast, Position halten, Festplatten) |
| `kurz_vor_ende_` | die beiden Runden vor der letzten |
| `letzte_runde_` | die letzte Runde und die Evakuierung |

**Neue Musik hinzufügen:** MP3 oder OGG in `assets/music` legen und nach diesem Muster benennen, zum Beispiel `welle_3.mp3`. Beim nächsten Start ist sie dabei – ohne Godot zu öffnen. Die Lautstärke regelst du in den Einstellungen unter **Musik**.

## Sounds und Stimmen (ElevenLabs)

- `assets/sounds` enthält 162 WAV-Dateien (eine davon ein Ersatz-Sound, siehe unten): Schüsse aller Waffen, Nachladen, Schritte, Treffer, Stimmen aller Infizierten in mehreren Varianten, Hund, Blut und Brocken, Explosionen, Shop-Rollladen, Runden-Stinger, Donner, Regen und Wind, Helikopter. 133 davon stammen aus dem ElevenLabs-Soundeffekt-Generator; elf (Pistole, Magnum, Scharfschützengewehr, Minigun samt Anlauf, Helikopter, Piepton, UMP und AK-47 jeweils mit und ohne Schalldämpfer) sind aus vorhandenen Aufnahmen abgeleitet. Der Schuss des **Granatwerfers** und die vier **Explosionen** sind seit v0.10 aus je zwei Aufnahmen gemischt: bei der Explosion ein tiefer Knall, von einem langen Grollen auf einen Schlag mit ausrollendem Nachhall gekürzt, und darüber der scharfe Knall eines Schusses. Damit so etwas zusammen mit Schüssen und Stimmen nicht übersteuert, sitzt auf dem Gesamtausgang ein Begrenzer.
- Die Originaldownloads liegen neben dem Projekt in `Nachtwache-ElevenLabs`. Daraus wurden die Sounds geschnitten, auf Mono gemischt und auf gleiche Lautheit gebracht.
- **Neu erzeugen:** `node tools/make_sounds.js "../Nachtwache-ElevenLabs;../Nachtwache-ElevenLabs/sfx_v10" assets/sounds` (mit `--only=launcher,explosion` am Ende nur diese beiden). `node tools/wav_info.js ORDNER` zeigt Pegel und Länge jeder WAV-Datei.
- **Aufnahmen vom 5. Oktober (v0.15):** Molotow-Aufschlag, Bodenfeuer, Flammenwerfer, Kolbenschlag (drei Varianten) und die Schüsse von M107 und M14 sind jetzt ElevenLabs-Aufnahmen (Rohdateien in `Nachtwache-ElevenLabs/sfx_v14`, je vier Varianten; `tools/make_sounds.js` nimmt die nach Messung beste oder mischt zwei bis drei). SVD und Doppelbüchse sind aus denselben Rohaufnahmen gemischt. Nachbauen: `node tools/make_sounds.js "../Nachtwache-ElevenLabs;../Nachtwache-ElevenLabs/sfx_v10;../Nachtwache-ElevenLabs/sfx_v14" assets/sounds --only=molotov,fire,flamer,melee,fifty,m14,svd,nitro`.
- **Schrotflinten (v0.16):** Der Schuss der Pump-Flinte ist neu gemischt – der wuchtigste Schrotflinten-Take als Körper, darunter der tiefe Schlag eines Kaliber-.50-Schusses, obenauf der scharfe Knall, hinten das lange Ausrollen eines dritten Takes, alles zusammengepresst. Gemessen ist er gut 5 dB lauter als vorher, und 62 statt 25 % seiner Energie liegen unter 200 Hz. Die Auto-Schrotflinte hat einen eigenen, kürzeren Schuss (`autoshotgun.wav`). Beides aus vorhandenen Rohaufnahmen, **nicht probegehört**.
- **G36 (v0.16):** Schuss, schallgedämpfter Schuss, Magazin heraus, Magazin hinein und Durchladen sind aus Rohaufnahmen gemischt, die bisher keine Waffe benutzt hat (`tools/make_sounds.js`, Einträge `g36…`): der schärfste Sturmgewehr-Take, kurz gepresst, damit er bei 750 Schuss pro Minute klar bleibt, darunter der Schlag eines zweiten und der Nachklang eines dritten. Keine neuen ElevenLabs-Credits, **nicht probegehört**.
- **Ripper (v0.17):** Sie sind keine Hunde und sollen nicht so klingen. Ihre Geräusche sind aus denselben Aufnahmen neu gebaut: auf zwei Drittel der Geschwindigkeit gebracht (tiefer, schwerer), das Bellen durch ein raues Mutanten-Kreischen ersetzt, das Heulen des Rudels durch einen verlangsamten unmenschlichen Schrei über einem tiefen Dröhnen, unter dem Knurren das Klicken der Striker (`tools/make_sounds.js`, Einträge `dog_…`, Option `pitch`). Ohne neue Aufnahmen, **nicht probegehört** – echte neue Kreaturen-Sounds wären ein ElevenLabs-Auftrag.
- **Ersatz-Sounds:** Nur für die Heilspritze gibt es noch keine eigene Aufnahme. `node tools/make_standins.js assets/sounds` baut sie aus vorhandenen (höher gespielt, geschnitten, mit etwas Rauschen). Eine echte Aufnahme desselben Namens ersetzt sie einfach.
- **Sound austauschen:** WAV mit demselben Namen in `assets/sounds` legen (Varianten heißen `name_1.wav`, `name_2.wav` …). Fehlt eine Datei, spielt das Spiel einen einfachen synthetischen Ersatz.
- **Stimmen:** `assets/voice` enthält 498 Aufnahmen (Coleman 127, Nadja 29, Viper, Scorpion und Raven je 72, C.R.U. 72 in vier Stimmen, Phantom, Havoc und Ghost je 16, Händlerin 6), erzeugt mit ElevenLabs *Multilingual v2*. Jeder Text in `scripts/radio.gd` hat damit eine Aufnahme. **Die 53 Zeilen aus v0.19** (5. Oktober, 2.060 Credits, Rohdateien in `Nachtwache-ElevenLabs/stimmen6`): Die drei Operatoren sprechen mit deinen eigenen Stimmen „Phantom“, „Havoc“ und „Ghost“, mit den Reglern, wie du sie gespeichert hast (50 / 75 / 0). Ihre Funksprüche (alle Stichwörter, die mit `op_` beginnen) legt `tools/make_voices.js` auf ein eigenes, engeres und härteres Band als Colemans und übersteuert sie leicht (`INTRUDER`); ihre drei Rufe auf dem Hof bleiben, wie sie aufgenommen wurden. Die drei neuen C.R.U.-Stimmen aus v0.15 sind die Standardstimmen Daniel, Brian und Roger, mit ruhiger, flacher Einstellung aufgenommen (Stability 75 %, Style 0 %) und beim Aufbereiten um 1 bis 3 Halbtöne tiefer gelegt und auf ein schmales, gepresstes Band gebracht – wie durch ein Helm-Funkgerät (`HARD` und `HELMET` in `tools/make_voices.js`; die erste Stimme ist unbearbeitet). **Nadja spricht seit v0.17 mit der Stimme „Daisy Sweetwood“** (26 Zeilen, Rohdateien in `Nachtwache-ElevenLabs/stimmen5`); weil diese Stimme zwischen den Sätzen eine Sekunde und mehr Pause lässt, kürzt das Werkzeug Nadjas Pausen auf gut eine halbe Sekunde (`PAUSES`). Die alte Nadja-Stimme liegt weiter in `stimmen2`. Nadja wurde für v0.10 mit neuen, gefühlvolleren Texten und einer lebhafteren Einstellung (Stability 30 %, Style 40 %) komplett neu aufgenommen. Für **Colonel Coleman** und **Nadja** wurden eigene Stimmen entworfen und in deinem ElevenLabs-Konto gespeichert; die anderen sprechen mit Standardstimmen. Colemans Aufnahmen klingen nach Funk (Bandpass, Kompressor), Nadjas nach Lautsprecher, solange sie hinter dem Glas sitzt.
- **Stimme ergänzen oder tauschen:** Text in `scripts/radio.gd` eintragen, bei ElevenLabs erzeugen, die MP3s in einen Ordner legen und `node tools/make_voices.js ORDNER order.json` laufen lassen (schneidet, pegelt und legt `assets/voice/<sprecher>/<stichwort>_<nummer>.ogg` an). Eine Pause von mehr als 0,9 Sekunden mitten in einer Zeile kürzt das Werkzeug. Die Rohdateien und die Zuordnung liegen in `Nachtwache-ElevenLabs/stimmen`, `stimmen2`, `stimmen3`, `stimmen4`, `stimmen5` und `stimmen6`. Ob jede Zeile ihre Aufnahme hat und keine Aufnahme übrig ist, zeigt `-s res://tools/voice_check.gd` (nach einem `--import`). Hat ein Stichwort mehrere Texte, aber nur für einige eine Aufnahme, benutzt das Spiel nur die vertonten.

## Stand und Grenzen

**v0.21** bringt **Mission 2** (im Hauptmenü neben Mission 1 wählbar): eine zweite, große Karte – Villa im Park, versteckter Bahnhof, Zugfahrt, Forschungsanlage – und einen Einsatz ohne Runden, der in Etappen von der Landung bis zum Frachtaufzug der Eindämmungshalle führt, mit drei Haltepunkten, vier Versorgungspunkten und Kontrollpunkten. Es ist die **erste Stufe**: Die Karte steht und der Einsatz läuft von vorn bis hinten; neue Gegner, aufgenommene Dialoge, die Operatoren als Begleiter und der Koop für diese Mission folgen. Mission 1 ist unverändert. Weil sich die Spielskripte geändert haben, brauchen für den Koop wieder beide denselben Stand.

**v0.20** bringt den **Testraum** (Hauptmenü → TESTRAUM, im Raum F1): jeden Gegner per Klick rufen, unendlich Leben und Munition, alle Waffen, Shop und Werkbank von überall und gratis, jede der 498 Aufnahmen einzeln anhören – auch den gekaperten Coleman –, Tageslicht und Zeitlupe. Nichts davon landet in deinem Profil. Weil sich die Spielskripte geändert haben, brauchen für den Koop wieder beide denselben Stand (die Lobby sagt es, wenn nicht).

**v0.19** bringt die drei **Helix-Operatoren Phantom, Havoc und Ghost** (deine Modelle, deine Stimmen – alle Sprüche sind aufgenommen): zäh, mit Lebensbalken, mit Blendgranate und Ortswechsel, nie zu töten, nur zu vertreiben – und sie reden über euren Funk. Ihre Ausrüstung gibt es als **Skins**, sobald du den jeweiligen einmal vertrieben hast. Das **Visier auf dem G36** ist kleiner. Im **Koop** steht der Mitspieler jetzt auf der Karte (in v0.18 fehlte er dort), und das Spiel **sagt in der Lobby, wenn zwei verschiedene Versionen** aufeinandertreffen, statt einen Einsatz zu starten, der nicht funktionieren kann. Und ab dem Moment, in dem Nadja aus ihrem Raum kommt, ist **der Funk gestört** – das gehört zur Geschichte.

**v0.18** macht den **Crusher gefährlich** (schneller, härter, ein weiter flacher Sprung mit Beben beim Landen – der alte Sprung ging fast nur nach oben, das war die Verzerrung), verstärkt das **M14** (100 Schaden, geht durch einen Körper) und lässt die **Granate des Werfers langsamer** fliegen. Bei den **Fähigkeiten** verteilst du die Punkte frei auf alle drei Wege und aktivierst einen davon; neu ist **Ausgebrannt** (brennende Charger und Striker-Wucherungen tun dem Trupp nichts). Oben rechts gibt es eine **Karte** mit eigenen Zeichen für gewöhnliche Infizierte, Spezial-Infizierte und Soldaten. Der **Shop** ist neu gebaut (Liste und Auswahl, Waffen als drehendes Modell mit Vergleich, verkaufen, wählen was geht), die **Werkbank** hat ein Menü mit fünf Linien je Waffe. Das **Labor** ist ausgestaltet: Infizierte in den Tanks, einer davon geplatzt, und sechs feste Serverschränke, aus denen die Festplatten des Auftrags gezogen werden. Das Rotpunktvisier ist jetzt **dein holografisches Visier** – auf allen vier Gewehren, die eines nehmen.

**v0.17** gibt dem **Rotpunktvisier** ein richtiges Gehäuse, lässt die **Bots Aufträge übernehmen** (je eine Fähigkeit pro Weg: Spürtrupp, Techniker, Wachposten), lässt **Schrotflinten durch Schilde schießen** (Brecher, Schildbrecher II), macht die **Ripper zu Mutanten statt Hunden** (neu gebaute Geräusche), gibt **Nadja eine neue Stimme**, bringt in der **letzten Runde** wieder etwas mehr Gegner (80 statt 70 % der Tabelle) und hält die **Bots in den ersten Runden zurück**, damit die Abschüsse dir gehören.

**v0.16** bringt das **G36** als bestes Sturmgewehr (dein Modell, mit Kimme und Korn, Magazinwechsel, drei Aufsätzen und eigenen Sounds), **stärkere Schrotflinten** (mehr Schaden, ein wuchtigerer Schuss, und eine Ladung aus der Nähe wirft zurück, wen sie nicht tötet), **sechs weitere Stürze** für Zombies und Soldaten samt eigenem Sturz für den Kopfschuss von hinten und für Treffer mit viel zu viel Schaden, die **drei härteren C.R.U.-Stimmen** und echte Aufnahmen für Molotow, Feuer, Flammenwerfer und Kolbenschlag. Behoben: In der **Ankunft** schwebte deine Waffe im Bild, und deine Taschenlampe leuchtete die leere Landezone an.

**v0.15** begrenzt, was du trägst: **eine Primär-, eine Sekundär- und eine schwere Waffe** (Tasten 1, 2, 3), mehr nur mit **Waffengurten**; eine weitere Waffe derselben Art wird gegen die alte **getauscht**. Im Skilltree **wählst du einen der drei Wege**. Dazu die **Heilspritze** auf Q (30 Lebenspunkte, 8 Sekunden Pause), **Ducken** auf C, der Nahkampf auf V, Team-Befehle auf 4 / 5 / 6, **volle Heilung und halbe Munition nach jeder Runde**, höchstens **ein Schild-Soldat gleichzeitig** und eine **kleinere letzte Runde**.

**v0.14** schaltet die **Fähigkeiten** scharf (Punkte vergeben, zurücknehmen, im Profil gespeichert) und gibt jedem Weg eine **Klassenwaffe**: Flammenwerfer, Doppelbüchse .600, M107 Kaliber .50. Dazu das **M14** (Einzelschuss) und die **SVD** als zweites Scharfschützengewehr, ein **Nahkampfschlag** (Q), der **Molotowcocktail** (H) mit brennendem Boden und brennenden Gegnern, **Team-Upgrades** im Shop, eine **Nadja**, die mehr aushält und seltener angegriffen wird, **vier Stimmen und zwölf Stürze** für die C.R.U., Soldaten, die **nicht mehr in Wände rollen**, der **Endlosmodus** und **Modifikationen** für jede Runde.

**v0.13** stellt **Kiefern und tote Bäume** aus dem freien *Stylized Nature MegaKit* von Quaternius zwischen die einfachen Tannen am Rand des Hofs – zusammen mit deinen beiden Laubbäumen sind es sieben Arten, rund 115 Bäume. Das Paket ist gemeinfrei (CC0); die Lizenz liegt in `assets/models/trees/LIZENZ_Quaternius_CC0.txt`, das ganze Paket (68 Modelle, auch Büsche, Gras und Steine) entpackt in `Nachtwache-Modelle/quaternius`. Weitere Bäume: Datei nach `assets/models/trees` legen und in `TREE_MODELS` in `scripts/cabin.gd` eintragen – Größe und Helligkeit passt das Spiel selbst an. Außerdem ist die **AK-47** neu aufbereitet – mit demselben Verfahren wie M4A4 und Maschinengewehr (verschweißen, vereinfachen, Farben neu aufbacken), weil das alte Vereinfachen das Modell an den Texturnähten aufgerissen hatte: Aus der Nähe (beim Nachladen) und in den Händen des C.R.U. Elite sind die Risse und hellen Kanten weg; Maße und Verhalten sind dieselben.

**v0.12** bringt das **M4A4** als Startgewehr (mit Magazin, Kimme und Korn, die eigens dafür gebaut wurden) und ein **Maschinengewehr** mit 100-Schuss-Kasten, drei weitere **tote Forscher und Wachleute** (jetzt fünf verschiedene, die neuen mit einem Koffer daneben), **Laubbäume** als Modelle zwischen den Tannen am Rand des Hofs – und der **Zaun um den Hof ist weg**, damit die Infizierten von überall kommen.

**v0.11** macht das **Gas** zu einem dünnen Dunst, der sich in großen Bänken über den Hof ausbreitet statt als grelle Wolke an einer Stelle zu stehen, gibt dem **Granatwerfer** eine gebogene Flugbahn samt Anzeige, dem **Rotpunktvisier** eine feinere Marke, den **Bots** 129 neue Sprüche und neue Anlässe zu rufen, und zeigt im Menü die drei Wege der **Fähigkeiten** – noch in Wartung.

**v0.10** bringt den **C.R.U. Elite** mit AK-47 und Gasgranaten, die **AK-47** als kaufbares Gewehr mit Magazinwechsel und Aufsätzen, ein Rotpunktvisier und ein Zielfernrohr, durch die man deutlich mehr sieht, einen Medic, dessen Gas flach über den Boden kriecht und Infizierte sichtbar verstärkt, tote Forscher, die von Anfang an auf dem Hof liegen, eine neue Granatexplosion (Feuerwolken, Funken, Glut, Rauch) samt richtigem 40-mm-Geschoss, Granaten mit Flugbahn-Anzeige, **Musik**, die der Nacht folgt, eine neue Oberfläche mit Einstellungen für Ton und Bild und 81 zusätzliche Aufnahmen für Funk und Rufe (Coleman allein 58), dazu einen neuen Schuss für den Granatwerfer und neue Explosionen.

**v0.9** bringt den Medic-Zombie mit seiner Wolke, den Schild-Soldaten der C.R.U., einen dritten C.R.U.-Körper, den Crusher schon vor der letzten Runde, Gasfelder im Hof und Gasalarm im Haus (damit Gasmaske und Obergeschoss einen Zweck haben), eine Munitionsstation und Aufträge im Obergeschoss, tote Forscher als Modelle und eine Granatexplosion mit Feuerball, Druckring, Erdfontäne und Rauch. Dazu kommt der Start auf dem Mac, die Einstellung **3D** für schwächere Rechner und Vollbild per Alt + Enter.

**v0.8** bringt die UMP45 mit sichtbarem Magazinwechsel und drei Aufsätzen, die ballistische Weste gegen die C.R.U. und Lampen, an denen man die C.R.U. im Dunkeln erkennt. Darunter der Stand von v0.7.

**v0.7 – der Fireteam-Ausbau** (Konzept: `phase4_fireteam_ausbau.md` im Ordner `Nachtwache-Konzept` neben dem Projekt). Neu gegenüber v0.6: die Helix-Geschichte von der Landung bis zum Abflug, Ankunft per Helikopter als Zwischensequenz, Keller mit Labor und Tunnel, Bereiche, die sich nach und nach öffnen, Hack-Modul mit Ausfällen, Nadja hinter Glas und als Begleiterin, die C.R.U. als Gegner mit sechs Rollen, sechs weitere Waffen, englische Sprachausgabe für Funk und Rufe, vier neue Aufträge (Funkmast, Position halten, Proben, Festplatten), Skins und Trupp-Auswahl.

Aus dem Konzept noch offen: Barrikaden reparieren, einen NPC an einem Ort beschützen und Schalter-Rätsel als eigene Aufträge; zusätzliche Bot-Befehle; die Geschichte hat immer dieselben Stationen (nur Rundenarten, Aufträge und Orte der Aufträge wechseln).

- **Nicht probegehört:** Stimmen und Sounds wurden nach Messwerten (Tonhöhe, Tempo, Pegel) ausgewählt und abgemischt. Passt eine Stimme nicht, lässt sie sich pro Sprecher austauschen (siehe oben). Nadjas neue Aufnahmen sind langsamer und haben mehr Pausen als die alten; ihre Tonhöhe bewegt sich laut Messung aber nicht stärker als vorher (rund zwei Halbtöne Streuung). Ob sie lebendiger klingt, entscheidet das Ohr.
- **Nicht von Hand gespielt:** Die Geschichte ist automatisch von Anfang bis Ende durchgeprüft und in Bildern kontrolliert, aber niemand hat sie bisher am Stück gespielt. Zielgenauigkeit und Schaden der C.R.U., die Dauer der Hacks und die Preise der neuen Waffen sind Schätzwerte: `ROLES` in `cru_soldier.gd`, `RUNNERS` in `mission.gd`, `WEAPONS` in `player.gd`.
- **Mac: nichts davon lief bisher auf einem Mac.** `SPIELEN.command` wurde nur unter Windows mit einem nachgestellten Godot durchgespielt (Suche an allen Orten, falsche Version, erster Import, Start), das Mac-Paket nur mit einem ZIP-Prüfprogramm (alle Dateien heil, `SPIELEN.command` als startbar gekennzeichnet). Ungeprüft sind: ob macOS die Datei nach dem Entpacken wirklich per Doppelklick startet und was seine Sicherheitsabfrage dazu sagt, wie flüssig das Spiel auf einem M3 läuft und ob 50 % der richtige Startwert für **3D** ist, wie das Bild mit Apples Grafikschnittstelle aussieht, die Ersatzschrift der Überschriften und der Koop zwischen Windows und Mac.
- **OBS** wurde hier nicht selbst getestet: Das Spiel wurde dafür auf Direct3D 12 umgestellt, die Aufnahme musst du einmal ausprobieren.
- **Koop** wurde mit zwei Spielinstanzen auf einem PC getestet: Verbindung, Gegner, Vorrat, Kisten, Einkauf, Aufhelfen, Spielende, Schlag, Feuer und Molotow des Gasts, die angesagte Modifikation, ein C.R.U.-Soldat samt Feuerstößen auf beiden Seiten und die Geschichte von der ersten Sperre bis zum Abflug (der Helikopter wartet, bis beide da sind). Über das Internet und mit der automatischen Portfreigabe wurde es noch nicht ausprobiert. Abschüsse, C.R.U.-Abschüsse und Aufträge des Teams zählen am Ende für die Laufbahn beider Spieler.
- Die Bots kennen die Aufträge nicht: Sie kämpfen und folgen, aber Geräte anbringen, Kisten öffnen und Nadja aufhelfen musst du selbst (oder dein Mitspieler).
- Der Charger kam ohne Skelett und wird beim Start automatisch geriggt. Für Frau, Striker und Crusher gelten die UniRig-Skelette; in den Projektkopien wurden fehlerhafte Hautgewichte korrigiert. Deine Originale in den Downloads sind unverändert.
- Das Honey-Badger-Modell hat rund 700.000 Eckpunkte. Auf deiner Grafikkarte ist das kein Problem; für schwächere Rechner sollte es später vereinfacht werden.
- Aufsätze gibt es für M4A4, UMP45, AK-47 und G36. Beim G36 bleiben Kimme und Korn stehen, wenn ein Visier draufsitzt: Das Rotpunktvisier schaut über sie hinweg, die Spitze des Korns steht unten im Glas. Für andere Waffen genügt ein Eintrag in `ATTACHMENTS` und ein Modell des Teils an der Waffe; der Magazinwechsel der anderen Waffen läuft weiter unterhalb des Bildes ab.
- Wie die UMP klingt, ist aus vorhandenen Schüssen abgeleitet (`ump.wav`, `ump_sil.wav`) und nicht probegehört.
- **Platzhalter in v0.14:** Die fünf neuen Waffen (M14, SVD, Flammenwerfer, Doppelbüchse, M107) sind per Skript gebaute Blender-Modelle ohne Texturen – sauber, aber schlicht. Eigene Modelle: Datei in `assets/models` ersetzen und die Punkte in `MODELS` und `VIEWS` in `scripts/weapon_view.gd` anpassen (Bauskripte und Maße: `Nachtwache-Modelle/phase7`). Ihre Sounds und die von Nahkampf, Molotow und Feuer sind seit v0.15 Aufnahmen, wie die drei neuen C.R.U.-Stimmen – **nichts davon ist probegehört**: Auswahl und Pegel folgen Messwerten, und ob die Stimmen so hart klingen wie gewünscht, entscheidet das Ohr.
- **Nicht von Hand gespielt (v0.21):** Mission 2 ist automatisch geprüft (jeder Weg, jeder Raum, jede Etappe; ein Bot läuft sie von der Landung bis zum Aufzug durch) und auf Bildern angesehen, aber nicht von Hand gespielt. Geschätzt sind: wie viele Gegner wo warten und nachkommen, wie lange gehalten wird (`PRESSURE`, `HOLD_…` und `_enter` in `scripts/hive.gd`), wie hell die Räume sind und was der Vorrat an den Kontrollpunkten hergibt. Was gesagt wird, sind Platzhalter-Texte ohne Aufnahme.
- **Nicht von Hand gespielt (v0.20):** Der Testraum ist automatisch geprüft (jede Gegnerart gerufen und wieder entfernt, jeder Schalter, jede Zeile abgespielt) und auf Bildern angesehen, aber nicht von Hand benutzt. Das Tageslicht ist ein einfaches gleichmäßiges Licht mit einer Sonne und einem einfarbigen Himmel – zum Ansehen gedacht, nicht schön.
- **Nicht von Hand gespielt, nicht gehört (v0.19):** Wie zäh und wie gefährlich die drei Operatoren sind (Leben, Schaden, wie oft die Blendgranate kommt und wie lange sie blendet), ist geschätzt. Die Funkstörung nach Nadjas Befreiung entsteht beim Abspielen (tiefer, Aussetzer, Datengeräusche) und ist nur gemessen, nicht gehört: `FAKE_PITCH` und `_break_up` in `scripts/sound.gd`. Auch die Stimmen der drei und ihr Funkklang sind nur gemessen (Länge, Pegel), nicht gehört – klingt der Funk zu dumpf oder zu verzerrt, lässt sich `INTRUDER` in `tools/make_voices.js` ändern und alles in einer Minute neu aufbereiten, ohne neue Credits. Als Bots lassen sich die drei Skins nicht einsetzen, weil sie keine Trupp-Sprüche haben.
- **Nicht von Hand gespielt (v0.18):** Alles ist automatisch geprüft und auf Bildern angesehen, aber nicht gespielt. Schätzwerte sind: wie gefährlich der Crusher jetzt ist (Tempo, Schaden, Sprungweite, Beben: oben in `scripts/infected.gd` unter `LEAP_…` und `QUAKE_…`), die Preise und Stufen der Werkbank, wie groß das holografische Visier beim Zielen im Bild steht (`HOLO_EYE` in `scripts/weapon_view.gd`: größer = weiter weg = kleiner) und seine Farbe (`HOLO_PAINT`). Die Karte dreht sich mit dir; eine feste Nord-Ausrichtung gibt es nicht. Die Fähigkeiten-Regel habe ich so verstanden: ein gemeinsamer Vorrat von 15 Punkten für alle drei Wege – nicht 15 je Weg.
- **Nicht von Hand gespielt, nicht gehört (v0.17):** Wie stark die Bots am Anfang gebremst sind (40 % Schaden in Runde 1, voll ab Runde 7), wie schnell sie Aufträge erledigen (`SQUAD_PACE` in `mission.gd`) und der Anteil der letzten Runde (`FINAL_SHARE` in `game.gd`) sind Schätzwerte. Nadjas neue Stimme und die Ripper-Geräusche sind nur gemessen. Die Bots übernehmen keine Aufträge der Geschichte, bei denen etwas getragen wird (Hack-Modul holen und anbringen, Evakuierung).
- **Nicht von Hand gespielt, nicht gehört (v0.16):** Die Werte des G36 (450 Vorrat, Schaden 35, 750 Schuss/min) und der Schrotflinten (Schaden 24 × 9 und 17 × 8, Stoß `push` in `WEAPONS`, Reichweite des Stoßes `PUSH_NEAR`/`PUSH_FAR` in `player.gd`) sind Schätzwerte. Wie das G36, die Schrotflinten und die neuen Stimmen klingen, ist nur gemessen. Die Aufsätze sitzen beim G36 auf dem schmalen Tragebügel und sind breiter als er.
- **Nicht von Hand gespielt (v0.15):** Mit Heilspritze, voller Heilung und halber Munition nach jeder Runde ist die Nacht spürbar leichter als in v0.14 – ob zu leicht, zeigt erst das Spielen. Die Stellschrauben: `SYRINGE_HEAL`, `SYRINGE_WAIT` und `ROUND_AMMO` in `player.gd`, `ROUND_HEAL`, `TRADE_IN`, `SHIELD_LIMIT` und `FINAL_SHARE` in `game.gd`.
- **Nicht von Hand gespielt (v0.14):** Schaden, Preise und Reichweiten der neuen Waffen, die Stärke der Modifikationen und das Wachstum des Endlosmodus sind Schätzwerte (`WEAPONS` in `player.gd`, `MODIFIERS` und `ENDLESS_GROWTH` in `game.gd`, `FireField` in `fire_field.gd`). Der Bot, der Nächte durchspielt, benutzt weder Nahkampf noch Molotow noch Klassenwaffen.
- Die Flammen sind weiche, leuchtende Zungen aus Partikeln, keine gezeichneten Flammen; der Strahl des Flammenwerfers geht optisch durch Wände, trifft dahinter aber nichts.
- Das Startgewehr ist seit v0.12 das M4A4-Modell (in der Hand der C.R.U.-Soldaten und der Bots steckt weiter das alte, aus einfachen Formen gebaute Gewehr). Die sechs neuen Waffen, der Helikopter und das Hack-Modul sind schlichte Blender-Modelle – als Platzhalter gedacht, falls du eigene hast.
- Auf dem Balkon, der Galerie und am Treppenkopf passen nur etwa sechs Infizierte gleichzeitig an einen Überlebenden; der Rest staut sich dahinter.
- Es werden keine Combat-Arms-Dateien verwendet.

## Prüfung

498 Integrationstests laufen in der echten Godot-Physik: Bewegung, Treffer und Kopfschüsse, Wände und Fenster, alle Zugänge, beide Treppen, alle Gegnerfähigkeiten, Animationen auf allen Skeletten, Stationen, Gas, Pause, alle zehn Runden, Rundenshop, alle Waffen, Blut-Effekte, Team-Bots und ihre Befehle, Rundenarten und Aufträge, Shop-Gegenstände, Giftnebel, Stalker und Leech, Schwierigkeitsstufen, Bestenliste, Stimmen und Funk-Warteschlange, die C.R.U. (schießen, ausweichen, werfen, Trupp-Zusammensetzung, Lampen), die sechs neuen Waffen, die UMP45 mit Aufsätzen und Magazinwechsel, die ballistische Weste, der Medic und seine Wolke, der Schild-Soldat, Gasfelder und Gasalarm, Aufträge im Obergeschoss, Skins, die Geschichte von der ersten Sperre über Hack-Modul, Keller, Labor, Nadjas Tür und Tunnel bis zum Abflug – und was mit v0.14 kam (ein Block für sich: `--smoke-test --only=arsenal`): Nahkampf, Molotow und Feuer, die fünf neuen Waffen, Einzelschuss, Klassenwaffen und ihre Sperre, Team-Upgrades, Nadja, die vier Stimmen und zwölf Stürze der C.R.U. (jeder Sturz jedes Soldatentyps endet am Boden), Rollen nur mit Platz, Fähigkeitspunkte vergeben und zurücknehmen, Endlosmodus und Modifikationen – und v0.15 (`--only=loadout`): Waffen-Plätze, Tausch und Gurte, Tasten nach Waffenart, Heilspritze, Ducken hinter Deckung, Heilung und Munition am Rundenende, ein Schild-Soldat gleichzeitig.

```text
Godot_v4.7.2-stable_win64.exe --headless --path "PFAD_ZU_NACHTWACHE" -- --smoke-test
```

Ein Bot kann das echte Spiel im Zeitraffer durchspielen und meldet Infizierte, die irgendwo hängen bleiben. Ohne `--headless` und mit `--bot-speed=1` misst er außerdem die Bildrate:

```text
Godot_v4.7.2-stable_win64.exe --headless --path "PFAD_ZU_NACHTWACHE" -- --bot-check --bot-seconds=600
Godot_v4.7.2-stable_win64.exe --path "PFAD_ZU_NACHTWACHE" -- --bot-check --bot-seconds=75 --bot-round=8 --bot-speed=1
```

Koop-Test mit zwei Instanzen auf einem PC (erst den Host starten, dann den Gast). Mit `--mp-story` bei beiden gehen sie statt des Gefechts die Geschichte durch:

```text
Godot_v4.7.2-stable_win64.exe --headless --path "PFAD_ZU_NACHTWACHE" -- --mp-host-test
Godot_v4.7.2-stable_win64.exe --headless --path "PFAD_ZU_NACHTWACHE" -- --mp-join-test
```

Screenshots: `--v15-check` (Fähigkeiten vor und nach der Wahl eines Wegs, der Shop mit Tausch und Waffengurt, die Kachel der Heilspritze, die Sicht im Ducken, das Rundenende), `--v14-check` (Menüs mit Modus und Fähigkeiten, die fünf neuen Waffen an der Hüfte und im Anschlag, die aufgekippte Doppelbüchse, Nahkampf, Flammenwerfer, Molotow, die Stürze der Soldaten, die neuen Shop-Listen, eine Runde mit Modifikation, das Ende einer Endlos-Nacht), `--story-check` (alle Stationen der Geschichte), `--intro-check` (die Ankunft), `--v9-check` (Medic, Schild-Soldat, Elite, Gas, tote Forscher, Explosion), `--falls-check` (die sechs neuen Stürze auf Zombies und Soldaten), `--gun-check --gun=g36`, `--gun=ak` oder `--gun=ump` (Waffe an der Hüfte, durch jedes Visier, Magazinwechsel), `--blast-check` (die Explosion in sechs Augenblicken), `--gun-check --gun=rifle` und `--gun=mg` (M4A4 und Maschinengewehr), `--scene-check` (alle fünf Leichen, die Bäume, der offene Rand des Hofs), `--gas-check` (eine Gasbank von außen, von weitem und von innen, eine Hofseite unter Gas, der Rand des Hofs, die Gasgranate, das Erdgeschoss, die Flugbahn des Granatwerfers), `--ump-check` (UMP, Aufsätze, Magazinwechsel, Shop), `--cru-check`, `--weapons-check`, `--visual-check`, `--map-tour`, `--team-check`, `--ripper-check`, `--shotgun-check`, `--mission-check`, `--gear-check`, `--models-check`, `--menu-check`, jeweils mit `--capture-dir=ORDNER`. Mit `--scale=0.5` rechnet ein Start das 3D-Bild mit halber Auflösung, mit `--squad=raven,viper` wählt er die beiden Bots – beides, ohne etwas zu speichern. Automatische Läufe (alles, was auf `-check` oder `-test` endet, und alles ohne Fenster) lesen und ändern dein gespeichertes Profil und deine Einstellungen nicht. Nach neuen Skripten mit `class_name` oder neuen Dateien in `assets` einmal den Editor öffnen (oder `--headless --import` ausführen), damit Godot sie kennt.
