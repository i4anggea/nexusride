"""Write ignored iOS xcconfig files from the app's local environment files."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIGS = (
    (".env.dev.json", "ios/Flutter/Maps.Debug.xcconfig"),
    (".env.prod.json", "ios/Flutter/Maps.Release.xcconfig"),
)


def main() -> None:
    for env_file, output_file in CONFIGS:
        values = json.loads((ROOT / env_file).read_text(encoding="utf-8"))
        key = values.get("GOOGLE_MAPS_KEY_IOS")
        if not isinstance(key, str) or not key.strip():
            raise SystemExit(f"GOOGLE_MAPS_KEY_IOS no existe en {env_file}")
        if "\n" in key or "\r" in key:
            raise SystemExit(f"GOOGLE_MAPS_KEY_IOS no es válida en {env_file}")

        destination = ROOT / output_file
        destination.write_text(
            "// Generado localmente desde "
            f"{env_file}; contiene una clave y no debe versionarse.\n"
            f"GOOGLE_MAPS_KEY_IOS = {key}\n",
            encoding="utf-8",
        )
        print(f"Configuración iOS actualizada: {output_file}")


if __name__ == "__main__":
    main()
