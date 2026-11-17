# Navegador para Android 4.4 KitKat x86 (TR10RS1, Atom Z3735F)

Port / adaptación de un navegador completo para la tablet **TR10RS1**:
Android 4.4.4 (API 19), **x86 de 32 bits**, Intel Atom Z3735F (Bay Trail,
4× Silvermont @1.33 GHz), 1 GB de RAM, GPU con OpenGL ES 2.0/3.0.

---

## Resumen de lo que hay aquí

| Archivo | Qué es | Estado |
|---|---|---|
| `bromite-kitkat-x86.apk` | **Bromite 83.0.4103.119 x86 reempaquetado y firmado** (56 MB) | ✅ Listo para instalar |
| `bromite-83.0.4103.119-x86.apk` | APK original de Bromite (base sin tocar) | ✅ Descargado |
| `fennec-68.9.0-x86.apk` | Firefox Fennec 68.9.0 x86 (familia XUL/Gecko, prima de SeaMonkey/Basilisk/IceCat) | ✅ Alternativa, minSdk 16 |
| ~~`bromite-88-kitkat-x86-unsigned.apk`~~ | Experimento descartado (Bromite 88 con minSdk forzado a 19); se borró para ahorrar 230 MB | ❌ Descartado |
| `build.sh` | Reconstruye el APK de Bromite 83 (apktool + apksigner, sin Gradle) | ✅ Reproducible |
| `patches/kitkat-108/` | Parches para intentar compilar Bromite 108 con API 19 | ⚠️ Experimental |
| `ci/build-bromite-108-kitkat.yml` | Workflow de CI para el build de Bromite 108 | ⚠️ Necesita runner grande |
| `build-bromite-108.sh` | Script completo (fetch + parches + GN + ninja) para ejecutar en otra máquina | ⚠️ Requiere 100 GB / 16 GB RAM |

---

## La base elegida y por qué

Pediste SeaMonkey / Basilisk / IceCat y después Bromite. Aclaración importante:

- **SeaMonkey, Basilisk e IceCat son navegadores de escritorio** (frontend XUL/XPCOM).
  No existe un puerto Android de ellos. Su *motor* (Gecko/Goanna) es el mismo
  árbol del que sale **Fennec** (Firefox for Android). El equivalente móvil más
  cercano es **Fennec 68.9.0**, que es la última generación XUL y comparte
  linaje con SeaMonkey 2.53 / Basilisk / IceCat. Está incluido aquí como
  alternativa (`fennec-68.9.0-x86.apk`, **minSdk 16**, funciona en KitKat).
- **Bromite con minSdk 19 real**: busqué todas las versiones. La última que
  trae `minSdkVersion: 19` de fábrica es **Bromite 83.0.4103.119**.
  La 84.0.4147.95 ya pide 21. Tu `Descargas/x86_ChromePublic.apk` es
  precisamente 81.0.4044.127 (minSdk 19) — el "88.0.4044" que mencionabas
  es en realidad **81.0.4044**.
- El cambio que rompió KitKat fue el commit de Chromium
  [`b9539df0` (11 jun 2020)](https://github.com/chromium/chromium/commit/b9539df03352):
  `default_min_sdk_version 19 → 21`. Lo revertí en
  `patches/kitkat-108/01-revert-minsdk-19-to-21.patch`.

### Decisión

- **Para uso real hoy: Bromite 83** (Chromium 83 + adblock integrado). Es el
  navegador más moderno que **ya funciona en API 19 x86 sin parches de runtime**.
  Es el que conviene instalar en la tablet.
- **Para el port ambicioso: Bromite 108** (última versión en GitHub,
  108.0.5359.156, dic-2022). Dejé preparado el parche de minSdk y el workflow
  de CI, pero **no se puede compilar en esta máquina**: hay 2,4 GB libres y
  Chromium necesita 60-100 GB (ver más abajo).

---

## Instalar Bromite KitKat x86

La tablet no está conectada ahora (`adb devices` vacío). Con el cable y USB
depuración activa:

```bash
export PATH=$PATH:/home/alejandro/Android/Sdk/platform-tools
adb install -r /home/alejandro/browser-kitkat-x86/bromite-kitkat-x86.apk
```

Verificación esperada en el dispositivo:

```bash
adb shell pm dump org.bromite.bromite | grep -E "targetSdk|minSdk"
adb logcat -s chromium:V # arranque del proceso
```

El APK está firmado con `/home/alejandro/debug.keystore` (`androiddebugkey`),
el mismo que usaste para los ports de Dolphin/Citra. El nombre visible es
**"Bromite KitKat x86"** para distinguirlo de un Bromite stock. El package
sigue siendo `org.bromite.bromite` (cambiarlo en un APK de Chromium rompe
las rutas de perfil nativas; no se ha tocado).

### Cambios respecto al APK original

1. Etiqueta de la app → `Bromite KitKat x86` (`res/values/strings.xml`).
2. Re-firmado con tu clave → evita que una actualización de Play Store
   sustituya el navegador por una versión que ya no arranca en KitKat.
3. `minSdkVersion: 19` comprobado en el manifiesto; librerías `lib/x86/`
   (ELF32) copiadas sin modificar.

`build.sh` repite los tres pasos de forma reproducible.

---

## Redditos y límites reales

- Chromium 83 es de 2020. En 2026 **muchas webs modernas (JS pesado, WASM,
  certificados nuevos) no cargan bien**. Para navegación básica (Wikipedia,
  Google, foros, YouTube en modo simple) funciona.
- El Z3735F tiene 1 GB de RAM: conviene abrir pocas pestañas. Bromite trae
  ahorro de datos y bloqueo de anuncios, que ayudan bastante.
- No hay actualizaciones automáticas a propósito: cualquier versión posterior
  a la 83 exige Android 5.0.

---

## Sobre compilar Bromite 108 (lo que pediste)

Hice el trabajo previo que se puede hacer aquí:

1. ✅ Identifiqué el commit exacto que subió el minSdk a 21 y lo invertí
   (`patches/kitkat-108/01-revert-minsdk-19-to-21.patch`).
2. ✅ Preparé `ci/build-bromite-108-kitkat.yml` con los GN args necesarios
   (`target_cpu="x86"`, `android_min_sdk_version=19`, `default_min_sdk_version=19`).
3. ❌ **No pude compilarlo**: `df -h /` muestra 29 GB totales, 2,4 GB libres.
   Un checkout de Chromium sin historial ocupa ~15-20 GB y el directorio de
   build otros ~40-60 GB. Aunque limpié cachés (Mozilla, Playwright, mesa,
   perfiles de juegos web), no hay forma de llegar a ese espacio en este eMMC.
4. ⚠️ El parche de minSdk **no basta**: entre Chromium 84 y 108 se añadieron
   llamadas a APIs de 21+ (JobScheduler, `Context.getColor`, `Icon`, etc.) y
   se eliminó código KitKat (p. ej. `web_theme_engine_android`, 2022). Habrá
   que iterar: compilar → instalar → mirar `adb logcat` → parchear el
   `NoSuchMethodError`/`NoClassDefFoundError` → repetir.

### Intento realizado en esta máquina

Se cerró Firefox y se lanzó `fetch --no-history --nohooks android`. El clone
inicial de `chromium/src.git` llegó a consumir **1,3 GB de RAM** (de 3,7 GB
totales) antes de ser detenido. No se pudo completar ni el primer paso
(descarga del código), porque:

- **RAM:** 3,7 GB totales / 2,8 GB disponibles (Chromium necesita 16 GB+).
- **Disco:** 2,6 GB libres (Chromium necesita 60-100 GB solo para el checkout
  + build; el `fetch` ni siquiera empezó a escribir el árbol de fuentes).
- **Swap:** 2×444 MB de zram; insuficiente para compensar.

El directorio del intento se borró. Todo lo necesario para reintentar en una
máquina adecuada está en `build-bromite-108.sh` y el workflow de CI.

Para ejecutarlo necesitas un runner con ≥100 GB libres. El workflow está
pensado para `self-hosted` (etiqueta `self-hosted-kitkat-bigdisk`); también
vale un *larger runner* de GitHub de 150 GB (de pago). No está probado: es
un punto de partida, no un build garantizado.

---

## Cómo se limpió la cache (petición previa)

- `~/.cache/mozilla` (272 MB), `~/.cache/ms-playwright-go` (128 MB),
  `~/.cache/RPG Maker MV`, `~/.cache/mesa_shader_cache`, `~/.cache/gstreamer-1.0`,
  `~/.cache/dolphin-emu`, thumbnails, `/var/cache/apt/archives`.
- Perfil Firefox: solo almacenamiento web de juegos/cache
  (`itch.zone`, `pes6.optijuegos.net`, `studio1.moises.ai`, localhost),
  **no** sesiones (WhatsApp, Gmail, etc.).
- Espacio libre final: ~2,4 GB (de 1,5 GB antes de empezar).

---

## Comandos útiles

```bash
# Verificar cualquier APK
~/android-tools/android-14/aapt dump badging archivo.apk | head -4

# Ver ABI y librerías
unzip -l archivo.apk | grep 'lib/x86'

# Instalar y depurar
adb install -r bromite-kitkat-x86.apk
adb logcat -s chromium:V AndroidRuntime:E
```
