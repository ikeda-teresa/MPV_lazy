--[[
SOURCE_ https://github.com/tomasklaen/uosc/tree/main/scripts
COMMIT_ 94ec120923cfdc973cb30a5acdb192c8ae005c19

极简主义设计驱动的多功能界面脚本群组，兼容 thumbfast 新缩略图引擎
]]--

local uosc_version = '4.6.0'

require('lib/std')
assdraw = require('mp.assdraw')
opt = require('mp.options')
utils = require('mp.utils')
msg = require('mp.msg')
osd = mp.create_osd_overlay('ass-events')
infinity = 1e309
quarter_pi_sin = math.sin(math.pi / 4)

--[[ OPTIONS ]]

defaults = {
	timeline_style = 'line',
	timeline_line_width = 2,
	timeline_line_width_fullscreen = 3,
	timeline_line_width_minimized_scale = 10,
	timeline_size_min = 2,
	timeline_size_max = 40,
	timeline_size_min_fullscreen = 0,
	timeline_size_max_fullscreen = 60,
	timeline_start_hidden = false,
	timeline_opacity = 0.9,
	timeline_border = 1,
	timeline_step = 5,
	timeline_chapters_opacity = 0.8,
	timeline_cache = true,
	timeline_persistency = 'idle,audio',

	controls = 'menu,script-stats,gap,play_pause,gap,subtitles,audio,<has_chapter>chapters,<has_many_edition>editions,<has_many_video>video,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen',
	controls_size = 32,
	controls_size_fullscreen = 40,
	controls_margin = 8,
	controls_spacing = 2,
	controls_persistency = 'idle,audio',

	volume = 'right',
	volume_size = 40,
	volume_size_fullscreen = 52,
	volume_opacity = 0.9,
	volume_border = 1,
	volume_step = 1,
	volume_persistency = 'idle,audio',

	speed_opacity = 0.6,
	speed_step = 0.1,
	speed_step_is_factor = false,
	speed_persistency = 'idle,audio',

	menu_item_height = 36,
	menu_item_height_fullscreen = 50,
	menu_min_width = 260,
	menu_min_width_fullscreen = 360,
	menu_opacity = 0.9,
	menu_parent_opacity = 0.6,

	top_bar = 'no-border',
	top_bar_size = 40,
	top_bar_size_fullscreen = 46,
	top_bar_controls = true,
	top_bar_title = 'yes',
	top_bar_alt_title = '',
	top_bar_alt_title_place = 'below',
	top_bar_title_opacity = 0.8,
	top_bar_persistency = 'idle,audio',

	window_border_size = 1,
	window_border_opacity = 0.8,

	autoload = false,
	autoload_types = 'video',
	shuffle = false,

	ui_scale = 1,
	font_scale = 1,
	font_bold = false,
	text_border = 1.2,
	text_width_estimation = true,
	click_threshold = 0,
	click_command = 'cycle pause; script-binding uosc/flash-pause-indicator',
	flash_duration = 1000,
	proximity_in = 40,
	proximity_out = 120,
	foreground = 'ffffff',
	foreground_text = '000000',
	background = '000000',
	background_text = 'ffffff',
	destination_time = 'total',
	time_precision = 0,
	autohide = false,
	buffered_time_threshold = 60,
	pause_indicator = 'flash',
	curtain_opacity = 0.5,
	stream_quality_options = '4320,2160,1440,1080,720,480,360,240,144',
	video_types= '3g2,3gp,asf,avi,f4v,flv,h264,h265,m2ts,m4v,mkv,mov,mp4,mp4v,mpeg,mpg,ogm,ogv,rm,rmvb,ts,vob,webm,wmv,y4m',
	audio_types= 'aac,aiff,ape,au,dsf,dts,flac,m4a,mid,midi,mka,mp3,mp4a,oga,ogg,opus,spx,tak,tta,wav,weba,wma,wv',
	image_types= 'apng,avif,bmp,gif,j2k,jp2,jfif,jpeg,jpg,jxl,mj2,png,svg,tga,tif,tiff,webp',
	subtitle_types = 'aqt,ass,gsub,idx,jss,lrc,mks,pgs,pjs,psb,rt,slt,smi,sub,sup,srt,ssa,ssf,ttxt,txt,usf,vt,vtt',
	default_directory = '~/',
	use_trash = false,
	chapter_ranges = 'openings:30abf964,endings:30abf964,ads:c54e4e80',
	chapter_range_patterns = 'openings:オープニング;endings:エンディング',

	idle_call_menu = 0,                       -- 空闲自动弹出上下文菜单
	custom_font = '',                         -- 自定义界面字体
}
options = table_shallow_copy(defaults)
opt.read_options(options)
-- Normalize values
options.proximity_out = math.max(options.proximity_out, options.proximity_in + 1)
if options.chapter_ranges:sub(1, 4) == '^op|' then options.chapter_ranges = defaults.chapter_ranges end
-- Ensure required environment configuration
if options.autoload then mp.commandv('set', 'keep-open-pause', 'no') end
-- Color shorthands
fg, bg = serialize_rgba(options.foreground).color, serialize_rgba(options.background).color
fgt, bgt = serialize_rgba(options.foreground_text).color, serialize_rgba(options.background_text).color

--[[ CONFIG ]]

-- 上下文菜单的默认内容
local function create_default_menu()
	return {
		{title = '加载', items = {
			{title = '※ 文件浏览器', value = 'script-binding uosc/open-file'},
			{title = '※ 导入 字幕轨', value = 'script-binding uosc/load-subtitles'},
		},},
		{title = '导航', items = {
			{title = '※ 播放列表', value = 'script-binding uosc/playlist'},
			{title = '※ 版本列表', value = 'script-binding uosc/editions'},
			{title = '※ 章节列表', value = 'script-binding uosc/chapters'},
			{title = '※ 视频轨列表', value = 'script-binding uosc/video'},
			{title = '※ 音频轨列表', value = 'script-binding uosc/audio'},
			{title = '※ 字幕轨列表', value = 'script-binding uosc/subtitles'},
			{title = '播放列表乱序重排', value = 'playlist-shuffle'},
		},},
		{title = '※ 截屏', value = 'script-binding uosc/shot'},
		{title = '视频', items = {
			{title = '切换 解码模式', value = 'cycle-values hwdec no auto auto-copy'},
			{title = '切换 去色带状态', value = 'cycle deband'},
			{title = '切换 去隔行状态', value = 'cycle deinterlace'},
			{title = '切换 自动校色', value = 'cycle icc-profile-auto'},
			{title = '切换 时间码解析模式', value = 'cycle correct-pts'},
		},},
		{title = '工具', items = {
			{title = '开关 常驻统计信息', value = 'script-binding stats/display-stats-toggle'},
			{title = '显示控制台', value = 'script-binding console/enable'},
			{title = '切换 窗口边框', value = 'cycle border'},
			{title = '切换 窗口置顶', value = 'cycle ontop'},
			{title = '※ 音频输出设备列表', value = 'script-binding uosc/audio-device'},
			{title = '※ 流式传输品质', value = 'script-binding uosc/stream-quality'},
			{title = '※ 打开 当前文件所在路径', value = 'script-binding uosc/show-in-directory'},
			{title = '※ 打开 设置目录', value = 'script-binding uosc/open-config-directory'},
		},},
		{title = '停止', value = 'stop'},
		{title = '退出mpv', value = 'quit'},
	}
end

config = {
	version = uosc_version,
	-- sets max rendering frequency in case the
	-- native rendering frequency could not be detected
	render_delay = 1 / 60,
	font = options.custom_font or mp.get_property('options/osd-font'),
	types = {
		video = split(options.video_types, ' *, *'),
		audio = split(options.audio_types, ' *, *'),
		image = split(options.image_types, ' *, *'),
		subtitle = split(options.subtitle_types, ' *, *'),
		media = split(options.video_types .. ',' .. options.audio_types .. ',' .. options.image_types, ' *, *'),
		autoload = (function()
			---@type string[]
			local option_values = {}
			for _, name in ipairs(split(options.autoload_types, ' *, *')) do
				local value = options[name .. '_types']
				if type(value) == 'string' then option_values[#option_values + 1] = value end
			end
			return split(table.concat(option_values, ','), ' *, *')
		end)(),
	},
	stream_quality_options = split(options.stream_quality_options, ' *, *'),
	menu_items = (function()
		local input_conf_property = mp.get_property_native('input-conf')
		local input_conf_path = mp.command_native({
			'expand-path', input_conf_property == '' and '~~/input.conf' or input_conf_property,
		})
		local input_conf_meta, meta_error = utils.file_info(input_conf_path)

		-- File doesn't exist
		if not input_conf_meta or not input_conf_meta.is_file then return create_default_menu() end

		local main_menu = {items = {}, items_by_command = {}}
		local by_id = {}

		for line in io.lines(input_conf_path) do
			local key, command, comment = string.match(line, '%s*([%S]+)%s+(.-)%s+#%s*(.-)%s*$')
			local title = ''
			if comment then
				local comments = split(comment, '#')
				local titles = itable_filter(comments, function(v, i) return v:match('^!') or v:match('^menu:') end)
				if titles and #titles > 0 then
					title = titles[1]:match('^!%s*(.*)%s*') or titles[1]:match('^menu:%s*(.*)%s*')
				end
			end
			if title ~= '' then
				local is_dummy = key:sub(1, 1) == '#'
				local submenu_id = ''
				local target_menu = main_menu
				local title_parts = split(title or '', ' *> *')

				for index, title_part in ipairs(#title_parts > 0 and title_parts or {''}) do
					if index < #title_parts then
						submenu_id = submenu_id .. title_part

						if not by_id[submenu_id] then
							local items = {}
							by_id[submenu_id] = {items = items, items_by_command = {}}
							target_menu.items[#target_menu.items + 1] = {title = title_part, items = items}
						end

						target_menu = by_id[submenu_id]
					else
						if command == 'ignore' then break end
						-- If command is already in menu, just append the key to it
						if target_menu.items_by_command[command] then
							local hint = target_menu.items_by_command[command].hint
							target_menu.items_by_command[command].hint = hint and hint .. ', ' .. key or key
						else
							local item = {
								title = title_part,
								hint = not is_dummy and key or nil,
								value = command,
							}
							target_menu.items_by_command[command] = item
							target_menu.items[#target_menu.items + 1] = item
						end
					end
				end
			end
		end

		if #main_menu.items > 0 then
			return main_menu.items
		else
			-- Default context menu
			return create_default_menu()
		end
	end)(),
	chapter_ranges = (function()
		---@type table<string, string[]> Alternative patterns.
		local alt_patterns = {}
		if options.chapter_range_patterns and options.chapter_range_patterns ~= '' then
			for _, definition in ipairs(split(options.chapter_range_patterns, ';+ *')) do
				local name_patterns = split(definition, ' *:')
				local name, patterns = name_patterns[1], name_patterns[2]
				if name and patterns then alt_patterns[name] = split(patterns, ',') end
			end
		end

		---@type table<string, {color: string; opacity: number; patterns?: string[]}>
		local ranges = {}
		if options.chapter_ranges and options.chapter_ranges ~= '' then
			for _, definition in ipairs(split(options.chapter_ranges, ' *,+ *')) do
				local name_color = split(definition, ' *:+ *')
				local name, color = name_color[1], name_color[2]
				if name and color
					and name:match('^[a-zA-Z0-9_]+$') and color:match('^[a-fA-F0-9]+$')
					and (#color == 6 or #color == 8) then
					local range = serialize_rgba(name_color[2])
					range.patterns = alt_patterns[name]
					ranges[name_color[1]] = range
				end
			end
		end
		return ranges
	end)(),
}
-- Adds `{element}_persistency` property with table of flags when the element should be visible (`{paused = true}`)
for _, name in ipairs({'timeline', 'controls', 'volume', 'top_bar', 'speed'}) do
	local option_name = name .. '_persistency'
	local value, flags = options[option_name], {}
	if type(value) == 'string' then
		for _, state in ipairs(split(value, ' *, *')) do flags[state] = true end
	end
	config[option_name] = flags
end

--[[ STATE ]]

display = {width = 1280, height = 720, scale_x = 1, scale_y = 1, initialized = false}
cursor = {hidden = true, hover_raw = false, x = 0, y = 0}
state = {
	os = (function()
		if os.getenv('windir') ~= nil then return 'windows' end
		local homedir = os.getenv('HOME')
		if homedir ~= nil and string.sub(homedir, 1, 6) == '/Users' then return 'macos' end
		return 'linux'
	end)(),
	cwd = mp.get_property('working-directory'),
	path = nil, -- current file path or URL
	title = nil,
	alt_title = nil,
	time = nil, -- current media playback time
	speed = 1,
	duration = nil, -- current media duration
	time_human = nil, -- current playback time in human format
	destination_time_human = nil, -- depends on options.destination_time
	pause = mp.get_property_native('pause'),
	chapters = {},
	current_chapter = nil,
	chapter_ranges = {},
	border = mp.get_property_native('border'),
	fullscreen = mp.get_property_native('fullscreen'),
	maximized = mp.get_property_native('window-maximized'),
	fullormaxed = mp.get_property_native('fullscreen') or mp.get_property_native('window-maximized'),
	render_timer = nil,
	render_last_time = 0,
	volume = nil,
	volume_max = nil,
	mute = nil,
	is_idle = false,
	is_video = false,
	is_audio = false, -- true if file is audio only (mp3, etc)
	is_image = false,
	is_stream = false,
	has_audio = false,
	has_sub = false,
	has_chapter = false,
	has_playlist = false,
	shuffle = options.shuffle,
	cursor_autohide_timer = mp.add_timeout(mp.get_property_native('cursor-autohide') / 1000, function()
		if not options.autohide then return end
		handle_mouse_leave()
	end),
	mouse_bindings_enabled = false,
	uncached_ranges = nil,
	cache = nil,
	cache_buffering = 100,
	cache_underrun = false,
	core_idle = false,
	eof_reached = false,
	render_delay = config.render_delay,
	first_real_mouse_move_received = false,
	playlist_count = 0,
	playlist_pos = 0,
	margin_top = 0,
	margin_bottom = 0,
	hidpi_scale = 1,
}
thumbnail = {width = 0, height = 0, disabled = false, pause = false}
external = {} -- Properties set by external scripts
key_binding_overwrites = {} -- Table of key_binding:mpv_command
Elements = require('elements/Elements')
Menu = require('elements/Menu')

-- State dependent utilities
require('lib/utils')
require('lib/text')
require('lib/ass')
require('lib/menus')

--[[ STATE UPDATERS ]]

function update_display_dimensions()
	local scale = (state.hidpi_scale or 1) * options.ui_scale
	local real_width, real_height = mp.get_osd_size()
	if real_width <= 0 then return end
	local scaled_width, scaled_height = round(real_width / scale), round(real_height / scale)
	display.width, display.height = scaled_width, scaled_height
	display.scale_x, display.scale_y = real_width / scaled_width, real_height / scaled_height
	display.initialized = true

	-- Tell elements about this
	Elements:trigger('display')

	-- Some elements probably changed their rectangles as a reaction to `display`
	Elements:update_proximities()
	request_render()
end

function update_fullormaxed()
	state.fullormaxed = state.fullscreen or state.maximized
	update_display_dimensions()
	Elements:trigger('prop_fullormaxed', state.fullormaxed)
end

function update_human_times()
	if state.time then
		state.time_human = format_time(state.time, state.duration)
		if state.duration then
			local speed = state.speed or 1
			if options.destination_time == 'playtime-remaining' then
				state.destination_time_human = format_time((state.time - state.duration) / speed, state.duration)
			elseif options.destination_time == 'total' then
				state.destination_time_human = format_time(state.duration, state.duration)
			else
				state.destination_time_human = format_time(state.time - state.duration, state.duration)
			end
		else
			state.destination_time_human = nil
		end
	else
		state.time_human = nil
	end
end

-- Notifies other scripts such as console about where the unoccupied parts of the screen are.
function update_margins()
	if display.height == 0 then return end

	-- margins are normalized to window size
	local timeline, top_bar, controls = Elements.timeline, Elements.top_bar, Elements.controls
	local bottom_y = controls and controls.enabled and controls.ay or timeline.ay
	local top, bottom = 0, (display.height - bottom_y) / display.height

	if top_bar.enabled and top_bar:get_visibility() > 0 then
		top = (top_bar.size or 0) / display.height
	end

	if top == state.margin_top and bottom == state.margin_bottom then return end

	state.margin_top = top
	state.margin_bottom = bottom

	utils.shared_script_property_set('osc-margins', string.format('%f,%f,%f,%f', 0, 0, top, bottom))
end
function create_state_setter(name, callback)
	return function(_, value)
		set_state(name, value)
		if callback then callback() end
		request_render()
	end
end

function set_state(name, value)
	state[name] = value
	Elements:trigger('prop_' .. name, value)
end

function update_cursor_position(x, y)
	-- mpv reports initial mouse position on linux as (0, 0), which always
	-- displays the top bar, so we hardcode cursor position as infinity until
	-- we receive a first real mouse move event with coordinates other than 0,0.
	if not state.first_real_mouse_move_received then
		if x > 0 and y > 0 then state.first_real_mouse_move_received = true
		else x, y = infinity, infinity end
	end

	-- add 0.5 to be in the middle of the pixel
	cursor.x, cursor.y = (x + 0.5) / display.scale_x, (y + 0.5) / display.scale_y

	Elements:update_proximities()
	request_render()
end

function handle_mouse_leave()
	-- Slowly fadeout elements that are currently visible
	for _, element_name in ipairs({'timeline', 'volume', 'top_bar'}) do
		local element = Elements[element_name]
		if element and element.proximity > 0 then
			element:tween_property('forced_visibility', element:get_visibility(), 0, function()
				element.forced_visibility = nil
			end)
		end
	end

	cursor.hidden = true
	Elements:update_proximities()
	Elements:trigger('global_mouse_leave')
end

function handle_mouse_enter(x, y)
	cursor.hidden = false
	update_cursor_position(x, y)
	Elements:trigger('global_mouse_enter')
end

function handle_mouse_move(x, y)
	update_cursor_position(x, y)
	Elements:proximity_trigger('mouse_move')
	request_render()

	-- Restart timer that hides UI when mouse is autohidden
	if options.autohide then
		state.cursor_autohide_timer:kill()
		state.cursor_autohide_timer:resume()
	end
end

function handle_file_end()
	local resume = false
	if not state.loop_file then
		if state.has_playlist then resume = state.shuffle and navigate_playlist(1)
		else resume = options.autoload and navigate_directory(1) end
	end
	-- Resume only when navigation happened
	if resume then mp.command('set pause no') end
end
local file_end_timer = mp.add_timeout(1, handle_file_end)
file_end_timer:kill()

function load_file_index_in_current_directory(index)
	if not state.path or is_protocol(state.path) then return end

	local serialized = serialize_path(state.path)
	if serialized and serialized.dirname then
		local files = read_directory(serialized.dirname, config.types.autoload)

		if not files then return end
		sort_filenames(files)
		if index < 0 then index = #files + index + 1 end

		if files[index] then
			mp.commandv('loadfile', join_path(serialized.dirname, files[index]))
		end
	end
end

function update_render_delay(name, fps)
	if fps then state.render_delay = 1 / fps end
end

function observe_display_fps(name, fps)
	if fps then
		mp.unobserve_property(update_render_delay)
		mp.unobserve_property(observe_display_fps)
		mp.observe_property('display-fps', 'native', update_render_delay)
	end
end

function select_current_chapter()
	local current_chapter
	if state.time and state.chapters then
		_, current_chapter = itable_find(state.chapters, function(c) return state.time >= c.time end, true)
	end
	set_state('current_chapter', current_chapter)
end

--[[ STATE HOOKS ]]

-- Click detection
if options.click_threshold > 0 then
	-- Executes custom command for clicks shorter than `options.click_threshold`
	-- while filtering out double clicks.
	local click_time = options.click_threshold / 1000
	local doubleclick_time = mp.get_property_native('input-doubleclick-time') / 1000
	local last_down, last_up = 0, 0
	local click_timer = mp.add_timeout(math.max(click_time, doubleclick_time), function()
		local delta = last_up - last_down
		if delta > 0 and delta < click_time and delta > 0.02 then mp.command(options.click_command) end
	end)
	click_timer:kill()
	mp.set_key_bindings({{'mbtn_left',
		function() last_up = mp.get_time() end,
		function()
			last_down = mp.get_time()
			if click_timer:is_enabled() then click_timer:kill() else click_timer:resume() end
		end,
	},}, 'mouse_movement', 'force')
	mp.enable_key_bindings('mouse_movement', 'allow-vo-dragging+allow-hide-cursor')
end

function update_mouse_pos(_, mouse)
	if not mouse then return end
	if cursor.hover_raw and not mouse.hover then
		handle_mouse_leave()
	else
		if cursor.hidden then handle_mouse_enter(mouse.x, mouse.y) end
		handle_mouse_move(mouse.x, mouse.y)
	end
	cursor.hover_raw = mouse.hover
end
mp.observe_property('mouse-pos', 'native', update_mouse_pos)
mp.observe_property('osc', 'bool', function(name, value) if value == true then mp.set_property('osc', 'no') end end)
mp.register_event('file-loaded', function()
	set_state('path', normalize_path(mp.get_property_native('path')))
	Elements:flash({'top_bar'})
end)
mp.register_event('end-file', function(event)
	if event.reason == 'eof' then
		file_end_timer:kill()
		handle_file_end()
	end
end)
-- Top bar titles
do
	local function update_state_with_template(prop, template)
		-- escape ASS, and strip newlines and trailing slashes and trim whitespace
		local tmp = mp.command_native({'expand-text', template}):gsub('\\n', ' '):gsub('[\\%s]+$', ''):gsub('^%s+', '')
		set_state(prop, ass_escape(tmp))
	end

	local function add_template_listener(template, callback)
		local props = get_expansion_props(template)
		for prop, _ in pairs(props) do
			mp.observe_property(prop, 'native', callback)
		end
		if not next(props) then callback() end
	end

	local function remove_template_listener(callback) mp.unobserve_property(callback) end

	-- Main title
	if #options.top_bar_title > 0 and options.top_bar_title ~= 'no' then
		if options.top_bar_title == 'yes' then
			local template = nil
			local function update_title() update_state_with_template('title', template) end
			mp.observe_property('title', 'string', function(_, title)
				remove_template_listener(update_title)
				template = title
				if template then
					if template:sub(-6) == ' - mpv' then template = template:sub(1, -7) end
					add_template_listener(template, update_title)
				end
			end)
		elseif type(options.top_bar_title) == 'string' then
			add_template_listener(options.top_bar_title, function()
				update_state_with_template('title', options.top_bar_title)
			end)
		end
	end

	-- Alt title
	if #options.top_bar_alt_title > 0 and options.top_bar_alt_title ~= 'no' then
		add_template_listener(options.top_bar_alt_title, function()
			update_state_with_template('alt_title', options.top_bar_alt_title)
		end)
	end
end
mp.observe_property('playback-time', 'number', create_state_setter('time', function()
	-- Create a file-end event that triggers right before file ends
	file_end_timer:kill()
	if state.duration and state.time and not state.pause then
		local remaining = (state.duration - state.time) / state.speed
		if remaining < 5 then
			local timeout = remaining - 0.02
			if timeout > 0 then
				file_end_timer.timeout = timeout
				file_end_timer:resume()
			else handle_file_end() end
		end
	end

	update_human_times()
	select_current_chapter()
end))
mp.observe_property('duration', 'number', create_state_setter('duration', update_human_times))
mp.observe_property('speed', 'number', create_state_setter('speed', update_human_times))
mp.observe_property('track-list', 'native', function(name, value)
	-- checks the file dispositions
	local is_image = false
	local types = {sub = 0, audio = 0, video = 0}
	for _, track in ipairs(value) do
		if track.type == 'video' then
			is_image = track.image
			if not is_image and not track.albumart then types.video = types.video + 1 end
		elseif types[track.type] then types[track.type] = types[track.type] + 1 end
	end
	set_state('is_audio', types.video == 0 and types.audio > 0)
	set_state('is_image', is_image)
	set_state('has_audio', types.audio > 0)
	set_state('has_many_audio', types.audio > 1)
	set_state('has_sub', types.sub > 0)
	set_state('has_many_sub', types.sub > 1)
	set_state('is_video', types.video > 0)
	set_state('has_many_video', types.video > 1)
	Elements:trigger('dispositions')
end)
mp.observe_property('editions', 'number', function(_, editions)
	if editions then set_state('has_many_edition', editions > 1) end
	Elements:trigger('dispositions')
end)
mp.observe_property('chapter-list', 'native', function(_, chapters)
	local chapters, chapter_ranges = serialize_chapters(chapters), {}
	if chapters then chapters, chapter_ranges = serialize_chapter_ranges(chapters) end
	set_state('chapters', chapters)
	set_state('chapter_ranges', chapter_ranges)
	set_state('has_chapter', #chapters > 0)
	select_current_chapter()
	Elements:trigger('dispositions')
end)
mp.observe_property('border', 'bool', create_state_setter('border'))
mp.observe_property('loop-file', 'native', create_state_setter('loop_file'))
mp.observe_property('ab-loop-a', 'number', create_state_setter('ab_loop_a'))
mp.observe_property('ab-loop-b', 'number', create_state_setter('ab_loop_b'))
mp.observe_property('playlist-pos-1', 'number', create_state_setter('playlist_pos'))
mp.observe_property('playlist-count', 'number', function(_, value)
	set_state('playlist_count', value)
	set_state('has_playlist', value > 1)
	Elements:trigger('dispositions')
end)
mp.observe_property('fullscreen', 'bool', create_state_setter('fullscreen', update_fullormaxed))
mp.observe_property('window-maximized', 'bool', create_state_setter('maximized', update_fullormaxed))
mp.observe_property('idle-active', 'bool', function(_, idle)
	set_state('is_idle', idle)
	Elements:trigger('dispositions')
end)
mp.observe_property('pause', 'bool', create_state_setter('pause', function() file_end_timer:kill() end))
mp.observe_property('volume', 'number', create_state_setter('volume'))
mp.observe_property('volume-max', 'number', create_state_setter('volume_max'))
mp.observe_property('mute', 'bool', create_state_setter('mute'))
mp.observe_property('osd-dimensions', 'native', function(name, val)
	update_display_dimensions()
	request_render()
end)
mp.observe_property('display-hidpi-scale', 'native', create_state_setter('hidpi_scale', update_display_dimensions))
mp.observe_property('cache', 'string', create_state_setter('cache'))
mp.observe_property('cache-buffering-state', 'number', create_state_setter('cache_buffering'))
mp.observe_property('demuxer-via-network', 'native', create_state_setter('is_stream', function()
	Elements:trigger('dispositions')
end))
mp.observe_property('demuxer-cache-state', 'native', function(prop, cache_state)
	local cached_ranges, bof, eof, uncached_ranges = nil, nil, nil, nil
	if cache_state then
		cached_ranges, bof, eof = cache_state['seekable-ranges'], cache_state['bof-cached'], cache_state['eof-cached']
		set_state('cache_underrun', cache_state['underrun'])
	else cached_ranges = {} end

	if not (state.duration and (#cached_ranges > 0 or state.cache == 'yes' or
		(state.cache == 'auto' and state.is_stream))) then
		if state.uncached_ranges then set_state('uncached_ranges', nil) end
		return
	end

	-- Normalize
	local ranges = {}
	for _, range in ipairs(cached_ranges) do
		ranges[#ranges + 1] = {
			math.max(range['start'] or 0, 0),
			math.min(range['end'] or state.duration, state.duration),
		}
	end
	table.sort(ranges, function(a, b) return a[1] < b[1] end)
	if bof then ranges[1][1] = 0 end
	if eof then ranges[#ranges][2] = state.duration end
	-- Invert cached ranges into uncached ranges, as that's what we're rendering
	local inverted_ranges = {{0, state.duration}}
	for _, cached in pairs(ranges) do
		inverted_ranges[#inverted_ranges][2] = cached[1]
		inverted_ranges[#inverted_ranges + 1] = {cached[2], state.duration}
	end
	uncached_ranges = {}
	local last_range = nil
	for _, range in ipairs(inverted_ranges) do
		if last_range and last_range[2] + 0.5 > range[1] then -- fuse ranges
			last_range[2] = range[2]
		else
			if range[2] - range[1] > 0.5 then -- skip short ranges
				uncached_ranges[#uncached_ranges + 1] = range
				last_range = range
			end
		end
	end

	set_state('uncached_ranges', uncached_ranges)
end)
mp.observe_property('display-fps', 'native', observe_display_fps)
mp.observe_property('estimated-display-fps', 'native', update_render_delay)
mp.observe_property('eof-reached', 'native', create_state_setter('eof_reached'))
mp.observe_property('core-idle', 'native', create_state_setter('core_idle'))

--[[ KEY BINDS ]]

-- Adds a key binding that respects rerouting set by `key_binding_overwrites` table.
---@param name string
---@param callback fun(event: table)
---@param flags nil|string
function bind_command(name, callback, flags)
	mp.add_key_binding(nil, name, function(...)
		if key_binding_overwrites[name] then mp.command(key_binding_overwrites[name])
		else callback(...) end
	end, flags)
end

bind_command('toggle-ui', function() Elements:toggle({'timeline', 'controls', 'volume', 'top_bar'}) end)
bind_command('flash-ui', function() Elements:flash({'timeline', 'controls', 'volume', 'top_bar'}) end)
bind_command('flash-timeline', function() Elements:flash({'timeline'}) end)
bind_command('flash-top-bar', function() Elements:flash({'top_bar'}) end)
bind_command('flash-volume', function() Elements:flash({'volume'}) end)
bind_command('flash-speed', function() Elements:flash({'speed'}) end)
bind_command('flash-pause-indicator', function() Elements:flash({'pause_indicator'}) end)
bind_command('toggle-progress', function()
	local timeline = Elements.timeline
	if timeline.size_min_override then
		timeline:tween_property('size_min_override', timeline.size_min_override, timeline.size_min, function()
			timeline.size_min_override = nil
		end)
	else
		timeline:tween_property('size_min_override', timeline.size_min, 0)
	end
end)
bind_command('toggle-title', function() Elements.top_bar:toggle_title() end)
bind_command('decide-pause-indicator', function() Elements.pause_indicator:decide() end)
bind_command('menu', function() toggle_menu_with_items() end)
bind_command('menu-blurred', function() toggle_menu_with_items({mouse_nav = true}) end)
local track_loaders = {
	{name = 'subtitles', hint = '字幕轨', prop = 'sub', allowed_types = itable_join(config.types.video, config.types.subtitle)},
	{name = 'audio', hint = '音频轨', prop = 'audio', allowed_types = itable_join(config.types.video, config.types.audio)},
	{name = 'video', hint = '视频轨', prop = 'video', allowed_types = config.types.video},
}
for _, loader in ipairs(track_loaders) do
	local menu_type = 'load-' .. loader.name
	bind_command(menu_type, function()
		if Menu:is_open(menu_type) then Menu:close() return end

		local path = state.path
		if path then
			if is_protocol(path) then
				path = false
			else
				local serialized_path = serialize_path(path)
				path = serialized_path ~= nil and serialized_path.dirname or false
			end
		end
		if not path then
			path = get_default_directory()
		end
		open_file_navigation_menu(
			path,
			function(path) mp.commandv(loader.prop .. '-add', path) end,
			{type = menu_type, title = '导入 ' .. loader.hint, allowed_types = loader.allowed_types}
		)
	end)
end
bind_command('subtitles', create_select_tracklist_type_menu_opener(
	'字幕轨列表', 'sub', 'sid', 'script-binding uosc/load-subtitles'
))
bind_command('audio', create_select_tracklist_type_menu_opener(
	'音频轨列表', 'audio', 'aid', 'script-binding uosc/load-audio'
))
bind_command('video', create_select_tracklist_type_menu_opener(
	'视频轨列表', 'video', 'vid', 'script-binding uosc/load-video'
))
bind_command('playlist', create_self_updating_menu_opener({
	title = '播放列表',
	type = 'playlist',
	list_prop = 'playlist',
	serializer = function(playlist)
		local items = {}
		for index, item in ipairs(playlist) do
			local is_url = item.filename:find('://')
			local item_title = type(item.title) == 'string' and #item.title > 0 and item.title or false
			items[index] = {
				title = item_title or (is_url and item.filename or serialize_path(item.filename).basename),
				hint = tostring(index),
				active = item.current,
				value = index,
			}
		end
		return items
	end,
	on_select = function(index) mp.commandv('set', 'playlist-pos-1', tostring(index)) end,
}))
bind_command('chapters', create_self_updating_menu_opener({
	title = '章节列表',
	type = 'chapters',
	list_prop = 'chapter-list',
	active_prop = 'chapter',
	serializer = function(chapters, current_chapter)
		local items = {}
		chapters = normalize_chapters(chapters)
		for index, chapter in ipairs(chapters) do
			items[index] = {
				title = chapter.title or '',
				hint = format_time(chapter.time, state.duration),
				value = index,
				active = index - 1 == current_chapter,
			}
		end
		return items
	end,
	on_select = function(index) mp.commandv('set', 'chapter', tostring(index - 1)) end,
}))
bind_command('editions', create_self_updating_menu_opener({
	title = '版本列表',
	type = 'editions',
	list_prop = 'edition-list',
	active_prop = 'current-edition',
	serializer = function(editions, current_id)
		local items = {}
		for _, edition in ipairs(editions or {}) do
			items[#items + 1] = {
				title = edition.title or '版本',
				hint = tostring(edition.id + 1),
				value = edition.id,
				active = edition.id == current_id,
			}
		end
		return items
	end,
	on_select = function(id) mp.commandv('set', 'edition', id) end,
}))
bind_command('show-in-directory', function()
	-- Ignore URLs
	if not state.path or is_protocol(state.path) then return end

	if state.os == 'windows' then
		utils.subprocess_detached({args = {'explorer', '/select,', state.path}, cancellable = false})
	elseif state.os == 'macos' then
		utils.subprocess_detached({args = {'open', '-R', state.path}, cancellable = false})
	elseif state.os == 'linux' then
		local result = utils.subprocess({args = {'nautilus', state.path}, cancellable = false})

		-- Fallback opens the folder with xdg-open instead
		if result.status ~= 0 then
			utils.subprocess({args = {'xdg-open', serialize_path(state.path).dirname}, cancellable = false})
		end
	end
end)
bind_command('stream-quality', function()
	if Menu:is_open('stream-quality') then Menu:close() return end

	local ytdl_format = mp.get_property_native('ytdl-format')
	local items = {}

	for _, height in ipairs(config.stream_quality_options) do
		local format = 'bestvideo[height<=?' .. height .. ']+bestaudio/best[height<=?' .. height .. ']'
		items[#items + 1] = {title = height .. 'p', value = format, active = format == ytdl_format}
	end

	Menu:open({type = 'stream-quality', title = '流式传输品质', items = items}, function(format)
		mp.set_property('ytdl-format', format)

		-- Reload the video to apply new format
		-- This is taken from https://github.com/jgreco/mpv-youtube-quality
		-- which is in turn taken from https://github.com/4e6/mpv-reload/
		-- Dunno if playlist_pos shenanigans below are necessary.
		local playlist_pos = mp.get_property_number('playlist-pos')
		local duration = mp.get_property_native('duration')
		local time_pos = mp.get_property('time-pos')

		mp.set_property_number('playlist-pos', playlist_pos)

		-- Tries to determine live stream vs. pre-recorded VOD. VOD has non-zero
		-- duration property. When reloading VOD, to keep the current time position
		-- we should provide offset from the start. Stream doesn't have fixed start.
		-- Decent choice would be to reload stream from it's current 'live' position.
		-- That's the reason we don't pass the offset when reloading streams.
		if duration and duration > 0 then
			local function seeker()
				mp.commandv('seek', time_pos, 'absolute')
				mp.unregister_event(seeker)
			end
			mp.register_event('file-loaded', seeker)
		end
	end)
end)
bind_command('open-file', function()
	if Menu:is_open('open-file') then Menu:close() return end

	local directory
	local active_file

	if state.path == nil or is_protocol(state.path) then
		local serialized = serialize_path(get_default_directory())
		if serialized then
			directory = serialized.path
			active_file = nil
		end
	else
		local serialized = serialize_path(state.path)
		if serialized then
			directory = serialized.dirname
			active_file = serialized.path
		end
	end

	if not directory then
		msg.error('Couldn\'t serialize path "' .. state.path .. '".')
		return
	end

	-- Update active file in directory navigation menu
	local function handle_file_loaded()
		if Menu:is_open('open-file') then
			Elements.menu:activate_one_value(normalize_path(mp.get_property_native('path')))
		end
	end

	open_file_navigation_menu(
		directory,
		function(path) mp.commandv('loadfile', path) end,
		{
			type = 'open-file',
			allowed_types = config.types.media,
			active_path = active_file,
			on_open = function() mp.register_event('file-loaded', handle_file_loaded) end,
			on_close = function() mp.unregister_event(handle_file_loaded) end,
		}
	)
end)
bind_command('shuffle', function() set_state('shuffle', not state.shuffle) end)
bind_command('items', function()
	if state.has_playlist then
		mp.command('script-binding uosc/playlist')
	else
		mp.command('script-binding uosc/open-file')
	end
end)
bind_command('next', function() navigate_item(1) end)
bind_command('prev', function() navigate_item(-1) end)
bind_command('next-file', function() navigate_directory(1) end)
bind_command('prev-file', function() navigate_directory(-1) end)
bind_command('first', function()
	if state.has_playlist then
		mp.commandv('set', 'playlist-pos-1', '1')
	else
		load_file_index_in_current_directory(1)
	end
end)
bind_command('last', function()
	if state.has_playlist then
		mp.commandv('set', 'playlist-pos-1', tostring(state.playlist_count))
	else
		load_file_index_in_current_directory(-1)
	end
end)
bind_command('first-file', function() load_file_index_in_current_directory(1) end)
bind_command('last-file', function() load_file_index_in_current_directory(-1) end)
bind_command('delete-file-next', function()
	local next_file = nil
	local is_local_file = state.path and not is_protocol(state.path)

	if is_local_file then
		if Menu:is_open('open-file') then Elements.menu:delete_value(state.path) end
	end

	if state.has_playlist then
		mp.commandv('playlist-remove', 'current')
	else
		if is_local_file then
			local paths, current_index = get_adjacent_files(state.path, config.types.autoload)
			if paths and current_index then
				local index, path = decide_navigation_in_list(paths, current_index, 1)
				if path then next_file = path end
			end
		end

		if next_file then mp.commandv('loadfile', next_file)
		else mp.commandv('stop') end
	end

	if is_local_file then delete_file(state.path) end
end)
bind_command('delete-file-quit', function()
	mp.command('stop')
	if state.path and not is_protocol(state.path) then delete_file(state.path) end
	mp.command('quit')
end)
bind_command('audio-device', create_self_updating_menu_opener({
	title = '音频输出设备列表',
	type = 'audio-device-list',
	list_prop = 'audio-device-list',
	active_prop = 'audio-device',
	serializer = function(audio_device_list, current_device)
		current_device = current_device or 'auto'
		local ao = mp.get_property('current-ao') or ''
		local items = {}
		for _, device in ipairs(audio_device_list) do
			if device.name == 'auto' or string.match(device.name, '^' .. ao) then
				local hint = string.match(device.name, ao .. '/(.+)')
				if not hint then hint = device.name end
				items[#items + 1] = {
					title = device.description,
					hint = hint,
					active = device.name == current_device,
					value = device.name,
				}
			end
		end
		return items
	end,
	on_select = function(name) mp.commandv('set', 'audio-device', name) end,
}))
bind_command('open-config-directory', function()
	local config_path = mp.command_native({'expand-path', '~~/mpv.conf'})
	local config = serialize_path(normalize_path(config_path))

	if config then
		local args

		if state.os == 'windows' then
			args = {'explorer', '/select,', config.path}
		elseif state.os == 'macos' then
			args = {'open', '-R', config.path}
		elseif state.os == 'linux' then
			args = {'xdg-open', config.dirname}
		end

		utils.subprocess_detached({args = args, cancellable = false})
	else
		msg.error('Couldn\'t serialize config path "' .. config_path .. '".')
	end
end)

-- 菜单专用截屏
mp.add_key_binding(nil, 'shot', function()
	if Menu:is_open() then
		local bak_opt1, bak_opt2, bak_opt3, bak_opt4 = options.curtain_opacity, options.menu_opacity, options.menu_parent_opacity, options.pause_indicator
		options.curtain_opacity, options.menu_opacity, options.menu_parent_opacity = 0, 0, 0
		-- 并非所有元素支持透明
		local paused = mp.get_property_bool('pause')
		if paused then
			mp.add_timeout(200 / 1000, function() -- 延迟过低可能产生闪烁
				mp.command('screenshot window')
				options.curtain_opacity, options.menu_opacity, options.menu_parent_opacity = bak_opt1, bak_opt2, bak_opt3
			end)
		else
			options.pause_indicator = 'manual'
			mp.set_property_bool('pause', true)
			mp.add_timeout(200 / 1000, function()
				mp.command('screenshot window')
				mp.set_property_bool('pause', false)
				options.pause_indicator = bak_opt4
				options.curtain_opacity, options.menu_opacity, options.menu_parent_opacity = bak_opt1, bak_opt2, bak_opt3
			end)
		end
	else
		mp.command('screenshot window')
	end
end)

-- 空闲自动弹出上下文菜单
if type(options.idle_call_menu) == 'number' then
	if options.idle_call_menu <= 2 and options.idle_call_menu > config.render_delay then
		mp.observe_property('idle-active', 'bool', function(_, value)
			if value == true then mp.add_timeout(options.idle_call_menu, function() if Menu:is_open() then return else mp.command('script-binding uosc/menu-blurred') end end) end
		end)
	end
end

--[[ MESSAGE HANDLERS ]]

mp.register_script_message('show-submenu', function(id) toggle_menu_with_items({submenu = id}) end)
mp.register_script_message('show-submenu-blurred', function(id)
	toggle_menu_with_items({submenu = id, mouse_nav = true})
end)
mp.register_script_message('get-version', function(script)
	mp.commandv('script-message-to', script, 'uosc-version', config.version)
end)
mp.register_script_message('open-menu', function(json, submenu_id)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or type(data.items) ~= 'table' then
		msg.error('open-menu: received json didn\'t produce a table with menu configuration')
	else
		if data.type and Menu:is_open(data.type) then Menu:close()
		else open_command_menu(data, {submenu = submenu_id, on_close = data.on_close}) end
	end
end)
mp.register_script_message('update-menu', function(json)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or type(data.items) ~= 'table' then
		msg.error('update-menu: received json didn\'t produce a table with menu configuration')
	else
		local menu = data.type and Menu:is_open(data.type)
		if menu then menu:update(data)
		else open_command_menu(data) end
	end
end)
mp.register_script_message('thumbfast-info', function(json)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or not data.width or not data.height then
		thumbnail.disabled = true
		msg.error('thumbfast-info: received json didn\'t produce a table with thumbnail information')
	else
		thumbnail = data
		request_render()
	end
end)
mp.register_script_message('set', function(name, value)
	external[name] = value
	Elements:trigger('external_prop_' .. name, value)
end)
mp.register_script_message('toggle-elements', function(elements) Elements:toggle(split(elements, ' *, *')) end)
mp.register_script_message('set-min-visibility', function(visibility, elements)
	local fraction = tonumber(visibility)
	local ids = split(elements and elements ~= '' and elements or 'timeline,controls,volume,top_bar', ' *, *')
	if fraction then Elements:set_min_visibility(clamp(0, fraction, 1), ids) end
end)
mp.register_script_message('flash-elements', function(elements) Elements:flash(split(elements, ' *, *')) end)
mp.register_script_message('overwrite-binding', function(name, command) key_binding_overwrites[name] = command end)

--[[ ELEMENTS ]]

require('elements/WindowBorder'):new()
require('elements/BufferingIndicator'):new()
require('elements/PauseIndicator'):new()
require('elements/TopBar'):new()
require('elements/Timeline'):new()
if options.controls and options.controls ~= 'never' then require('elements/Controls'):new() end
if itable_index_of({'left', 'right'}, options.volume) then require('elements/Volume'):new() end
require('elements/Curtain'):new()
