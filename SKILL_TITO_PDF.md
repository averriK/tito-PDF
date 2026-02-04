# Skill: tito-pdf (PDF/DOCX → Markdown + Tables, determinístico)

## Objetivo
`tito-pdf` es un helper local (sin LLM / sin claude-flow) para convertir un PDF/DOCX a Markdown y, opcionalmente, extraer tablas.

Tiene dos formas de salida:
- Recomendado (paths explícitos): usá `--md-out` / `--tables-out` / etc.
- Convenience (sin paths explícitos): escribe `<stem>.md` (y `<stem>.tables.md` si pedís tablas) junto al input o bajo `--out-dir`.

Este skill está inspirado por el pipeline de `tito retrieve`, pero reemplaza las etapas LLM por parsers y heurísticas locales.

## Restricciones (importante)
- NO llama a ninguna API.
- NO usa MCP.
- Es determinístico/offline: depende de herramientas locales (qpdf/gs/ocrmypdf/tesseract) y librerías Python.

## Setup (una vez)
Desde el root del repo:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Dependencias del sistema (recomendadas):
- `qpdf`
- `gs` (Ghostscript)
- `tesseract` (para OCR)

## Uso básico
Markdown (recomendado):

```bash
tito-pdf /path/al/documento.pdf --md-out out/documento.md
```

Convenience mode (sin paths explícitos):

```bash
tito-pdf /path/al/documento.pdf                 # escribe /path/al/documento.md
tito-pdf /path/al/documento.pdf --out-dir out   # escribe out/documento.md
tito-pdf /path/al/documento.pdf --tables --out-dir out  # escribe out/documento.tables.md
tito-pdf /path/al/documento.pdf --all --out-dir out     # escribe out/documento.md + out/documento.tables.md
```

DOCX:

```bash
tito-pdf /path/al/documento.docx --md-out out/documento.md
```

## Modo (recomendado)
Para no tener que pensar en flags, usá `--mode`:
- `--mode robust` (default): OCR conservador + tablas estrictas
- `--mode fast`: sin OCR (útil para PDFs con texto “bueno” o runs rápidos)
- `--mode best`: fuerza OCR y, si no hay tablas en estricto, reintenta tablas en modo lenient

Ejemplos:

```bash
tito-pdf /path/al/documento.pdf --md-out out/documento.md --mode fast
```

```bash
tito-pdf /path/al/documento.pdf --md-out out/documento.md --tables-out out/documento.tables.md --mode best
```

## Outputs
- Markdown principal: `--md-out PATH` o `<stem>.md` en convenience.
- Tablas (opcional): `--tables-out PATH` o `<stem>.tables.md` en convenience.
- Audit JSON (opcional): `--tables-audit-out PATH` (requiere `--tables-out`).
- Assets JSON (opcional): `--assets-json PATH` (incluye `schema_version==1`, `tool=="tito-pdf"`, timestamps, duration_ms, metrics, etc.).

## Integration / explicit outputs (para orquestadores)
Estos flags existen para que otro tool controle exactamente dónde se escriben los outputs (p.ej. `tito retrieve`).

- `--md-out PATH`: escribe el Markdown principal
- `--raw-text-out PATH`: escribe el texto extraído como plaintext (no Markdown)
- `--tables-out PATH`: escribe tablas en Markdown
- `--tables-audit-out PATH`: escribe audit JSON de tablas (requiere `--tables-out`)
- `--assets-json PATH`: escribe un JSON pequeño con metadata + métricas

Nota: el usuario normal NO debería necesitar estos flags; usá `--out-dir` + `--mode`.

## Uso: tablas solamente

Convenience:

```bash
tito-pdf /path/al/documento.pdf --tables --out-dir out
```

Explícito:

```bash
tito-pdf /path/al/documento.pdf \
  --mode fast \
  --tables-out out/documento.tables.md \
  --tables-audit-out out/documento.tables.audit.json
```

## OCR
Por defecto, si existe `ocrmypdf`, se intenta OCR de forma conservadora (`--skip-text`).
- Para desactivar OCR:

```bash
tito-pdf /path/al/documento.pdf --md-out out/documento.md --no-ocr
```

- Para forzar OCR (útil si el PDF tiene “texto malo” o es escaneado):

```bash
tito-pdf /path/al/documento.pdf --md-out out/documento.md --force-ocr
```

## Tabla extraction: modo lenient
Por defecto, la detección intenta ser estricta (menos falsos positivos).
- Primero usa PyMuPDF (`Page.find_tables`, `lines/lines`).
- Si no encuentra nada aceptable, hace fallback a `pdfplumber`.
- En PDFs multi-columna (papers), el modo estricto suele **rechazar** “tablas” angostas (ancho ~una columna) porque casi siempre son falsos positivos (texto partido).

Si el output de tablas dice `(No tables detected.)`, la recomendación es reintentar con:

```bash
tito-pdf /path/al/documento.pdf --tables --out-dir out --mode best
```

Alternativa manual (más control):

```bash
tito-pdf /path/al/documento.pdf --tables --out-dir out --tables-lenient
```

Nota: `--tables-lenient` puede producir más tablas, pero también más falsos positivos.

## Iteración / “si algo sale mal” (playbook)

### 1) Error: faltan librerías Python
Síntoma: error importando `fitz`/PyMuPDF o `pdfplumber`.
Acción:
- activar venv e instalar deps:

```bash
source .venv/bin/activate
pip install -r requirements.txt
```

### 2) OCR falla
Síntoma: WARNING de OCR o `ocrmypdf` no está en PATH.
Acción:
- Si el PDF NO es escaneado: reintentar con `--no-ocr`.
- Si el PDF ES escaneado: instalar `tesseract` + `ocrmypdf` y reintentar con `--force-ocr`.

### 3) No se detectan tablas
Síntoma: el archivo de tablas contiene `(No tables detected.)`.
Acción (orden recomendado):
1) Reintentar con `--mode best`.
2) Si querés acotar runtime, probá un rango pequeño primero:

```bash
tito-pdf /path/al/documento.pdf --tables --out-dir out --mode best --max-pages 10
```

3) Si aún no hay tablas, probablemente el PDF no tiene tablas detectables sin un extractor más pesado (p.ej. Camelot/Tabula) o las tablas son imágenes difíciles.

### 4) Tablas “malas” (falsos positivos, title blocks, columnas de texto)
Acción:
- Reintentar SIN `--tables-lenient` (modo estricto).
- Si necesitás recall, usar lenient pero limitar páginas (`--max-pages`) y revisar audit JSON.

### 5) Performance / PDFs grandes
Acción:
- Hacer un run rápido con `--max-pages`.
- Luego correr full sin `--max-pages`.

## Qué debe hacer el agente (Claude) al usar este skill
- Ejecutar `tito-pdf ...` (preferir `--md-out`/paths explícitos cuando sea integración).
- Leer **solo** los outputs producidos (paths explícitos o `--out-dir`).
- Si algo falta o se ve mal, reintentar siguiendo el playbook (lenient/no-ocr/force-ocr/max-pages).
- No imprimir el contenido completo del PDF en la conversación; referenciar paths y extraer solo fragmentos mínimos si hace falta.
