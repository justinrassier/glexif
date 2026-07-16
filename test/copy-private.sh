src="/mnt/external/photo-test/2026"
dest="$HOME/git/glexif/test/private-fixtures"

mkdir -p "$dest"

find "$src" -type f -name '*.JPG' -print0 |
while IFS= read -r -d '' file; do
  relative="${file#"$src"/}"
  id="$(printf '%s' "$relative" | sha256sum | cut -c1-16)"
  cp -- "$file" "$dest/${id}_$(basename "$file")"
done
