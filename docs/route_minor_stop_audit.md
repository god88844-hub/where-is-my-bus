# Vizag Route Minor Stop Audit

Date: 2026-04-25

## APSRTC verification status

- Confirmed from APSRTC's official backend service documents:
  - `01012026_9130_2_MADDILAPALEM` (`RTCCP-DVP`, `RTC COMPLEX VSP -> DEVARAPALLE`) with `32` waypoint ids
  - `01012026_9130_3_MADDILAPALEM` (`DVP-RTCCP`, `DEVARAPALLE -> RTC COMPLEX VSP`) with `32` waypoint ids
  - `01012026_A009_11_MADDILAPALEM` (`ADP-RTCCP`, `ANANDAPURAM -> RTC COMPLEX VSP`) with `24` waypoint ids
  - `01012026_B011_10_SIMHACHALAM` (`SML-RTCCP`, `SIMHACHALAM -> RTC COMPLEX VSP`) with `10` waypoint ids
  - `01022026_YRD1_10_GAJUWAKA` (`OGWK-RKBH`, `OLD GAJUWAKA -> R.K.BEACH`) with `17` waypoint ids

- Not available from APSRTC on 2026-04-25:
  - exact waypoint names from `/servicewaypointdetails/bydocid`
  - exact place-id to place-name mapping from `/mappedplaces/fetchAllUniquePlaces`

- Current blocker:
  - APSRTC's customer API kept returning `E5000: Sorry, server is too busy.`
  - APSRTC's ETA host kept returning `502 Bad Gateway`
  - because of that, the audit below treats APSRTC as the official source for route existence and waypoint counts, but not yet for every minor-stop name

## Ready now

### 10K

Local status: done locally with OSM enrichment in both directions.

Default major-stop view:
- `RTC Complex -> Jagadamba Centre -> RK Beach -> VUDA Park -> Tenneti Park -> Kailasagiri`

Clean stop list:
- `RTC Complex -> Jagadamba Centre -> KGH Out Gate -> KGH In Gate -> RK Beach -> Appughar Bus Stop -> VUDA Park -> Tenneti Park -> Kailasagiri`

Still needed:
- APSRTC route-doc match for this exact corridor
- coordinate spot-check for `KGH Out Gate`, `KGH In Gate`, `Appughar Bus Stop`

### 12D

Local status: done locally in both directions after reverse enrichment fix.

APSRTC corridor confirmation:
- `RTC COMPLEX VSP -> DEVARAPALLE` and `DEVARAPALLE -> RTC COMPLEX VSP`
- official waypoint count: `32` each direction

Forward default major-stop view:
- `RTC Complex -> NAD Junction -> Gopalapatnam -> Pendurthi -> Kothavalasa -> Anandapuram -> Devarapalli`

Forward grouped stop list:
- `RTC Complex`: `Railway Station`, `Kancharapalem`, `Urvasi`, `Estate`, `104 Area`, `Marripalem`, `Karasa`
- `NAD Junction`: `Baji Junction`, `Simhachalam Railway Station`
- `Gopalapatnam`: `Naidu Thota`, `Vepagunta`, `Purushotapuram`, `Sujatha Nagar`, `Chinnamushidivada`, `Pendurti College`
- `Pendurthi`: `Saripalli`, `Chintalapalem`, `Desapatrunipalem`, `Mangalapalem`, `Kothavalasa Railway Station`
- `Kothavalasa`: `Tummikapalli`, `Dasaravanipalem`, `Viyyampeta`, `Devada`, `Musiram`, `Lankavanipalem`, `Kummapalli`, `Koruvada`
- `Anandapuram`: `Jammadevi Peta`, `Nallabilli`, `Vavilapadu Junction`, `Kasipuram`
- `Devarapalli`

Reverse default major-stop view:
- `Devarapalli -> Kothavalasa -> Pendurthi -> NAD Junction -> Railway Station -> RTC Complex`

Reverse grouped stop list:
- `Devarapalli`: `Kasipuram`, `Vavilapadu Junction`, `Nallabilli`, `Jammadevi Peta`, `Anandapuram`, `Koruvada`, `Kummapalli`, `Lankavanipalem`, `Musiram`, `Devada`, `Viyyampeta`, `Dasaravanipalem`, `Tummikapalli`
- `Kothavalasa`: `Kothavalasa Railway Station`, `Mangalapalem`, `Desapatrunipalem`, `Chintalapalem`, `Saripalli`
- `Pendurthi`: `Pendurti College`, `Chinnamushidivada`, `Sujatha Nagar`, `Purushotapuram`, `Vepagunta`, `Naidu Thota`, `Gopalapatnam`, `Simhachalam Railway Station`, `Baji Junction`
- `NAD Junction`: `Karasa`, `Marripalem`, `104 Area`, `Estate`, `Urvasi`, `Kancharapalem`
- `Railway Station`
- `RTC Complex`

Still needed:
- exact APSRTC waypoint-name reconciliation once their stop endpoint is back
- coordinate validation for the inserted minor-stop chain on both directions

### 28K

Local status: done locally for first-pass minor-stop coverage; major-stop view was expanded in this pass so it no longer collapses to just origin and terminus.

Default major-stop view:
- `RK Beach -> Jagadamba Centre -> RTC Complex -> NAD Junction -> Gopalapatnam -> Pendurthi -> Kothavalasa`

Grouped stop list:
- `RK Beach`: `Collector Office`
- `Jagadamba Centre`
- `RTC Complex`: `Railway Station`, `Convent Junction`, `Gnanapuram`, `Urvasi`, `Kancharapalem`, `Estate`, `104 Area`, `Marripalem`, `Karasa`
- `NAD Junction`: `Baji Junction`, `Simhachalam Railway Station`
- `Gopalapatnam`: `Gopalapatnam/Bunk`, `Naidu Thota`, `Vepagunta`, `Purushotapuram`, `Sujatha Nagar`, `Chinnamushidivada`, `Pendurti College`
- `Pendurthi`: `Saripalli`, `Chintalapalem`, `Desapatrunipalem`, `Mangalapalem`, `Kothavalasa Railway Station`, `Kothavalasa Junction`
- `Kothavalasa`

Still needed:
- official APSRTC corridor/doc match for the exact `28K` service
- coordinate validation for the long middle section between `RTC Complex` and `Kothavalasa`

### 222 / 222R

Local status: promoted locally from the exported OSM `222R` relation in this pass. This is now the best current local corridor match for APSRTC `A009-11` between `RTC Complex` and `Anandapuram`, but the exact APSRTC public route-number / endpoint match is still not confirmed.

Default major-stop view:
- `Railway Station -> RTC Complex -> MVP Colony -> Hanumanthawaka -> Madhurawada -> Anandapuram -> Tagarapuvalasa`

Clean stop list:
- `Railway Station -> RTC Complex -> Rama Talkies -> MVP Colony -> Venkojipalem -> Hanumanthawaka -> Old Dairy Farm -> Vizag Zoo -> Endada -> Carshed / IT Park -> Madhurawada -> Kommadi -> Marikavalasa -> Boravanipalem -> Paradesipalem -> Boyapalem -> Pyda Engineering College -> Bheemili X Road -> Anandapuram -> Peddipalem -> Tallavalasa -> Tagarapuvalasa`

Still needed:
- exact APSRTC confirmation that `A009-11` truncates at `RTC Complex` instead of continuing to `Railway Station` / `Tagarapuvalasa`
- exact APSRTC waypoint-name reconciliation once `/servicewaypointdetails/bydocid` comes back

## Manual next-pass checklists

### B011 / Simhachalam -> RTC Complex

Best current local corridor match:
- `sml-6a` / `6A`: `Simhachalam -> Srinivanagar -> Gopalapatnam -> NAD Junction -> Marripalem -> Industrial Estate -> Kancharapalem -> Convent Junction -> Railway Station -> RTC Complex`

Still needed:
- decide whether APSRTC `B011-10` maps to the public `6A` family or another Simhachalam branch
- confirm whether `Railway Station` is a real intermediate stop or only a local naming split near `RTC Complex`

### YRD1 / Old Gajuwaka -> RK Beach

Best current manual stitch candidate:
- `Old Gajuwaka -> Gajuwaka -> Scindia -> Convent Junction -> Town Kotha Road -> Jagadamba -> RK Beach`

Closest local source families:
- `gwk-400` / `gwk-99` for the `Old Gajuwaka -> port-side / Scindia` half
- `1T` / `99` for the `Scindia -> Jagadamba -> RK Beach` half

Still needed:
- one exact public route-family match before this can be promoted into the app
- manual coordinate checks for the stitched `Old Gajuwaka -> RK Beach` chain

## Not done yet

- Exact APSRTC minor-stop verification is still blocked by APSRTC server errors.
- `A009-11` (`ANANDAPURAM -> RTC COMPLEX VSP`, `24` official waypoint ids) is now corridor-matched locally to the `222` / `222R` family, but the exact APSRTC public route-number / endpoint match is still not confirmed.
- `YRD1` (`OLD GAJUWAKA -> R.K.BEACH`, `17` official waypoint ids) still does not have one clean exact local route-family match.
- `B011` (`SIMHACHALAM -> RTC COMPLEX VSP`, `10` official waypoint ids) is corridor-matched locally to the `6A` / `sml-6a` family, but not yet fully route-number-matched from APSRTC.
- More long routes still need manual major-stop curation so the default journey view stays useful after the new major-stops-first UI change.

## Local helper

Use this to inspect the app's current final route shape after OSM/manual enrichment:

```bash
dart run tool/route_audit.dart 10K 12D 28K 400 6A
```
