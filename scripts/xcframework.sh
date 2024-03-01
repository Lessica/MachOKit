set -Ceu

PACKAGE_DIR=$(
  cd "$(dirname "$0")/.." || exit 1
  pwd
)
cd "${PACKAGE_DIR}" || exit 1

DERIVED_DATA_PATH=".build"
OUTPUT="XCFrameworks"
CONFIGURATION="Release"

enable_dynamic_type() {
    # https://forums.swift.org/t/how-to-build-swift-package-as-xcframework/41414/3
    perl -i -p0e 's/type: .static,//g' Package.swift
    perl -i -p0e 's/type: .dynamic,//g' Package.swift
    perl -i -p0e 's/(library[^,]*,)/$1 type: .dynamic,/g' Package.swift
}

archive_project() {
    local SCHEME=$1
    local PLATFORM=$2

    # https://github.com/realm/realm-swift/blob/aea16af78a0bbfb2c964801becaecb9cade9335f/build.sh#L208
    case $PLATFORM in
    "macOS")
        DESTINATION="$CONFIGURATION"
        ;;
    "iOS")
        DESTINATION="$CONFIGURATION-iphoneos"
        ;;
    "iOS Simulator")
        DESTINATION="$CONFIGURATION-iphonesimulator"
        ;;
    "watchOS")
        DESTINATION="$CONFIGURATION-watchos"
        ;;
    "watchOS Simulator")
        DESTINATION="$CONFIGURATION-watchsimulator"
        ;;
    "tvOS")
        DESTINATION="$CONFIGURATION-appletvos"
        ;;
    "tvOS Simulator")
        DESTINATION="$CONFIGURATION-appletvsimulator"
        ;;
    "visionOS")
        DESTINATION="$CONFIGURATION-xros"
        ;;
    "visionOS Simulator")
        DESTINATION="Release-xrsimulator"
        ;;
    esac

    local ARCHIVE_PATH=".build/archives/$PLATFORM"

    local OTHER_LDFLAGS='$(inherited)'
    if [ "$#" -ge 3 ]; then
        OTHER_LDFLAGS=$3
    fi

    xcodebuild archive -workspace . -scheme "$SCHEME" \
                -configuration "$CONFIGURATION" \
                -destination "generic/platform=$PLATFORM" \
                -archivePath "$ARCHIVE_PATH" \
                -derivedDataPath "$DERIVED_DATA_PATH" \
                SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES DEFINES_MODULE=YES \
                FRAMEWORK_SEARCH_PATHS=\"XCFrameworks/"$PLATFORM"/**\" \
                OTHER_LDFLAGS="$OTHER_LDFLAGS"

    local BUILD_PRODUCTS_PATH=".build/Build/Intermediates.noindex/ArchiveIntermediates/$SCHEME/BuildProductsPath"
    local SWIFT_MODULE_PATH="$BUILD_PRODUCTS_PATH/$DESTINATION/$SCHEME.swiftmodule"

    mkdir -p "$ARCHIVE_PATH.xcarchive/Products/usr/local/lib/$SCHEME.framework/Modules"
    if [ -d "$SWIFT_MODULE_PATH" ]; then
        cp -r "$SWIFT_MODULE_PATH" \
        "$ARCHIVE_PATH.xcarchive/Products/usr/local/lib/$SCHEME.framework/Modules"
    else
        local HEADERS=$(ls "Sources/$SCHEME/include")
        HEADERS_ARRAY=()
        while IFS= read -r line; do
            HEADERS_ARRAY+=("$line")
        done <<<"$HEADERS"

        local MODULEMAP_HEADER=""
        for header in "${HEADERS_ARRAY[@]}"; do
            MODULEMAP_HEADER="$MODULEMAP_HEADER    header \"$header\"\n"
        done

        echo -e "framework module $SCHEME {\n$MODULEMAP_HEADER    export *\n}" > "$ARCHIVE_PATH.xcarchive/Products/usr/local/lib/$SCHEME.framework/Modules/module.modulemap"
        mkdir -p "$ARCHIVE_PATH.xcarchive/Products/usr/local/lib/$SCHEME.framework/Headers"
        cp -r "Sources/$SCHEME/include/." \
            "$ARCHIVE_PATH.xcarchive/Products/usr/local/lib/$SCHEME.framework/Headers"

    fi

    mkdir -p "$OUTPUT/$PLATFORM"
    mv "$ARCHIVE_PATH.xcarchive/Products/usr/local/lib/$SCHEME.framework" "$OUTPUT/$PLATFORM/$SCHEME.framework"
}

create_xcframework() {
    local SCHEME=$1
    local PLATFORMS=(
        "macOS"
        "iOS"
        "iOS Simulator"
        "watchOS"
        "watchOS Simulator"
        "tvOS"
        "tvOS Simulator"
        "visionOS"
        "visionOS Simulator"
    )
    local ARGS=(
        -create-xcframework
    )

    for platfrom in "${PLATFORMS[@]}"; do
        local path=$OUTPUT/"$platfrom"/$SCHEME.framework
        if [ -e "$path" ]; then
            ARGS+=(
                -framework \"$path\"
            )
        fi
    done

    ARGS+=(
        -output \"$OUTPUT/"$SCHEME".xcframework\"
    )

    eval xcodebuild "${ARGS[@]}"
}

zip_xcframework() {
    local SCHEME=$1
    local CUR=$(pwd)
    cd "$OUTPUT"
    zip -ry - "$SCHEME.xcframework" > "$SCHEME.xcframework.zip"
    cd "$CUR"
}

print_checksum() {
    local SCHEME=$1
    local CUR=$(pwd)
    cd "$OUTPUT"
    CHECKSUM=$(swift package compute-checksum "$SCHEME.xcframework.zip")
    echo "$SCHEME checksum:"
    echo ${CHECKSUM}
    cd "$CUR"
}

machokit() {
    LINK_FLAGS="-framework MachOKitC"

    archive_project "MachOKit" "iOS" "$LINK_FLAGS"
    archive_project "MachOKit" "iOS Simulator" "$LINK_FLAGS"
    archive_project "MachOKit" "macOS" "$LINK_FLAGS"

    create_xcframework "MachOKit"
    zip_xcframework "MachOKit"
}

machokitc() {
    archive_project "MachOKitC" "iOS"
    archive_project "MachOKitC" "iOS Simulator"
    archive_project "MachOKitC" "macOS"

    create_xcframework "MachOKitC"
    zip_xcframework "MachOKitC"
}


rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

enable_dynamic_type

machokitc
machokit

print_checksum "MachOKit"
print_checksum "MachOKitC"

