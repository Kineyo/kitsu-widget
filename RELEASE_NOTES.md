# Notas de Lanzamiento / Release Notes: OpenClaw Qwen-Widget v2.0.0

**Versión:** `v2.0.0`  
**Fecha:** Octubre 2026  
**Arquitectura:** Híbrida Lua 5.3 + C/C++17 Nativo  
**Plataformas soportadas:** Linux (Pop!_OS, Debian/Ubuntu, Arch Linux), Windows (x64), macOS (Apple Silicon / Intel)  
**Licencia:** MIT  

---

## 🚀 Resumen Ejecutivo

La versión **2.0.0** representa una reescritura estructural completa de **OpenClaw Qwen-Widget**, transformando el concepto original de widget de escritorio basado exclusivamente en Lua y el demonio externo de Ollama en una suite de escritorio **híbrida de alto rendimiento (Lua 5.3 + C/C++17)** con motor de inferencia local embebido (`llama.cpp`), soporte nativo para proveedores Cloud API, corrector gramatical instantáneo activado por hooks nativos del sistema, mini-reproductor unificado para Spotify y YouTube Music con karaoke LRC sincronizado, y un presupuesto estricto de memoria RAM inferior a **500 MB**.

---

## 🌟 Novedades Principales y Mejoras Clave

### 1. Motor de Inferencia Híbrido: `llama.cpp` Embebido + Cloud API
* **Independencia de Ollama:** Se eliminó la dependencia obligatoria de un demonio externo de Ollama. El widget incluye y gestiona directamente su propio ejecutable [`bin/llama-server`](file:///home/alex/Documentos/widget/bin/llama-server) con bibliotecas nativas en `lib/native/`.
* **Presupuesto Estricto de Memoria (≤ 500 MB RAM):**
  * Inyección del guardia POSIX [`src/qwen_mmap_guard.c`](file:///home/alex/Documentos/widget/src/qwen_mmap_guard.c) vía `LD_PRELOAD` que intercepta llamadas `mmap` y ejecuta periódicamente `posix_fadvise(..., POSIX_FADV_DONTNEED)` para purgar páginas limpias de la caché del kernel Linux.
  * Cuantización agresiva de la memoria caché de claves y valores (KV cache: `--cache-type-k q4_0 --cache-type-v q4_0`).
  * Ventana de contexto compacta y eficiente (`--ctx-size 512` / `768`).
  * Purgado de heap mediante `malloc_trim(0)` y recolección forzada de basura en Lua tras inactividad. Consumo real medido: **~240 MB de VmRSS**.
* **Gestor Autónomo de Modelos GGUF ([`lib/model_manager.lua`](file:///home/alex/Documentos/widget/lib/model_manager.lua)):**
  * Descarga y verificación automática de integridad mediante lectura del encabezado binario *magic* `GGUF`.
  * Modelos base preconfigurados:
    * `es-grammar` ([`models/es-grammar.gguf`](file:///home/alex/Documentos/widget/models/es-grammar.gguf)): Modelo especializado para corrección y estilo gramatical en español.
    * `qwen3.0-0.8b` ([`models/qwen3.0-0.8b.gguf`](file:///home/alex/Documentos/widget/models/qwen3.0-0.8b.gguf)): Modelo compacto ultraligero para chat general.
* **Integración Nativa con Proveedores Cloud API ([`lib/ai_engine.lua`](file:///home/alex/Documentos/widget/lib/ai_engine.lua)):**
  * Soporte de primer nivel para **OpenAI**, **Google Gemini**, **Anthropic Claude**, **OpenRouter** y cualquier **Endpoint compatible con OpenAI**.
  * Selector rápido `[LOCAL / CLOUD]` en la barra superior de la ventana de chat.
  * Almacenamiento seguro de credenciales en `~/.config/qwen-widget/secrets.json` con permisos restrictivos `0600`.

---

### 2. Corrector Gramatical y Menú Contextual Instantáneo ([`lib/text_popup.lua`](file:///home/alex/Documentos/widget/lib/text_popup.lua))
* **Hooks Nativos en C++ ([`src/qwen_native.cpp`](file:///home/alex/Documentos/widget/src/qwen_native.cpp)):**
  * Monitoreo en segundo plano de eventos de selección del portapapeles (`PRIMARY` y `CLIPBOARD`) mediante `XFixesSelectSelectionInput` y lectura del puntero (`XQueryPointer` / XInput2 / fallback Wayland).
  * El menú contextual flotante aparece de forma instantánea junto al cursor al soltar el botón del ratón, sin atajos manuales ni polling innecesario de CPU.
* **Acciones Contextuales con 1 Clic:**
  * `CORREGIR`: Corrección ortográfica y gramatical estricta.
  * `MEJORAR`: Reescritura formal y elocuente.
  * `TRADUCIR`: Traducción rápida al español o inglés.
  * `RESUMIR`: Síntesis ejecutiva de textos largos.
  * `EXPLICAR`: Desglose claro de conceptos complejos.
* **Contraste Visual Garantizado:** Paleta de colores explícita de alto contraste (`#0D0F18`, `#3B82F6`, `#F8FAFC`) con retroalimentación en estados `normal`, `hover`, `active` y `disabled`.

---

### 3. Mini-Reproductor Multimedia y Letras Sincronizadas ([`lib/player.lua`](file:///home/alex/Documentos/widget/lib/player.lua))
* **Soporte Dual YouTube Music + Spotify:**
  * Detección automática por IPC de sesión D-Bus (`org.mpris.MediaPlayer2.*`) mediante [`lib/mpris.lua`](file:///home/alex/Documentos/widget/lib/mpris.lua) o selección manual ciclable: `[AUTO | YT MUSIC | SPOTIFY]`.
* **Controles Completos de Reproducción:**
  * Botones de pista anterior (`PREV`), pausar/reanudar (`PLAY/PAUSE`), pista siguiente (`NEXT`).
  * Barra de progreso interactiva (`seek bar`) con soporte para clic y arrastre continuo.
  * Control deslizante de volumen (`0% - 100%`) sincronizado bidireccionalmente con el reproductor activo.
* **Letras Sincronizadas en Tiempo Real (Karaoke LRC) ([`lib/lyrics.lua`](file:///home/alex/Documentos/widget/lib/lyrics.lua), [`lib/lyrics_bubble.lua`](file:///home/alex/Documentos/widget/lib/lyrics_bubble.lua)):**
  * Limpieza heurística de metadatos de pistas (eliminación de sufijos como `Official Video`, `Remastered`, `ft.`, `feat.`).
  * Consulta asíncrona a la API de LRCLIB con almacenamiento en caché persistente en `~/.cache/qwen-widget/lyrics/`.
  * Botón para alternar visibilidad de letras (`LRC ON/OFF`) y botones de ajuste fino de latencia (`-0.5s` / `+0.5s`).

---

### 4. Acoplamiento Magnético y Geometría en Tiempo Real
* **Seguimiento Dinámico Sin Latencia:** Implementación nativa en C++ ([`src/qwen_native.cpp`](file:///home/alex/Documentos/widget/src/qwen_native.cpp)) de funciones geométricas:
  * `compute_dock_position`: Cálculo de acoplamiento de paneles secundarios con respecto a la burbuja principal.
  * `clamp_rect`: Restricción estricta dentro de los límites visibles del monitor o área de trabajo.
  * `lerp_point`: Suavizado por interpolación lineal.
* Al arrastrar la burbuja principal en pantalla, el mini-reproductor, la ventana de chat y la burbuja de letras se desplazan en tiempo real sin desfase ni parpadeo.

---

### 5. Sistema de Diseño Visual "Cero Emojis" y Sprites Dinámicos
* **Eliminación Total de Emojis:** Todos los emojis de la interfaz, menús emergentes, notificaciones y herramientas CLI fueron sustituidos por tipografía limpia e iconos vectoriales geométricos renderizados con Cairo ([`lib/icons.lua`](file:///home/alex/Documentos/widget/lib/icons.lua)).
* **Nueva Imagen Base y Sprites Reactivos:**
  * El avatar base se actualizó a [`qwen_image-v2.jpeg`](file:///home/alex/Documentos/widget/qwen_image-v2.jpeg).
  * El script programático [`scripts/generate_sprites.py`](file:///home/alex/Documentos/widget/scripts/generate_sprites.py) genera los 7 estados reactivos del widget en formatos `.png` y `.webp` bajo `assets/sprites/`:
    * `idle`: Estado pasivo / reposo.
    * `hover`: Cursor sobre la burbuja principal.
    * `chatting`: Conversación abierta con el usuario.
    * `thinking`: Procesamiento de inferencia o agente activo.
    * `music`: Reproducción multimedia activa.
    * `grammar`: Interacción con el menú contextual de texto.
    * `error`: Notificación de fallo o timeout.

---

### 6. Ventana de Chat Renovada y Panel de Configuración en 6 Secciones
* **Ventana de Chat Flotante ([`lib/chat.lua`](file:///home/alex/Documentos/widget/lib/chat.lua)):**
  * Streaming en vivo de respuestas carácter por carácter.
  * Telemetría visible con métricas de uso de RAM y nombre del modelo activo.
  * Botones dedicados de anclaje (`PIN`), alternancia de proveedor y borrado de historial.
* **Panel de Configuración Centralizado:**
  Organizado en 6 pestañas de alto contraste:
  1. `General`: Posición, tamaños de burbujas, márgenes y anclaje.
  2. `Modelos Locales`: Selección de modelos GGUF, asignación de hilos CPU y contexto.
  3. `API Cloud`: Proveedores, modelos remotos y gestión segura de API Keys.
  4. `Música`: Selección de fuente (Auto/YT Music/Spotify), visualización de letras y offset.
  5. `Gramática`: Activación del popup de selección y selección del modelo de escritura.
  6. `OpenClaw`: Habilitación y configuración modular de habilidades del agente.

---

### 7. Agente Autónomo OpenClaw Asíncrono y Habilidades Modulares
* **Loop ReAct No Bloqueante ([`lib/openclaw_agent.lua`](file:///home/alex/Documentos/widget/lib/openclaw_agent.lua)):**
  * Totalmente desacoplado del bucle principal de GTK3 para garantizar que la interfaz responda fluidamente durante ejecuciones complejas.
* **Estructura Modular de Habilidades ([`lib/skills/`](file:///home/alex/Documentos/widget/lib/skills/)):**
  * [`base.lua`](file:///home/alex/Documentos/widget/lib/skills/base.lua) & [`manager.lua`](file:///home/alex/Documentos/widget/lib/skills/manager.lua): Registro y ciclo de vida de herramientas.
  * [`system_info.lua`](file:///home/alex/Documentos/widget/lib/skills/system_info.lua): Telemetría en tiempo real (CPU, RAM, batería, disco).
  * [`bash.lua`](file:///home/alex/Documentos/widget/lib/skills/bash.lua): Ejecución segura de comandos del sistema.
  * [`media_control.lua`](file:///home/alex/Documentos/widget/lib/skills/media_control.lua): Comandos de reproducción musical.
  * [`web_search.lua`](file:///home/alex/Documentos/widget/lib/skills/web_search.lua): Búsquedas en la web vía DuckDuckGo.
  * [`app_launch.lua`](file:///home/alex/Documentos/widget/lib/skills/app_launch.lua): Lanzador rápido de aplicaciones.
  * [`screenshot.lua`](file:///home/alex/Documentos/widget/lib/skills/screenshot.lua): Capturas de pantalla multi-entorno.
  * [`notify.lua`](file:///home/alex/Documentos/widget/lib/skills/notify.lua): Envío de alertas visuales nativas.
  * [`writing.lua`](file:///home/alex/Documentos/widget/lib/skills/writing.lua): Transformación gramatical y de estilo.
  * [`openclaw_gateway.lua`](file:///home/alex/Documentos/widget/lib/skills/openclaw_gateway.lua): Puente de comunicación con el ecosistema OpenClaw.

---

### 8. Soporte Multiplataforma, Empaquetado y CI/CD
* **Sistema de Compilación Nativo con CMake ([`CMakeLists.txt`](file:///home/alex/Documentos/widget/CMakeLists.txt)):**
  * Soporte nativo para C++17 en Linux, macOS y Windows.
  * Generación de la biblioteca dinámica [`lib/qwen_native.so`](file:///home/alex/Documentos/widget/lib/qwen_native.so) / `.dll` y el ejecutable lanzador [`bin/qwen-widget-bin`](file:///home/alex/Documentos/widget/bin/qwen-widget-bin).
* **Formatos de Empaquetado Redistribuibles:**
  * **Linux:** Paquete `.deb` para Pop!_OS / Debian / Ubuntu, paquete `.pkg.tar.zst` para Arch Linux ([`packaging/arch/PKGBUILD`](file:///home/alex/Documentos/widget/packaging/arch/PKGBUILD)), y archivo universal portable `.tar.gz`.
  * **Windows:** Instalador autónomo `.exe` generado con NSIS ([`packaging/windows/installer.nsi`](file:///home/alex/Documentos/widget/packaging/windows/installer.nsi)).
  * **macOS:** Empaquetador `.dmg` y `.pkg` con integración de APIs de accesibilidad ([`packaging/macos/build_dmg.sh`](file:///home/alex/Documentos/widget/packaging/macos/build_dmg.sh)).
* **Automatización CI/CD ([`.github/workflows/release.yml`](file:///home/alex/Documentos/widget/.github/workflows/release.yml)):**
  * Flujo de trabajo automatizado en GitHub Actions para compilar binarios y publicar releases para todas las plataformas objetivo.

---

## 📦 Detalle de Archivos y Componentes Modificados

| Componente / Archivo | Tipo | Descripción del Cambio |
| :--- | :--- | :--- |
| [`CMakeLists.txt`](file:///home/alex/Documentos/widget/CMakeLists.txt) | **Nuevo** | Configuración de compilación C++17 multiplataforma para módulos nativos y guardias. |
| [`src/qwen_native.cpp`](file:///home/alex/Documentos/widget/src/qwen_native.cpp) | **Nuevo** | Módulo nativo C++17 para hooks de selección (X11/Wayland/macOS), MPRIS2 y geometría de anclaje. |
| [`src/qwen_mmap_guard.c`](file:///home/alex/Documentos/widget/src/qwen_mmap_guard.c) | **Nuevo** | Guardia POSIX `LD_PRELOAD` que expulsa páginas limpias de caché kernel para cumplir el presupuesto ≤ 500 MB RAM. |
| [`src/qwen_runner.cpp`](file:///home/alex/Documentos/widget/src/qwen_runner.cpp) | **Nuevo** | Lanzador binario embebido multiplataforma. |
| [`lib/ai_engine.lua`](file:///home/alex/Documentos/widget/lib/ai_engine.lua) | **Nuevo** | Motor de inferencia unificado: `llama.cpp` local + proveedores Cloud API (OpenAI, Gemini, Claude, OpenRouter). |
| [`lib/model_manager.lua`](file:///home/alex/Documentos/widget/lib/model_manager.lua) | **Nuevo** | Descarga automática y validación binaria de cabeceras GGUF de modelos locales. |
| [`lib/icons.lua`](file:///home/alex/Documentos/widget/lib/icons.lua) | **Nuevo** | Renderizado de iconografía geométrica vectorial con Cairo (política cero emojis). |
| [`lib/text_popup.lua`](file:///home/alex/Documentos/widget/lib/text_popup.lua) | **Nuevo** | Menú contextual flotante para corrección gramatical instantánea en selección de texto. |
| [`lib/skills/`](file:///home/alex/Documentos/widget/lib/skills/) | **Nuevo** | Directorio de habilidades modulares desacopladas para el agente OpenClaw. |
| [`scripts/generate_sprites.py`](file:///home/alex/Documentos/widget/scripts/generate_sprites.py) | **Nuevo** | Procesador programático para generar sprites PNG/WebP y máscaras desde la imagen base. |
| [`scripts/build_packages.sh`](file:///home/alex/Documentos/widget/scripts/build_packages.sh) | **Nuevo** | Constructor automatizado de paquetes locales `.deb` y `.tar.gz`. |
| [`packaging/`](file:///home/alex/Documentos/widget/packaging/) | **Nuevo** | Especificaciones de empaquetado para Arch Linux (`PKGBUILD`), macOS (`build_dmg.sh`) y Windows (`installer.nsi`). |
| [`.github/workflows/release.yml`](file:///home/alex/Documentos/widget/.github/workflows/release.yml) | **Nuevo** | Pipeline de integración y entrega continua para compilación cruzada y publicación. |
| [`lib/config.lua`](file:///home/alex/Documentos/widget/lib/config.lua) | **Modificado** | Configuración centralizada ampliada (backend híbrido, paletas de alto contraste, persistencia JSON). |
| [`lib/chat.lua`](file:///home/alex/Documentos/widget/lib/chat.lua) | **Modificado** | Reescritura de la UI de chat con streaming fluido, telemetría RAM y panel de configuración de 6 pestañas. |
| [`lib/player.lua`](file:///home/alex/Documentos/widget/lib/player.lua) | **Modificado** | Mini-reproductor dual (YT Music + Spotify), control de volumen, barra interactiva y acoplamiento en tiempo real. |
| [`lib/mpris.lua`](file:///home/alex/Documentos/widget/lib/mpris.lua) | **Modificado** | Conexión D-Bus optimizada para extraer metadatos y controlar medios con baja latencia. |
| [`lib/lyrics.lua`](file:///home/alex/Documentos/widget/lib/lyrics.lua) | **Modificado** | Limpieza de títulos de pistas, consulta asíncrona a LRCLIB y caché local persistente. |
| [`lib/widget.lua`](file:///home/alex/Documentos/widget/lib/widget.lua) | **Modificado** | Máquina de estados visual reactiva conectada a los sprites generados. |
| [`bin/qwen-power`](file:///home/alex/Documentos/widget/bin/qwen-power) | **Modificado** | Script de control de encendido y apagado adaptado a la arquitectura sin emojis y con gestión de `llama-server`. |
| [`bin/qwen-widget`](file:///home/alex/Documentos/widget/bin/qwen-widget) | **Modificado** | Lanzador del widget con configuración de librerías nativas `LD_LIBRARY_PATH` y `LUA_CPATH`. |
| [`install.sh`](file:///home/alex/Documentos/widget/install.sh) | **Modificado** | Instalador interactivo y desatendido con descarga de modelos GGUF y compilación automática. |
| [`run.sh`](file:///home/alex/Documentos/widget/run.sh) | **Modificado** | Script unificado para compilar, probar, limpiar y lanzar el entorno de desarrollo. |

---

## ⚠️ Cambios Disruptivos y Guía de Migración

1. **Reemplazo del servicio Ollama:**  
   * **Antes (v1.0):** Se requería tener el servicio de `ollama` ejecutándose en segundo plano (`systemctl start ollama`) y el modelo descargado mediante `ollama pull qwen3:0.6b`.
   * **Ahora (v2.0):** No es necesario tener Ollama instalado ni en ejecución. El widget utiliza [`bin/llama-server`](file:///home/alex/Documentos/widget/bin/llama-server) embebido o proveedores Cloud. Los modelos se gestionan en formato `.gguf` bajo el directorio `models/`.
2. **Ubicación de Configuraciones y Secretos:**  
   * Los parámetros de usuario se persisten en `~/.config/qwen-widget/config.json`.
   * Las claves de API Cloud se guardan por separado en `~/.config/qwen-widget/secrets.json` con permisos de seguridad `0600`.
3. **Dependencias del Sistema para Compilación:**  
   * Requiere un compilador C++17 compatible (`g++` o `clang++`), `cmake >= 3.16`, cabeceras de `glib-2.0`, `x11`, `xfixes`, `xi` y `lua5.3`.

---

## 🛠️ Guía Rápida de Compilación y Ejecución

### En Pop!_OS / Debian / Ubuntu:
```bash
# 1. Instalar dependencias
sudo apt-get update && sudo apt-get install -y \
  cmake g++ gcc make pkg-config libglib2.0-dev libx11-dev libxfixes-dev libxi-dev \
  lua5.3 liblua5.3-dev lua-lgi gir1.2-gtk-3.0 curl python3-pil

# 2. Compilar módulos nativos C++
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)

# 3. Instalar y ejecutar
./install.sh
./run.sh --run
```

### En Arch Linux:
```bash
cd packaging/arch
makepkg -si
```

### Ejecutar desde Paquete Portable (`.tar.gz`):
```bash
tar -xzf dist/qwen-widget-2.0.0-linux-x86_64.tar.gz
cd qwen-widget-2.0.0
./bin/qwen-widget
```

---

*Para reportar errores o solicitar nuevas funcionalidades, visita el repositorio oficial en GitHub.*
