"""Build a deterministic ZIP; only runtime files from package are included."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
package = root / "package"
manifest = dict(line.split("=", 1) for line in
                (package / "app.info").read_text(encoding="utf-8").splitlines()
                if "=" in line)
version = next(value.strip() for key, value in manifest.items() if key.strip() == "version")
destination = root / "src" / "dist" / ("黄金矿工_" + version + "_完整安装包.zip")
destination.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(destination, "w", ZIP_DEFLATED) as archive:
    for source in sorted(p for p in package.rglob("*") if p.is_file()):
        info = ZipInfo("gold_miner/" + source.relative_to(package).as_posix(),
                       date_time=(2026, 10, 12, 0, 0, 0))
        info.compress_type = ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        archive.writestr(info, source.read_bytes())
print(f"Built {destination.name}: {destination.stat().st_size} bytes")
