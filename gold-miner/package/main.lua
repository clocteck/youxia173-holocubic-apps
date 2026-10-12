-- =========================================
-- Gold Miner (320x240) for HoloCubic / Cubic Lua
-- Controls mirror 2048 / Plane: keys + BLE pad
-- =========================================

local prev = rawget(_G, "GOLD_MINER_APP")
if prev and prev.stop then
  pcall(function() prev.stop("reload") end)
end

-- Firmware file/font paths are SD-root-relative, and LVGL images need a drive.
-- Resolve app-relative resources once from the actual entry, never a fixed app ID.
local current_app = assert(app and app.current and app.current(), "GoldMiner: app context missing")
local entry = assert(current_app.entry, "GoldMiner: app entry missing")
local app_dir = entry:gsub("^[Ss]:/", "/"):gsub("^/sd/", "/"):match("^(.*)/[^/]+$")
assert(app_dir and app_dir:sub(1, 1) == "/", "GoldMiner: invalid app entry")
local function resource_path(relative)
  return "S:" .. app_dir .. "/" .. relative
end
local route_base = (app.route_base and app.route_base()) or current_app.route_base
route_base = assert(route_base, "GoldMiner: app route missing"):gsub("/+$", "")

GOLD_MINER_APP = {
  VERSION = "1.2.11",
  font_handles = {},
}
local APP = GOLD_MINER_APP

local W, H = 320, 240
local MAIN_STYLE = (rawget(_G, "LV_PART_MAIN") or 0) | (rawget(_G, "LV_STATE_DEFAULT") or 0)
local CANVAS_FMT = rawget(_G, "LV_IMG_CF_TRUE_COLOR") or rawget(_G, "CANVAS_FMT_TRUE_COLOR")
local ALIGN_LEFT = rawget(_G, "LV_TEXT_ALIGN_LEFT") or 0
local ALIGN_CENTER = rawget(_G, "LV_TEXT_ALIGN_CENTER") or 1
local ALIGN_RIGHT = rawget(_G, "LV_TEXT_ALIGN_RIGHT") or 2

local canvas_create = rawget(_G, "lv_canvas_create")
local canvas_begin = rawget(_G, "lv_canvas_frame_begin") or rawget(_G, "lv_canvas_begin")
local canvas_end = rawget(_G, "lv_canvas_frame_end") or rawget(_G, "lv_canvas_end")
local canvas_fill = rawget(_G, "lv_canvas_fill_bg") or rawget(_G, "lv_canvas_fill")
local canvas_rect = rawget(_G, "lv_canvas_draw_rect")
local canvas_line = rawget(_G, "lv_canvas_draw_line")
local canvas_arc = rawget(_G, "lv_canvas_draw_arc")
local canvas_text = rawget(_G, "lv_canvas_draw_text")
local canvas_img = rawget(_G, "lv_canvas_draw_img")
local obj_pos = rawget(_G, "lv_obj_set_pos")
local obj_invalidate = rawget(_G, "lv_obj_invalidate")

if not lv_scr_act or not lv_obj_clean or not canvas_create or not canvas_fill then
  if print then print("[GoldMiner] LVGL canvas API missing") end
  return
end

local FONT_12 = rawget(_G, "LV_FONT_MONTSERRAT_12") or 12
local FONT_14 = rawget(_G, "LV_FONT_MONTSERRAT_14") or FONT_12
local FONT_16 = rawget(_G, "LV_FONT_MONTSERRAT_16") or 16
local FONT_20 = rawget(_G, "LV_FONT_MONTSERRAT_20") or FONT_16
local FONT_24 = rawget(_G, "LV_FONT_MONTSERRAT_24") or 24

local function load_font_ref(path, fallback)
  if lv_font_load then
    local ok, handle = pcall(function() return lv_font_load(resource_path(path)) end)
    if ok and type(handle) == "number" and handle > 0 then
      APP.font_handles[#APP.font_handles + 1] = handle
      return handle
    end
  end
  return fallback
end

local function release_fonts()
  if lv_font_free then
    for _, handle in ipairs(APP.font_handles) do
      pcall(function() lv_font_free(handle) end)
    end
  end
  APP.font_handles = {}
end

-- All Chinese fonts ship with this app; do not depend on other installed apps.
local function init_fonts()
  FONT_12 = load_font_ref("font/ui_zh_12.bin", FONT_12)
  FONT_14 = FONT_12
  FONT_16 = load_font_ref("font/ui_zh_16.bin", FONT_16)
  FONT_20 = load_font_ref("font/ui_zh_20.bin", FONT_16)
  FONT_24 = load_font_ref("font/ui_zh_24.bin", FONT_20)
end

init_fonts()

local C = {
  sky = 0x6EC4E8,
  dirt = 0x5A2E14,
  dirt2 = 0x7A3F1C,
  dirt3 = 0xA05A28,
  ground = 0x3D2410,
  black = 0x000000,
  white = 0xFFFFFF,
  soft = 0x402010,
  muted = 0x6A3A18,
  hud = 0xF2C43A,
  gold = 0xF4C430,
  gold_dk = 0xC9971A,
  rock = 0x7A7A7A,
  rock_dk = 0x555555,
  gem = 0x4DE1FF,
  gem_dk = 0x1A8FB5,
  bag = 0xE8D09A,
  pig = 0xC48A4A,
  hook = 0xD0D0D0,
  rope = 0x222222,
  accent = 0xC06010,
  danger = 0xD62828,
  ok = 0x1B8A3A,
  panel = 0xFFF3C8,
  panel2 = 0xFFE39A,
  shop_sel = 0xFFD166,
}


local ST_TITLE = 1
local ST_PLAY = 2
local ST_RESULT = 3
local ST_SHOP = 4
local ST_OVER = 5
local ST_WIN = 6

local HOOK_IDLE = 1
local HOOK_OUT = 2
local HOOK_IN = 3

local PIVOT_X, PIVOT_Y = 160, 34
local PLAY_TOP = 48
local MAX_LEN = 252 -- bottom corners must be reachable
local MIN_LEN = 18
local SWING_MAX = 1.22
local TICK_MS = 33 -- about 30 FPS; cached sprites and partial scene redraw

-- Goals refer to the wallet INCLUDING earlier levels and shop spending.
local LEVELS = {
  { goal = 650, time = 60, count = 10 },
  { goal = 1195, time = 60, count = 11 },
  { goal = 2010, time = 60, count = 12 },
  { goal = 3095, time = 60, count = 13 },
  { goal = 4450, time = 60, count = 14 },
  { goal = 6075, time = 60, count = 15 },
  { goal = 7970, time = 60, count = 16 },
  { goal = 10135, time = 60, count = 17 },
  { goal = 12570, time = 60, count = 18 },
  { goal = 15275, time = 60, count = 18 },
  { goal = 18250, time = 60, count = 18 },
  { goal = 21495, time = 60, count = 18 },
  { goal = 25010, time = 60, count = 18 },
  { goal = 28795, time = 60, count = 18 },
  { goal = 32850, time = 60, count = 18 },
  { goal = 37175, time = 60, count = 18 },
}

local SHOP = {
  { id = "strength", cost = 150, max = 1 },
  { id = "lucky", cost = 100, max = 1 },
  { id = "rockbook", cost = 80, max = 1 },
  { id = "dynamite", cost = 100, max = 5 },
  { id = "polish", cost = 200, max = 1 },
}

local PAD_UP, PAD_DOWN, PAD_LEFT, PAD_RIGHT = 1, 2, 4, 8
local PAD_A, PAD_SELECT, PAD_MENU, PAD_HOME = 16, 4096, 8192, 32768

local floor = math.floor
local abs = math.abs
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local pi = math.pi
local format = string.format
local pcall_fn = pcall

local function device_language()
  local codec = rawget(_G, "json") or rawget(_G, "sjson")
  local lang = ""
  if file and file.getcontents and codec and codec.decode then
    -- Device-wide language settings, not resources belonging to this app.
    for _, path in ipairs({ "/sd/apps/settings.json", "/sd/settings.json" }) do
      local ok, raw = pcall_fn(function() return file.getcontents(path) end)
      if ok and type(raw) == "string" and raw ~= "" then
        local decoded, doc = pcall_fn(function() return codec.decode(raw) end)
        if decoded and type(doc) == "table" then
          local value = tostring(doc.language or doc.locale or doc.lang or "")
          if value ~= "" then lang = value:lower():gsub("_", "-") break end
        end
      end
    end
  end
  if lang == "zh-tw" or lang == "zh-hk" or lang == "zh-mo" or lang:match("^zh%-hant") then return "zh-TW" end
  if lang == "en" or lang:match("^en%-") then return "en" end
  if lang == "ja" or lang:match("^ja%-") then return "ja" end
  return "zh-CN"
end

local LANG = device_language()

local TEXT = {
  ["zh-CN"] = {
    author = "作者：游侠173", title = "黄金矿工",
    start = "上键 / A 开始", hint = "上键放钩  下键炸药  HOME退出",
    goal = "目标 $%d", time = "时间 %02d", level_bombs = "第%d关  炸药%d",
    level_pop = "第%d关", no_tnt = "没有炸药", no_catch = "没有抓取物", blasted = "炸开了!",
    maxed = "已满级", short = "还差$%d", bought = "已购买%s",
    shop_title = "商店  $%d", shop_help = "左右选择  上键购买  下键下一关",
    strength = "力量药水", strength_desc = "下一关：重物拉回加速",
    lucky = "幸运草", lucky_desc = "下一关：袋子奖励更丰厚",
    rockbook = "石头图鉴", rockbook_desc = "下一关：石头价值变为3倍",
    dynamite = "炸药", dynamite_desc = "下键炸掉重物，可留到以后",
    polish = "钻石抛光", polish_desc = "下一关：钻石价值增加50%",
    clear = "过关成功!", level_score = "本关 $%d", wallet = "财富 $%d",
    see_win = "上键/A 查看通关", to_shop = "上键/A 进商店",
    timeout = "时间到", to_end = "上键/A 结束",
    over = "游戏结束", reached = "到达第%d关", again = "上键/A 再来一局",
    win = "通关成功!", cleared = "完成全部%d关", title_back = "上键/A 回标题",
  },
  ["zh-TW"] = {
    author = "作者：遊俠173", title = "黃金礦工",
    start = "上鍵 / A 開始", hint = "上鍵放鉤  下鍵炸藥  HOME退出",
    goal = "目標 $%d", time = "時間 %02d", level_bombs = "第%d關  炸藥%d",
    level_pop = "第%d關", no_tnt = "沒有炸藥", no_catch = "沒有抓取物", blasted = "炸開了!",
    maxed = "已滿級", short = "還差$%d", bought = "已購買%s",
    shop_title = "商店  $%d", shop_help = "左右選擇  上鍵購買  下鍵下一關",
    strength = "力量藥水", strength_desc = "下一關：重物拉回加速",
    lucky = "幸運草", lucky_desc = "下一關：袋子獎勵更豐厚",
    rockbook = "石頭圖鑑", rockbook_desc = "下一關：石頭價值變為3倍",
    dynamite = "炸藥", dynamite_desc = "下鍵炸掉重物，可留到以後",
    polish = "鑽石拋光", polish_desc = "下一關：鑽石價值增加50%",
    clear = "過關成功!", level_score = "本關 $%d", wallet = "財富 $%d",
    see_win = "上鍵/A 查看通關", to_shop = "上鍵/A 進商店",
    timeout = "時間到", to_end = "上鍵/A 結束",
    over = "遊戲結束", reached = "到達第%d關", again = "上鍵/A 再來一局",
    win = "通關成功!", cleared = "完成全部%d關", title_back = "上鍵/A 回標題",
  },
  en = {
    author = "Author: youxia173", title = "Gold Miner",
    start = "Up / A to start", hint = "Up hook   Down TNT   HOME exit",
    goal = "Goal $%d", time = "Time %02d", level_bombs = "Lv%d  TNT %d",
    level_pop = "Level %d", no_tnt = "No dynamite", no_catch = "Nothing hooked", blasted = "Dropped!",
    maxed = "Maxed", short = "Need $%d", bought = "Bought %s",
    shop_title = "Shop  $%d", shop_help = "Left/Right choose   Up buy   Down next",
    strength = "Strength", strength_desc = "Next level: reel heavy items faster",
    lucky = "Clover", lucky_desc = "Next level: bags pay more",
    rockbook = "Rock Book", rockbook_desc = "Next level: rocks worth 3x",
    dynamite = "Dynamite", dynamite_desc = "Down drops the catch. It can be saved",
    polish = "Polish", polish_desc = "Next level: diamonds pay +50%",
    clear = "Level clear!", level_score = "Level $%d", wallet = "Money $%d",
    see_win = "Up/A  see the win", to_shop = "Up/A  open shop",
    timeout = "Time up", to_end = "Up/A  end",
    over = "Game over", reached = "Reached level %d", again = "Up/A  play again",
    win = "You win!", cleared = "Cleared all %d levels", title_back = "Up/A  title",
  },
  ja = {
    author = "作者：youxia173", title = "ゴールドマイナー",
    start = "上 / A で開始", hint = "上でフック  下で爆弾  HOMEで終了",
    goal = "目標 $%d", time = "時間 %02d", level_bombs = "%d面  爆弾%d",
    level_pop = "第%d面", no_tnt = "爆弾がない", no_catch = "何も掴んでいない", blasted = "捨てた!",
    maxed = "上限です", short = "あと$%d", bought = "%sを購入",
    shop_title = "店  $%d", shop_help = "左右で選択  上で購入  下で次へ",
    strength = "パワー", strength_desc = "次の面：重い物を速く巻く",
    lucky = "クローバー", lucky_desc = "次の面：袋の報酬が増える",
    rockbook = "石の図鑑", rockbook_desc = "次の面：岩の価値が3倍",
    dynamite = "爆弾", dynamite_desc = "下で掴んだ物を捨てる。残せる",
    polish = "ダイヤ磨き", polish_desc = "次の面：ダイヤの価値+50%",
    clear = "クリア!", level_score = "この面 $%d", wallet = "所持 $%d",
    see_win = "上/A で結果", to_shop = "上/A で店へ",
    timeout = "時間切れ", to_end = "上/A で終了",
    over = "ゲームオーバー", reached = "第%d面まで", again = "上/A でもう一回",
    win = "全クリア!", cleared = "全部%d面クリア", title_back = "上/A でタイトル",
  },
}

local function tr(key, ...)
  local pack = TEXT[LANG] or TEXT["zh-CN"]
  local value = pack[key] or TEXT["zh-CN"][key] or key
  if select("#", ...) > 0 then return format(value, ...) end
  return value
end

math.randomseed(((millis and millis()) or 1) + ((time and time.get and select(1, time.get())) or 0))
math.random(); math.random(); math.random()

local rect_dsc = { bg_color = C.black, bg_opa = 255, radius = 0, border_width = 0, border_color = C.black, border_opa = 255 }
local line_dsc = { color = C.white, opa = 255, width = 1 }
local text_dsc = { color = C.white, opa = 255, align = ALIGN_LEFT, font_size = 12, font_handle = nil, letter_space = 0 }

local state = ST_TITLE
local level = 1
local money = 0
local score = 0
local goal = 0
local time_left = 0
local sim_ms = 0
local effects = {}
local round_effects = {}
local shop_prices = {}
local result_ready_at = 0
local items = {}
local hook = {
  mode = HOOK_IDLE,
  angle = 0,
  dir = 1,
  len = MIN_LEN,
  catch = nil,
}
local upgrades = {
  strength = 0,
  lucky = 0,
  rockbook = 0,
  dynamite = 0,
  polish = 0,
}
local shop_index = 1
local title_blink = 0
local result_ok = false
local message = ""
local message_until = 0
local last_tick_ms = 0
local dirty = true
local running = true
local field_dirty = true
local last_render_state = nil
local show_fps = false
local last_title_phase = -1
local perf_start, perf_frames, perf_draw_ms = nil, 0, 0
local monitor_count, monitor_started
local fps_label=""
APP.perf = { fps = 0, draw_ms = 0, cached_sprites = 0, cached_bytes = 0,
  dirty_tiles = 0, target_fps = 1000/TICK_MS, refresh_hz = 0 }

-- Reuse a small tile mask and old dynamic bounds; no second full-screen buffer.
local TILE, COLS, ROWS = 16, 20, 12
local tiles, old_bounds = {}, {}
local old_count, bounds_count = 0, 0
local hud_money, hud_goal, hud_second, hud_level, hud_bombs

local function mark_box(x, y, w, h)
  if x+w < 0 or x >= W or y+h < PLAY_TOP or y >= H then return end
  local c1 = math.max(0, math.floor(x/TILE))
  local c2 = math.min(COLS-1, math.floor((x+w)/TILE))
  local r1 = math.max(0, math.floor((y-PLAY_TOP)/TILE))
  local r2 = math.min(ROWS-1, math.floor((y+h-PLAY_TOP)/TILE))
  local changed=false
  for row=r1,r2 do
    for col=c1,c2 do
      local i=row*COLS+col+1
      if not tiles[i] then changed=true; tiles[i]=true end
    end
  end
  return changed
end

local function dynamic_box(x, y, w, h)
  bounds_count = bounds_count + 1
  local box = old_bounds[bounds_count]
  if not box then box = {}; old_bounds[bounds_count] = box end
  box[1],box[2],box[3],box[4] = x,y,w,h
  mark_box(x,y,w,h)
end

local function touches_dirty(x, y, w, h)
  if x+w < 0 or x >= W or y+h < PLAY_TOP or y >= H then return false end
  local c1 = math.max(0, math.floor(x/TILE))
  local c2 = math.min(COLS-1, math.floor((x+w)/TILE))
  local r1 = math.max(0, math.floor((y-PLAY_TOP)/TILE))
  local r2 = math.min(ROWS-1, math.floor((y+h-PLAY_TOP)/TILE))
  for row=r1,r2 do
    for col=c1,c2 do if tiles[row*COLS+col+1] then return true end end
  end
  return false
end

local function now_ms()
  if millis then
    local ok, v = pcall_fn(millis)
    if ok and type(v) == "number" then return v end
  end
  return sim_ms
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function frame_begin()
  if canvas_begin and APP.canvas then pcall_fn(canvas_begin, APP.canvas) end
end

local function frame_end()
  if canvas_end and APP.canvas then
    pcall_fn(canvas_end, APP.canvas)
  elseif obj_invalidate and APP.canvas then
    pcall_fn(obj_invalidate, APP.canvas)
  end
end

local function fill(color)
  pcall_fn(canvas_fill, APP.canvas, color, 255)
end

local function rect(x, y, w, h, color, opa, radius)
  if not canvas_rect or w <= 0 or h <= 0 then return end
  rect_dsc.bg_color = color or C.black
  rect_dsc.bg_opa = opa or 255
  rect_dsc.radius = radius or 0
  rect_dsc.border_width = 0
  pcall_fn(canvas_rect, APP.canvas, floor(x), floor(y), floor(w), floor(h), rect_dsc)
end

local function line(x1, y1, x2, y2, color, opa, width)
  if not canvas_line then return end
  pcall_fn(canvas_line, APP.canvas, floor(x1), floor(y1), floor(x2), floor(y2), color or C.white, opa or 255, width or 1)
end

local function disc(cx, cy, r, color, opa)
  rect(cx - r, cy - r, r * 2, r * 2, color, opa, r)
end

local function circle(cx, cy, r, color, opa, width)
  if not canvas_arc then
    disc(cx, cy, r, color, opa)
    return
  end
  line_dsc.color = color or C.white
  line_dsc.opa = opa or 255
  line_dsc.width = width or 1
  pcall_fn(canvas_arc, APP.canvas, floor(cx), floor(cy), floor(r), 0, 360, line_dsc)
end

local function text(x, y, w, value, font, color, align, opa)
  if not canvas_text then return end
  text_dsc.color = color or C.white
  text_dsc.opa = opa or 255
  text_dsc.align = align or ALIGN_LEFT
  text_dsc.font_handle = font or FONT_12
  text_dsc.letter_space = 0
  pcall_fn(canvas_text, APP.canvas, floor(x), floor(y), floor(w), tostring(value or ""), text_dsc)
end

local function tip_pos()
  local a = hook.angle
  return PIVOT_X + sin(a) * hook.len, PIVOT_Y + cos(a) * hook.len
end


-- Keep the original classic artwork at its native resolution.
local SPRITES = {
  miner = { "assets/miner.png", 100, 44 },
  tnt = { "assets/tnt.png", 24, 30 },
  gold_s = { "assets/gold_s.png", 16, 16 },
  gold_m = { "assets/gold_m.png", 26, 26 },
  gold_l = { "assets/gold_l.png", 36, 36 },
  rock = { "assets/rock.png", 28, 28 },
  gem = { "assets/gem.png", 14, 14 },
  bag = { "assets/bag.png", 22, 22 },
  pig = { "assets/pig.png", 28, 28 },
  pig_right = { "assets/pig_right.png", 28, 28 },
}
for _, sprite in pairs(SPRITES) do
  sprite[1] = resource_path(sprite[1])
end
local image_dsc = { opa = 255 }
local failed_sprites = {}
local sprite_cache = {}
local cache_disabled = not (rawget(_G,"LV_IMG_CF_TRUE_COLOR_ALPHA") and
  ((lv_obj_add_flag and rawget(_G,"LV_OBJ_FLAG_HIDDEN")) or obj_pos) and lv_obj_del)
APP.perf.cache_disabled=cache_disabled

local function free_sprite(cached)
  if cached.id then pcall_fn(lv_obj_del,cached.id) end
  if cached.handle then pcall_fn(lv_snapshot_free,cached.handle) end
end

local function snapshot_sprite(sprite)
  if not (lv_img_create and lv_img_set_src and lv_snapshot_take and lv_snapshot_free and obj_pos and lv_obj_del) then return nil end
  local ok,id=pcall_fn(lv_img_create,lv_scr_act())
  if not ok or not id or id==0 then return nil end
  pcall_fn(obj_pos,id,-1000,-1000)
  local set_ok=pcall_fn(lv_img_set_src,id,sprite[1])
  local taken,handle
  if set_ok then taken,handle=pcall_fn(lv_snapshot_take,id,LV_IMG_CF_TRUE_COLOR_ALPHA) end
  pcall_fn(lv_img_set_src,id,nil)
  pcall_fn(lv_obj_del,id)
  if not taken or not handle or handle==0 then return nil end
  return {handle=handle,source={handle=handle}}
end

local function cache_sprite(kind, sprite)
  if cache_disabled or sprite_cache[kind] == false then return nil end
  if sprite_cache[kind] then return sprite_cache[kind] end
  -- Some device firmware cannot allocate alpha canvases, but supports alpha snapshots.
  local snapshot=snapshot_sprite(sprite)
  if snapshot then
    sprite_cache[kind]=snapshot
    APP.perf.cached_sprites=APP.perf.cached_sprites+1
    APP.perf.cached_bytes=APP.perf.cached_bytes+sprite[2]*sprite[3]*4
    return snapshot
  end
  local ok, id = pcall_fn(canvas_create, lv_scr_act(), sprite[2], sprite[3], LV_IMG_CF_TRUE_COLOR_ALPHA)
  if not ok or not id or id == 0 then
    APP.perf.cache_error="create: "..tostring(id)
    sprite_cache[kind] = false
    return nil
  end
  local hidden
  if lv_obj_add_flag and rawget(_G,"LV_OBJ_FLAG_HIDDEN") then
    hidden=pcall_fn(lv_obj_add_flag,id,LV_OBJ_FLAG_HIDDEN)
  else hidden=pcall_fn(obj_pos,id,-1000,-1000) end
  if not hidden then
    APP.perf.cache_error="hide"
    pcall_fn(lv_obj_del,id); sprite_cache[kind]=false; return nil
  end
  if canvas_begin then pcall_fn(canvas_begin,id) end
  pcall_fn(canvas_fill,id,0,0)
  local drawn, result, err = pcall_fn(canvas_img,id,0,0,sprite[1],image_dsc)
  if canvas_end then pcall_fn(canvas_end,id) end
  if not drawn or result == false or err ~= nil then
    APP.perf.cache_error="decode: "..tostring(err or result)
    pcall_fn(lv_obj_del,id)
    sprite_cache[kind] = false
    return nil
  end
  local cached = { id=id, source={canvas_id=id} }
  sprite_cache[kind] = cached
  APP.perf.cached_sprites = APP.perf.cached_sprites + 1
  APP.perf.cached_bytes = APP.perf.cached_bytes + sprite[2]*sprite[3]*4
  return cached
end
local function draw_sprite(kind, x, y)
  local sprite = SPRITES[kind]
  if not canvas_img or not sprite or failed_sprites[kind] then return false end
  local cached = cache_sprite(kind, sprite)
  local source = cached and cached.source or sprite[1]
  local ok, result, err = pcall_fn(canvas_img, APP.canvas,
    floor(x - sprite[2]/2), floor(y - sprite[3]/2), source, image_dsc)
  if cached and (not ok or result == false or err ~= nil) then
    APP.perf.cache_error="source: "..tostring(err or result)
    -- Older firmware may accept canvases but not canvas-backed image sources.
    free_sprite(cached)
    sprite_cache[kind] = false
    APP.perf.cached_sprites = APP.perf.cached_sprites - 1
    APP.perf.cached_bytes = APP.perf.cached_bytes - sprite[2]*sprite[3]*4
    ok,result,err = pcall_fn(canvas_img,APP.canvas,
      floor(x-sprite[2]/2),floor(y-sprite[3]/2),sprite[1],image_dsc)
  end
  if not ok or result == false or err ~= nil then
    failed_sprites[kind] = true
    return false
  end
  return true
end

local function item_defs()
  return {
    { kind = "gold_s", r = 7, value = 50, weight = 0.7, fill = C.gold, edge = C.gold_dk },
    { kind = "gold_m", r = 11, value = 100, weight = 1.8, fill = C.gold, edge = C.gold_dk },
    { kind = "gold_l", r = 17, value = 500, weight = 4.5, fill = C.gold, edge = C.gold_dk },
    { kind = "rock", r = 12, value = 20, weight = 6, fill = C.rock, edge = C.rock_dk },
    { kind = "gem", r = 6, value = 600, weight = 0.6, fill = C.gem, edge = C.gem_dk },
    { kind = "bag", r = 9, value = 0, weight = 1.3, fill = C.bag, edge = 0x8A4A28 },
    { kind = "pig", r = 10, value = 2, weight = 0.8, fill = C.pig, edge = 0x8A5A30, move = true },
    { kind = "rock", r = 17, value = 30, weight = 8, fill = C.rock, edge = C.rock_dk },
    { kind = "tnt", r = 10, value = 0, weight = 1, fill = C.danger, edge = C.soft },
  }
end

local function overlaps(x, y, r, list)
  for i = 1, #list do
    local it = list[i]
    local dx, dy = it.x - x, it.y - y
    local need = it.r + r + 4
    if dx * dx + dy * dy < need * need then return true end
  end
  return false
end

local function bag_value()
  local roll = math.random(1, 100) + (round_effects.lucky or 0) * 35
  if roll >= 90 then return 500
  elseif roll >= 70 then return 250
  elseif roll >= 40 then return 100
  else return 20 end
end

local function rock_value(base)
  return base * ((round_effects.rockbook or 0) > 0 and 3 or 1)
end

local function spawn_level()
  field_dirty = true
  items = {}
  effects = {}
  message = ""
  round_effects = { strength = upgrades.strength, lucky = upgrades.lucky,
    rockbook = upgrades.rockbook, polish = upgrades.polish }
  -- Classic shop boosts last one round; dynamite remains in inventory.
  upgrades.strength, upgrades.lucky, upgrades.rockbook, upgrades.polish = 0, 0, 0, 0
  local cfg = LEVELS[level]
  goal, time_left, score = cfg.goal, cfg.time, 0
  hook.mode, hook.angle, hook.dir, hook.len, hook.catch = HOOK_IDLE, 0, 1, MIN_LEN, nil

  local defs = item_defs()
  local function add(def, x, y)
    local it = { kind = def.kind, x = x, y = y, r = def.r,
      value = def.value, weight = def.weight, fill = def.fill, edge = def.edge,
      alive = true, move = def.move or false,
      vx = 0 }
    if def.move then
      local speed = level >= 12 and 20 or (level >= 9 and 17 or 14)
      it.vx = math.random(0, 1) == 0 and -speed or speed
    end
    if def.kind == "pig" and level >= 3 and math.random(100) <= (level >= 9 and 65 or 45) then
      it.has_gem, it.value = true, 602
    end
    items[#items + 1] = it
  end
  -- Jittered grid: disjoint cells, no overlap, and every cell inside the swing cone.
  -- Reserve enough guaranteed gold/diamonds even when the wallet was spent in the shop.
  local required = math.max(0, goal - money) + 650
  local guaranteed = 0
  local slots = {}
  for row = 1, 3 do
    for col = 1, 6 do slots[#slots + 1] = { row = row, col = col } end
  end
  for i = #slots, 2, -1 do
    local j = math.random(i)
    slots[i], slots[j] = slots[j], slots[i]
  end
  for i = 1, cfg.count do
    local cell = slots[i]
    local def
    if i <= 2 then def = defs[3]
    elseif i == 3 then def = defs[5]
    else
      local roll = math.random(100)
      if level >= 9 then
        local late = level - 8
        if roll <= 12 then def = defs[1]
        elseif roll <= 24 then def = defs[2]
        elseif roll <= 38 then def = defs[3]
        elseif roll <= 52 + late then def = defs[4]
        elseif roll <= 60 + late then def = defs[8]
        elseif roll <= 70 then def = defs[5]
        elseif roll <= 78 then def = defs[6]
        elseif roll <= 90 then def = defs[9]
        else def = defs[7] end
      elseif roll <= 22 then def = defs[1]
      elseif roll <= 43 then def = defs[2]
      elseif roll <= 59 then def = defs[3]
      elseif roll <= 73 then def = defs[4]
      elseif roll <= 80 then def = defs[8]
      elseif roll <= 87 then def = defs[5]
      elseif roll <= 95 then def = defs[6]
      elseif roll <= 98 or level < 3 then def = defs[7]
      else def = defs[9] end
      if guaranteed < required and cfg.count - i < math.ceil((required - guaranteed) / 500) then
        def = defs[3]
      end
    end
    local x = 35 + (cell.col - 1) * 50 + math.random(-5, 5)
    local y = 104 + (cell.row - 1) * 51 + math.random(-4, 4)
    add(def, x, y)
    if def.kind:sub(1, 4) == "gold" or def.kind == "gem" then
      guaranteed = guaranteed + def.value
    end
  end
  dirty = true
end

local function set_message(msg, ms)
  message = msg or ""
  message_until = now_ms() + (ms or 900)
end

local function start_game()
  level = 1
  money = 0
  upgrades = { strength = 0, lucky = 0, rockbook = 0, dynamite = 1, polish = 0 }
  shop_index = 1
  spawn_level()
  state = ST_PLAY
  set_message(tr("level_pop", level), 1000)
end

local function next_level_or_shop()
  if level >= #LEVELS then
    state = ST_WIN
    dirty = true
    return
  end
  state = ST_SHOP
  for i, item in ipairs(SHOP) do
    shop_prices[i] = math.floor(item.cost * math.random(8, 14) / 10 / 5) * 5
  end
  shop_index = 1
  dirty = true
end

local function finish_level(ok)
  result_ok = ok
  result_ready_at = now_ms() + 650
  message = ""
  state = ST_RESULT
  dirty = true
end

local function pull_speed()
  if not hook.catch then return 195 end
  local boost = (round_effects.strength or 0) > 0 and 1.65 or 1
  local drag = 1
  local kind = hook.catch.kind
  if kind == "gold_l" then drag = 0.7
  elseif kind == "rock" then drag = 0.8 end
  return 105 * boost * drag / (0.5 + hook.catch.weight * 0.55)
end

local function explode_tnt(barrel)
  field_dirty = true
  local queue = { barrel }
  local head = 1
  barrel.alive = false
  while head <= #queue do
    local center = queue[head]
    head = head + 1
    effects[#effects + 1] = { x = center.x, y = center.y, ttl = 0.4, kind = "blast", scale = 1.5 }
    for _, it in ipairs(items) do
      if it.alive then
        local dx, dy = it.x - center.x, it.y - center.y
        if dx*dx + dy*dy <= ((36 + it.r) * 1.5)^2 then
          it.alive = false
          if it.kind == "tnt" then queue[#queue + 1] = it end
        end
      end
    end
  end
end

local function try_catch(x1, y1, x2, y2)
  local vx, vy = x2 - x1, y2 - y1
  local len2 = vx * vx + vy * vy
  local first, first_t
  for _, it in ipairs(items) do
    if it.alive then
      local dx, dy = x1 - it.x, y1 - it.y
      local radius = it.r + 3
      local c = dx * dx + dy * dy - radius * radius
      local t
      if c <= 0 then t = 0
      elseif len2 > 0 then
        local b = dx * vx + dy * vy
        local d = b * b - len2 * c
        if d >= 0 then
          local entry = (-b - sqrt(d)) / len2
          if entry >= 0 and entry <= 1 then t = entry end
        end
      end
      if t and (not first_t or t < first_t) then first, first_t = it, t end
    end
  end
  if not first then return false end
  hook.len = hook.len - sqrt(len2) * (1 - first_t)
  if first.kind == "tnt" then
    explode_tnt(first)
    hook.catch = nil
    return true
  end
  first.alive = false
  field_dirty = true
  if first.kind == "bag" then first.value = bag_value()
  elseif first.kind == "rock" then first.value = rock_value(first.value)
  elseif first.kind == "gem" and (round_effects.polish or 0) > 0 then
    first.value = math.floor(first.value * 1.5)
  elseif first.has_gem and (round_effects.polish or 0) > 0 then
    first.value = 902
  end
  hook.catch = first
  return true
end

local function use_dynamite()
  if upgrades.dynamite <= 0 then
    set_message(tr("no_tnt"), 700)
    return
  end
  if hook.mode ~= HOOK_IN or not hook.catch then
    set_message(tr("no_catch"), 700)
    return
  end
  upgrades.dynamite = upgrades.dynamite - 1
  local x, y = tip_pos()
  effects[#effects + 1] = { x = x, y = y, ttl = 0.4, kind = "blast" }
  hook.catch = nil
  set_message(tr("blasted"), 700)
  dirty = true
end

local function fire_hook()
  if state ~= ST_PLAY then return end
  if hook.mode ~= HOOK_IDLE then return end
  hook.mode = HOOK_OUT
  dirty = true
end

local function buy_shop()
  local item = SHOP[shop_index]
  if not item then return end
  local owned = upgrades[item.id] or 0
  if owned >= item.max then
    set_message(tr("maxed"), 700)
    return
  end
  local price = shop_prices[shop_index] or item.cost
  if money < price then
    set_message(tr("short", price - money), 800)
    return
  end
  money = money - price
  upgrades[item.id] = owned + 1
  set_message(tr("bought", tr(item.id)), 800)
  dirty = true
end

local function leave_shop()
  level = level + 1
  spawn_level()
  state = ST_PLAY
  set_message(tr("level_pop", level), 1000)
end

local function update_play(dt)
  dt = math.min(dt, time_left)
  for i = #effects, 1, -1 do
    effects[i].ttl = effects[i].ttl - dt
    if effects[i].ttl <= 0 then table.remove(effects, i) end
  end
  for _, it in ipairs(items) do
    if it.alive and it.move then
      local nx = it.x + it.vx * dt
      if nx < 20 + it.r or nx > W - 20 - it.r  then
        it.vx = -it.vx
      else
        -- Do not wander inside a gold/rock hitbox.
        local blocked = false
        for _, other in ipairs(items) do
          if other ~= it and other.alive then
            local dx, dy = other.x - nx, other.y - it.y
            if dx * dx + dy * dy < (other.r + it.r + 2)^2 then blocked = true; break end
          end
        end
        if blocked then it.vx = -it.vx else it.x = nx end
      end
    end
  end
  if hook.mode == HOOK_IDLE then
    hook.angle = hook.angle + hook.dir * 1.35 * dt
    if abs(hook.angle) >= SWING_MAX then
      hook.angle = clamp(hook.angle, -SWING_MAX, SWING_MAX)
      hook.dir = -hook.dir
    end
  elseif hook.mode == HOOK_OUT then
    local x1, y1 = tip_pos()
    local sa, ca = sin(hook.angle), cos(hook.angle)
    local boundary = math.min(MAX_LEN, (H - 12 - PIVOT_Y) / ca)
    if abs(sa) > 0.001 then boundary = math.min(boundary, (W / 2 - 10) / abs(sa)) end
    hook.len = math.min(hook.len + 165 * dt, boundary)
    local tx, ty = tip_pos()
    if try_catch(x1, y1, tx, ty) or hook.len >= boundary then hook.mode = HOOK_IN end
  elseif hook.mode == HOOK_IN then
    hook.len = math.max(MIN_LEN, hook.len - pull_speed() * dt)
    local tx, ty = tip_pos()
    if hook.catch then hook.catch.x, hook.catch.y = tx, ty end
    if hook.len <= MIN_LEN then
      if hook.catch then
        local value = hook.catch.value or 0
        score, money = score + value, money + value
        effects[#effects + 1] = { x = 160, y = 70, ttl = 1.1, kind = "cash", value = value }
        hook.catch = nil
      end
      hook.mode = HOOK_IDLE
    end
  end
  time_left = math.max(0, time_left - dt)
  -- Leave the full minute available to earn spending money after reaching the goal.
  if time_left <= 0 then finish_level(money >= goal) end
  dirty = true
end

local function draw_item(it)
  if not it then return end
  local x, y, r = it.x, it.y, it.r
  local sprite_kind = it.kind
  if it.kind == "pig" and (it.vx or 1) >= 0 then sprite_kind = "pig_right" end
  if draw_sprite(sprite_kind, x, y) then
    if it.kind == "rock" and r > 12 then
      draw_sprite("rock", x-4, y)
      draw_sprite("rock", x+4, y)
    end
    if it.has_gem then
      draw_item({kind="gem",x=x+((it.vx or 1)>=0 and 11 or -11),y=y+3,r=6})
    end
    return
  end
  -- Native drawing covers missing PNGs and new artwork such as TNT.
  if it.kind:sub(1, 4) == "gold" then
    rect(x-r, y-r*0.45, r*2, r*1.15, 0x713A12, 255, r*0.3)
    rect(x-r*0.8, y-r*0.85, r*1.5, r*1.6, 0xD78B14, 255, r*0.28)
    rect(x-r*0.72, y-r*0.72, r*1.3, r*1.15, 0xFFD34B, 255, r*0.25)
    line(x-r*0.5, y-r*0.45, x+r*0.15, y-r*0.6, 0xFFF3A0, 255, 2)
    line(x+r*0.35, y, x+r*0.6, y+r*0.4, 0xAD6510, 255, 2)
  elseif it.kind == "rock" then
    rect(x-r, y-r*0.5, r*2, r*1.35, 0x383C40, 255, 4)
    rect(x-r*0.7, y-r*0.9, r*1.4, r*1.6, 0x777D82, 255, 4)
    line(x-r*0.45, y-r*0.5, x+r*0.2, y-r*0.7, 0xB5B8B6, 255, 2)
    line(x, y-r*0.2, x+r*0.5, y+r*0.4, 0x4E5358, 255, 2)
  elseif it.kind == "gem" then
    -- Scanlines form a cut diamond, not a circular gold-like blob.
    for row = -4, 6 do
      local half = row < 0 and (row + 7) or (6-row)
      line(x-half, y+row, x+half, y+row, row < 0 and 0xB4FFFF or 0x26C5E8, 255, 1)
    end
    line(x-6, y, x+6, y, 0x087CBA, 255, 1)
    line(x-2, y-4, x, y+5, C.white, 255, 1)
  elseif it.kind == "bag" then
    rect(x-7, y-4, 14, 13, 0x9D592A, 255, 5)
    rect(x-6, y-5, 11, 12, 0xE6B969, 255, 4)
    rect(x-4, y-9, 8, 4, 0xE6B969, 255, 1)
    line(x-4, y-5, x+4, y-5, 0x633419, 255, 2)
    text(x-5, y-4, 10, "?", FONT_12, 0x633419, ALIGN_CENTER)
  elseif it.kind == "pig" then
    local face = (it.vx or 1) >= 0 and 1 or -1
    rect(x-10, y-5, 19, 12, 0x874626, 255, 5)
    rect(x-9, y-6, 18, 10, 0xD99B5A, 255, 4)
    rect(x+face*7-4, y-6, 8, 9, 0xF3BF83, 255, 3)
    rect(x+face*6-1, y-9, 3, 5, 0x9B5534, 255, 1)
    rect(x+face*8, y-4, 2, 2, C.black)
    local step = floor(now_ms()/140)%2
    rect(x-6, y+4, 3, 3+step, 0x63371F)
    rect(x+4, y+4, 3, 4-step, 0x63371F)
    if it.has_gem then draw_item({kind="gem",x=x+face*11,y=y+3,r=6}) end
  elseif it.kind == "tnt" then
    rect(x-10,y-10,20,21,0x482C20,255,3)
    rect(x-8,y-9,16,19,0xBD3B2D,255,2)
    rect(x-9,y-7,18,3,0xE8BD77)
    rect(x-9,y+5,18,3,0xE8BD77)
    -- Fixed 17x7 pixel lettering fits the barrel without font wrapping.
    local ink = 0xFFF2D0
    line(x-8,y-3,x-4,y-3,ink,255,1)
    line(x-6,y-3,x-6,y+3,ink,255,1)
    line(x-2,y-3,x-2,y+3,ink,255,1)
    line(x-2,y-3,x+2,y+3,ink,255,1)
    line(x+2,y-3,x+2,y+3,ink,255,1)
    line(x+4,y-3,x+8,y-3,ink,255,1)
    line(x+6,y-3,x+6,y+3,ink,255,1)
  end
end

local function draw_miner(center_only)
  if center_only then rect(110,0,100,PLAY_TOP-4,0xF5D778)
  else rect(0,0,W,PLAY_TOP,0xF5D778) end
  if draw_sprite("miner", PIVOT_X, 22) then
    rect(0, PLAY_TOP-4, W, 4, 0x75471D)
    return
  end
  rect(124, 0, 72, PLAY_TOP-3, 0x8BC4CE, 255, 12)
  -- White-bearded miner, hard hat, blue overalls and hand crank.
  rect(147, 20, 25, 20, 0x315582, 255, 5)
  disc(159, 17, 10, 0xF3BE87)
  rect(148, 19, 22, 13, 0xFFF1CF, 255, 6)
  rect(153, 18, 13, 4, 0xFFF9E4, 255, 2)
  rect(155, 22, 9, 3, 0x885435, 255, 1)
  rect(148, 7, 23, 9, 0xEAA529, 255, 5)
  rect(145, 13, 29, 3, 0x8F581B, 255, 1)
  disc(159, 10, 3, 0xFFF2B0)
  rect(153, 16, 2, 2, C.black)
  rect(164, 16, 2, 2, C.black)
  local crank = hook.mode == HOOK_IN and sin(now_ms()/90)*3 or 0
  line(149, 30, 139, 35+crank, 0xF3BE87, 255, 4)
  line(170, 30, 181, 35-crank, 0xF3BE87, 255, 4)
  rect(137, 36, 47, 5, 0x5F361C, 255, 1)
  circle(PIVOT_X, PIVOT_Y, 6, 0x3F3429, 255, 2)
  rect(0, PLAY_TOP-4, W, 4, 0x75471D)
end

local function restore_dirt(x,y,w,h)
  local bottom = y+h
  local a = math.min(bottom,115)
  if y<a then rect(x,y,w,a-y,0x925B30) end
  local b = math.max(y,115)
  a = math.min(bottom,178)
  if b<a then rect(x,b,w,a-b,0x85512B) end
  b = math.max(y,178)
  if b<bottom then rect(x,b,w,bottom-b,0x764727) end
end

local function prepare_dirty(full)
  for i=1,COLS*ROWS do tiles[i] = full or false end
  if not full then
    for i=1,old_count do
      local box=old_bounds[i]; mark_box(box[1],box[2],box[3],box[4])
    end
  end
  bounds_count = 0
  local tx,ty=tip_pos()
  local n=math.max(1,math.ceil(hook.len/12))
  for i=0,n do
    local t=i/n
    dynamic_box(PIVOT_X+(tx-PIVOT_X)*t-3,PIVOT_Y+(ty-PIVOT_Y)*t-3,6,6)
  end
  dynamic_box(tx-14,ty-14,28,28)
  if hook.catch then
    local r=hook.catch.r+19
    dynamic_box(tx-r,ty-r,r*2,r*2)
  end
  for _,it in ipairs(items) do
    if it.alive and it.move then dynamic_box(it.x-30,it.y-20,60,40) end
  end
  for _,fx in ipairs(effects) do
    if fx.kind=="cash" then dynamic_box(fx.x-62,fx.y-(1.1-fx.ttl)*20-3,124,30)
    else dynamic_box(fx.x-32,fx.y-32,64,64) end
  end
  if message~="" and now_ms()<message_until then dynamic_box(74,55,172,28) end
  if money~=hud_money or goal~=hud_goal then mark_box(0,PLAY_TOP,W,2) end
  local label=show_fps and format("%.0ffps %.0fHz",APP.perf.fps,APP.perf.refresh_hz) or ""
  if label~=fps_label or (show_fps and touches_dirty(0,222,108,18)) then mark_box(0,222,108,18) end
  old_count=bounds_count
  -- A transparent sprite must be erased completely before being composited again.
  -- Expand through touching static sprites until all affected artwork is covered.
  if not full then
    local changed
    repeat
      changed=false
      for _,it in ipairs(items) do
        if it.alive and not it.move then
          local r=it.r+6
          if touches_dirty(it.x-r,it.y-r,r*2,r*2) then
            if mark_box(it.x-r,it.y-r,r*2,r*2) then changed=true end
          end
        end
      end
    until not changed
  end
end

local function draw_playfield(full)
  full = full == nil or full
  prepare_dirty(full)
  if full then restore_dirt(0,PLAY_TOP,W,H-PLAY_TOP)
  else
    -- Merge adjacent tiles into horizontal runs before restoring the background.
    for row=0,ROWS-1 do
      local col=0
      while col<COLS do
        if tiles[row*COLS+col+1] then
          local first=col
          repeat col=col+1 until col==COLS or not tiles[row*COLS+col+1]
          restore_dirt(first*TILE,PLAY_TOP+row*TILE,(col-first)*TILE,TILE)
        else col=col+1 end
      end
    end
  end
  local count=0
  for i=1,COLS*ROWS do if tiles[i] then count=count+1 end end
  APP.perf.dirty_tiles=count
  for i=1,22 do
    local x,y=(i*73)%310+4,PLAY_TOP+12+(i*47)%174
    if touches_dirty(x-1,y-1,6,4) then line(x,y,x+3,y+1,0xA66B3B,255,1) end
  end
  draw_miner(not full)
  for _,it in ipairs(items) do
    if it.alive and (it.move or touches_dirty(it.x-it.r-6,it.y-it.r-6,it.r*2+12,it.r*2+12)) then
      draw_item(it)
    end
  end
  local tx, ty = tip_pos()
  line(PIVOT_X, PIVOT_Y, tx, ty, C.rope, 255, 1)
  if hook.catch then draw_item(hook.catch) end
  -- Rotate the claw with the rope; close its fingers around a catch.
  local sa, ca = sin(hook.angle), cos(hook.angle)
  local function claw_line(a, b, c, d)
    line(tx+ca*a+sa*b, ty-sa*a+ca*b, tx+ca*c+sa*d, ty-sa*c+ca*d, 0xE6E7DD, 255, 2)
  end
  local spread = hook.catch and 4 or 7
  claw_line(0,-4,0,1)
  claw_line(0,0,-spread,5); claw_line(-spread,5,-3,9)
  claw_line(0,0,spread,5); claw_line(spread,5,3,9)

  local second=math.ceil(time_left)
  if full or money~=hud_money or goal~=hud_goal then
    rect(0,0,110,PLAY_TOP-4,0xF5D778)
    text(4,2,106,"$"..money,FONT_16,money>=goal and C.ok or C.soft)
    text(4,23,106,tr("goal", goal),FONT_12,C.soft)
  end
  if full or second~=hud_second or level~=hud_level or upgrades.dynamite~=hud_bombs then
    rect(210,0,110,PLAY_TOP-4,0xF5D778)
    text(212,2,104,tr("time", second),FONT_16,time_left<=10 and C.danger or C.soft,ALIGN_RIGHT)
    text(212,24,104,tr("level_bombs", level, upgrades.dynamite),FONT_12,C.soft,ALIGN_RIGHT)
  end
  hud_money,hud_goal,hud_second,hud_level,hud_bombs=money,goal,second,level,upgrades.dynamite
  local progress=W*clamp(money/goal,0,1)
  -- Restore the progress stripe only where the rope/background actually touched it.
  local col=0
  while col<COLS do
    if tiles[col+1] then
      local first=col
      repeat col=col+1 until col==COLS or not tiles[col+1]
      local x=first*TILE
      rect(x,PLAY_TOP,(col-first)*TILE,2,0x925B30)
      if x<progress then rect(x,PLAY_TOP,math.min(progress,col*TILE)-x,2,C.gold) end
    else col=col+1 end
  end
  for _, fx in ipairs(effects) do
    if fx.kind == "cash" then
      text(fx.x-60, fx.y-(1.1-fx.ttl)*20, 120, "+$"..fx.value, FONT_16, 0xFFF4A7, ALIGN_CENTER)
    else
      local r = (5+(0.4-fx.ttl)*55) * (fx.scale or 1)
      circle(fx.x, fx.y, r, 0xFFDF64, 255, 3)
      line(fx.x-r, fx.y, fx.x+r, fx.y, 0xFF9B35, 255, 2)
    end
  end
  if now_ms()<message_until and message~="" then
    rect(76, 57, 168, 23, C.panel, 240, 4)
    text(76, 61, 168, message, FONT_12, C.accent, ALIGN_CENTER)
  end
  if show_fps and touches_dirty(0,222,108,18) then
    text(4,224,104,format("%.0ffps %.0fHz",APP.perf.fps,APP.perf.refresh_hz),FONT_12,0xFFF1C7)
  end
  fps_label=show_fps and format("%.0ffps %.0fHz",APP.perf.fps,APP.perf.refresh_hz) or ""
end

local function draw_title()
  fill(0xF5D778)
  rect(0, 137, W, 103, 0x85512B)
  draw_miner()
  text(0, 49, W, tr("author"), FONT_12, C.muted, ALIGN_CENTER)
  text(0, 65, W, "GOLD MINER", FONT_24, 0x713A12, ALIGN_CENTER)
  text(0, 97, W, tr("title"), FONT_20, C.soft, ALIGN_CENTER)
  local demo = { {"gold_l",55,178,17}, {"rock",105,196,12},
    {"gem",160,173,6}, {"bag",209,195,9}, {"pig",264,177,10} }
  for _, d in ipairs(demo) do draw_item({kind=d[1],x=d[2],y=d[3],r=d[4],vx=1}) end
  if floor(now_ms()/550)%2==0 then text(0, 120, W, tr("start"), FONT_14, C.accent, ALIGN_CENTER) end
  text(0, 215, W, tr("hint"), FONT_12, 0xFFF1C7, ALIGN_CENTER)
end

local function draw_result()
  draw_playfield()
  rect(40, 60, 240, 120, C.panel, 230, 10)
  if result_ok then
    text(40, 78, 240, tr("clear"), FONT_20, C.ok, ALIGN_CENTER)
    text(40, 110, 240, tr("level_score", score), FONT_16, C.soft, ALIGN_CENTER)
    text(40, 136, 240, tr("wallet", money), FONT_14, C.accent, ALIGN_CENTER)
    text(40, 158, 240, (level == #LEVELS and tr("see_win") or tr("to_shop")), FONT_12, C.muted, ALIGN_CENTER)
  else
    text(40, 78, 240, tr("timeout"), FONT_20, C.danger, ALIGN_CENTER)
    text(40, 110, 240, tr("goal", goal), FONT_16, C.soft, ALIGN_CENTER)
    text(40, 136, 240, tr("wallet", money), FONT_14, C.accent, ALIGN_CENTER)
    text(40, 158, 240, tr("to_end"), FONT_12, C.muted, ALIGN_CENTER)
  end
end

local function draw_shop()
  fill(0xF5D778)
  text(0, 8, W, tr("shop_title", money), FONT_16, C.accent, ALIGN_CENTER)
  text(0, 28, W, tr("shop_help"), FONT_12, C.muted, ALIGN_CENTER)

  for i = 1, #SHOP do
    local item = SHOP[i]
    local y = 48 + (i - 1) * 30
    local selected = (i == shop_index)
    rect(16, y, W - 32, 26, selected and C.shop_sel or C.panel2, 255, 6)
    local owned = upgrades[item.id] or 0
    local ix = 33
    if item.id == "dynamite" then
      rect(ix-5,y+7,10,14,C.danger,255,2); line(ix,y+7,ix+5,y+3,C.soft,255,1)
    elseif item.id == "lucky" then
      disc(ix-3,y+9,4,C.ok); disc(ix+3,y+9,4,C.ok); disc(ix,y+15,4,C.ok)
    elseif item.id == "strength" then
      rect(ix-5,y+8,10,13,0xD65035,255,3); rect(ix-3,y+4,6,5,C.soft)
    elseif item.id == "rockbook" then
      rect(ix-7,y+5,14,17,0x76502E,255,2); rect(ix-4,y+8,9,11,0xE5CA91)
    else draw_item({kind="gem",x=ix,y=y+14,r=6}) end
    text(50, y + 6, 110, tr(item.id), FONT_12, selected and C.accent or C.soft, ALIGN_LEFT)
    text(170, y + 6, 65, "$" .. tostring(shop_prices[i] or item.cost), FONT_12, C.soft, ALIGN_LEFT)
    text(230, y + 6, 70, owned .. "/" .. item.max, FONT_12, C.muted, ALIGN_RIGHT)
  end

  local cur = SHOP[shop_index]
  if cur then
    text(0, 210, W, tr(cur.id .. "_desc"), FONT_12, C.soft, ALIGN_CENTER)
  end
  if now_ms() < message_until and message ~= "" then
    text(0, 224, W, message, FONT_12, C.ok, ALIGN_CENTER)
  end
end

local function draw_over()
  fill(C.panel)
  text(0, 70, W, tr("over"), FONT_24, C.danger, ALIGN_CENTER)
  text(0, 110, W, tr("reached", level), FONT_16, C.soft, ALIGN_CENTER)
  text(0, 138, W, tr("wallet", money), FONT_14, C.accent, ALIGN_CENTER)
  text(0, 180, W, tr("again"), FONT_14, C.muted, ALIGN_CENTER)
end

local function draw_win()
  fill(C.panel)
  text(0, 70, W, tr("win"), FONT_24, C.ok, ALIGN_CENTER)
  text(0, 110, W, tr("cleared", #LEVELS), FONT_16, C.soft, ALIGN_CENTER)
  text(0, 138, W, tr("wallet", money), FONT_14, C.accent, ALIGN_CENTER)
  text(0, 180, W, tr("title_back"), FONT_14, C.muted, ALIGN_CENTER)
end

local function render()
  if not APP.canvas then return end
  local started=now_ms()
  local full=field_dirty or state~=last_render_state
  frame_begin()
  if state == ST_TITLE then
    draw_title()
  elseif state == ST_PLAY then
    draw_playfield(full)
  elseif state == ST_RESULT then
    draw_result()
  elseif state == ST_SHOP then
    draw_shop()
  elseif state == ST_OVER then
    draw_over()
  elseif state == ST_WIN then
    draw_win()
  end
  frame_end()
  field_dirty=false
  last_render_state=state
  local finished=now_ms()
  if state==ST_PLAY then
    if not perf_start then perf_start=started end
    perf_frames=perf_frames+1
    perf_draw_ms=perf_draw_ms+math.max(0,finished-started)
    local span=finished-perf_start
    if span>=1000 then
      APP.perf.fps=perf_frames*1000/span
      APP.perf.draw_ms=perf_draw_ms/perf_frames
      perf_frames,perf_draw_ms,perf_start=0,0,finished
      if lv_lvgl_monitor_get then
        local ok,count=pcall_fn(lv_lvgl_monitor_get)
        if ok and type(count)=="number" then
          if monitor_count and finished>monitor_started then
            APP.perf.refresh_hz=math.max(0,count-monitor_count)*1000/(finished-monitor_started)
          end
          monitor_count,monitor_started=count,finished
        end
      end
    end
  else
    perf_start=nil; perf_frames=0; perf_draw_ms=0
    monitor_count,monitor_started=nil,nil
  end
  dirty = false
end

local function on_action()
  if state == ST_TITLE then
    start_game()
  elseif state == ST_PLAY then
    fire_hook()
  elseif state == ST_RESULT then
    if now_ms() < result_ready_at then return end
    if result_ok then
      next_level_or_shop()
    else
      state = ST_OVER
      dirty = true
    end
  elseif state == ST_SHOP then
    buy_shop()
  elseif state == ST_OVER then
    start_game()
  elseif state == ST_WIN then
    state = ST_TITLE
    dirty = true
  end
end

local function on_left()
  if state == ST_SHOP then
    shop_index = shop_index - 1
    if shop_index < 1 then shop_index = #SHOP end
    dirty = true
  end
end

local function on_right()
  if state == ST_SHOP then
    shop_index = shop_index + 1
    if shop_index > #SHOP then shop_index = 1 end
    dirty = true
  end
end

local function on_down()
  if state == ST_PLAY then
    use_dynamite()
  elseif state == ST_SHOP then
    leave_shop()
  end
end

local function on_exit()
  pcall_fn(function() app.exit() end)
end

-- UI init
lv_obj_clean(lv_scr_act())
local root = lv_scr_act()
if lv_obj_set_style_bg_color then pcall_fn(lv_obj_set_style_bg_color, root, C.black, MAIN_STYLE) end
if lv_obj_set_style_bg_opa then pcall_fn(lv_obj_set_style_bg_opa, root, 255, MAIN_STYLE) end
if CANVAS_FMT then
  APP.canvas = canvas_create(root, W, H, CANVAS_FMT)
else
  APP.canvas = canvas_create(root, W, H)
end
if obj_pos and APP.canvas then pcall_fn(obj_pos, APP.canvas, 0, 0) end

last_tick_ms = now_ms()
render()

local key_mod = rawget(_G, "key")
if key_mod and key_mod.on then
  pcall_fn(function() key_mod.off() end)

  local function edge(evt)
    return evt == (key_mod.START or key_mod.SHORT)
  end

  key_mod.on(key_mod.UP, function(evt)
    if edge(evt) then on_action() end
  end)
  key_mod.on(key_mod.DOWN, function(evt)
    if edge(evt) then on_down() end
  end)
  key_mod.on(key_mod.LEFT, function(evt)
    if edge(evt) or evt == key_mod.LONG_REPEAT then on_left() end
  end)
  key_mod.on(key_mod.RIGHT, function(evt)
    if edge(evt) or evt == key_mod.LONG_REPEAT then on_right() end
  end)
  key_mod.on(key_mod.HOME, function(evt)
    if evt == key_mod.SHORT or evt == key_mod.LONG_START then on_exit() end
  end)
end

local controller_buttons = 0
local controller_timer = nil
if controller and controller.state and tmr and tmr.create then
  controller_timer = tmr.create()
  APP.controller_timer = controller_timer
  controller_timer:alarm(40, tmr.ALARM_AUTO, function()
    if not running then return end
    local ok, pad = pcall(function() return controller.state("ble-main") end)
    local buttons = ok and type(pad) == "table" and tonumber(pad.buttons) or 0
    buttons = buttons or 0
    local pressed = buttons & (~controller_buttons)
    controller_buttons = buttons

    if (pressed & (PAD_SELECT | PAD_HOME)) ~= 0 then
      on_exit()
      return
    end
    if (pressed & (PAD_A | PAD_MENU | PAD_UP)) ~= 0 then
      on_action()
    end
    if (pressed & PAD_DOWN) ~= 0 then
      on_down()
    end
    if (pressed & PAD_LEFT) ~= 0 then
      on_left()
    end
    if (pressed & PAD_RIGHT) ~= 0 then
      on_right()
    end
  end)
end

local tick_timer = nil
if tmr and tmr.create then
  tick_timer = tmr.create()
  APP.tick_timer = tick_timer
  tick_timer:alarm(TICK_MS, tmr.ALARM_AUTO, function()
    if not running then return end
    if app and app.exiting then
      local ok, exiting = pcall_fn(app.exiting)
      if ok and exiting then
        APP.stop("exit")
        return
      end
    end

    sim_ms = sim_ms + TICK_MS
    local now = now_ms()
    local elapsed = math.max(0, (now - last_tick_ms) / 1000)
    last_tick_ms = now

    if state == ST_PLAY then
      -- Small physics steps prevent tunnelling. A stalled frame still consumes real time.
      local remaining = math.min(elapsed, 0.5)
      while remaining > 0.00001 and state == ST_PLAY do
        local step = math.min(0.05, remaining)
        update_play(step)
        remaining = remaining - step
      end
      if elapsed > 0.5 and state == ST_PLAY then
        time_left = math.max(0, time_left - (elapsed - 0.5))
        if time_left <= 0 then finish_level(money >= goal) end
      end
    elseif state == ST_TITLE then
      local phase=floor(now/550)%2
      if phase~=last_title_phase then dirty=true; last_title_phase=phase end
    end

    if message ~= "" and now >= message_until then message = ""; dirty = true end
    if dirty then
      render()
    end
  end)
end

function APP.stop(reason)
  running = false
  if controller_timer then
    pcall_fn(function() controller_timer:stop() end)
    pcall_fn(function() controller_timer:unregister() end)
    controller_timer = nil
    APP.controller_timer = nil
  end
  if tick_timer then
    pcall_fn(function() tick_timer:stop() end)
    pcall_fn(function() tick_timer:unregister() end)
    tick_timer = nil
    APP.tick_timer = nil
  end
  pcall_fn(function()
    if key and key.off then key.off() end
  end)
  if rawget(_G, "GOLD_MINER_APP") == APP then
    _G.GOLD_MINER_APP = nil
  end
  for kind,cached in pairs(sprite_cache) do
    if cached then free_sprite(cached) end
    sprite_cache[kind]=nil
  end
  if APP.perf_route and httpd and httpd.unregister then
    pcall_fn(httpd.unregister,httpd.GET,APP.perf_route)
    APP.perf_route=nil
  end
  if APP.perf_home and httpd and httpd.unregister then
    pcall_fn(httpd.unregister,httpd.GET,APP.perf_home)
    APP.perf_home=nil
  end
  if lv_clear then pcall_fn(lv_clear) end
  release_fonts()
end

APP.shutdown = APP.stop
-- Read-only diagnostics, only while this game is running; no file writes per frame.
if httpd and httpd.dynamic and httpd.GET then
  local home_route=route_base .. "/"
  local route=route_base .. "/perf"
  local function perf_response()
    local p=APP.perf
    return {status="200 OK",type="application/json",headers={["cache-control"]="no-store"},
      body=format('{"target_fps":%.2f,"app_fps":%.2f,"refresh_hz":%.2f,"draw_ms":%.2f,"cached_sprites":%d,"cached_bytes":%d,"cache_disabled":%s,"cache_error":"%s","dirty_tiles":%d,"total_tiles":240,"state":%d}',
        p.target_fps,p.fps,p.refresh_hz,p.draw_ms,p.cached_sprites,p.cached_bytes,tostring(p.cache_disabled),
        tostring(p.cache_error or ""):gsub("[\\\"%c]"," "),p.dirty_tiles,state)}
  end
  -- Firmware enables app WebUI dispatch only after a home route is registered.
  local home_ok,home_err=pcall_fn(httpd.dynamic,httpd.GET,home_route,perf_response)
  if home_ok and not home_err then APP.perf_home=home_route end
  local ok,err=pcall_fn(httpd.dynamic,httpd.GET,route,perf_response)
  if ok and not err then APP.perf_route=route end
end
if print then print("[GoldMiner]", APP.VERSION) end
