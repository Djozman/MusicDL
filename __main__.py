"""Entry point for the MusicDL standalone binary."""
import sys
import os

os.environ.setdefault("ANTRA_FROZEN", "1")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from antra_dl import main as antra_dl_main
from tidal_dl import main as tidal_dl_main


def main() -> int:
    argv = [a for a in sys.argv[1:]]
    if argv and argv[0] in ("tidal", "tidal-dl", "tdl"):
        return tidal_dl_main()
    return antra_dl_main()


if __name__ == "__main__":
    raise SystemExit(main())