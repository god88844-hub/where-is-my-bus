# Coordinate Review

Source of truth remains `lib/data/vizag_data.dart`.

This note consolidates the user-provided coordinate sets and the later review that split stops into:
- safe to use
- minor tuning needed
- clearly wrong / displaced

## Safe / Kept As Exact Overrides

Examples called out as good or good enough:
- `airport`
- `rk_beach`
- `vizianagaram`
- `gajuwaka`
- `anakapalli`
- `bhimili`
- `mvp_colony`
- `duvvada`
- `simhachalam`
- `rushikonda`

## Approximate Corrections Applied From Later Review

These were called out as materially wrong in the later audit, so the override map now uses the later approximate replacements:

| id | applied lat | applied lng | note |
| --- | ---: | ---: | --- |
| `arilova` | 17.7600 | 83.3200 | moved from east-central approximation |
| `gopalapatnam` | 17.7480 | 83.2180 | corrected out of east Vizag |
| `kailasagiri` | 17.7490 | 83.3420 | corrected away from sea-side drift |
| `kothavalasa` | 17.9000 | 83.1500 | corrected north-west |
| `madhurawada` | 17.8200 | 83.3500 | shifted north |
| `nad_junction` | 17.7400 | 83.2300 | corrected west corridor |
| `pendurthi` | 17.8330 | 83.2000 | corrected north-west |
| `rtc_complex` | 17.7260 | 83.3010 | small north-east correction |
| `scindia` | 17.6900 | 83.2700 | corrected industrial corridor |
| `steel_plant` | 17.6400 | 83.1700 | moved toward plant interior |

## Aliases Kept

These remain duplicated intentionally as aliases, not as conflicting separate places:
- `mvp_colony` and `mvp_complex`
- `sagar_nagar` and `sagarnagar`

## Remaining Risk

The latest user review still indicates some entries remain approximate rather than surveyed stop pins.
This dataset is suitable for MVP route snapping and ETA work, but not yet for map-grade stop placement without another validation pass.
