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
| Linke Maustaste halten | Schießen |
| Rechte Maustaste halten | Zielen über Kimme und Korn |
| R | Nachladen (die Schrotflinte lädt Patrone für Patrone; ein Schuss bricht das Laden ab) |
| Shift (beim Vorwärtslaufen) | Sprinten |
| Leertaste | Springen |
| E | Station / Waffenshop benutzen, Teammitglied, Mitspieler oder Nadja aufhelfen |
| F | Taschenlampe |
| 1 / 2 / 3 / 4 / Mausrad | Sturmgewehr und AK-47 (die **1** wechselt zwischen beiden) / P90 und UMP45 (die **2** wechselt) / Honey Badger / Schrotflinte. Beim Wechsel blendet das Spiel kurz ein, was du trägst |
| 5 / 6 / 7 / 8 / 9 / 0 | Pistole / Magnum / Auto-Schrotflinte / Scharfschützengewehr / Granatwerfer / Minigun (alle aus dem Shop) |
| X / C / V | Befehl an das Team: Position halten / bei mir bleiben / frei bewegen |
| G / T / B | Splittergranate / Blendgranate / Claymore (aus dem Shop). Granaten: **Taste halten** zeigt die Flugbahn und wo sie aufschlägt, **loslassen** wirft. Kurz antippen wirft sofort. Mit einer Granate in der Hand kannst du nicht schießen |
| E halten | Auftragsgegenstand benutzen (Code bergen, Generator starten, Sicherung, Kiste, Hack-Modul anbringen oder neu starten) |
| Leertaste / Enter / Mausklick | Die Ankunft per Helikopter am Anfang überspringen |
| N | In der Pause die nächste Runde sofort starten |
| Esc | Pausieren / fortsetzen (im Koop läuft das Spiel weiter) |
| F11 oder Alt + Enter | Vollbild (auch als Knopf im Menü; am Mac gehört F11 dem System) |
| F2 | Testhilfe: aktuelle Runde sofort abschließen |

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
| **Evakuierung** | Nadja ist frei – der Hauptauftrag ist erfüllt. Die nächste Runde ist die letzte: Bringt sie zum Landeplatz und haltet ihn, bis der Helikopter unten ist. Der Crusher kommt dazu. Geht Nadja zu Boden, hilf ihr mit **E** auf; liegt sie 30 Sekunden, ist die Nacht verloren. Stehen alle am Helikopter, ist sie gewonnen |

Die Nacht dauert damit acht oder neun Runden (neun, wenn ein früher Auftrag misslingt); die letzte zählt für die Bestenliste immer als Runde 10. Ohne die Geschichte (Karten ohne Labor, automatische Tests) bleibt es bei zehn Runden bis zum Helikopter.

Die Infizierten kommen aus dem Gas durch die Lücken im Zaun – immer von der Seite des Hofs, auf der du gerade bist – und dringen durch **Vordertür, Hintertür, Seitentür und das Loch in der Küchenwand** ins Haus ein (durch die Seitentür erst, wenn das Kaminzimmer offen ist). Über die **Treppe im Haus** und die **Außentreppe zum Balkon** kommen sie auch ins Obergeschoss, sobald es offen ist. Durch Fenster und über Geländer kannst du schießen, durchklettern kann niemand.

### Runden und Aufträge

Nicht jede Runde ist gleich. Ab Runde 3 würfelt das Spiel für jede Nacht neu aus, was kommt:

| Runde | Was passiert |
|---|---|
| Normale Welle | die Mischung aus der Tabelle unten |
| **Horde** | deutlich mehr Mauler in kürzeren Abständen |
| **Mutanten** | wenige Infizierte, dafür fast nur Spezialgegner |
| **C.R.U.** (ab Runde 4) | kaum Infizierte, dafür ein ganzer Trupp Helix-Soldaten |
| **Infizierte + C.R.U.** (ab Runde 4) | beides zugleich |
| **Hinterhalt** (ab Runde 5) | mitten in einer Runde kommt ein kleiner C.R.U.-Trupp über den Zaun |

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

Gas verletzt dich nach drei Sekunden und dann jede Sekunde weiter. Die **Gasmaske** aus dem Shop hält es ab, solange ihr Filter reicht (8, 20, 45 oder 120 Sekunden je nach Stufe); an frischer Luft erholt er sich. Die Restzeit steht unten links.

| Wo | Wann | Was hilft |
|---|---|---|
| **Hinter dem Zaun** | immer | nicht hingehen |
| **Gasfelder im Hof** | ab Runde 2 eines, ab Runde 4 zwei, ab Runde 7 drei gleichzeitig | Grün leuchtende Wolken, rund 15 m breit. Sie bleiben etwa eine Minute, dünnen aus und quellen woanders wieder auf – nie auf dem Landeplatz und nie in Gebäuden. Umgehen, im Haus warten oder mit Maske durchlaufen |
| **Giftnebel über einer Hofseite** | ab Runde 4, manchmal | Eine ganze Seite (Nord, Süd, Ost, West) liegt für die Runde unter Gas. In den Gebäuden bist du sicher |
| **Gasalarm im Haus** | ab Runde 4, manchmal, sobald das Obergeschoss offen ist | Zehn Sekunden Warnung, dann steht das **Erdgeschoss** des Farmhauses gut eine halbe Minute unter Gas. **Oben ist die Luft sauber**: rauf auf die Galerie, in die Zimmer oder auf den Balkon – oder Maske auf und unten bleiben. Keller und Nebengebäude bleiben frei |
| **Gas des Medic** | solange er lebt | Flache grüne Schwaden, die um ihn herumkriechen. Maske, Abstand – oder ihn erschießen |
| **Gasgranate des C.R.U. Elite** | wenn er eine wirft | Eine kleine Wolke für rund 13 Sekunden, **auch in Räumen**. Raus aus der Wolke, oder Maske auf |

In den Runden, in denen ein Hack-Modul läuft oder der Helikopter kommt, gibt es keinen Gasalarm im Haus.

### Stimmen

Alle Funksprüche und Rufe sind **auf Englisch vertont** (ElevenLabs), mit Untertitel: **Colonel Coleman** über Funk, **Nadja** über die Laborlautsprecher und später neben dir, **Viper**, **Scorpion** und **Raven** rufen im Gefecht (Nachladen, Abschuss, Spezialgegner, C.R.U., am Boden …) und antworten auf Befehle, die **C.R.U.** brüllt sich Kommandos zu, die Händlerin grüßt. Funksprüche reden nie durcheinander: Kommt einer, während ein anderer läuft, wartet er. Die Texte stehen in `scripts/radio.gd`, die Aufnahmen in `assets/voice/<sprecher>/<stichwort>_<nummer>.ogg`; fehlt eine Aufnahme, erscheint nur der Untertitel.

### Schwierigkeit und Bestenliste

Im Hauptmenü stellst du mit **STUFE** die Schwierigkeit ein: Leicht, Normal, Schwer, Albtraum. Höhere Stufen machen die Gegner nicht zäher, sondern bringen mehr und schnellere Infizierte, mehr Spezialgegner, härtere Treffer, weniger Fundstücke, höhere Preise, schwächere Heilung, giftigeres Gas, mehr Aufträge und Ereignisse, eine C.R.U., die schneller reagiert, besser trifft und öfter flankiert, ausweicht und wirft, und längere Hacks mit einem Ausfall mehr – und vervielfachen den Score. Die **BESTENLISTE** merkt sich pro Stufe die zehn besten Einsätze (`user://nachtwache_profile.json`).

### Der Hof

| Ort | Was es dort gibt |
|---|---|
| **Farmhaus, Erdgeschoss** | Große Halle mit Galerie (Waffenshop in der Mitte), Kaminzimmer, Esszimmer, Küche, Treppenhaus, Lagerraum mit **Munition (60)** und **Erste Hilfe (100)** |
| **Farmhaus, Obergeschoss** | Galerie rund um die Halle, vier Zimmer, Balkon mit Außentreppe; im Lagerboden (Nordosten) eine dritte **Munitionsstation**. Hier bist du sicher, wenn unten Gas steht, und manche Aufträge führen hier hinauf |
| **Scheune** (Nordosten) | zweite **Munitionsstation**, Heuboden, Tore an beiden Giebeln |
| **Werkstatt / Garage** (Nordwesten) | **Werkbank** (250, max. dreimal je Waffe) |
| **Gästehütte** (Südwesten) | zweite **Erste Hilfe** |
| **Schuppen** (Südosten), Koppel, Brunnen, Gemüsebeet, Straße mit Tor | Deckung und Wege zwischen den Gebäuden |
| **Keller und Labor** (unter dem Haus) | Hinter der Helix-Sicherheitstür unter der Treppe: Kellertreppe, Gang, Laborhalle mit Arbeitstischen, Serverschränken und Probentanks, im Westen **Nadjas Isolationsraum** hinter Panzerglas |
| **Versorgungstunnel** | Vom Labor nach Norden zu einem Betonbunker im Hof hinter dem Haus – der zweite Weg ins Labor |
| **Landeplatz** (Südwesten) | Freie Fläche mit Knicklichtern: Hier seilt ihr euch ab, hier landet am Ende der Helikopter |
| **Funkmast** (Südosten) | Gittermast mit Schaltkasten; ist er eingeschaltet, blinkt oben das rote Licht |

**Nicht alles ist von Anfang an offen.** Bretter versperren das Kaminzimmer (samt Seitentür), eine Barrikade die Treppe im Haus, ein Gittertor die Außentreppe; die Kellertür, Nadjas Tür und der Tunnel sind verriegelt. Das Kaminzimmer öffnet sich nach Runde 1, das Obergeschoss nach Runde 3, der Rest durch die Geschichte. Rote Lampen an den Sperren werden grün, wenn der Weg frei ist. Auch die Infizierten kommen nur durch, wo offen ist.

Der **Waffenshop** in der Halle ist **vor der ersten und nach jeder überstandenen Runde geöffnet** (grüne Lampe, Rollladen oben) und **während einer Runde geschlossen**. Die Pause dauert 20 Sekunden; im Solo-Spiel steht die Zeit, solange das Shop-Menü offen ist.

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
| **Crusher** | 6, 8 und letzte | Der große Blaue. Vor der letzten Runde kommt er mitten in der Runde und ist noch nicht ausgewachsen (gut die Hälfte bzw. drei Viertel seines Lebens); am Ende steht er in voller Größe da. Sehr viel Leben, große Reichweite, kopfschussresistent. Springt dich an, wenn du Abstand hältst, wird ab halbem Leben rasend und löst sich beim Tod in eine Säurewolke auf |

- **Treffer wirken:** Jeder Treffer reißt den Körper herum, konzentriertes Feuer bringt Infizierte ins Taumeln. Tote fallen je nach Schussrichtung nach hinten, vorn oder zur Seite; es gibt mehrere Todesanimationen pro Richtung.
- **Blut:** Kopfschüsse und schwere Treffer können Kopf oder Arm abreißen, Leichen bluten aus, Blut bleibt an Boden und Wänden.
- Weit entfernte Infizierte **beeilen sich**, damit niemand auf Nachzügler warten muss.
- Abschüsse bringen **Score** und **Vorrat**; Kopfschuss-Kills geben 50 Punkte extra. Jede überstandene Runde bringt 100 Vorrat und 20 HP. Gefallene lassen gelegentlich **Munition** (beige) oder ein **Verbandspäckchen** (grün) fallen.
- Zum **Giftgas** siehe den nächsten Abschnitt: hinter dem Zaun steht es immer, im Hof und im Haus kommt und geht es.

### C.R.U. – Containment Response Unit

Helix' Eliteeinheit: Sie soll Beweise vernichten, Nadja holen und alle ausschalten, die zu viel wissen. Die Infizierten lassen sie in Ruhe (ein Helix-Aerosol tarnt sie), und sie die Infizierten.

- Du erkennst sie im Dunkeln an der **roten Markerlampe** auf der Brust und am **Lichtkegel ihrer Waffenlampe**, der im Nebel steht. Fällt einer, gehen seine Lampen aus.
- Sie **schießen** in Feuerstößen, suchen sich Stellungen mit Deckung und Schusslinie, wechseln sie alle paar Sekunden und rücken geduckt vor.
- **Flankierer** arbeiten sich seitlich um dich herum, angeschlagene Soldaten **ziehen sich zurück** und kommen wieder.
- Pfeifen Kugeln knapp an ihnen vorbei, **werfen sie sich mit einer Rolle zur Seite** – außer der Schuss war schallgedämpft (Honey Badger, UMP45 mit Schalldämpfer).
- Sie werfen **Granaten** auf stehende Ziele (rotes Leuchten, Warnung „GRANATE!“).

| Rolle | Besonderheit |
|---|---|
| Assault | Sturmgewehr, eine Granate |
| Breacher | Schrotflinte, sucht die Nähe |
| Heavy | lange Feuerstöße als Deckungsfeuer, schwer gepanzert, weicht nie aus |
| Marksman | wenige, harte Schüsse aus großer Entfernung, kniet beim Zielen |
| Medic | läuft zu Verwundeten und flickt sie |
| Commander | macht alle in seiner Nähe schneller und genauer; fällt er, ist der Trupp kurz verunsichert |
| Shield | trägt einen mannshohen Schild mit Sichtfenster vor sich her: **von vorn geht keine Kugel durch**, auch kein Kopfschuss. Er rückt langsam vor und **dreht sich nur träge** – lauf an ihm vorbei und schieß ihm in den Rücken oder in die Seite, oder nimm Granaten: eine Explosion geht um den Schild herum. In jedem Trupp ist einer |
| Elite | der Soldat mit Kapuze und Gasmaske, deren Gläser orange glühen. Gut zwei Drittel mehr Leben als ein Assault, eine Panzerung, die vier von zehn Treffern schluckt, und eine **AK-47**, die deutlich härter trifft. Statt Splittergranaten wirft er **Gasgranaten**: Wo eine liegen bleibt, steht für rund 13 Sekunden eine kleine Giftwolke – auch im Haus. Ab Runde 5 gehört einer zu jedem vollen C.R.U.-Trupp, in den letzten Runden sind es zwei |

Je höher die Schwierigkeit, desto schneller reagieren sie, desto besser treffen sie und desto öfter weichen sie aus, flankieren und werfen.

### Waffen

| Waffe | Preis | Magazin | Besonderheit |
|---|---|---|---|
| Sturmgewehr | Startwaffe | 30 | Solide auf jede Entfernung |
| AK-47 | 300 | 30 | Kaliber 7,62: knapp ein Drittel mehr Schaden pro Kugel als das Sturmgewehr und etwas schneller, dafür mehr Rückstoß und Streuung. Teilt sich die Taste **1** mit dem Sturmgewehr. Das Magazin wird sichtbar gewechselt, und sie nimmt **Aufsätze** |
| P90 | 100 | 50 | Sehr schnell, streut mehr |
| UMP45 | 220 | 25 | Schwere MP: langsamer als die P90, dafür trifft jede Kugel härter. Das Magazin wird sichtbar gewechselt. Nimmt **Aufsätze** (siehe unten) |
| Schrotflinte | 250 | 6 | Neun Schrotkugeln pro Schuss, wuchtiger Rückstoß, Vorderschaft-Repetieren; auf kurze Distanz tödlich, ab etwa 25 m fast wirkungslos |
| Honey Badger | 350 | 30 | Schallgedämpft, präzise, hoher Einzelschaden |
| Auto-Schrotflinte | 500 | 8 | Halbautomatisch mit Kastenmagazin: kein Repetieren, schnelles Nachladen |
| M9 Pistole | 60 | 15 | Leicht und schnell, billige Zweitwaffe |
| .44 Magnum | 220 | 6 | Sechs Schuss, jeder ein Hammer |
| Scharfschützengewehr | 450 | 5 | Zielfernrohr (rechte Maustaste), Repetierer; die Kugel geht durch bis zu vier Körper |
| Granatwerfer | 900 | 6 | 40-mm-Granaten, zünden beim Aufschlag. **Erst nach Runde 4** im Shop |
| Minigun | 1500 | 200 | Läuft kurz an und feuert dann 1300 Schuss pro Minute; macht langsam. **Erst nach Runde 6** im Shop |

### Aufsätze für UMP45 und AK-47

In der Shop-Liste **Aufsätze**, für jede der beiden Waffen eigens zu kaufen. Einmal gekauft, lässt sich ein Teil dort beliebig oft kostenlos anbringen und wieder abnehmen. Pro Platz sitzt immer nur ein Teil auf der Waffe: ein Visier auf der Schiene, ein Schalldämpfer an der Mündung.

| Aufsatz | Preis | Wirkung |
|---|---|---|
| Rotpunktvisier | 120 | Ein großes, klares Glas mit Leuchtpunkt im Ring. Es sitzt dicht am Auge und über Kimme und Korn, sodass kaum etwas vom Gewehr im Bild steht. Etwas mehr Vergrößerung als über Kimme und Korn, beim Zielen 45 % weniger Streuung |
| Zielfernrohr 4× | 260 | Vierfache Vergrößerung. Das Bild füllt fast den ganzen Bildschirm; das Fadenkreuz hat Haltemarken für weite Schüsse. Beim Zielen 65 % weniger Streuung; die Sicht dreht langsamer |
| Schalldämpfer | 180 (AK-47: 200) | Leiser Schuss, kaum Mündungsfeuer, 20 bis 25 % weniger Rückstoß, etwas weniger Streuung, 5 % weniger Schaden – und die C.R.U. weicht deinen Schüssen nicht mehr aus |

### Ausrüstung aus dem Shop

Der Shop hat sechs Reiter: **Waffen**, **Pistolen**, **Schwer**, **Aufsätze**, **Ausrüstung** und **Verbrauch**. Hinter dem Tresen steht die Händlerin.

| Gegenstand | Preis | Wirkung |
|---|---|---|
| Splittergranate (G) | 60 | Explodiert nach gut zwei Sekunden, reißt alles im Umkreis mit – auch dich. Bis zu vier |
| Blendgranate (T) | 45 | Betäubt Infizierte, die sie sehen, für einige Sekunden. Bis zu vier |
| Claymore (B) | 90 | Mine vor deinen Füßen; zündet, sobald ein Infizierter davor läuft. Bis zu vier |
| Adrenalinspritze | 300 | Rettet dich einmal, wenn dein Leben auf null fällt |
| Schutzweste / Schwere Rüstung | 150 / 300 | 50 bzw. 100 Rüstung; Rüstung fängt 60 % jedes Treffers ab |
| Ballistische Weste | 160 / 260 / 400 | Drei Stufen gegen die C.R.U.: 25, 40 und 55 % weniger Schaden durch ihre Kugeln und Granaten. Verbraucht sich nicht und wirkt zusätzlich zur Rüstung; gegen Infizierte hilft sie nicht. Die Stufe steht neben der Lebensanzeige |
| Größere Magazine | 200 | +50 % Magazin für die Waffe in deiner Hand (im Reiter Aufsätze) |
| Gasmaske | 150 / 250 / 400 / 600 | Vier Stufen: Filter für 8, 20, 45 und 120 Sekunden im Giftgas; erholt sich an frischer Luft. Wofür sie gut ist, steht unter „Gas und Gasmaske“ |

Die Preise gelten für „Normal“ und steigen mit der Schwierigkeit.

### Dein Team

Im Solo-Spiel begleiten dich zwei Bots – am Anfang **Viper** (Honey Badger) und **Scorpion** (Schrotflinte). Sie halten ein paar Schritte Abstand, kommen nach, wenn du dich entfernst, schießen selbstständig, laden nach und weichen zurück, wenn ihnen etwas zu nahe kommt. Geht einer zu Boden, hilfst du ihm mit **E** auf; nach 14 Sekunden oder am Rundenende steht er von selbst wieder. **Gehst du selbst zu Boden**, kommt der nächste Bot angerannt und hilft dir auf – verloren ist die Nacht erst, wenn niemand mehr steht.

Befehle für beide Bots: **X** = Position halten (an der Stelle, auf die du zielst; ein Ring markiert sie), **C** = bei mir bleiben, **V** = frei bewegen (sie suchen sich die Infizierten selbst, bleiben aber in deiner Nähe). Sie bestätigen jeden Befehl und rufen im Gefecht. Mit Team kommen mehr Infizierte. Ohne Bots starten: `SPIELEN.cmd` um ` -- --no-team` ergänzen.

Wer steht und nichts zu bekämpfen hat, **behält seine Blickrichtung** und dreht sich nicht mit dir mit. Willst du dir die Modelle in Ruhe ansehen: **X** drücken – dann bleiben sie stehen, auch wenn du nah herangehst (bei „bei mir bleiben“ machen sie dir ab zwei Metern Platz).

**Skins & Trupp** (Hauptmenü): Hier wählst du, wie du selbst aussiehst – so sieht dich dein Koop-Mitspieler, und so seilst du dich am Anfang ab – und welche zwei Bots mitkommen.

| Aussehen | Freigeschaltet | Als Bot wählbar |
|---|---|---|
| Fireteam (das Spielermodell) | von Anfang an | nein |
| Viper, Scorpion | von Anfang an | ja |
| Raven (Honey Badger) | nach dem ersten gewonnenen Einsatz | ja |
| C.R.U.-Rüstung | 40 C.R.U.-Soldaten ausgeschaltet | nein |
| Breacher-Rüstung | 500 Gegner ausgeschaltet | nein |

Was du selbst trägst, bleibt für die Bots wählbar: Du kannst als Viper spielen und trotzdem Viper im Trupp haben. Zum Ausprobieren lässt sich der Trupp auch beim Start festlegen: `SPIELEN.cmd` um ` -- --squad=raven,viper` ergänzen. Die Zähler stehen in der Laufbahn deines Profils (`user://nachtwache_profile.json`); automatische Testläufe schreiben dort nichts hinein.

## Koop zu zweit

1. **Dein Mitspieler braucht dasselbe Spiel.** `KOOP_PAKET_ERSTELLEN.cmd` packt das Projekt samt Godot in `Nachtwache-Koop-Paket.zip` (neben dem Projektordner). Er entpackt die ZIP und startet im Ordner `Nachtwache` die `SPIELEN.cmd`. Beim allerersten Start bereitet Godot die Spieldaten vor – das dauert etwa eine Minute (auf langsameren PCs länger). Hat dein Mitspieler einen **Mac**, baut `KOOP_PAKET_MAC_ERSTELLEN.cmd` stattdessen `Nachtwache-Koop-Paket-Mac.zip` – ohne Godot, das lädt er selbst (siehe „Auf dem Mac“).
2. **Du:** Hauptmenü → **KOOP HOSTEN**. Das Menü zeigt deine Adressen; dort stellst du auch die Stufe ein.
3. **Er:** **KOOP BEITRETEN** → deine Adresse eintragen → **VERBINDEN**. Sobald er verbunden ist, startest du den Einsatz.

Über das Internet benutzt das Spiel **UDP-Port 24565**. Beim Eröffnen versucht es, den Port per UPnP selbst im Router freizugeben; das Menü sagt, ob das geklappt hat. Wenn nicht: im Router den UDP-Port 24565 auf deinen PC weiterleiten – oder ihr installiert beide ein VPN-Tool (z. B. Radmin VPN oder ZeroTier) und er trägt deine VPN-Adresse ein. Im selben WLAN/LAN reicht die angezeigte lokale Adresse.

Im Koop ersetzt dein Mitspieler die Bots. Die Geschichte läuft für beide: Der Gast sieht dieselben Sperren, Aufträge, Nadja und den Helikopter, und am Ende müssen **beide** mit Nadja am Landeplatz stehen. Vorrat und Score gehören dem Team, jeder hat eigene Waffen und Munition. Wer zu Boden geht, kann vom anderen mit **E** aufgehoben werden und steht nach der Runde wieder; liegen beide, ist die Nacht verloren. Der Host rechnet die Gegner, der Gast sieht sie mit kleiner Verzögerung.

## Auf dem Mac

Das Spiel ist auch für einen Mac mit Apple-Chip vorbereitet. **Auf einem Mac ausprobiert wurde es noch nicht** – was genau ungeprüft ist, steht unter „Stand und Grenzen“. Klappt der Start per Skript nicht, führt der Weg über Godot (Punkt 4) trotzdem zum Ziel.

1. **Godot 4.7.2 für macOS** von godotengine.org laden (die Standard-Version, nicht .NET) – **genau dieselbe Version wie beim Mitspieler**, sonst startet das Projekt womöglich nicht oder der Koop läuft auseinander. Die geladene Datei entpacken, `Godot.app` in den Ordner **Programme** ziehen und **einmal per Doppelklick öffnen** (macOS fragt beim ersten Mal, ob die App aus dem Internet geöffnet werden darf), dann wieder schließen.
2. `Nachtwache-Koop-Paket-Mac.zip` entpacken. Diese ZIP baut auf dem Windows-PC die Datei `KOOP_PAKET_MAC_ERSTELLEN.cmd`: das Projekt ohne die Windows-Startdateien und ohne Godot, rund 540 MB.
3. Im Ordner `Nachtwache` die Datei **`SPIELEN.command`** doppelklicken. Sie sucht Godot 4.7.2 in den Programmen, in den Downloads, auf dem Schreibtisch und neben dem Spielordner. Beim ersten Start bereitet Godot die Spieldaten vor (ein paar Minuten), danach startet das Spiel. Das Terminal-Fenster bleibt offen, solange du spielst.
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
| `scripts/gas_field.gd` | Gas, das kommt und geht: Gasfelder im Hof (`POCKET_ROUNDS`), Gasalarm im Erdgeschoss (`FLOOD_SECONDS`) |
| `scripts/story.gd` | Die Geschichte: welcher Schritt in welche Runde fällt, wann sich welcher Bereich öffnet (`AREA_ROUNDS`), Nadja, Helikopter, die Ankunft am Anfang |
| `scripts/helicopter.gd` | Der Helikopter: Rotoren, Lichter, Seile, Motorgeräusch |
| `scripts/radio.gd` | Alle Funksprüche (`LINES`) und Rufe (`BARKS`) auf Englisch, nach Stichwort und Sprecher |
| `scripts/profile.gd` | Schwierigkeitsstufen (`DIFFICULTIES`), Bestenliste, Laufbahn, Skins (`SKINS`) |
| `scripts/cru_soldier.gd`, `scripts/cru_visual.gd` | Die C.R.U.: Rollen (`ROLES`), Stellungswahl, Feuerstöße, Flankieren, Rückzug, Ausweichrolle, Granaten, Sanitäter; ihre Waffen- und Markerlampen (`_fit_lamps`) |
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
| `scripts/hud.gd` | Menüs, Shop-Menü, Koop-Lobby und Anzeigen |
| `scripts/sound.gd` | Lädt die Sounds aus `assets/sounds`, Lautstärken (`MIX`), Hall drinnen/draußen |
| `scripts/music.gd` | Die Musik: welche Datei zu welchem Teil der Nacht gehört (`PHASES`), wann gewechselt und wie lange übergeblendet wird |
| `scripts/verification.gd` | Automatische Prüfungen, Bot-Durchlauf, Koop-Test |
| `SPIELEN.command`, `tools/make_mac_package.js` | Start auf dem Mac (sucht Godot, bereitet beim ersten Mal die Spieldaten vor); der Packer für das Mac-Paket, der `SPIELEN.command` in der ZIP als startbar kennzeichnet |

Gute erste Stellschrauben: `ROUNDS` in `game.gd` (wer in welcher Runde kommt), `TYPES` in `infected.gd` (Leben/Tempo/Schaden), `WEAPONS` in `player.gd` (Schaden, Feuerrate, Preis), `GUNS` und die Abstände `KEEP_AWAY` / `FOLLOW_FAR` in `teammate.gd` und `MIX` in `sound.gd` (Lautstärke jedes Sounds in dB).

In `cabin.gd` stehen benannte Orte in `points` (z. B. `hall`, `barn`, `stairs_bottom`, `cellar_door`, `lab`, `landing`) und die abschließbaren Bereiche in `AREAS` (`lock_all()`, `unlock(bereich)`). Wie Keller, Labor, Tunnel, Sperren und Landeplatz gebaut sind, steht ausführlich (auf Englisch) in `KARTE_PHASE4.md` im Ordner `Nachtwache-Konzept` neben dem Projekt. Neue feste Objekte mit `_prop(...)` oder `_solid(...)` anlegen, dann blockieren sie auch die Laufwege. `tools/map_check.gd` prüft die Karte (Wege von allen Startpunkten zu allen Orten, Treppen, Türen):

```text
Godot_v4.7.2-stable_win64.exe --headless --path "PFAD_ZU_NACHTWACHE" -s res://tools/map_check.gd
```

## Animationen (Mixamo)

- Der gelbe Hazmat-Mauler wurde bei Mixamo automatisch geriggt (`assets/models/mixamo/mauler_hazmat_rig.fbx`). Dazu kommen rund 40 Clips: Zombie-Gänge, Angriffe (Schlag, Tritt, Kopfstoß, Biss), Trefferreaktionen, elf Todesvarianten, die Mutanten-Clips für den Crusher (Gang, Rennen, Schläge, Sprung, Brüllen) und die Soldaten-Clips für die Bots. Gespiegelte Varianten erzeugt das Spiel selbst.
- Die anderen Gegner behalten ihre eigenen Skelette. Beim Start überträgt `infected_visual.gd` jeden Clip auf jedes Skelett: Es erkennt Hüfte, Wirbelsäule, Arme und Beine am Knochenbaum, richtet die Gliedmaßen auf die Mixamo-Grundhaltung aus und stellt die Füße auf den Boden.
- **Neuen Clip einbauen:** bei Mixamo als *FBX, Without Skin, 30 fps* (Laufzyklen mit *In Place*) herunterladen, nach `assets/models/mixamo/` legen, in der `.import`-Datei `nodes/root_scale=100.0` setzen (die anderen Dateien zeigen es) und in `CLIPS` eintragen.
- Die elf Modelle des Fireteam-Ausbaus (Meshy, ohne Skelett geliefert) wurden in Blender auf rund 30.000 Dreiecke verkleinert und mit einem 22-Knochen-Skelett versehen; die Skripte dafür liegen neben dem Projekt in `Nachtwache-Modelle/phase4/tools` (`run_all.sh`).
- Für v0.7 kamen zehn Clips dazu: seitwärts gehen, ducken, geduckt rennen, Hechtrolle, Granatwurf, am Seil hängen und landen für die Soldaten (`MOVES` in `soldier_visual.gd`), dazu stehen, reden und nervös sein für Nadja und die Händlerin (`CLIPS` in `npc_visual.gd`).
- Die **UMP45** kam als ein einziges Teil ohne Magazin. `Nachtwache-Modelle/ump/make_ump.py` (Blender) bringt sie auf 69 cm, dreht den Lauf nach vorn, legt den Griff auf den Nullpunkt, verkleinert die Texturen auf 2048 und baut das Magazin als eigenes Teil dazu; die Maße für das Spiel stehen in `fertig/SPEC.json` daneben. Visiere und Schalldämpfer entstehen im Code (`_ump_mods` in `weapon_view.gd`).
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

- `assets/sounds` enthält 139 WAV-Dateien: Schüsse aller Waffen, Nachladen, Schritte, Treffer, Stimmen aller Infizierten in mehreren Varianten, Hund, Blut und Brocken, Explosionen, Shop-Rollladen, Runden-Stinger, Donner, Regen und Wind, Helikopter. 129 davon stammen aus dem ElevenLabs-Soundeffekt-Generator; die zehn neuen (Pistole, Magnum, Scharfschützengewehr, Granatwerfer, Minigun samt Anlauf, Helikopter, Piepton, UMP mit und ohne Schalldämpfer) sind aus vorhandenen Aufnahmen abgeleitet.
- Die Originaldownloads liegen neben dem Projekt in `Nachtwache-ElevenLabs`. Daraus wurden die Sounds geschnitten, auf Mono gemischt und auf gleiche Lautheit gebracht.
- **Neu erzeugen:** `node tools/make_sounds.js ../Nachtwache-ElevenLabs assets/sounds`. `node tools/wav_info.js ORDNER` zeigt Pegel und Länge jeder WAV-Datei.
- **Sound austauschen:** WAV mit demselben Namen in `assets/sounds` legen (Varianten heißen `name_1.wav`, `name_2.wav` …). Fehlt eine Datei, spielt das Spiel einen einfachen synthetischen Ersatz.
- **Stimmen:** `assets/voice` enthält 181 Aufnahmen (Coleman 67, Nadja 20, Viper, Scorpion und Raven je 24, C.R.U. 16, Händlerin 6), erzeugt mit ElevenLabs *Multilingual v2*. Für **Colonel Coleman** und **Nadja** wurden eigene Stimmen entworfen und in deinem ElevenLabs-Konto gespeichert; die anderen sprechen mit Standardstimmen. Colemans Aufnahmen klingen nach Funk (Bandpass, Kompressor), Nadjas nach Lautsprecher, solange sie hinter dem Glas sitzt.
- **Stimme ergänzen oder tauschen:** Text in `scripts/radio.gd` eintragen, bei ElevenLabs erzeugen, die MP3s in einen Ordner legen und `node tools/make_voices.js ORDNER order.json` laufen lassen (schneidet, pegelt und legt `assets/voice/<sprecher>/<stichwort>_<nummer>.ogg` an). Die Rohdateien und die Zuordnung liegen in `Nachtwache-ElevenLabs/stimmen`. Hat ein Stichwort mehrere Texte, aber nur für einige eine Aufnahme, benutzt das Spiel nur die vertonten.

## Stand und Grenzen

**v0.10** bringt den **C.R.U. Elite** mit AK-47 und Gasgranaten, die **AK-47** als kaufbares Gewehr mit Magazinwechsel und Aufsätzen, ein Rotpunktvisier und ein Zielfernrohr, durch die man deutlich mehr sieht, einen Medic, dessen Gas flach über den Boden kriecht und Infizierte sichtbar verstärkt, tote Forscher, die von Anfang an auf dem Hof liegen, eine neue Granatexplosion (Feuerwolken, Funken, Glut, Rauch) samt richtigem 40-mm-Geschoss, Granaten mit Flugbahn-Anzeige, **Musik**, die der Nacht folgt, eine neue Oberfläche mit Einstellungen für Ton und Bild und viele zusätzliche Funksprüche.

**v0.9** bringt den Medic-Zombie mit seiner Wolke, den Schild-Soldaten der C.R.U., einen dritten C.R.U.-Körper, den Crusher schon vor der letzten Runde, Gasfelder im Hof und Gasalarm im Haus (damit Gasmaske und Obergeschoss einen Zweck haben), eine Munitionsstation und Aufträge im Obergeschoss, tote Forscher als Modelle und eine Granatexplosion mit Feuerball, Druckring, Erdfontäne und Rauch. Dazu kommt der Start auf dem Mac, die Einstellung **3D** für schwächere Rechner und Vollbild per Alt + Enter.

**v0.8** bringt die UMP45 mit sichtbarem Magazinwechsel und drei Aufsätzen, die ballistische Weste gegen die C.R.U. und Lampen, an denen man die C.R.U. im Dunkeln erkennt. Darunter der Stand von v0.7.

**v0.7 – der Fireteam-Ausbau** (Konzept: `phase4_fireteam_ausbau.md` im Ordner `Nachtwache-Konzept` neben dem Projekt). Neu gegenüber v0.6: die Helix-Geschichte von der Landung bis zum Abflug, Ankunft per Helikopter als Zwischensequenz, Keller mit Labor und Tunnel, Bereiche, die sich nach und nach öffnen, Hack-Modul mit Ausfällen, Nadja hinter Glas und als Begleiterin, die C.R.U. als Gegner mit sechs Rollen, sechs weitere Waffen, englische Sprachausgabe für Funk und Rufe, vier neue Aufträge (Funkmast, Position halten, Proben, Festplatten), Skins und Trupp-Auswahl.

Aus dem Konzept noch offen: Barrikaden reparieren, einen NPC an einem Ort beschützen und Schalter-Rätsel als eigene Aufträge; zusätzliche Bot-Befehle; die Geschichte hat immer dieselben Stationen (nur Rundenarten, Aufträge und Orte der Aufträge wechseln).

- **Nicht probegehört:** Stimmen und Sounds wurden nach Messwerten (Tonhöhe, Tempo, Pegel) ausgewählt und abgemischt. Passt eine Stimme nicht, lässt sie sich pro Sprecher austauschen (siehe oben). Für 23 von Colemans Funksprüchen gibt es eine zweite Textvariante ohne Aufnahme; das Spiel benutzt dann nur die erste.
- **Nicht von Hand gespielt:** Die Geschichte ist automatisch von Anfang bis Ende durchgeprüft und in Bildern kontrolliert, aber niemand hat sie bisher am Stück gespielt. Zielgenauigkeit und Schaden der C.R.U., die Dauer der Hacks und die Preise der neuen Waffen sind Schätzwerte: `ROLES` in `cru_soldier.gd`, `RUNNERS` in `mission.gd`, `WEAPONS` in `player.gd`.
- **Mac: nichts davon lief bisher auf einem Mac.** `SPIELEN.command` wurde nur unter Windows mit einem nachgestellten Godot durchgespielt (Suche an allen Orten, falsche Version, erster Import, Start), das Mac-Paket nur mit einem ZIP-Prüfprogramm (alle Dateien heil, `SPIELEN.command` als startbar gekennzeichnet). Ungeprüft sind: ob macOS die Datei nach dem Entpacken wirklich per Doppelklick startet und was seine Sicherheitsabfrage dazu sagt, wie flüssig das Spiel auf einem M3 läuft und ob 50 % der richtige Startwert für **3D** ist, wie das Bild mit Apples Grafikschnittstelle aussieht, die Ersatzschrift der Überschriften und der Koop zwischen Windows und Mac.
- **OBS** wurde hier nicht selbst getestet: Das Spiel wurde dafür auf Direct3D 12 umgestellt, die Aufnahme musst du einmal ausprobieren.
- **Koop** wurde mit zwei Spielinstanzen auf einem PC getestet: Verbindung, Gegner, Vorrat, Kisten, Einkauf, Aufhelfen, Spielende, ein C.R.U.-Soldat samt Feuerstößen auf beiden Seiten und die Geschichte von der ersten Sperre bis zum Abflug (der Helikopter wartet, bis beide da sind). Über das Internet und mit der automatischen Portfreigabe wurde es noch nicht ausprobiert. Abschüsse, C.R.U.-Abschüsse und Aufträge des Teams zählen am Ende für die Laufbahn beider Spieler.
- Die Bots kennen die Aufträge nicht: Sie kämpfen und folgen, aber Geräte anbringen, Kisten öffnen und Nadja aufhelfen musst du selbst (oder dein Mitspieler).
- Der Charger kam ohne Skelett und wird beim Start automatisch geriggt. Für Frau, Striker und Crusher gelten die UniRig-Skelette; in den Projektkopien wurden fehlerhafte Hautgewichte korrigiert. Deine Originale in den Downloads sind unverändert.
- Das Honey-Badger-Modell hat rund 700.000 Eckpunkte. Auf deiner Grafikkarte ist das kein Problem; für schwächere Rechner sollte es später vereinfacht werden.
- Aufsätze gibt es bisher nur für die UMP45. Für andere Waffen genügt ein Eintrag in `ATTACHMENTS` und ein Modell des Teils an der Waffe; der Magazinwechsel der anderen Waffen läuft weiter unterhalb des Bildes ab.
- Wie die UMP klingt, ist aus vorhandenen Schüssen abgeleitet (`ump.wav`, `ump_sil.wav`) und nicht probegehört.
- Das Sturmgewehr ist weiterhin aus einfachen Formen gebaut, bis es ein eigenes Modell bekommt. Die sechs neuen Waffen, der Helikopter und das Hack-Modul sind schlichte Blender-Modelle – als Platzhalter gedacht, falls du eigene hast.
- Auf dem Balkon, der Galerie und am Treppenkopf passen nur etwa sechs Infizierte gleichzeitig an einen Überlebenden; der Rest staut sich dahinter.
- Es werden keine Combat-Arms-Dateien verwendet.

## Prüfung

386 Integrationstests laufen in der echten Godot-Physik: Bewegung, Treffer und Kopfschüsse, Wände und Fenster, alle Zugänge, beide Treppen, alle Gegnerfähigkeiten, Animationen auf allen Skeletten, Stationen, Gas, Pause, alle zehn Runden, Rundenshop, alle Waffen, Blut-Effekte, Team-Bots und ihre Befehle, Rundenarten und Aufträge, Shop-Gegenstände, Giftnebel, Stalker und Leech, Schwierigkeitsstufen, Bestenliste, Stimmen und Funk-Warteschlange, die C.R.U. (schießen, ausweichen, werfen, Trupp-Zusammensetzung, Lampen), die sechs neuen Waffen, die UMP45 mit Aufsätzen und Magazinwechsel, die ballistische Weste, der Medic und seine Wolke, der Schild-Soldat, Gasfelder und Gasalarm, Aufträge im Obergeschoss, Skins – und die Geschichte von der ersten Sperre über Hack-Modul, Keller, Labor, Nadjas Tür und Tunnel bis zum Abflug.

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

Screenshots: `--story-check` (alle Stationen der Geschichte), `--intro-check` (die Ankunft), `--v9-check` (Medic, Schild-Soldat, Elite, Gas, tote Forscher, Explosion), `--gun-check --gun=ak` oder `--gun=ump` (Waffe an der Hüfte, durch jedes Visier, Magazinwechsel), `--blast-check` (die Explosion in sechs Augenblicken), `--ump-check` (UMP, Aufsätze, Magazinwechsel, Shop), `--cru-check`, `--weapons-check`, `--visual-check`, `--map-tour`, `--team-check`, `--ripper-check`, `--shotgun-check`, `--mission-check`, `--gear-check`, `--models-check`, `--menu-check`, jeweils mit `--capture-dir=ORDNER`. Mit `--scale=0.5` rechnet ein Start das 3D-Bild mit halber Auflösung, mit `--squad=raven,viper` wählt er die beiden Bots – beides, ohne etwas zu speichern. Automatische Läufe (alles, was auf `-check` oder `-test` endet, und alles ohne Fenster) lesen und ändern dein gespeichertes Profil und deine Einstellungen nicht. Nach neuen Skripten mit `class_name` oder neuen Dateien in `assets` einmal den Editor öffnen (oder `--headless --import` ausführen), damit Godot sie kennt.
