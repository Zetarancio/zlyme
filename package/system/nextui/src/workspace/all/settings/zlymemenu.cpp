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

void Zlyme_appendDisplayItems(std::vector<AbstractMenuItem *> &items)
{
	const std::vector<std::any> hz_v = {std::string("60"), std::string("50"), std::string("40")};
	const std::vector<std::string> hz_l = {"60 Hz", "50 Hz (PAL)", "40 Hz"};
	items.push_back(new MenuItem{ListItemType::Generic, "Panel refresh",
		"DSI modes from the ROCKNIX panel timings (60 / 50 / 40).",
		hz_v, hz_l,
		[]() -> std::any {
			std::string r = ctl_get("refresh");
			if (r != "50" && r != "40")
				r = "60";
			return r;
		},
		[](const std::any &v) {
			ctl_set("refresh", std::any_cast<std::string>(v).c_str());
			system("zlyme-ctl apply-refresh");
		},
		[]() {
			ctl_set("refresh", "60");
			system("zlyme-ctl apply-refresh");
		}});
}

static InputReactionHint Zlyme_backup(AbstractMenuItem &item)
{
	(void)item;
	int r = system("sync; tar -acf /storage/zlyme-backup.tar.gz -C /storage .config");
	MenuList::showOverlay(r == 0 ? "Saved /storage/zlyme-backup.tar.gz" : "Backup failed",
		OverlayDismissMode::DismissOnA);
	return NoOp;
}

static InputReactionHint Zlyme_restoreBackup(AbstractMenuItem &item)
{
	(void)item;
	if (!std::ifstream("/storage/zlyme-backup.tar.gz")) {
		MenuList::showOverlay("No /storage/zlyme-backup.tar.gz", OverlayDismissMode::DismissOnA);
		return NoOp;
	}
	int r = system("tar -axf /storage/zlyme-backup.tar.gz -C /storage && sync");
	MenuList::showOverlay(r == 0 ? "Restored. Reboot to apply." : "Restore failed",
		OverlayDismissMode::DismissOnA);
	return NoOp;
}

void Zlyme_appendNetworkItems(std::vector<AbstractMenuItem *> &items)
{
	const std::vector<std::any> on_off_v = {false, true};
	const std::vector<std::string> on_off = {"Off", "On"};

	items.push_back(new MenuItem{ListItemType::Generic, "SSH",
		"OpenSSH with SFTP. Applies immediately. Empty-password login is on.",
		on_off_v, on_off,
		[]() -> std::any { return ctl_on("ssh"); },
		[](const std::any &v) { service_apply("ssh", "/etc/init.d/S50sshd", std::any_cast<bool>(v)); },
		[]() { service_apply("ssh", "/etc/init.d/S50sshd", true); }});
	items.push_back(new MenuItem{ListItemType::Generic, "Samba",
		"File share of /storage. Applies immediately.",
		on_off_v, on_off,
		[]() -> std::any { return ctl_on("samba"); },
		[](const std::any &v) { service_apply("samba", "/etc/init.d/S70samba", std::any_cast<bool>(v)); },
		[]() { service_apply("samba", "/etc/init.d/S70samba", false); }});
	items.push_back(new MenuItem{ListItemType::Generic, "Syncthing",
		"Web UI on :8384. Applies immediately.",
		on_off_v, on_off,
		[]() -> std::any { return ctl_on("syncthing"); },
		[](const std::any &v) { service_apply("syncthing", "/etc/init.d/S75syncthing", std::any_cast<bool>(v)); },
		[]() { service_apply("syncthing", "/etc/init.d/S75syncthing", false); }});
}

void Zlyme_appendSystemItems(std::vector<AbstractMenuItem *> &items)
{
	const std::vector<std::any> gpu_v = {std::string("panfrost"), std::string("libmali")};
	const std::vector<std::string> gpu_l = {"Panfrost", "mali_kbase"};
	const std::vector<std::any> uv_v = {
		std::string("off"), std::string("l1"), std::string("l2"), std::string("l3")};
	const std::vector<std::string> uv_l = {"Off", "L1", "L2", "L3"};

	items.push_back(new MenuItem{ListItemType::Generic, "GPU",
		"libmali (default, GLES+Vulkan ICD) or Panfrost GLES. They cannot share the GPU. Takes effect on next boot. Pick Vulkan inside the emulator, not here.",
		gpu_v, gpu_l,
		[]() -> std::any {
			std::string g = ctl_get("gpu");
			return g.empty() ? std::string("libmali") : g;
		},
		[](const std::any &v) { ctl_set("gpu", std::any_cast<std::string>(v).c_str()); },
		[]() { ctl_set("gpu", "libmali"); }});
	items.push_back(new MenuItem{ListItemType::Generic, "CPU undervolt",
		"ROCKNIX opp-table overlays. Takes effect on next boot.",
		uv_v, uv_l,
		[]() -> std::any {
			std::string u = ctl_get("undervolt");
			if (u != "l1" && u != "l2" && u != "l3")
				u = "off";
			return u;
		},
		[](const std::any &v) {
			ctl_set("undervolt", std::any_cast<std::string>(v).c_str());
			system("zlyme-ctl apply-overlays");
		},
		[]() {
			ctl_set("undervolt", "off");
			system("zlyme-ctl apply-overlays");
		}});

	const std::vector<std::any> on_off_v = {false, true};
	const std::vector<std::string> on_off = {"Off", "On"};
	items.push_back(new MenuItem{ListItemType::Generic, "CPU boost 1992",
		"Unlocks the 1992 MHz OPP for heavy emus. Gets hot. Off keeps Performance at 1800.",
		on_off_v, on_off,
		[]() -> std::any { return ctl_on("boost"); },
		[](const std::any &v) { ctl_set("boost", std::any_cast<bool>(v) ? "on" : "off"); },
		[]() { ctl_set("boost", "off"); }});
	items.push_back(new MenuItem{ListItemType::Generic, "zram swap",
		"384 MiB lz4 swap as an OOM net on 1 GiB. Off if a heavy emu feels spongy.",
		on_off_v, on_off,
		[]() -> std::any { return ctl_on("zram"); },
		[](const std::any &v) {
			ctl_set("zram", std::any_cast<bool>(v) ? "on" : "off");
			system("zlyme-ctl apply-zram");
		},
		[]() {
			ctl_set("zram", "on");
			system("zlyme-ctl apply-zram");
		}});
	items.push_back(new MenuItem{ListItemType::Generic, "USB host (top port)",
		"Upper USB-C host (sticks, hubs). Off saves power. Bottom port is charge only. Takes effect on next boot.",
		on_off_v, on_off,
		[]() -> std::any { return ctl_on("otg"); },
		[](const std::any &v) {
			ctl_set("otg", std::any_cast<bool>(v) ? "on" : "off");
			system("zlyme-ctl apply-overlays");
		},
		[]() {
			ctl_set("otg", "on");
			system("zlyme-ctl apply-overlays");
		}});
	items.push_back(new MenuItem{ListItemType::Generic, "HDMI port",
		"Disable the HDMI controller. Off saves power. Takes effect on next boot.",
		on_off_v, on_off,
		[]() -> std::any { return ctl_on("hdmi"); },
		[](const std::any &v) {
			ctl_set("hdmi", std::any_cast<bool>(v) ? "on" : "off");
			system("zlyme-ctl apply-overlays");
		},
		[]() {
			ctl_set("hdmi", "on");
			system("zlyme-ctl apply-overlays");
		}});
	items.push_back(new MenuItem{ListItemType::Generic, "Second SD slot",
		"Disable sdmmc1. Off saves power. Takes effect on next boot.",
		on_off_v, on_off,
		[]() -> std::any { return ctl_on("sd2"); },
		[](const std::any &v) {
			ctl_set("sd2", std::any_cast<bool>(v) ? "on" : "off");
			system("zlyme-ctl apply-overlays");
		},
		[]() {
			ctl_set("sd2", "on");
			system("zlyme-ctl apply-overlays");
		}});

	const std::vector<std::any> led_v = {
		std::string("battery"), std::string("green"), std::string("red"), std::string("off")};
	const std::vector<std::string> led_l = {"Battery", "Green", "Red", "Off"};
	items.push_back(new MenuItem{ListItemType::Generic, "Status LED",
		"Battery: auto (green, red charging, flash if low). Green/Red/Off lock the colour.",
		led_v, led_l,
		[]() -> std::any {
			std::string l = ctl_get("led");
			if (l != "green" && l != "red" && l != "off" && l != "amber")
				l = "battery";
			if (l == "amber")
				l = "red";
			return l;
		},
		[](const std::any &v) {
			std::string l = std::any_cast<std::string>(v);
			ctl_set("led", l.c_str());
			std::string cmd = std::string("zlyme-led ") + l;
			system(cmd.c_str());
		},
		[]() {
			ctl_set("led", "battery");
			system("zlyme-led battery");
		}});
}

void Zlyme_appendBackupItem(std::vector<AbstractMenuItem *> &items)
{
	items.push_back(new MenuItem{ListItemType::Button, "Backup now",
		"Save /storage/.config to /storage/zlyme-backup.tar.gz",
		Zlyme_backup});
	items.push_back(new MenuItem{ListItemType::Button, "Restore backup",
		"Unpack zlyme-backup.tar.gz. Reboot after.",
		Zlyme_restoreBackup});
}

static std::string sd2_status_line()
{
	FILE *f = popen("zlyme-storage status 2>/dev/null", "r");
	if (!f)
		return "sd2=?";
	char buf[128] = {0};
	if (!fgets(buf, sizeof(buf), f)) {
		pclose(f);
		return "sd2=?";
	}
	pclose(f);
	return trim(buf);
}

static InputReactionHint Zlyme_mountSd2(AbstractMenuItem &item)
{
	(void)item;
	system("zlyme-storage start");
	MenuList::showOverlay(std::string("Library card: ") + sd2_status_line(),
		OverlayDismissMode::DismissOnA);
	return NoOp;
}

static InputReactionHint Zlyme_ejectSd2(AbstractMenuItem &item)
{
	(void)item;
	system("zlyme-storage eject");
	MenuList::showOverlay("Library card ejected", OverlayDismissMode::DismissOnA);
	return NoOp;
}

void Zlyme_appendStorageItems(std::vector<AbstractMenuItem *> &items)
{
	const std::vector<std::any> on_off_v = {false, true};
	const std::vector<std::string> on_off = {"Off", "On"};
	items.push_back(new MenuItem{ListItemType::Generic, "Merge extra storage",
		"Show SD2 and USB games in the same folders as the OS card. Duplicate names keep the OS-card file. Applies immediately.",
		on_off_v, on_off,
		[]() -> std::any { return ctl_on("merge"); },
		[](const std::any &v) {
			ctl_set("merge", std::any_cast<bool>(v) ? "on" : "off");
			system("zlyme-ctl apply-merge");
		},
		[]() {
			ctl_set("merge", "on");
			system("zlyme-ctl apply-merge");
		}});
	items.push_back(new MenuItem{ListItemType::Button, "Mount library card",
		"Second SD or a USB disk with roms/. Games show in the list after this. Also runs at boot via eudev.",
		Zlyme_mountSd2});
	items.push_back(new MenuItem{ListItemType::Button, "Eject library card",
		"Unmount the second SD before pulling it. Do not eject while a game from that card is running.",
		Zlyme_ejectSd2});
}
