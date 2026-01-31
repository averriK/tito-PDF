# Skill: tito-pdf (PDF → Markdown + Tables, determinístico)

## Objetivo
`tito-pdf` es un helper local (sin LLM / sin claude-flow) para convertir un PDF a:
- `md/<id>.retrieve.md` (Markdown con headings best-effort)
- `md/<id>.retrieve.tables.md` (tablas separadas, estilo TITO)
- `sessions/run-.../` (artefactos + audit JSON)

Este skill está inspirado por el pipeline de `tito retrieve`, pero reemplaza las etapas LLM por parsers y heurísticas locales.

## Restricciones (importante)
- NO llama a ninguna API.
- NO usa MCP.
- Es determinístico/offline: depende de herramientas locales (qpdf/gs/ocrmypdf/tesseract) y librerías Python.

## Setup (una vez)
Desde `~/github/garage/pdf`:

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
Genera texto + tablas (default = `--all`):

```bash
./tito-pdf /path/al/documento.pdf --out-dir . --id mi_doc
```

## Modo (recomendado)
Para no tener que pensar en flags, usá `--mode`:
- `--mode robust` (default): OCR conservador + tablas estrictas
- `--mode fast`: sin OCR (útil para PDFs con texto “bueno” o runs rápidos)
- `--mode best`: fuerza OCR y, si no hay tablas en estricto, reintenta tablas en modo lenient

Ejemplos:

```bash
./tito-pdf /path/al/documento.pdf --out-dir . --id mi_doc --mode fast
```

```bash
./tito-pdf /path/al/documento.pdf --out-dir . --id mi_doc --mode best
```

Outputs:
- `md/mi_doc.retrieve.md`
- `md/mi_doc.retrieve.tables.md`
- `sessions/run-YYYYMMDD_HHMMSS/mi_doc.retrieve.tables.audit.json`

## Integration / contract outputs (para orquestadores)
Estos flags existen para que otro tool controle exactamente dónde se escriben los outputs (p.ej. `tito retrieve`).

- `--raw-text-out PATH`: escribe el texto extraído como plaintext (no Markdown)
- `--tables-out PATH`: escribe tablas en Markdown
- `--tables-audit-out PATH`: escribe audit JSON de tablas
- `--assets-json PATH`: escribe un JSON pequeño con paths/flags/metadata

Nota: el usuario normal NO debería necesitar estos flags; usá `--out-dir` + `--mode`.

## Uso: tablas solamente

```bash
./tito-pdf /path/al/documento.pdf --out-dir . --id mi_doc --tables
```

## OCR
Por defecto, si existe `ocrmypdf`, se intenta OCR de forma conservadora (`--skip-text`).
- Para desactivar OCR:

```bash
./tito-pdf /path/al/documento.pdf --out-dir . --id mi_doc --no-ocr
```

- Para forzar OCR (útil si el PDF tiene “texto malo” o es escaneado):

```bash
./tito-pdf /path/al/documento.pdf --out-dir . --id mi_doc --force-ocr
```

## Tabla extraction: modo lenient
Por defecto, `--tables` intenta detección basada en líneas (menos falsos positivos).
- Primero usa PyMuPDF (`Page.find_tables`, `lines/lines`).
- Si no encuentra nada aceptable, hace fallback a `pdfplumber`.
- En PDFs multi-columna (papers), el modo estricto suele **rechazar** “tablas” angostas (ancho ~una columna) porque casi siempre son falsos positivos (texto partido).

Si el output dice `(No tables detected.)`, la recomendación es reintentar con:

```bash
./tito-pdf /path/al/documento.pdf --out-dir . --id mi_doc --tables --mode best
```

Alternativa manual (más control):

```bash
./tito-pdf /path/al/documento.pdf --out-dir . --id mi_doc --tables --tables-lenient
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
Síntoma: `md/<id>.retrieve.tables.md` contiene `(No tables detected.)`.
Acción (orden recomendado):
1) Reintentar con `--mode best`.
2) Si querés acotar runtime, probá un rango pequeño primero:

```bash
./tito-pdf /path/al/documento.pdf --out-dir . --id mi_doc --tables --mode best --max-pages 10
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
- Ejecutar `./tito-pdf ...` y luego leer **solo** los outputs relevantes bajo `md/` y el audit JSON.
- Si algo falta o se ve mal, reintentar siguiendo el playbook (lenient/no-ocr/force-ocr/max-pages).
- No imprimir el contenido completo del PDF en la conversación; referenciar paths y extraer solo fragmentos mínimos si hace falta.
