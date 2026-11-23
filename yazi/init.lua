-- Plugins (package.toml; ya pkg add <name> to add one)
require("git"):setup {   -- git status signs in the file list (fetchers in yazi.toml)
	order = 1500,
}

-- The header in the prompt's style (starship.toml): powerline segments for the user, the folder and git, in the theme's colors
-- (plugins/palette.yazi, written by `theme`), and a rule under it. githead.yazi reads the repo; its text goes in the git segment.
local ok, c = pcall(require, "palette")
if not ok then   -- before `theme` has run: Nord
	c = { red = "#bf616a", peach = "#d08770", yellow = "#ebcb8b", crust = "#242933" }
end
require("githead"):setup {
	branch_color = c.crust, remote_branch_color = c.crust, tag_color = c.crust, commit_color = c.crust,
	behind_remote_color = c.crust, ahead_remote_color = c.crust, stashes_color = c.crust, state_color = c.crust,
	staged_color = c.crust, unstaged_color = c.crust, untracked_color = c.crust,
}
for i, child in ipairs(Header._left) do   -- githead added itself after the folder: it is drawn inside the folder's segments instead
	if child[1] == Header.githead then
		table.remove(Header._left, i)
		break
	end
end

local CAP_L, ARROW, CAP_R = "\u{e0b6}", "\u{e0b0}", "\u{e0b4}"   -- as in starship.toml
local ICONS = { Documents = "󰈙 ", Downloads = " ", Music = "󰝚 ", Pictures = " ", Developer = "󰲋 " }   -- its substitutions
local block = function(text, bg) return ui.Span(text):fg(c.crust):bg(bg) end

function Header:cwd()
	local max = self._area.w - self._right_width
	if max <= 0 then
		return ""
	end
	local git = self:githead()
	local user = " 󰀵 " .. (os.getenv("USER") or "") .. " "
	local path = ya.readable_path(tostring(self._current.cwd)):gsub("[^/]+", function(dir) return ICONS[dir] and ICONS[dir]:sub(1, -2) or dir end)
	path = " " .. ui.truncate(path .. self:flags(), { max = math.max(4, max - ui.width(user) - git:width() - 8), rtl = true }) .. " "
	local parts = { ui.Span(CAP_L):fg(c.red), block(user, c.red), ui.Span(ARROW):fg(c.red):bg(c.peach), block(path, c.peach) }
	if git:width() > 0 then
		parts[#parts + 1] = ui.Span(ARROW):fg(c.peach):bg(c.yellow)
		parts[#parts + 1] = ui.Line({ " ", git, " " }):fg(c.crust):bg(c.yellow)
		parts[#parts + 1] = ui.Span(CAP_R):fg(c.yellow)
	else
		parts[#parts + 1] = ui.Span(CAP_R):fg(c.peach)
	end
	return ui.Line(parts)
end

-- The rule: the header gets a second row, a line along its bottom. Root:layout is Yazi 26.9's, with the header 2 rows high.
function Root:layout()
	self._chunks = ui.Layout()
		:direction(ui.Layout.VERTICAL)
		:constraints({
			ui.Constraint.Length(2),
			ui.Constraint.Length(Tabs.height()),
			ui.Constraint.Fill(1),
			ui.Constraint.Length(1),
		})
		:split(self._area)
end

local header_redraw = Header.redraw
function Header:redraw()
	local elements = header_redraw(self)
	elements[#elements + 1] = ui.Bar(ui.Edge.BOTTOM):area(self._area):symbol("─"):style(th.mgr.border_style)
	return elements
end
