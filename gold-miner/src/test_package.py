"""Offline package regression tests. Requires Python 3.9+ and lupa (Lua 5.4)."""
import base64
import json
import re
import unittest
import zipfile
from pathlib import Path

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "package"
SOURCE = (PACKAGE / "main.lua").read_text(encoding="utf-8")


def make_runtime(entry="/apps/gold_miner/main.lua", route="/gold_miner", settings=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().TEST_ENTRY = entry
    lua.globals().TEST_ROUTE = route
    lua.globals().TEST_READ_FILE = lambda path: (settings or {}).get(path)
    def decode_json(raw):
        value = json.loads(raw)
        return lua.table_from(value) if isinstance(value, (dict, list)) else value
    lua.globals().TEST_DECODE_JSON = decode_json
    # Mock rendering only; execute the real game, input callbacks and cleanup.
    lua.execute("function noop(...) return 1 end")
    for name in set(re.findall(r"\blv_[A-Za-z0-9_]+", SOURCE)):
        lua.globals()[name] = lua.globals().noop
    for name in set(re.findall(r"\bLV_[A-Z0-9_]+", SOURCE)):
        lua.globals()[name] = 1
    lua.execute('''
        paths = {}; routes = {}; callbacks = {}; timers = {}; freed_fonts = {}; texts = {}
        exits = 0; buttons = 0; clock = 1000
        print = function() end
        millis = function() return clock end
        app = {
          current = function() return {entry=TEST_ENTRY, route_base=TEST_ROUTE} end,
          route_base = function() return TEST_ROUTE end,
          exit = function() exits=exits+1 end,
          exiting = function() return exits>0 end
        }
        file = {getcontents=function(path) return TEST_READ_FILE(path) end}
        sjson = {decode=function(raw) return TEST_DECODE_JSON(raw) end}
        lv_canvas_draw_text = function(id, x, y, width, text, descriptor)
          texts[#texts+1]=text
        end
        lv_font_load = function(path) paths[#paths+1]=path; return #paths+100 end
        lv_font_free = function(handle) freed_fonts[#freed_fonts+1]=handle end
        lv_img_set_src = function(id, path)
          if type(path) == "string" then paths[#paths+1]=path end
        end
        lv_canvas_draw_img = function(id, x, y, path)
          if type(path) == "string" then paths[#paths+1]=path end
        end
        key = {UP=1, DOWN=2, LEFT=3, RIGHT=4, HOME=5,
               START=1, SHORT=2, LONG_START=3, LONG_REPEAT=4}
        key.on = function(code, fn) callbacks[code]=fn end
        key.off = function() callbacks={} end
        controller = {state=function(source)
          assert(source == "ble-main")
          return {buttons=buttons, connected=true}
        end}
        tmr = {ALARM_AUTO=1}
        tmr.create = function()
          local timer = {}
          function timer:alarm(ms, mode, fn) self.ms=ms; self.fn=fn end
          function timer:stop() self.stopped=true end
          function timer:unregister() self.unregistered=true end
          timers[#timers+1]=timer
          return timer
        end
        httpd = {GET=1}
        httpd.dynamic = function(method, route, handler) routes[route]=handler end
        httpd.unregister = function(method, route) routes[route]=nil end
    ''')
    lua.execute(SOURCE)
    return lua


class PackageTests(unittest.TestCase):
    def test_device_language_selection(self):
        cases = {
            "zh": "黄金矿工", "zh-CN": "黄金矿工", "zh_SG": "黄金矿工",
            "zh-Hans": "黄金矿工", "zh-Hans-CN": "黄金矿工",
            " ZH_cn ": "黄金矿工", "zh-TW": "黃金礦工", "ZH_HK": "黃金礦工",
            "zh-MO": "黃金礦工", "zh-Hant": "黃金礦工", "zh-Hant-TW": "黃金礦工",
            "en": "Gold Miner", "en-US": "Gold Miner", "EN_GB": "Gold Miner",
            "ja": "ゴールドマイナー", "ja-JP": "ゴールドマイナー", "JA_jp": "ゴールドマイナー",
            "fr": "黄金矿工", "de": "黄金矿工", "ko": "黄金矿工",
            "es": "黄金矿工", "ru": "黄金矿工",
            "unknown": "黄金矿工", "zhx": "黄金矿工", "": "黄金矿工",
        }
        for locale, title in cases.items():
            with self.subTest(locale=locale):
                lua = make_runtime(settings={"/sd/apps/settings.json": json.dumps({"language": locale})})
                self.assertIn(title, list(lua.globals().texts.values()))
                if title == "Gold Miner":
                    self.assertTrue(all(text.isascii() for text in lua.globals().texts.values()))

    def test_language_settings_fallbacks(self):
        cases = [
            ({}, "黄金矿工"),
            ({"/sd/apps/settings.json": "broken JSON"}, "黄金矿工"),
            ({"/sd/apps/settings.json": "true"}, "黄金矿工"),
            ({"/sd/apps/settings.json": '{"language": 42}'}, "黄金矿工"),
            ({"/sd/settings.json": '{"locale": "zh_CN"}'}, "黄金矿工"),
            ({"/sd/apps/settings.json": "broken JSON", "/sd/settings.json": '{"lang": "zh_TW"}'}, "黃金礦工"),
            ({"/sd/apps/settings.json": '{"language": "ja"}', "/sd/settings.json": '{"language": "zh"}'}, "ゴールドマイナー"),
            ({"/sd/apps/settings.json": '{"language": " "}', "/sd/settings.json": '{"language": "zh"}'}, "黄金矿工"),
            ({"/sd/apps/settings.json": '{"language": ""}', "/sd/settings.json": '{"language": "en"}'}, "Gold Miner"),
            ({"/sd/settings.json": '{"lang": "ja_JP"}'}, "ゴールドマイナー"),
        ]
        for settings, title in cases:
            with self.subTest(settings=settings):
                lua = make_runtime(settings=settings)
                self.assertIn(title, list(lua.globals().texts.values()))

    def test_repository_layout(self):
        self.assertEqual({p.name for p in ROOT.iterdir() if p.is_dir()}, {"package", "src"})
        self.assertFalse((ROOT.parent / "hidpad").exists())
        for name in ("app.info", "info.html", "main.lua", "main.png"):
            self.assertTrue((PACKAGE / name).is_file(), name)
        self.assertTrue((ROOT / "src" / "docs" / "安装说明.md").is_file())

    def test_relocated_resources_and_routes(self):
        for entry, route in [
            ("/apps/gold_miner/main.lua", "/gold_miner"),
            ("/sd/apps/renamed_game/main.lua", "/renamed_game"),
            ("S:/apps/other_game/main.lua", "/other_game/"),
        ]:
            with self.subTest(entry=entry):
                lua = make_runtime(entry, route)
                # Start the real game and render a frame as well as its title.
                lua.execute("callbacks[key.UP](key.START); clock=1033; timers[2].fn()")
                prefix = re.sub(r"^(?:/sd|S:)/", "/", entry).rsplit("/", 1)[0]
                paths = list(lua.globals().paths.values())
                self.assertGreater(len(paths), 4)
                for path in paths:
                    self.assertTrue(path.startswith("S:" + prefix + "/"), path)
                    relative = path[len("S:" + prefix + "/"):]
                    self.assertTrue((PACKAGE / relative).is_file(), relative)
                self.assertEqual(len([p for p in paths if "/font/" in p]), 4)
                self.assertEqual(set(lua.globals().routes.keys()),
                                 {route.rstrip("/") + "/", route.rstrip("/") + "/perf"})
                lua.execute('GOLD_MINER_APP.stop("test")')
                self.assertEqual(len(list(lua.globals().routes.keys())), 0)
                self.assertEqual(len(list(lua.globals().freed_fonts.values())), 4)
                for timer in lua.globals().timers.values():
                    self.assertTrue(timer.stopped and timer.unregistered)

    def test_home_and_controller_exit(self):
        for event in ("SHORT", "LONG_START"):
            with self.subTest(event=event):
                lua = make_runtime()
                lua.execute("callbacks[key.HOME](key." + event + ")")
                self.assertEqual(lua.globals().exits, 1)
                lua.execute("timers[2].fn()")
                self.assertIsNone(lua.globals().GOLD_MINER_APP)
        for mask in (4096, 32768):
            with self.subTest(mask=mask):
                lua = make_runtime()
                lua.globals().buttons = mask
                lua.execute("timers[1].fn(); timers[1].fn()")
                self.assertEqual(lua.globals().exits, 1, "exit only on press edge")
        for mask in (16, 8192, 1):
            with self.subTest(action=mask):
                lua = make_runtime()
                lua.globals().buttons = mask
                lua.execute("timers[1].fn()")
                self.assertEqual(lua.globals().exits, 0)
                perf = lua.globals().routes["/gold_miner/perf"]()
                self.assertEqual(json.loads(perf.body)["state"], 2)

    def test_all_resource_declarations(self):
        resources = set(re.findall(r'"((?:font|assets)/[^"\n]+)"', SOURCE))
        self.assertEqual(len(resources), 14)
        for path in resources:
            self.assertTrue((PACKAGE / path).is_file(), path)
        self.assertNotIn("/apps/gold_miner", SOURCE)
        self.assertNotIn('"/gold_miner/', SOURCE)
        # These are intentionally global device settings, not app assets.
        absolute_paths = re.findall(r'"(/sd/[^"\n]+)"', SOURCE)
        self.assertEqual(absolute_paths, ["/sd/apps/settings.json", "/sd/settings.json"])

    def test_manifest_and_archive(self):
        manifest = {}
        for line in (PACKAGE / "app.info").read_text(encoding="utf-8").splitlines():
            if not line.strip() or line.lstrip().startswith(("#", ";")):
                continue
            key, value = map(str.strip, line.split("=", 1))
            self.assertNotIn(key, manifest, "duplicate metadata key")
            manifest[key] = value
        self.assertEqual(manifest["kind"], "app")
        self.assertEqual(manifest["category"], "game")
        self.assertEqual(manifest["catalog_scope"], "community")
        self.assertEqual(manifest["author"], "游侠173")
        for prefix in ("name", "description"):
            self.assertEqual(manifest[prefix], manifest[prefix + "_en"])
            self.assertNotEqual(manifest[prefix + "_ja"], manifest[prefix + "_en"])
        self.assertEqual(manifest["name_ja"], "ゴールドマイナー")
        for key in ("entry", "icon"):
            self.assertFalse(manifest[key].startswith(("/", "S:")))
            self.assertTrue((PACKAGE / manifest[key]).is_file())
        for suffix in ("zh_cn", "zh_tw", "en", "ja", "zh", "zh_hant"):
            self.assertTrue(manifest["name_" + suffix])
            self.assertTrue(manifest["description_" + suffix])
        version = manifest["version"]
        html = (PACKAGE / "info.html").read_text(encoding="utf-8")
        self.assertIn("<strong>" + version + "</strong>", html)
        self.assertIn('VERSION = "' + version + '"', SOURCE)
        for resource in re.findall(r'(?:src|href)="([^"]+)"', html):
            if resource.startswith("data:image/png;base64,"):
                self.assertEqual(base64.b64decode(resource.split(",", 1)[1], validate=True),
                                 (PACKAGE / "main.png").read_bytes())
            elif resource.startswith("https://"):
                self.assertEqual(resource, "https://github.com/youxia173/youxia173-holocubic-apps")
            else:
                self.assertTrue((PACKAGE / resource).is_file(), resource)
        self.assertRegex(html, r'<img class="icon" src="data:image/png;base64,')
        self.assertRegex(html, r'(?s)<footer>.*href="https://github.com/youxia173/youxia173-holocubic-apps".*</footer>')
        archive = ROOT / "src" / "dist" / ("黄金矿工_" + version + "_完整安装包.zip")
        with zipfile.ZipFile(archive) as z:
            files = [p for p in PACKAGE.rglob("*") if p.is_file()]
            self.assertEqual(len(z.namelist()), len(files))
            for path in files:
                self.assertEqual(z.read("gold_miner/" + path.relative_to(PACKAGE).as_posix()),
                                 path.read_bytes())
        display_size = f"{archive.stat().st_size / 1_000_000:.2f} MB"
        self.assertIn("<strong>" + display_size + "</strong>", html)


if __name__ == "__main__":
    unittest.main(verbosity=2)
