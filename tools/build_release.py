"""Build dist/PawnTrickster_<version>.zip from this repository.
Usage: python tools/build_release.py 0.2.4
The zip holds reframework/autorun/PawnTrickster.lua and reframework/data/PawnTrickster/README.txt (forward slashes),
ready to extract into the game folder or to install with a mod manager."""
import os, sys, zipfile

repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
version = sys.argv[1] if len(sys.argv) > 1 else "dev"
files = ["reframework/autorun/PawnTrickster.lua", "reframework/data/PawnTrickster/README.txt"]
first = open(os.path.join(repo, files[0]), encoding="utf-8").readline()
if version != "dev" and version not in first:
    sys.exit("the first line of PawnTrickster.lua does not name version %s: %s" % (version, first.strip()))
os.makedirs(os.path.join(repo, "dist"), exist_ok=True)
out = os.path.join(repo, "dist", "PawnTrickster_%s.zip" % version)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for arc in files:
        z.write(os.path.join(repo, arc.replace("/", os.sep)), arc)
with zipfile.ZipFile(out) as z:
    for i in z.infolist():
        print("%8d  %s" % (i.file_size, i.filename))
print("wrote", out)
