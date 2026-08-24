# Route data import report

Source: `docs/data/Route_Numbers_and_Stops.xlsx`
Generated: 2026-08-24 22:40

Forward routes: **104** (101 public numbers, each with an auto-generated reverse trip)
Canonical stops: **478** (27 awaiting coordinates)

## Dropped entries (owner decision)

- 222V variant 2 (41 stops, ends 'VIZIANAGARAM.') dropped per owner decision — 43-stop variant kept

## Duplicate numbers kept as independent routes

- 25E entry #2 (AMARAVATHI NAGAR -> OHPO) got route id '25E-B'
- 38R entry #2 (MADDILAPALEM -> KG PALEM) got route id '38R-B'
- 400R entry #2 (MADDILAPALEM -> KOTHAPOTNAM.) got route id '400R-B'

## Same stop name, distinct locations (split into separate stops)

- ANANDAPURAM: 2 distinct locations -> stop ids ['anandapuram', 'anandapuram_2']
- MARRIPALEM: 2 distinct locations -> stop ids ['marripalem', 'marripalem_2']
- RAVADA: 2 distinct locations -> stop ids ['ravada', 'ravada_2']
- VENKANNAPALEM: 2 distinct locations -> stop ids ['venkannapalem', 'venkannapalem_2']
- HB COLONY: 2 distinct locations -> stop ids ['hb_colony', 'hb_colony_2']

## Coordinate variance within one stop (>250 m, anchor kept)

- VUDA PARK: occurrence (17.72584, 83.33888) is 267 m from group 0 anchor (17.72384, 83.33749) — anchor kept
- V T AGRAHARAM: occurrence (18.08659, 83.38685) is 257 m from group 0 anchor (18.08883, 83.38749) — anchor kept
- THATICHETLAPALEM: occurrence (17.73551, 83.28819) is 252 m from group 0 anchor (17.73347, 83.28717) — anchor kept
- KANCHARAPALEM: occurrence (17.73540, 83.27883) is 356 m from group 0 anchor (17.73234, 83.27784) — anchor kept
- KANCHARAPALEM: occurrence (17.73540, 83.27883) is 356 m from group 0 anchor (17.73234, 83.27784) — anchor kept
- KANCHARAPALEM: occurrence (17.73540, 83.27883) is 356 m from group 0 anchor (17.73234, 83.27784) — anchor kept
- URVASI: occurrence (17.73691, 83.27119) is 252 m from group 0 anchor (17.73472, 83.27181) — anchor kept
- URVASI: occurrence (17.73691, 83.27119) is 252 m from group 0 anchor (17.73472, 83.27181) — anchor kept
- URVASI: occurrence (17.73691, 83.27119) is 252 m from group 0 anchor (17.73472, 83.27181) — anchor kept
- MVP COLONY: occurrence (17.74306, 83.33876) is 348 m from group 0 anchor (17.74082, 83.33648) — anchor kept
- ASAKAPALLI X ROAD: occurrence (17.77704, 83.11242) is 585 m from group 0 anchor (17.77222, 83.11463) — anchor kept
- AGANAMPUDI: occurrence (17.68805, 83.12515) is 1045 m from group 0 anchor (17.68875, 83.13499) — anchor kept
- NARAVA: occurrence (17.74404, 83.18251) is 394 m from group 0 anchor (17.74330, 83.18615) — anchor kept
- PM PALEM: occurrence (17.80421, 83.34545) is 703 m from group 0 anchor (17.80663, 83.33931) — anchor kept
- BHEEMILI: occurrence (17.89503, 83.44765) is 681 m from group 0 anchor (17.89186, 83.45315) — anchor kept

## Stops awaiting coordinates (name added, lat/lng = 0)

- A Kothapalli
- Achayyapalem
- Amaravathi Nagar
- Ambedkar Colony
- CBS
- Chinna Nandipalli
- Court
- Hill NO2
- Hill NO3
- Itsezroad
- Kushi Junction
- MDV Colony
- Madhavadhara
- Musidipalli
- Nagarapalem
- Narayana Hostel
- Nggos Colony
- OBS
- P N Palli Colony
- Pedda Nandipalli
- Ratnagiri Colony
- Sevanagar
- Taruva
- Thavvavanipalem
- Timiram
- VBC
- Vakapalli

## Applied spelling aliases

- ANAKAPALLI BUS DIPOT -> ANAKAPALLI BUS DEPOT
- BORAVANIPALEM -> BORRAVANIPALEM
- COVENT JN -> CONVENT JN
- DAKAMARRI -> DAKAMAARI
- GURUDWAR -> GURUDWARA
- KOMMADI JUNCTION -> KOMMADI
- KURMANPALEM -> KURMANNAPALEM
- MADDILAPLEM -> MADDILAPALEM
- OOTAGEDA -> OOTAGEDDA
- PADMANABAM -> PADMANABHAM
- PARWADA -> PARAWADA
- PENDHURTHI -> PENDURTHI
- PENDHURTHI JUNIOR COLLEGE -> PENDURTHI JUNIOR COLLEGE
- PYDAH COLLEGE COLLEGE -> PYDAH COLLEGE
- VIJAYRAMARAJU PETA -> VIJAYARAMARAJUPETA
- VIJAYRAMRAJUPETA -> VIJAYARAMARAJUPETA
