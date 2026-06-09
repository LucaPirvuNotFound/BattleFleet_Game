# RAPORT PRIVIND IMPLEMENTAREA SISTEMELOR GRAFICE SI A ARHITECTURII

## BattleFleet_Game

**Autor:** Maciuca Bogdan-Alexandru
**Grupa:** 233
**Rol in proiect:** Grafica / Engine / Arhitectura intregului sistem
**Proiect:** BattleFleet_Game

---

## 1. Introducere

Prezentul raport documenteaza contributiile aduse proiectului BattleFleet_Game in cadrul rolului de Grafica, Engine si Arhitectura Sistemului. Scopul principal al acestor contributii a fost dezvoltarea sistemelor vizuale si mecanice care definesc experienta de joc, precum si stabilirea unei arhitecturi scalabile si usor de intretinut pentru intregul proiect.

Contributiile acopera trei directii majore:

1. **Arhitectura sistemului** — organizarea proiectului in scene standalone, descoperirea automata a entitatilor prin grupuri, separarea clara a responsabilitatilor intre componente
2. **Sisteme grafice** — planul de apa infinit, sistemul de ceata de razboi (fog-of-war), ceata de distanta, cercurile de vizibilitate, iluminarea globala
3. **Engine si mecanici** — harta procedurala cu noise, sistemul de teren, camera cu zoom si drag, conversia modelelor 3D din Blender in format Godot

Instrumentele AI, in special OpenCode(Deepseek LLM), au fost utilizate pentru accelerarea implementarii, depanarea rapida a erorilor de shader si mentinerea coerentei arhitecturale pe masura ce proiectul a evoluat.

---

## 2. Instrumente AI Utilizate

### 2.1. Claude Code — Agentul Principal de Dezvoltare

Claude Code a fost instrumentul central pe parcursul implementarii. Acesta a fost utilizat pentru:

- **Dezvoltarea sistemului Fog-of-War** — A generat si rafinat atat shader-ul de ceata (`Fog.gdshader`), cat si scriptul de coordonare (`FogOfWar.gd`) si scena standalone (`FogOfWar.tscn`). A rezolvat o problema complexa de UV mapping in shader, unde textura ViewportTexture se tilea in mod implicit, cauzand artefacte vizuale.
- **Implementarea planului de apa infinit** — A generat logica prin care plansul de apa urmareste camera pe axele X si Z, creand iluzia unui ocean infinit, in timp ce terenul ramane fix.
- **Shader-e si materiale** — A scris shader-ele pentru ceata de razboi si a configurat ceata de distanta in WorldEnvironment.
- **Generarea testelor unitare** — A creat 4 suite de teste unitare si un test de acceptanta pentru validarea sistemelor implementate.
- **Configurarea CI/CD** — A generat pipeline-ul GitHub Actions care ruleaza testele automat la fiecare push sau Pull Request.
- **Documentarea proiectului** — A generat documentatia tehnica si prezentul raport.

Un aspect remarcabil al colaborarii a fost capacitatea agentului de a intelege contextul arhitectural al proiectului si de a opera exclusiv in limitele stabilite, fara a introduce modificari neautorizate.

### 2.2. Google Gemini — Elaborarea Prompturilor

Google Gemini a fost utilizat in etapele initiale ale proiectului pentru a elabora prompturi detaliate si structurate. Aceste prompturi au continut specificatii tehnice precise privind arhitectura dorita si constrangerile de implementare.

### 2.3. GUT (Godot Unit Testing) — Framework de Testare

Biblioteca GUT v9.2.0 a fost integrata in proiect pentru a permite testarea automata a componentelor. Aceasta a necesitat o corectie de compatibilitate cu Godot 4.6.1 (shadowing-ul clasei native `Logger`).

---

## 3. Metodologia de Lucru

Implementarea a urmat o metodologie iterativa, bazata pe cicluri de feedback rapid:

1. **Proiectarea arhitecturii** — Stabilirea structurii proiectului, a relatiilor dintre componente si a conventiilor de cod
2. **Implementarea sistemelor grafice** — Dezvoltarea shader-elor si a scenelor vizuale
3. **Testarea si depanarea** — Validarea vizuala si functionala a sistemelor
4. **Documentarea** — Inregistrarea deciziilor arhitecturale si a configuratiilor

---

## 4. Arhitectura Sistemului

### 4.1. Structura Proiectului Godot

Proiectul este organizat in directorul `game/`, cu punctul de intrare `game/project.godot`. Arhitectura urmareste un model bazat pe scene standalone, fiecare componenta majora fiind incapsulata intr-o scena proprie, cu dependinte explicite si descoperire automata prin grupuri.

```
game/
  scenes/           # Scene Godot (FogOfWar, VisionCircle, Map, etc.)
  scripts/          # Scripturi GDScript (organizate pe domenii)
    match/          # Scripturi pentru modul de joc (MapGenerator, MatchPrepController)
    network/        # Client API pentru comunicarea cu backend-ul
  shaders/          # Shader-e GLSL (Fog.gdshader, etc.)
  assets/models/    # Modele 3D (WIP si finalizate)
  tests/            # Teste unitare si de acceptanta GUT
  addons/           # Plugin-uri (GUT)
```

### 4.2. Scene Standalone si Descoperire Automata

Una dintre deciziile arhitecturale fundamentale a fost separarea sistemelor in scene independente, care se auto-descopera reciproc prin grupuri Godot:

- **Sistemul Fog-of-War** (`FogOfWar.tscn`) — Scena standalone care contine propriul SubViewport, plansul de ceata, materialul si resursele de noise. Detectsaza automat terenul prin grupul `terrain` si navele prin grupul `ships`.
- **Sistemul de minimap** (`Minimap.gd`) — Scaneaza grupul `ships` pentru a afisa pozitiile navelor pe harta.
- **Sistemul de teren** (`Terrain.gd`) — Se inregistreaza automat in grupul `terrain` la initializare.
- **Sistemul de nave** (`Ship.gd`) — Se inregistreaza automat in grupul `ships` la initializare.

Aceasta abordare permite adaugarea oricarei componente intr-o scena fara a fi nevoie de conectari manuale sau exporturi de semnale intre noduri.

### 4.3. Generatorul de Harta

Clasa `MapGenerator` construieste harta runtime, combinand:

- **Un plans de apa** — Scara 2000x2000 unitati, pozitionat la Y = -2
- **Un teren procedural** — Generat pe baza unui seed, cu inaltimi calculate prin noise Perlin

Generatorul este o clasa `RefCounted` statica, care poate fi apelata atat din editor, cat si din runtime.

### 4.4. Gestiunea Memoriei si Performanta

Deciziile arhitecturale au fost ghidate de considerente de performanta:

- Plansul de ceata este fix la originea lumii, nu urmareste camera — aceasta previne drift-ul texturii de noise si reduce calculele per cadru
- Dimensiunea plansului de ceata (10000x10000) acopera toate pozitiile posibile ale camerei la zoom maxim, eliminand necesitatea re-ancorarii
- SubViewport-ul pentru masca de ceata are rezolutie configurabila (implicit 512x512), echilibrand calitatea vizuala si performanta
- Cercurile de vizibilitate sunt sprite-uri 2D in SubViewport, nu mesh-uri 3D, minimizand costul de randare

---

## 5. Sisteme Grafice Implementate

### 5.1. Planul de Apa Infinit

Unul dintre obiectivele principale a fost crearea senzatiei de lume infinita. Plansul de apa urmareste camera pe axele orizontale (X si Z), mentinand pozitia fixa pe verticala:

```gdscript
func _process(_delta: float) -> void:
    var cam_pos := _camera.global_position
    water_plane.global_position.x = cam_pos.x
    water_plane.global_position.z = cam_pos.z
    water_plane.global_position.y = -2.0
```

Aceasta tehnica creeaza iluzia unui ocean care se intinde la nesfarsit, in timp ce insulele si terenul raman in pozitii fixe. Undele si normalele apei se deplaseaza odata cu plansul, ceea ce pare natural pentru un ocean deschis.

Plansul de apa are scara 2000x2000, suficient pentru a acoperi orice pozitie a camerei fara a fi nevoie de re-ancorare frecventa.

### 5.2. Sistemul Fog-of-War

Sistemul de ceata de razboi este cea mai complexa componenta grafica implementata. Acesta functioneaza pe principiul unui SubViewport 2D care renderuieste cercuri de vizibilitate (alb) pe un fundal negru, iar rezultatul este proiectat ca textura peste lumea 3D.

**Componente:**

| Componenta | Rol |
|------------|-----|
| `FogOfWar.tscn` | Scena standalone care coordoneaza intregul sistem |
| `FogOfWar.gd` | Scriptul care gestioneaza descoperirea navelor si pozitionarea cercurilor |
| `Fog.gdshader` | Shader-ul care combina masca de ceata cu textura de noise |
| `FogPlane` | Plansul 3D peste care se aplica shader-ul de ceata |
| `SubViewport` | Buffer de randare 2D pentru masca de ceata |
| `VisionCircle.tscn` | Sprite gradient radial care reprezinta vizibilitatea unei nave |

**Shader-ul de ceata (`Fog.gdshader`):**

Shader-ul combina doua texturi principale:
- **Masca de ceata** — ViewportTexture de la SubViewport, care contine cercurile de vizibilitate. UV-ul este clampuit la intervalul [0, 1] pentru a preveni tiling-ul nedorit (problema care a cauzat artefacte in versiunile anterioare).
- **Textura de noise** — Generata procedural cu `FastNoiseLite`, configurata cu 4 octave si frecventa 0.0039. UV-ul noise-ului NU este clampuit, profitand de `repeat_enable` pentru a crea un model natural care se intinde pe intreaga harta.

Parametrii shader-ului includ:
- `fog_color` — Culoarea cetii (implicit bej deschis)
- `fog_density` — Densitatea cetii (0.51)
- `baseline_opacity` — Opacitatea de baza a cetii (0.613)
- `map_size` — Dimensiunea hartii, folosita pentru conversia coordonatelor UV
- `noise_texture` — Textura procedurala de noise
- `fog_mask` — Masca de vizibilitate de la SubViewport

**Cercurile de vizibilitate (`VisionCircle.tscn`):**

Gradientul cercurilor este configurat cu 3 puncte de oprire (stops):
- 0% — alb complet (vizibilitate deplina)
- 60% — alb complet (zona sigura)
- 100% — transparent (zona de ceata)

Aceasta configuratie asigura o tranzitie vizuala linistitoare intre zona vizibila si ceata.

### 5.3. Ceata de Distanta

Pentru a imbunatati imersiunea si a ascunde marginile lumii, a fost adaugata ceata de distanta prin nodul `WorldEnvironment`:

- **Tip:** Ceata exponentiala (`fog_enabled = true`)
- **Densitate:** 0.002
- **Culoare:** RGB(0.6, 0.72, 0.82) — o nuanta ceruita, potrivita pentru un mediu oceanic

Ceata de distanta a fost adaugata atat in scena de test `Map.tscn`, cat si in scena runtime `MatchPrep.tscn`.

### 5.4. Iluminarea Globala

Iluminarea scenei este asigurata de:

- **Lumina directionala** — Soarele principal, cu umbre activate
- **Lumina ambientala** — Setata prin WorldEnvironment, cu culoare albastra difuza pentru a se potrivi cu mediul marin
- **WorldEnvironment** — Configureaza atat ceata de distanta, cat si corectia de culoare si tonemapping-ul implicit

### 5.5. Plansul de Ceata Fix

O decizie tehnica importanta a fost pozitionarea plansului de ceata la originea lumii `(0, 50, 0)`, fara a urmari camera. Aceasta difera de abordarea plansului de apa (care urmareste camera) din urmatoarele motive:

- **Stabilitatea UV-urilor noise-ului** — Daca plansul de ceata s-ar deploda, coordonatele UV relative la nod s-ar modifica, cauzand un drift vizibil al texturii de noise
- **Acoperirea totala** — Cu dimensiunea de 10000x10000, plansul acopera toate pozitiile camerei la zoom maxim (viewport ~4000x7111 la offset maxim)
- **Simplitatea matematica** — Pozitionarea fixa simplifica calculul coordonatelor UV in shader

### 5.6. Conversia Modelelor 3D

Modelele 3D ale navelor (Cruiser, Destroyer, Corvette, Battleship) au fost convertite din formatul Blender (`.blend`) in formatele native Godot (`.glb`/`.gltf`). Aceasta conversie a fost necesara pentru:

- **Compatibilitate** — Formatele native Godot sunt optimizate pentru engine
- **Performanta** — Fișierele `.glb` sunt incarcate mai rapid decat `.blend`
- **Fiabilitate** — Elimina dependenta de Blender pentru incarcarea modelelor in runtime

Toate supraincarcarile de copii ascunse (hidden-child overrides) au fost eliminate in urma conversiei.

---

## 6. Sistemul de Teren si Harta Procesurala

### 6.1. Terenul Procesural

Terenul este generat procedural folosind algoritmul de noise Perlin (prin clasa `FastNoiseLite` a lui Godot). Clasa `Terrain.gd` extinde `MeshInstance3D` si ofera:

- **Dimensiune configurabila** — 64 pana la 2048 unitati (default 256)
- **Rezolutie configurabila** — 4 pana la 2048 subdiviziuni (default 32)
- **Baza de noise** — Seed randomizat sau specificat, cu 4 octave si frecventa ajustabila
- **Inaltime configurabila** — 4 pana la 128 unitati

Metoda `update_mesh()` reconstruieste mesh-ul pe baza parametrilor curenti, aplicand inaltimile calculate prin `get_height(x, z)` si normalele prin `get_normal(x, z)`.

Terenul este construit la runtime de catre `MapGenerator`, care instantiaza scena `Terrain.tscn`, configureaza seed-ul de noise si apeleaza `update_mesh()`.

### 6.2. Generatorul de Harta

`MapGenerator` este o clasa utilitara statica care construieste intreaga harta (apa + teren) la runtime. Aceasta este utilizata atat in scena de test `Map.tscn`, cat si in scena runtime `MatchPrep`, asigurand consistenta intre modurile de functionare.

---

## 7. Sistemul de Camera

Sistemul de camera permite:

- **Zoom** — Prin modificarea `size`-ului camerei ortografice, cu clampare la intervalul [50, 2000]
- **Drag** — Deplasarea camerei prin glisare, cu clampare la marginile hartii (± jumatatea dimensiunii)
- **Pozitionare** — Relativa la harta, cu mentinerea unghiului de vizualizare fix

Camera functioneaza in modul `PROJECTION_ORTHOGONAL`, potrivit pentru o privire de sus asupra campului de lupta.

---

## 8. Testarea Sistemelor

Pentru a asigura fiabilitatea sistemelor implementate, au fost create 5 suite de teste automate (26 de teste in total), care ruleaza atat local, cat si in pipeline-ul de integrare continua.

### 8.1. Teste Unitare (4 suite, 21 de teste)

- **`test_map_generator.gd` (8 teste)** — Validarea constructiei hartii, consistenta seed-urilor, tipurile nodurilor
- **`test_terrain.gd` (4 teste)** — Calculul inaltimii si al normalei, intervalul valorilor, consistenta si variabilitatea
- **`test_camera_math.gd` (4 teste)** — Matematica de zoom si drag, clamparea la limite
- **`test_fog_uv.gd` (5 teste)** — Formulele de coordonate UV pentru sistemul de ceata

### 8.2. Test de Acceptanta (1 suita, 5 teste)

- **`test_acceptance_fog_of_war.gd`** — Validarea integrationala a sistemului Fog-of-War: descoperirea terenului, inregistrarea navelor, pozitionarea cercurilor de vizibilitate, urmarirea miscarii, curatarea la eliminare

### 8.3. Integrare Continua

Pipeline-ul CI (`tests.yml`) ruleaza automat la fiecare push sau Pull Request:

1. **Job Godot** — Testeaza toate cele 5 suite in containerul `barichello/godot-ci:4.6` (fara GPU)
2. **Job Python** — Testeaza baza de date pe Ubuntu cu Python 3.10, 3.11 si 3.12

Toate cele 26 de teste ruleaza cu succes, atat local, cat si in CI.

---

## 9. Rezumatul Contributiilor

| Componenta | Descriere |
|------------|-----------|
| **Arhitectura sistemului** | Scene standalone, descoperire automata prin grupuri, separarea responsabilitatilor |
| **Fog-of-War** | Scena, shader, SubViewport, cercuri de vizibilitate, masca de ceata, noise procedural |
| **Plansul de apa infinit** | Urmarirea camerei pe axele orizontale, scara 2000x2000 |
| **Ceata de distanta** | Configurata prin WorldEnvironment in ambele scene (test si runtime) |
| **Teren procedural** | Generare cu FastNoiseLite, mesh reconstruibil, parametri configurabili |
| **Generator de harta** | Clasa statica pentru constructia runtime a terenului si a apei |
| **Sistem de camera** | Zoom cu clampare, drag cu limite, proiectie ortografica |
| **Modele 3D** | Conversia din Blender (.blend) in Godot (.glb/.gltf) |
| **Testare automata** | 26 de teste (unitare + acceptanta), rulabile local si in CI |
| **Integrare continua** | Pipeline GitHub Actions cu doua job-uri paralele |

---

## 10. Concluzii

Implementarea sistemelor grafice si a arhitecturii proiectului BattleFleet_Game a demonstrat importanta unei abordari bine structurate in dezvoltarea de jocuri 3D. Deciziile arhitecturale fundamentale — scene standalone cu descoperire automata, plansul de apa care urmareste camera, plansul de ceata fix — au fost validate atat prin testare automata, cat si prin functionarea corecta in runtime.

Utilizarea instrumentelor AI, in special Claude Code, a accelerat semnificativ procesul de dezvoltare, permitand:

- Generarea si rafinarea rapida a shader-elor complexe
- Rezolvarea eficienta a problemelor de UV mapping si tiling al texturilor
- Mentinerea coerentei arhitecturale pe masura ce proiectul a evoluat
- Documentarea sistematica a deciziilor tehnice si a configuratiilor

Sistemele implementate — plansul de apa infinit, fog-of-war cu noise procedural, terenul generat aleator, cercurile de vizibilitate cu gradient — contribuie la crearea unei experiente vizuale imersive, adaptate contextului marin al jocului.

Pe termen lung, arhitectura bazata pe grupuri si scene standalone permite echipei de dezvoltare sa:

- Adauge noi tipuri de nave sau obstacole fara a modifica codul existent
- Integreze sisteme noi (particule, efecte meteorologice) prin simpla inregistrare in grupuri
- Testeze fiecare componenta independent, datorita separarii clare a responsabilitatilor

---

## Anexa — Instrumente si Tehnologii Utilizate

| Instrument/Tehnologie | Rol |
|-----------------------|-----|
| Godot 4.6.1 | Engine de joc |
| GDScript | Limbaj de programare |
| GLSL (Godot Shader Language) | Shader-e grafice |
| FastNoiseLite | Generarea procedurara a terenului |
| Blender | Modelare 3D (export .glb/.gltf) |
| Claude Code | Agent AI pentru generare cod si depanare |
| Google Gemini | Elaborarea prompturilor initiale |
| GUT v9.2.0 | Framework de testare unitara |
| GitHub Actions | Platforma de integrare continua |

---

**Nota de Transparenta**

Prezentul raport a fost structurat si redactat cu ajutorul instrumentului Deepseek (agentul AI utilizat pe parcursul implementarii), pe baza unor prompturi detaliate in care autorul a descris etapele parcurse si deciziile tehnice luate. Continutul factual, experientele descrise si deciziile tehnice apartin in intregime autorului; Deepseek a avut rolul de a organiza informatiile intr-o forma coerenta si adecvata unui raport academic, fara a adauga sau modifica substanta celor comunicate.
