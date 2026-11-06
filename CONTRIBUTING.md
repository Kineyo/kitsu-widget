# Guía de Contribución (CONTRIBUTING)

¡Gracias por tu interés en contribuir a este proyecto! Este documento detalla las directrices de desarrollo, diseño y estándares de código para colaborar de forma ordenada y eficiente.

---

## 1. Filosofía del Proyecto y Reglas Innegociables

Antes de enviar código o abrir un Pull Request, ten en cuenta los cuatro pilares fundamentales del proyecto:

1. **Presupuesto de Memoria Estricto ($\le 500\text{ MB RAM}$):**
   - El widget y el motor local embebido (`llama.cpp`) deben operar en conjunto dentro de un límite estricto de 500 MB de RAM residente (`VmRSS`).
   - Todo nuevo código debe liberar buffers innecesarios, restaurar contextos de Cairo (`cr:save` / `cr:restore`) y realizar limpiezas periódicas de recolector de basura (`collectgarbage("step", 100)`).
2. **Política de Cero Emojis:**
   - La interfaz gráfica, los diálogos, las notificaciones y los botones **no utilizan emojis**.
   - Los elementos visuales se representan mediante tipografía limpia de alto contraste y símbolos vectoriales trazados matemáticamente con Cairo (`lib/icons.lua` y `assets/icons/`).
3. **Bucle de Interfaz Sin Bloqueos:**
   - La interfaz GTK3 no debe bloquearse bajo ninguna circunstancia. Toda petición HTTP, inferencia de modelos, escaneo de disco o comunicación IPC debe realizarse de forma asíncrona.
4. **Seguridad y Privacidad:**
   - Nunca escribas credenciales o claves de API en el código fuente ni en registros (`logs`). Los secretos se almacenan exclusivamente en `~/.config/qwen-widget/secrets.json` con permisos `0600`.

---

## 2. Preparación del Entorno de Desarrollo

### Dependencias del Sistema

#### En distribuciones basadas en Debian / Ubuntu / Pop!_OS:
```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential cmake pkg-config g++ gcc make \
    libglib2.0-dev libx11-dev libxfixes-dev libxi-dev \
    lua5.3 liblua5.3-dev lua-lgi \
    gir1.2-gtk-3.0 gir1.2-gdkpixbuf-2.0 gir1.2-pango-1.0 \
    curl python3 python3-pil
```

#### En Arch Linux / Manjaro:
```bash
sudo pacman -Syu --needed \
    base-devel cmake gcc pkgconf \
    lua53 lua53-lgi gtk3 glib2 \
    libx11 libxfixes libxi curl python-pillow
```

### Compilación Local

Clona tu bifurcación (*fork*) y compila los módulos nativos:

```bash
# 1. Configurar directorio de compilación
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release

# 2. Compilar binarios y bibliotecas compartidas
cmake --build build -j$(nproc)
```

Esto generará:
- `lib/qwen_native.so` (módulo nativo C++17 para hooks de selección y MPRIS2).
- `lib/libqwen_mmap_guard.so` (controlador de páginas mmap para `llama-server`).
- `bin/qwen-widget-bin` (lanzador binario nativo).

### Ejecución de Pruebas

Inicia la aplicación en modo desarrollo:
```bash
./run.sh
```

O verifica la sintaxis y carga de módulos Lua en la terminal:
```bash
./bin/kitsu-avatar --help
```

---

## 3. Estándares de Código

### C++17 (`src/qwen_native.cpp`, `src/qwen_runner.cpp`)
- Utiliza las características del estándar C++17 (RAII, `std::string_view`, manejo seguro de memoria).
- Valida siempre los punteros devueltos por X11 (`Display*`) y D-Bus (`GDBusConnection*`).
- Minimiza las dependencias externas a las bibliotecas base POSIX, X11 y GLib.

### C99 (`src/qwen_mmap_guard.c`)
- Debe mantenerse ultraligero y compatible con POSIX.
- Se inyecta mediante `LD_PRELOAD` en `llama-server`; no debe realizar bloqueos prolongados de hilos ni llamadas que puedan corromper el heap.

### Lua 5.3 (`lib/*.lua`)
- Declara siempre variables y funciones locales (`local`). No contamines el espacio de nombres global (`_G`).
- Encapsula llamadas a módulos externos o librerías dinámicas dentro de `pcall` para garantizar tolerancia a fallos.
- Al manipular gráficos con Cairo o pixbufs, limpia los recursos para prevenir fugas de memoria (*leaks*).

### Gestión de Imágenes y Recursos (`assets/`, `scripts/`)
- Si agregas ilustraciones maestras, guárdalas en `assets/` sin metadatos EXIF.
- Utiliza `scripts/generate_sprites.py` para regenerar sprites con supersampling y halos suavizados.
- Para cambios dinámicos de avatar en tiempo de ejecución, apóyate en `lib/avatar_customizer.lua`.

---

## 4. Guía de Commits y Mensajes

Seguimos la convención de [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` Nuevas funcionalidades (ej. `feat: agregar selector nativo de avatar en ajustes`).
- `fix:` Corrección de errores (ej. `fix: evitar desbordamiento de coordenadas al acoplar mini-reproductor`).
- `refactor:` Mejoras en la estructura del código sin cambiar comportamiento externo.
- `perf:` Optimizaciones de rendimiento o reducción de uso de RAM.
- `docs:` Actualizaciones de documentación, README o diagramas.
- `chore:` Mantenimiento de scripts de compilación, CI/CD o dependencias.

---

## 5. Proceso de Pull Requests

1. Crea una rama descriptiva para tu cambio: `git checkout -b feature/nombre-de-la-mejora`.
2. Verifica que la compilación con CMake sea exitosa y sin advertencias críticas.
3. Asegúrate de que la aplicación ejecute correctamente y no exceda los 500 MB de RAM.
4. Confirma que no se hayan introducido emojis en la interfaz gráfica.
5. Abre el Pull Request detallando los cambios introducidos, capturas de pantalla si aplica y pruebas realizadas.
