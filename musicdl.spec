# -*- mode: python ; coding: utf-8 -*-
#
# Build a single self-contained "musicdl" executable that bundles the antra
# package + all third-party deps. Run:
#   cd MusicDL && python3 -m PyInstaller musicdl.spec --noconfirm
import os

from PyInstaller.utils.hooks import collect_submodules, collect_data_files

HERE = os.getcwd()

# Hidden imports: the antra app lazily imports many optional source adapters
# and libraries, so pull them all in to be safe.
hiddenimports = [
    "tidalapi",
    "spotipy",
    "mutagen",
    "requests",
    "curl_cffi",
    "pywidevine",
    "websockets",
    "yt_dlp",
    "lyricsgenius",
    "pyotp",
    "imageio_ffmpeg",
] + collect_submodules("antra")

datas = collect_data_files("antra")

# Bundle static arm64 ffmpeg + ffprobe so the binary is fully portable.
# Extracted to _MEIPASS/_sysdata/ffmpeg; rthook_ffmpeg.py prepends it to PATH.
binaries = [
    (os.path.join(HERE, "bundle", "bin", "ffmpeg"), "_sysdata/ffmpeg"),
    (os.path.join(HERE, "bundle", "bin", "ffprobe"), "_sysdata/ffmpeg"),
]

a = Analysis(
    [os.path.join(HERE, "__main__.py")],
    pathex=[HERE],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    runtime_hooks=[os.path.join(HERE, "rthook_ffmpeg.py")],
    excludes=["tkinter", "matplotlib", "numpy", "pytest", "IPython"],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="musicdl",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
)