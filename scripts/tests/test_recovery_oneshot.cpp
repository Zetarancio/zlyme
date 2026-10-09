// Host stand-in for MenuItem confirm/defer. A runs on_confirm when the
// item is not inside its submenu. B inside the submenu only clears the
// deferred flag and leaves the callback in place, matching
// MenuItem::handleInput.
#include "oneshot.hpp"

#include <functional>
#include <iostream>
#include <string>

struct Item {
	using Callback = std::function<void(Item &)>;
	Callback on_confirm;
	bool deferred = false;
	bool has_submenu = false;
	std::string desc;

	void setConfirmCallback(Callback cb) { on_confirm = std::move(cb); }
	void setDesc(const std::string &d) { desc = d; }
	void setSubMenu() { has_submenu = true; }
	void defer(bool on) { deferred = on; }

	void pressA()
	{
		if (deferred)
			return;
		if (on_confirm)
			on_confirm(*this);
	}

	void pressB()
	{
		if (deferred)
			deferred = false;
	}
};

int main()
{
	int writes = 0;
	Item item;
	item.on_confirm = [&](Item &it) {
		writes++;
		it.setSubMenu();
		detach_verified_write(it, [](Item &again) {
			if (again.has_submenu)
				again.defer(true);
		});
	};

	item.pressA();
	if (writes != 1 || !item.deferred || !item.has_submenu)
		return 1;
	if (item.desc != "Write already verified. Choose Shut down or Restart.")
		return 1;

	item.pressB();
	if (item.deferred || writes != 1)
		return 1;

	item.pressA();
	if (writes != 1 || !item.deferred)
		return 1;

	item.pressB();
	item.pressA();
	if (writes != 1 || !item.deferred)
		return 1;

	std::cout << "recovery oneshot ok\n";
	return 0;
}
