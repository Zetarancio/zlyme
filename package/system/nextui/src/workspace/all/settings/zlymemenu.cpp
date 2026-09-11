#include "zlymemenu.hpp"

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <string>
#include <vector>

static std::string trim(std::string s)
{
	while (!s.empty() && (s.back() == '\n' || s.back() == '\r' || s.back() == ' ' || s.back() == '\t'))
		s.pop_back();
	return s;
}

static std::string ctl_get(const char *name)
{
	std::string cmd = std::string("zlyme-ctl get ") + name;
	FILE *f = popen(cmd.c_str(), "r");
	if (!f)
		return "";
	char buf[128] = {0};
	if (!fgets(buf, sizeof(buf), f)) {
		pclose(f);
		return "";
	}
	pclose(f);
	return trim(buf);
}

static bool ctl_on(const char *name)
{
	std::string v = ctl_get(name);
	return v == "on" || v == "1" || v == "yes";
}

static void ctl_set(const char *name, const char *val)
{
	std::string cmd = std::string("zlyme-ctl set ") + name + " " + val;
	system(cmd.c_str());
}

static void service_apply(const char *name, const char *init, bool on)
{
	ctl_set(name, on ? "on" : "off");
	std::string cmd = std::string(init) + (on ? " start" : " stop");
	system(cmd.c_str());
}

static std::string hdmi_conn()
{
	const char *cands[] = {
		"/sys/class/drm/card0-HDMI-A-1",
		"/sys/class/drm/card1-HDMI-A-1",
		nullptr,
	};
	for (int i = 0; cands[i]; i++) {
		std::ifstream in(std::string(cands[i]) + "/modes");
		if (in.good())
			return cands[i];
	}
	return "";
}

static std::vector<std::string> hdmi_modes()
{
	std::vector<std::string> out;
	std::string conn = hdmi_conn();
	if (conn.empty())
		return out;
	std::ifstream in(conn + "/modes");
	std::string m;
	while (in >> m)
		out.push_back(m);
	return out;
}

InputReactionHint Zlyme_cycleHdmi(AbstractMenuItem &item)
{
	(void)item;
	auto modes = hdmi_modes();
	if (modes.empty()) {
		MenuList::showOverlay("DSI 640x480@60 only", OverlayDismissMode::DismissOnA);
		return NoOp;
	}
	std::string cur = ctl_get("display_mode");
	std::string next = modes[0];
	bool found = false;
	for (size_t i = 0; i < modes.size(); i++) {
		if (found) {
			next = modes[i];
			break;
		}
		if (modes[i] == cur)
			found = true;
	}
	ctl_set("display_mode", next.c_str());
	std::string conn = hdmi_conn();
	if (!conn.empty()) {
		std::ofstream out(conn + "/mode");
		if (out)
			out << next;
	}
	MenuList::showOverlay(std::string("HDMI ") + next, OverlayDismissMode::DismissOnA);
	return NoOp;
}

static InputReactionHint Zlyme_backup(AbstractMenuItem &item)
{
	(void)item;
	int r = system("tar czf /storage/zlyme-backup.tar.gz -C /storage .config .userdata");
	MenuList::showOverlay(r == 0 ? "Saved /storage/zlyme-backup.tar.gz" : "Backup failed",
		OverlayDismissMode::DismissOnA);
	return NoOp;
}

MenuList *Zlyme_makeMenu()
{
	const std::vector<std::any> on_off_v = {false, true};
	const std::vector<std::string> on_off = {"Off", "On"};
	const std::vector<std::any> gpu_v = {std::string("panfrost"), std::string("libmali")};
	const std::vector<std::string> gpu_l = {"Panfrost", "mali_kbase (next boot)"};

	return new MenuList(MenuItemType::Fixed, "Zlyme", {
		new MenuItem{ListItemType::Generic, "SSH", "Dropbear. Empty-password login is on.",
			on_off_v, on_off,
			[]() -> std::any { return ctl_on("ssh"); },
			[](const std::any &v) { service_apply("ssh", "/etc/init.d/S50dropbear", std::any_cast<bool>(v)); },
			[]() { service_apply("ssh", "/etc/init.d/S50dropbear", true); }},
		new MenuItem{ListItemType::Generic, "Samba", "File share of /storage.",
			on_off_v, on_off,
			[]() -> std::any { return ctl_on("samba"); },
			[](const std::any &v) { service_apply("samba", "/etc/init.d/S70samba", std::any_cast<bool>(v)); },
			[]() { service_apply("samba", "/etc/init.d/S70samba", false); }},
		new MenuItem{ListItemType::Generic, "Syncthing", "Web UI on :8384 when on.",
			on_off_v, on_off,
			[]() -> std::any { return ctl_on("syncthing"); },
			[](const std::any &v) { service_apply("syncthing", "/etc/init.d/S75syncthing", std::any_cast<bool>(v)); },
			[]() { service_apply("syncthing", "/etc/init.d/S75syncthing", false); }},
		new MenuItem{ListItemType::Generic, "GPU", "Panfrost and mali_kbase cannot share the GPU. Applies on next boot.",
			gpu_v, gpu_l,
			[]() -> std::any {
				std::string g = ctl_get("gpu");
				return g.empty() ? std::string("panfrost") : g;
			},
			[](const std::any &v) { ctl_set("gpu", std::any_cast<std::string>(v).c_str()); },
			[]() { ctl_set("gpu", "panfrost"); }},
		new MenuItem{ListItemType::Button, "Backup now", "Save .config and .userdata to /storage/zlyme-backup.tar.gz",
			Zlyme_backup},
	});
}
