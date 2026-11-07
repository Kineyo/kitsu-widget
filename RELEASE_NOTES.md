# Notas de Lanzamiento / Release Notes: Kitsu Desktop AI & Media Suite v2.4.1

**Versión:** `v2.4.1`  
**Fecha:** Noviembre 2026  
**Arquitectura:** Híbrida Lua 5.3 + C/C++17 Nativo  
**Plataformas soportadas:** Linux (Pop!_OS, Debian/Ubuntu, Arch Linux), Windows (x64), macOS (Apple Silicon / Intel)  
**Licencia:** MIT  
**Repositorio Oficial:** [https://github.com/Kineyo/kitsu-widget](https://github.com/Kineyo/kitsu-widget)

---

## 🚀 Resumen Ejecutivo

La versión **2.4.1** de **Kitsu Desktop AI & Media Suite** consolida la transición completa a la arquitectura modular de temas, personalización estética sin ramas separadas, robustecimiento integral de seguridad en ejecución de subprocesos y un pipeline de entrega continua (CI/CD) multiplataforma en GitHub Actions.

Esta versión introduce el nuevo motor central de temas (`theme_manager.lua`), el tema temático cyber-noir inspirado en Serial Experiments Lain (*Lain // NAVI Copland OS*), el nuevo tema predeterminado *Titanium Slate (Profesional)*, conmutación en caliente entre Modo Claro y Oscuro con contraste tipográfico estricto, selector de esquinas rectas vs redondeadas, y el descargador asíncrono seguro de temas.

---

## 🌟 Novedades Principales de la Versión 2.4.1

### 1. Sistema Dinámico de Temas y Personas (`themes/`)
* **Temas Modulares sin Branches ni Forks:**
  * El widget ahora carga dinámicamente temas empaquetados en `themes/<id>/` y temas de usuario en `~/.config/kitsu/themes/<id>/`.
  * Cascada de resolución de recursos inteligente: tema activo de usuario → tema activo del sistema → tema default → recursos globales base.
* **Tema Predeterminado: Titanium Slate (Profesional):**
  * Paleta de grises neutros grafito y obsidiana, diseñada para entornos de productividad profesional sin saturación de colores.
* **Tema Temático: Lain // NAVI (Copland OS):**
  * Inspirado en la estética cyber-noir de *Serial Experiments Lain* y las interfaces Copland OS.
  * Paleta monocromática estricta en escala de grises, blanco y negro sin neones estridentes.
  * Avatar estilizado de Lain y tipografía monoespaciada/pixelada retro.
* **Plantilla para Desarrolladores (`themes/template/`):**
  * Incluye `theme.json`, `style.css` y `README.md` exhaustivamente comentados para guiar la creación y distribución de nuevos temas.
* **Descargador Asíncrono de Temas (`lib/theme_downloader.lua`):**
  * Permite descargar e instalar temas en formato `.zip` de forma transparente sin congelar la interfaz gráfica GTK3.

---

### 2. Contraste de Color y Conmutador Claro / Oscuro
* **Garantía de Alto Contraste:**
  * **Modo Oscuro:** Texto renderizado en blanco puro (`#FFFFFF`, `1.0, 1.0, 1.0`).
  * **Modo Claro:** Texto renderizado en negro puro (`#000000`, `0.0, 0.0, 0.0`).
* **Conmutación Instantánea:**
  * Botones dedicados en la pestaña de Configuración y en la barra de estado superior para alternar modos en tiempo real.
* **Compatibilidad GTK3 Limpia:**
  * Se eliminaron todas las directivas `!important` (no soportadas en GTK 3.0 CSS) y se aislaron las clases de estilo (`.chat-text`, `.chat-entry`, `.tab-btn`) para evitar colisiones visuales.

---

### 3. Geometría de Ventanas y Personalizador de Avatar
* **Selector de Esquinas Rectas vs Redondeadas:**
  * Permite a los usuarios elegir entre el diseño moderno de bordes curvos o bordes rectos (ideal para temas industriales o retro como NAVI).
* **Personalizador de Avatar 1:1 (`lib/avatar_customizer.lua`):**
  * Diálogo nativo para seleccionar cualquier imagen local, con recorte centrado automático a relación de aspecto 1:1 e interpolación bilineal de alta calidad.

---

### 4. Auditoría de Seguridad y Endurecimiento
* **Cero Rutas Absolutas Hardcoded:**
  * Se erradicaron todas las ocurrencias de rutas estáticas (`/home/alex`), resolviendo dinámicamente las rutas a través de variables de entorno y metadatos de depuración (`debug.getinfo`).
* **Eliminación de Vulnerabilidades de Inyección en Subprocesos:**
  * Se eliminó el uso de `bash -c` con interpolación de cadenas para la descarga de temas, gestión de capturas y notificaciones.
  * Toda ejecución externa utiliza ahora llamadas vectorizadas con `Gio.Subprocess.new` pasando listas de argumentos independientes.
  * Sanitización estricta por expresiones regulares en parámetros de habilidades (`app_launch.lua` y `theme_downloader.lua`).
* **Protección de Credenciales Cloud:**
  * El archivo `secrets.json` se almacena con permisos POSIX restrictivos `0600` gestionados directamente por el sistema de archivos GIO.

---

### 5. Motor de Inferencia Local Embebido y Multimedia
* **Independencia de Ollama:** `llama-server` embebido con cuantización agresiva KV cache (`q4_0`) y ventana compacta de contexto para operar estrictamente bajo el límite de **500 MB de RAM**.
* **Mini-Reproductor MPRIS2 y Karaoke LRC:** Sincronización en tiempo real de letras para Spotify y YouTube Music con desplazamiento suave.

---

## 📦 Pipeline Multiplataforma y Artefactos de Lanzamiento

El flujo automatizado de **GitHub Actions** (`.github/workflows/release.yml`) compila y empaqueta nativamente Kitsu para las siguientes plataformas:

| Plataforma | Formato de Paquete | Destino / Salida |
| :--- | :--- | :--- |
| **Debian / Ubuntu / Pop!_OS** | `.deb` nativo | `kitsu_2.4.1_amd64.deb` |
| **Linux Universal** | Tarball portable `.tar.gz` | `kitsu-2.4.1-linux-x86_64.tar.gz` |
| **Arch Linux** | Pacman package `.pkg.tar.zst` | `kitsu-2.4.1-1-x86_64.pkg.tar.zst` |
| **Windows x64** | Instalador ejecutable NSIS | `Kitsu-2.4.1-Setup-x64.exe` |
| **Windows Portable** | Archivo `.zip` portable | `kitsu-2.4.1-windows-x64.zip` |
| **macOS (Universal / Apple Silicon)** | Imagen de disco `.dmg` | `Kitsu-2.4.1-macOS.dmg` |

Cada compilación genera de forma automática sus correspondientes sumas de verificación criptográficas `SHA256SUMS.txt`.
