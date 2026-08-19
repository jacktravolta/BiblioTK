#!/bin/bash
# generador_todo_en_uno.sh - BiblioTK Todo en Uno
# Uso: chmod +x generador_todo_en_uno.sh && ./generador_todo_en_uno.sh

OUTPUT="BiblioTK_TODO_EN_UNO.md"
REPO_DIR="."

echo "# BiblioTK - Proyecto Todo-en-Uno" > "$OUTPUT"
echo "" >> "$OUTPUT"
echo "**Generado:** $(date)" >> "$OUTPUT"
echo "**Desde:** $(pwd)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "## ESTRUCTURA DEL PROYECTO" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
# Estructura limpia ignorando basura
find "$REPO_DIR" -type f \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/tmp/*" \
  -not -path "*/log/*" \
  -not -path "*/storage/*" \
  -not -path "*/public/assets/*" \
  -not -path "*/vendor/*" | sort >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "## CONTENIDO COMPLETO" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Archivos que SI queremos incluir
find "$REPO_DIR" -type f \( \
  -name "*.rb" -o \
  -name "*.erb" -o \
  -name "*.js" -o \
  -name "*.json" -o \
  -name "*.md" -o \
  -name "*.yml" -o \
  -name "*.yaml" -o \
  -name "*.css" -o \
  -name "*.scss" -o \
  -name "Gemfile" -o \
  -name "Gemfile.lock" -o \
  -name "Dockerfile" -o \
  -name "Rakefile" -o \
  -name "*.rake" \
\) \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/tmp/*" \
  -not -path "*/log/*" \
  -not -path "*/storage/*" \
  -not -path "*/public/assets/*" \
  -not -path "*/vendor/*" | sort | while read -r file; do
  
  echo "" >> "$OUTPUT"
  echo "---" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
  echo "### ARCHIVO: \`$file\`" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
  
  # Detectar extensión para markdown
  ext="${file##*.}"
  echo "\`\`\`$ext" >> "$OUTPUT"
  
  # Truncar si es muy grande (>20k chars ~ 500 lineas)
  lines=$(wc -l < "$file")
  if [ "$lines" -gt 500 ]; then
    head -n 500 "$file" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "... [ARCHIVO TRUNCADO - $lines lineas totales, se muestran 500] ..." >> "$OUTPUT"
  else
    cat "$file" >> "$OUTPUT"
  fi
  
  echo "" >> "$OUTPUT"
  echo '```' >> "$OUTPUT"
done

echo ""
echo "✅ Listo! Archivo creado: $OUTPUT"
ls -lh "$OUTPUT"
echo ""
echo "Ahora súbelo al chat de Meta AI."