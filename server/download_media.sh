#!/usr/bin/env bash
# Run from repo root: bash server/download_media.sh
# Requires: curl, python3, ffmpeg
set -uo pipefail   # no -e: errores por descarga no matan el script

BASE="https://upload.wikimedia.org/wikipedia/commons"
FAILED=()
SKIPPED=()
OK=()
TOTAL=0

mkdir -p server/media/originals
mkdir -p server/media/{images,audio,video}

# ── Helpers ────────────────────────────────────────────────────────────────────

# Obtiene la URL real del archivo via API de Wikimedia Commons.
# URL-encodea el nombre para que caracteres como (, ), ' no rompan la query.
wiki_url() {
  local encoded
  encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1],safe=''))" "$1")
  curl -sf "https://commons.wikimedia.org/w/api.php?action=query&titles=File:${encoded}&prop=imageinfo&iiprop=url&format=json" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
pages = data['query']['pages']
page = list(pages.values())[0]
if 'imageinfo' not in page:
    sys.exit(1)
print(page['imageinfo'][0]['url'])
"
}

# Descarga via API, guarda original en originals/ y convertido en server/media/.
# dl WIKI_NAME OUT_NAME TYPE TARGET_EXT [FALLBACK_WIKI_NAME]
dl() {
  local wiki_name="$1"
  local out_name="$2"
  local out_type="$3"   # images | audio | video
  local target_ext="$4"
  local fallback="${5:-}"
  TOTAL=$((TOTAL + 1))

  local dest="server/media/${out_type}/${out_name}.${target_ext}"

  # Skip si el convertido ya existe y no está vacío
  if [[ -s "$dest" ]]; then
    echo "⏭  ${out_name}.${target_ext}  (ya existe)"
    SKIPPED+=("$out_name")
    return 0
  fi

  # Intentar descarga (con fallback si se especifica)
  local url=""
  for name in "$wiki_name" ${fallback:+"$fallback"}; do
    url=$(wiki_url "$name" 2>/dev/null) && break
    url=""
  done

  if [[ -z "$url" ]]; then
    echo "   ✗ FALLÓ (sin URL): $wiki_name"
    FAILED+=("$out_name")
    return 0
  fi

  local src_ext="${url##*.}"; src_ext="${src_ext%%\?*}"
  local orig="server/media/originals/${out_name}.${src_ext}"

  echo "⬇  ${out_name}.${target_ext}  ←  $(basename "$url")"
  if ! curl -Lsf --fail "$url" -o "$orig"; then
    echo "   ✗ FALLÓ (curl): $wiki_name"
    FAILED+=("$out_name")
    rm -f "$orig"
    return 0
  fi

  if [[ "$src_ext" == "$target_ext" ]]; then
    cp "$orig" "$dest"
  else
    echo "   🔄 convirtiendo ${src_ext} → ${target_ext}"
    if ! ffmpeg -y -loglevel error -i "$orig" "$dest" 2>&1; then
      echo "   ✗ FALLÓ (ffmpeg): $out_name"
      FAILED+=("$out_name")
      return 0
    fi
  fi

  OK+=("$out_name")
}

# Descarga directa (URL conocida, sin API).
dl_direct() {
  local url="$1"
  local out_name="$2"
  local out_type="$3"
  local target_ext="$4"
  TOTAL=$((TOTAL + 1))

  local src_ext="${url##*.}"; src_ext="${src_ext%%\?*}"
  local orig="server/media/originals/${out_name}.${src_ext}"
  local dest="server/media/${out_type}/${out_name}.${target_ext}"

  if [[ -s "$dest" ]]; then
    echo "⏭  ${out_name}.${target_ext}  (ya existe)"
    SKIPPED+=("$out_name")
    return 0
  fi

  echo "⬇  ${out_name}.${target_ext}  ←  direct"
  if ! curl -Lsf --fail "$url" -o "$orig"; then
    echo "   ✗ FALLÓ (curl): $(basename "$url")"
    FAILED+=("$out_name")
    rm -f "$orig"
    return 0
  fi

  if [[ "$src_ext" == "$target_ext" ]]; then
    cp "$orig" "$dest"
  else
    echo "   🔄 convirtiendo ${src_ext} → ${target_ext}"
    if ! ffmpeg -y -loglevel error -i "$orig" "$dest"; then
      echo "   ✗ FALLÓ (ffmpeg): $out_name"
      FAILED+=("$out_name")
      return 0
    fi
  fi

  OK+=("$out_name")
}

# ── Audio ──────────────────────────────────────────────────────────────────────
echo "── Audio ────────────────────────────────────────────"
dl_direct "$BASE/a/a7/Chopin%2C_Nocturne_op_32_no_1.ogg"                    arte_chopin    audio ogg
dl_direct "$BASE/e/ed/Bird_song%2C_grassy_woodlands%2C_central_Victoria.ogg" nat_birds      audio ogg
dl_direct "$BASE/2/22/Stellardrone_-_Ultra_Deep_Field.ogg"                   esp_stellardrone audio ogg

# Fixture conversión: FLAC → OGG
dl_direct "$BASE/b/b1/Hello_World_audio.flac" hello_world audio ogg

# ── Video ──────────────────────────────────────────────────────────────────────
echo "── Video ────────────────────────────────────────────"
dl_direct "$BASE/a/ab/Adelboden_%28time-lapse%29.ogv"           arte_adelboden   video ogv
dl_direct "$BASE/9/9e/Video_of_the_waterfall_of_Seythenex.ogv"  nat_waterfall    video ogv
dl_direct "$BASE/9/9f/ESO_Timelapse_Compilation.ogv"            esp_eso_timelapse video ogv

# Fixture conversión: WebM → OGV
dl_direct "$BASE/2/22/Volcano_Lava_Sample.webm" volcano_lava video ogv

# ── Imágenes — via API + ffmpeg ───────────────────────────────────────────────
echo "── Imágenes / Arte ──────────────────────────────────"
dl "Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg"                          starry_night images jpg  # ✅ verified
dl "Claude_Monet_-_Water_Lilies_-_1906,_Ryerson.jpg"                           water_lilies images jpg  # ✅ verified
dl "The_Kiss_-_Gustav_Klimt_-_Google_Cultural_Institute.jpg"                    the_kiss     images jpg  # ✅ verified
dl "1665_Girl_with_a_Pearl_Earring.jpg"                                         girl_pearl   images jpg  # ✅ verified
dl "Tsunami_by_hokusai_19th_century.jpg"                                        great_wave   images jpg  # ✅ verified
dl "Sandro_Botticelli_-_La_nascita_di_Venere_-_Google_Art_Project_-_edited.jpg" birth_venus images jpg  # ✅ verified

echo "── Imágenes / Naturaleza ────────────────────────────"
dl "Aurora_borealis_over_Eielson_Air_Force_Base,_Alaska.jpg" aurora      images jpg  # ✅ verified
dl "Gullfoss.jpg"                                             gullfoss    images jpg  # ✅ verified
dl "Coral_reef_at_palmyra.jpg"                                coral_reef  images jpg  # ✅ verified
dl "Sahara_desert.jpg"                                        sahara      images jpg  # ✅ verified
dl "Amazon_Rainforest.jpg"                                    amazon      images jpg  # ✅ verified
dl "Half_Dome_from_Glacier_Point,_Yosemite_NP_-_Diliff.jpg"  yosemite    images jpg  # ✅ verified

echo "── Imágenes / Espacio ───────────────────────────────"
dl "Pillars_of_creation_2014_HST_WFC3-UVIS_full-res_denoised.jpg" pillars     images jpg  # ✅ verified
# Los 5 siguientes fallan via API por caracteres especiales → dl_direct con URL confirmada
dl_direct "$BASE/0/00/Crab_Nebula.jpg"                              crab_nebula images jpg  # ✅ URL directa confirmada
dl_direct "$BASE/9/9e/Milky_Way_Arch.jpg"                           milky_way   images jpg  # ✅ URL directa confirmada
dl_direct "$BASE/c/c7/Saturn_during_Equinox.jpg"                    saturn      images jpg  # ✅ URL directa confirmada
dl_direct "$BASE/9/98/Andromeda_Galaxy_%28with_h-alpha%29.jpg"      andromeda   images jpg  # ✅ URL directa confirmada (paréntesis)
dl_direct "$BASE/b/bf/Webb%27s_First_Deep_Field.jpg"                jwst_deep   images jpg  # ✅ URL directa confirmada (apóstrofe)

# Fixture conversión: PNG → JPG
dl_direct "$BASE/7/73/Pale_Blue_Dot.png" pale_blue_dot images jpg

# ── Resumen ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════"
echo "✅ OK:       ${#OK[@]} / $TOTAL"
echo "⏭  Skipped: ${#SKIPPED[@]} / $TOTAL"
echo "❌ Fallos:   ${#FAILED[@]} / $TOTAL"
[[ ${#FAILED[@]} -gt 0 ]] && echo "   → ${FAILED[*]}"
echo ""
echo "server/media/originals/ → $(find server/media/originals -type f 2>/dev/null | wc -l) archivos"
echo "server/media/images/    → $(find server/media/images    -type f 2>/dev/null | wc -l) archivos"
echo "server/media/audio/     → $(find server/media/audio     -type f 2>/dev/null | wc -l) archivos"
echo "server/media/video/     → $(find server/media/video     -type f 2>/dev/null | wc -l) archivos"
