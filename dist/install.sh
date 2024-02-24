#!/usr/bin/env bash
# Use this script to install Wings into an UNIX system.

show_help() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -i, --interpreter  Set the lua interpreter name (default: lua)"
  echo "  -h, --help        Show this help message and exit"
}

INSTALL_PATH="/usr/local/bin"
INTERPRETER="lua"

# Parse command line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -i|--interpreter) INTERPRETER="$2"; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown option: $1"; show_help; exit 1 ;;
  esac
  shift
done

# Check if the script has root permissions
if [[ "$(id -u)" != "0" ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Check if the interpreter is installed
if ! command -v "$INTERPRETER" &> /dev/null; then
  echo "The interpreter '$INTERPRETER' is not installed. Please install it first." >&2
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"


# Copy the lua script to the installation path
cp "$SCRIPT_DIR/wings.lua" "$INSTALL_PATH/wings"
chmod +x "$INSTALL_PATH/wings"
sed -i "1i#!/usr/bin/env $INTERPRETER" "$INSTALL_PATH/wings"

echo "Installation succeeded. You can now run 'wings' from any terminal."