#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_DIR=${1:-$SCRIPT_DIR}
RELEASE=${KERNEL_RELEASE:-$(uname -r)}
ARCH=${MODULE_ARCH:-$(uname -m)}
OUTPUT_DIR=${OUTPUT_DIR:-$SCRIPT_DIR/releases/$RELEASE/$ARCH}

if [ "$ARCH" != aarch64 ]; then
    echo "Expected aarch64 modules, got $ARCH" >&2
    exit 1
fi

for module_name in $(cat "$SCRIPT_DIR/modules.list"); do
    module_file="$SOURCE_DIR/$module_name.ko"
    [ -f "$module_file" ] || { echo "Missing $module_file" >&2; exit 1; }
    module_release=$(modinfo -F vermagic "$module_file" | awk '{print $1}')
    [ "$module_release" = "$RELEASE" ] || {
        echo "Release mismatch: $module_file ($module_release != $RELEASE)" >&2
        exit 1
    }
done

mkdir -p "$OUTPUT_DIR"
cp "$SCRIPT_DIR/modules.list" "$OUTPUT_DIR/modules.list"
for module_name in $(cat "$SCRIPT_DIR/modules.list"); do
    cp "$SOURCE_DIR/$module_name.ko" "$OUTPUT_DIR/$module_name.ko"
done
(
    cd "$OUTPUT_DIR"
    sha256sum ./*.ko modules.list > SHA256SUMS
)
echo "Saved modules to $OUTPUT_DIR"
echo "To distribute: tar -czf ${RELEASE}-${ARCH}-modules.tar.gz -C $SCRIPT_DIR/releases $RELEASE"
