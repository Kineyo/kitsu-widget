# Guía de Creación de Temas para Kitsu Desktop AI

Esta carpeta sirve como plantilla y documentación completa para crear versiones temáticas del widget sin necesidad de bifurcar el código (*forks*) ni crear ramas de Git.

---

## 1. Estructura de un Paquete de Tema

Cada tema se almacena en su propia carpeta (en `themes/<id>/` o en `~/.config/kitsu/themes/<id>/`):

```text
mi_tema/
├── theme.json          # (Obligatorio) Metadatos, paleta Cairo, geometría y personalidad
├── style.css           # (Opcional) Sobrescrituras de estilo GTK 3.0
└── assets/             # (Opcional) Recursos gráficos personalizados
    ├── avatar.png      # Avatar principal del widget (512x512 PNG)
    ├── icon.png        # Icono de aplicación y ventana
    └── sprites/        # Sprites reactivos de estados (PNG / WEBP)
        ├── idle.png       # Estado de reposo
        ├── hover.png      # Cursor sobre el widget
        ├── chatting.png   # Panel de chat abierto o hablando
        ├── thinking.png   # Inferencia de IA en progreso
        ├── music.png      # Reproductor reproduciendo música
        ├── grammar.png    # Menú de corrección ortográfica activo
        └── error.png      # Fallo de conexión o proceso
```

> [!NOTE]
> **Cascada de Fallback Automática:** No es obligatorio incluir todos los sprites. Si tu tema solo incluye `avatar.png` e `idle.png`, el widget tomará los sprites restantes automáticamente del tema base.

---

## 2. Explicación de Campos en `theme.json`

### `palette` (Colores vectoriales en Cairo RGBA)
Los colores se expresan como vectores `{ R, G, B, Alpha }` con valores de `0.0` a `1.0`:
- **`BG`**: Fondo del círculo flotante del widget (`[0.086, 0.090, 0.098, 0.96]`).
- **`BG_CHAT`**: Fondo de la ventana flotante de chat.
- **`BG_DBUBBLE`**: Fondo de las burbujas de datos dinámicas (clima, crypto, etc.).
- **`TEXT`**: Color primario para texto de alto contraste.
- **`TEXT_DIM`**: Color secundario para subtítulos, etiquetas y marcas temporales.
- **`ACCENT`**: Color de acento primario (bordes activos, anillos, cursores).
- **`ACCENT_PINK`**: Color de acento secundario (utilizado en reproductor de música y letras).
- **`ACCENT_CYAN`**: Color terciario para métricas y estados técnicos.
- **`INPUT_BG`**: Fondo del cuadro de texto de entrada en el chat.
- **`NOTIFICATION`**: Color de la insignia de notificación D-Bus/KDE Connect.

### `CONTRAST` (Variables de menú y botones)
Define colores en formato `#HEX` para los 4 estados de interacción de la UI:
- **`normal`**: `{ background, foreground, border }`
- **`hover`**: `{ background, foreground, border }`
- **`active`**: `{ background, foreground, border }`
- **`disabled`**: `{ background, foreground, border }`

### `geometry` (Dimensiones en píxeles)
- **`BUBBLE_SIZE`**: Diámetro del círculo flotante (por defecto `72`).
- **`CHAT_W`** / **`CHAT_H`**: Dimensiones de la ventana de chat (`400` x `510`).
- **`CHAT_RADIUS`**: Radio de redondeo de las esquinas del chat (`16`).
- **`GLOW_WIDTH`**: Grosor del anillo vectorial circundante (`2` o `3`).

### `persona` (Personalidad e Identidad de la IA)
- **`name`**: Nombre que el agente asume en las respuestas y encabezados.
- **`chat_header`**: Título desplegado en la barra superior de la ventana de chat.
- **`system_prompt`**: Instrucción fundamental inyectada a los modelos (llama.cpp o Cloud) para moldear el tono, jerga, actitud y estilo de respuesta.

### `skills` (Presets funcionales)
Activa o desactiva módulos según el propósito del tema:
```json
"skills": {
  "bash": true,
  "system_info": true,
  "media_control": true,
  "web_search": true,
  "lyrics": true,
  "data_bubbles": true,
  "player": true
}
```

---

## 3. Cómo Probar y Activar un Tema

### Opción A: Desde la Interfaz Gráfica (En Vivo)
1. Abre el panel de Chat del widget.
2. Haz clic en el engranaje de **Ajustes**.
3. En la sección **General**, localiza el desplegable **Tema Visual / Persona**.
4. Selecciona tu tema. Se aplicará instantáneamente sin reiniciar el widget.

### Opción B: Por Línea de Comandos (CLI)
```bash
./run.sh --theme mi_tema
# O directamente:
./bin/kitsu --theme mi_tema
```

### Opción C: Por Variable de Entorno
```bash
KITSU_THEME=mi_tema ./bin/kitsu
```

---

## 4. Empaquetado y Distribución

Para compartir tu tema con otros usuarios:
1. Comprime la carpeta de tu tema:
   ```bash
   cd themes/
   zip -r mi_tema.zip mi_tema/
   ```
2. Cualquier usuario puede instalarlo descomprimiéndolo en su directorio personal:
   ```bash
   mkdir -p ~/.config/kitsu/themes/
   unzip mi_tema.zip -d ~/.config/kitsu/themes/
   ```
   ¡El widget lo detectará inmediatamente al abrir el selector de temas!
