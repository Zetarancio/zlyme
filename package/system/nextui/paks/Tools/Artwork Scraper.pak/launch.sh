#!/bin/sh
# nextui.elf saveLast() points at this pak. Restore to the card root
# or the next session opens this pak as a folder (launch.sh).
printf '%s' /storage > /tmp/last.txt

PAK_DIR="$(dirname "$0")"
PAK_NAME="$(basename "$PAK_DIR")"
PAK_NAME="${PAK_NAME%.*}"

rm -f "$LOGS_PATH/$PAK_NAME.txt"
exec >>"$LOGS_PATH/$PAK_NAME.txt"
exec 2>&1

echo "$0" "$@"
cd "$PAK_DIR" || exit 1
mkdir -p "$USERDATA_PATH/$PAK_NAME"

architecture=arm
if uname -m | grep -q '64'; then
    architecture=arm64
fi

: "${PLATFORM:=my355}"
: "${DEVICE:=my355}"
: "${SDCARD_PATH:=/storage}"

# exFAT has no +x. command -v fails until these are chmod'd.
chmod +x "$PAK_DIR/bin/$architecture/jq" 2>/dev/null || true
chmod +x "$PAK_DIR/bin/$PLATFORM/minui-list" 2>/dev/null || true
chmod +x "$PAK_DIR/bin/$PLATFORM/minui-presenter" 2>/dev/null || true
chmod +x "$PAK_DIR/bin/$PLATFORM/gm" 2>/dev/null || true

export PATH="/usr/bin:$PAK_DIR/bin/$architecture:$PAK_DIR/bin/$PLATFORM:$PAK_DIR/bin:$PATH"
# System SDL2 / libmsettings first. Bundled libz can break minui-list.
export LD_LIBRARY_PATH="/usr/lib:${SYSTEM_PATH:-/usr}/lib:$PAK_DIR/lib/$architecture:$PAK_DIR/lib/$PLATFORM:$PAK_DIR/lib:${LD_LIBRARY_PATH:-}"
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
export SDL_RENDER_DRIVER="${SDL_RENDER_DRIVER:-opengles2}"
export SDL_GAMECONTROLLERCONFIG_FILE="${SDL_GAMECONTROLLERCONFIG_FILE:-/usr/lib/gamecontrollerdb.txt}"
export IMAGE_MATCHER_URL="https://matching-images-is.bittersweet.rip"
export MINUI_IMAGE_WIDTH=300

text_list_to_json() {
    key=$1
    src=$2
    dest=$3
    if command -v jq >/dev/null 2>&1; then
        jq -R -s --arg key "$key" 'split("\n") | map(select(. != "")) | {($key): map({name: .})}' <"$src" >"$dest"
    else
        cp "$src" "$dest"
    fi
}

populate_emus_list() {
    echo "Cache Management" >/tmp/emus.list
    for folder in "$SDCARD_PATH/Roms"/*; do
        [ -d "$folder" ] || continue
        name=$(basename "$folder")
        case "$name" in
            .*|_*) continue ;;
            APPS|PORTS) continue ;;
        esac
        # Stop at the first real file. ls of a library card is tens of thousands.
        found=0
        for f in "$folder"/*; do
            [ -e "$f" ] || break
            base=$(basename "$f")
            case "$base" in
                .*|*.txt|*.srm|*.sav|*.state|*.png|*.jpg|*.jpeg|*.xml|*.nfo) continue ;;
            esac
            found=1
            break
        done
        [ "$found" = 1 ] && echo "$name" >>/tmp/emus.list
    done
}

main_screen() {
    minui_list_file="/tmp/minui-list"
    rm -f "$minui_list_file" "/tmp/minui-output"
    touch "$minui_list_file"

    if [ ! -f "/tmp/emus.list" ]; then
        show_message "Populating emus list" forever
        populate_emus_list
    fi

    killall minui-presenter >/dev/null 2>&1 || true
    text_list_to_json folders /tmp/emus.list /tmp/emus.json
    minui-list --disable-auto-sleep --item-key "folders" --file "/tmp/emus.json" --format json --cancel-text "EXIT" --title "Artwork Scraper" --write-location /tmp/minui-output --write-value state
}

action_menu() {
    ROM_FOLDER="$1"

    rm -f /tmp/action.list /tmp/action-output
    echo "Download Boxart as Artwork" >>/tmp/action.list
    echo "Download Title as Artwork" >>/tmp/action.list
    echo "Download Screenshot as Artwork" >>/tmp/action.list
    echo "Delete Artwork" >>/tmp/action.list

    killall minui-presenter >/dev/null 2>&1 || true
    text_list_to_json actions /tmp/action.list /tmp/action.json
    minui-list --disable-auto-sleep --item-key "actions" --file "/tmp/action.json" --format json --cancel-text "BACK" --title "$ROM_FOLDER" --write-location /tmp/action-output --write-value state

    if [ $? -ne 0 ]; then
        return 1
    fi

    output="$(cat /tmp/action-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".actions[$selected_index].name")"

    echo "$selection"
    return 0
}

delete_menu() {
    ROM_FOLDER="$1"

    rm -f /tmp/delete.list /tmp/delete-output
    echo "Delete All Images" >/tmp/delete.list
    echo "Delete Individual Images" >>/tmp/delete.list

    killall minui-presenter >/dev/null 2>&1 || true
    text_list_to_json options /tmp/delete.list /tmp/delete.json
    minui-list --disable-auto-sleep --item-key "options" --file "/tmp/delete.json" --format json --cancel-text "BACK" --title "Delete $ROM_FOLDER Artwork" --write-location /tmp/delete-output --write-value state

    if [ $? -ne 0 ]; then
        return 1
    fi

    output="$(cat /tmp/delete-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".options[$selected_index].name")"

    echo "$selection"
    return 0
}

fetch_artwork() {
    ROM_FOLDER="$1" ART_TYPE="${2:-snap}" REFRESH_CACHE="${3:-false}"
    rom_file="$SDCARD_PATH/Artwork/.cache/matches/$ROM_FOLDER.in.txt"
    artwork_file="$SDCARD_PATH/Artwork/.cache/matches/$ROM_FOLDER.$ART_TYPE.out.txt"
    emu_name="$(get_emu_name "$ROM_FOLDER")"

    mkdir -p "$SDCARD_PATH/Artwork/.cache/matches"
    mkdir -p "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE"
    if [ "$REFRESH_CACHE" = "true" ] || [ ! -f "$artwork_file" ] || [ ! -s "$artwork_file" ]; then
        ls -A "$SDCARD_PATH/Roms/$ROM_FOLDER" >"$rom_file"

        curl -fksSL -X POST -H "Content-Type: text/plain" \
            --data-binary "@$rom_file" \
            -o "$artwork_file" \
            "$IMAGE_MATCHER_URL/matches/$emu_name/$ART_TYPE"
        if [ $? -ne 0 ]; then
            return 1
        fi

        sync
    fi

    # add a newline to the end of this for proper parsing
    echo >>"$artwork_file"

    download_count=0
    total_count="$(wc -l <"$artwork_file")"
    rom_count="$(wc -l <"$rom_file")"
    show_message "Ensuring artwork is cached" forever
    while read -r line; do
        # if the line is empty, skip it
        if [ -z "$line" ]; then
            continue
        fi

        rom_name="$(echo "$line" | cut -f1)"
        artwork_url="$(echo "$line" | cut -f2)"

        if [ -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" ] && [ "$REFRESH_CACHE" = "false" ]; then
            download_count=$((download_count + 1))
            continue
        fi

        curl -fksSL -X GET -H "Content-Type: text/plain" \
            -o "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" \
            "$artwork_url"
        if [ $? -ne 0 ]; then
            show_message "Failed to download $rom_name image" forever
            continue
        fi

        download_count=$((download_count + 1))
        iteration=$((download_count % 10))
        if [ "$iteration" -eq 0 ]; then
            show_message "Downloaded $download_count/$total_count" forever
        fi
    done <"$artwork_file"

    sync

    is_nextui=false
    image_folder="res"
    base_directory="$SDCARD_PATH/Roms/$ROM_FOLDER"
    if [ "$IS_NEXT" = "true" ] || [ "$IS_NEXT" = "yes" ]; then
        is_nextui=true
        image_folder="media"
    elif [ -f "$SHARED_USERDATA_PATH/minuisettings.txt" ]; then
        is_nextui=true
        image_folder="media"
    fi

    show_message "Copying $download_count images to '$ROM_FOLDER' .$image_folder folder" forever
    while read -r line; do
        if [ -z "$line" ]; then
            continue
        fi

        rom_name="$(echo "$line" | cut -f1)"
        filename="${rom_name%.*}"
        if [ -z "$rom_name" ] || [ -z "$filename" ]; then
            continue
        fi

        mkdir -p "$base_directory/.$image_folder/"
        if [ "$is_nextui" = "true" ]; then
            cp -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" "$base_directory/.$image_folder/$filename.png"
        else
            gm convert "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" -resize "$MINUI_IMAGE_WIDTH" "$base_directory/.$image_folder/$rom_name.png"
        fi

        echo "$rom_name"
    done <"$artwork_file"

    sync

    show_message "Copied $download_count images for $rom_count roms" 4
}

get_emu_name() {
    EMU_FOLDER="$1"

    echo "$EMU_FOLDER" | sed 's/.*(\([^)]*\)).*/\1/'
}

show_message() {
    message="$1"
    seconds="$2"

    if [ -z "$seconds" ]; then
        seconds="forever"
    fi

    killall minui-presenter >/dev/null 2>&1 || true
    echo "$message" 1>&2
    if [ "$seconds" = "forever" ]; then
        minui-presenter --message "$message" --timeout -1 &
    else
        minui-presenter --message "$message" --timeout "$seconds"
    fi
}

confirm_action() {
    message="$1"

    rm -f /tmp/confirm.list /tmp/confirm-output
    echo "Yes" >/tmp/confirm.list
    echo "No" >>/tmp/confirm.list

    killall minui-presenter >/dev/null 2>&1 || true
    text_list_to_json choices /tmp/confirm.list /tmp/confirm.json
    minui-list --disable-auto-sleep --item-key "choices" --file "/tmp/confirm.json" --format json --cancel-text "CANCEL" --title "$message" --write-location /tmp/confirm-output --write-value state

    if [ $? -ne 0 ]; then
        return 1
    fi

    output="$(cat /tmp/confirm-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".choices[$selected_index].name")"

    if [ "$selection" = "Yes" ]; then
        return 0
    else
        return 1
    fi
}

delete_all_images() {
    ROM_FOLDER="$1"

    confirm_action "Delete all artwork for $ROM_FOLDER?"
    if [ $? -ne 0 ]; then
        show_message "Deletion cancelled" 2
        return 1
    fi

    show_message "Deleting all images..." forever

    # Delete from cache
    rm -rf "$SDCARD_PATH/Artwork/$ROM_FOLDER"

    # Delete from rom folders (.res and .media)
    base_directory="$SDCARD_PATH/Roms/$ROM_FOLDER"
    rm -rf "$base_directory/.res"
    rm -rf "$base_directory/.media"

    # Delete cache files
    rm -f "$SDCARD_PATH/Artwork/.cache/matches/$ROM_FOLDER.in.txt"
    rm -f "$SDCARD_PATH/Artwork/.cache/matches/$ROM_FOLDER."*.out.txt

    sync
    show_message "All images deleted" 3
    return 0
}

select_images_to_delete() {
    ROM_FOLDER="$1"
    base_directory="$SDCARD_PATH/Roms/$ROM_FOLDER"

    # Determine which folder to check
    image_folder=".res"
    if [ -d "$base_directory/.media" ]; then
        image_folder=".media"
    fi

    if [ ! -d "$base_directory/$image_folder" ]; then
        show_message "No images found" 2
        return 1
    fi

    # Create list of images
    rm -f /tmp/images.list /tmp/images-output
    ls -1 "$base_directory/$image_folder"/*.png 2>/dev/null | while read -r img; do
        basename "$img" >>/tmp/images.list
    done

    if [ ! -s /tmp/images.list ]; then
        show_message "No images found" 2
        return 1
    fi

    killall minui-presenter >/dev/null 2>&1 || true
    text_list_to_json images /tmp/images.list /tmp/images.json
    minui-list --disable-auto-sleep --item-key "images" --file "/tmp/images.json" --format json --cancel-text "BACK" --title "Select image to delete" --write-location /tmp/images-output --write-value state

    if [ $? -ne 0 ]; then
        return 1
    fi

    output="$(cat /tmp/images-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".images[$selected_index].name")"

    if [ -n "$selection" ]; then
        delete_single_image "$ROM_FOLDER" "$selection"
    fi
}

delete_single_image() {
    ROM_FOLDER="$1"
    IMAGE_NAME="$2"

    confirm_action "Delete $IMAGE_NAME?"
    if [ $? -ne 0 ]; then
        show_message "Deletion cancelled" 2
        return 1
    fi

    show_message "Deleting image..." forever

    # Delete from cache (all art types)
    rm -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/snap/$IMAGE_NAME"
    rm -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/title/$IMAGE_NAME"
    rm -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/boxart/$IMAGE_NAME"

    # Delete from rom folders
    base_directory="$SDCARD_PATH/Roms/$ROM_FOLDER"
    rm -f "$base_directory/.res/$IMAGE_NAME"
    rm -f "$base_directory/.media/$IMAGE_NAME"

    sync
    show_message "Image deleted" 2
    return 0
}

clear_url_cache() {
    show_message "Clearing URL cache..." forever
    rm -rf "$SDCARD_PATH/Artwork/.cache/matches"
    sync
    show_message "URL cache cleared" 2
}

clear_image_cache() {
    show_message "Clearing image cache..." forever
    # Remove all cached images but keep the directory structure
    find "$SDCARD_PATH/Artwork" -type f -name "*.png" -exec rm {} \; || true
    sync
    show_message "Image cache cleared" 2
}

clear_all_cache() {
    show_message "Clearing all cache..." forever
    rm -rf "$SDCARD_PATH/Artwork/.cache"
    # Remove all cached images but keep the directory structure
    find "$SDCARD_PATH/Artwork" -type f -exec rm {} \; || true
    sync
    show_message "All cache cleared" 2
}

cache_menu() {
    # Create cache menu options
    cat >/tmp/cache_menu.list <<EOF
Clear URL cache only
Clear image cache only
Clear all cache
EOF

    killall minui-presenter >/dev/null 2>&1 || true
    text_list_to_json cache_options /tmp/cache_menu.list /tmp/cache_menu.json
    minui-list --disable-auto-sleep --item-key "cache_options" --file "/tmp/cache_menu.json" --format json --cancel-text "BACK" --title "Cache Management" --write-location /tmp/cache-output --write-value state

    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        rm -f /tmp/cache_menu.list /tmp/cache-output
        return 1
    fi

    output="$(cat /tmp/cache-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".cache_options[$selected_index].name")"

    rm -f /tmp/cache_menu.list /tmp/cache-output

    case "$selection" in
    "Clear URL cache only")
        clear_url_cache
        ;;
    "Clear image cache only")
        clear_image_cache
        ;;
    "Clear all cache")
        clear_all_cache
        ;;
    esac
    return 0
}

cleanup() {
    rm -f /tmp/stay_awake
    rm -f /tmp/emus
    rm -f /tmp/emus.list
    rm -f /tmp/minui-output
    rm -f /tmp/action.list
    rm -f /tmp/action-output
    rm -f /tmp/delete.list
    rm -f /tmp/delete-output
    rm -f /tmp/confirm.list
    rm -f /tmp/confirm-output
    rm -f /tmp/images.list
    rm -f /tmp/images-output
    killall minui-presenter >/dev/null 2>&1 || true
}

main() {
    echo "1" >/tmp/stay_awake
    trap "cleanup" EXIT INT TERM HUP QUIT

    if [ "$PLATFORM" = "tg3040" ] && [ -z "$DEVICE" ]; then
        export DEVICE="brick"
        export PLATFORM="tg5040"
    fi

    allowed_platforms="my355 tg5040 tg5050"
    if ! echo "$allowed_platforms" | grep -q "$PLATFORM"; then
        show_message "$PLATFORM is not a supported platform" 2
        return 1
    fi

    if ! command -v minui-list >/dev/null 2>&1; then
        show_message "minui-list not found" 2
        return 1
    fi

    if ! command -v minui-presenter >/dev/null 2>&1; then
        show_message "minui-presenter not found" 2
        return 1
    fi

    retries=0
    while true; do
        main_screen
        exit_code=$?
        # exit codes: 2 = back button, 3 = menu button
        if [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 3 ]; then
            break
        fi
        if [ "$exit_code" -ne 0 ]; then
            if [ "$retries" -lt 2 ]; then
                retries=$((retries + 1))
                show_message "Retrying list ($exit_code)" 2
                sleep 0.5
                continue
            fi
            show_message "minui-list crashed ($exit_code). Check logs." 4
            return "$exit_code"
        fi
        retries=0

        output="$(cat /tmp/minui-output)"
        selected_index="$(echo "$output" | jq -r '.selected')"
        selection="$(echo "$output" | jq -r ".folders[$selected_index].name")"

        if [ -z "$selection" ]; then
            show_message "No selection made" forever
            continue
        fi

        # Handle Cache Management selection
        if [ "$selection" = "Cache Management" ]; then
            cache_menu
            # Refresh the emus list to ensure it's up to date
            rm -f /tmp/emus.list
            continue
        fi

        # Show action menu
        action=$(action_menu "$selection")
        if [ $? -ne 0 ]; then
            continue
        fi

        if [ "$action" = "Download Boxart as Artwork" ]; then
            show_message "Fetching boxart images for $selection" forever
            fetch_artwork "$selection" "boxart"
        elif [ "$action" = "Download Title as Artwork" ]; then
            show_message "Fetching title images for $selection" forever
            fetch_artwork "$selection" "title"
        elif [ "$action" = "Download Screenshot as Artwork" ]; then
            show_message "Fetching screenshot images for $selection" forever
            fetch_artwork "$selection" "snap"
        elif [ "$action" = "Delete Artwork" ]; then
            delete_option=$(delete_menu "$selection")
            if [ $? -eq 0 ]; then
                if [ "$delete_option" = "Delete All Images" ]; then
                    delete_all_images "$selection"
                elif [ "$delete_option" = "Delete Individual Images" ]; then
                    select_images_to_delete "$selection"
                fi
            fi
        fi
    done
}

main "$@"
