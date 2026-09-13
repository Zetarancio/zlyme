#include "wifimenu.hpp"
#include "keyboardprompt.hpp"
#include "zlymemenu.hpp"
#include "btmenu.hpp"

#include <unordered_set>
#include <map>

#include <mutex>
#include <shared_mutex>
typedef std::shared_mutex Lock;
typedef std::unique_lock<Lock> WriteLock;
typedef std::shared_lock<Lock> ReadLock;

using namespace Wifi;
using namespace std::placeholders;

Menu::Menu(const int &globalQuit, int &globalDirty) : MenuList(MenuItemType::Fixed, "Network", {}), globalQuit(globalQuit), globalDirty(globalDirty)
{
    toggleItem = new MenuItem(ListItemType::Generic, "WiFi", "Radio on or off. Leave this on to scan and connect.", {false, true}, {"Off", "On"},
                              std::bind(&Menu::getWifToggleState, this),
                              std::bind(&Menu::setWifiToggleState, this, std::placeholders::_1),
                              std::bind(&Menu::resetWifiToggleState, this));
    diagItem = new MenuItem(ListItemType::Generic, "WiFi diagnostics", "Write extra WiFi logs.", {false, true}, {"Off", "On"},
                              std::bind(&Menu::getWifDiagnosticsState, this),
                              std::bind(&Menu::setWifiDiagnosticsState, this, std::placeholders::_1),
                              std::bind(&Menu::resetWifiDiagnosticsState, this));
    Zlyme_appendNetworkItems(serviceItems);
    btItem = new MenuItem(ListItemType::Button, "Bluetooth", "Pair HID controllers and headsets.", DeferToSubmenu, new Bluetooth::Menu(globalQuit, globalDirty));
    items.push_back(toggleItem);
    items.push_back(diagItem);
    items.push_back(btItem);
    items.insert(items.end(), serviceItems.begin(), serviceItems.end());

    // best effort layout based on the platform defines, user should really call performLayout manually
    MenuList::performLayout((SDL_Rect){0, 0, FIXED_WIDTH, FIXED_HEIGHT});
    layout_called = false;

    worker = std::thread{&Menu::updater, this};
}

Menu::~Menu()
{
    quit = true;
    if (worker.joinable())
        worker.join();
}

InputReactionHint Menu::handleInput(int &dirty, int &quit)
{
    auto ret = MenuList::handleInput(dirty, quit);
    if (selectionDirty)
    {
        dirty = true;
        selectionDirty = false; // handled
        //LOG_info("collected workerDirty\n");
    }
    return ret;
}

std::any Menu::getWifToggleState() const
{
    return WIFI_enabled();
}

void Menu::setWifiToggleState(const std::any &on)
{
    auto state = std::any_cast<bool>(on);
    ScopedOverlay overlay(state ? "Enabling WiFi..." : "Disabling WiFi...");
    WIFI_enable(state);
}

void Menu::resetWifiToggleState()
{
    //
}

std::any Menu::getWifDiagnosticsState() const
{
    return WIFI_diagnosticsEnabled();
}

void Menu::setWifiDiagnosticsState(const std::any &on)
{
    WIFI_diagnosticsEnable(std::any_cast<bool>(on));
}

void Menu::resetWifiDiagnosticsState()
{
    //
}

template <typename Map>
bool key_compare(Map const &lhs, Map const &rhs)
{
    return lhs.size() == rhs.size() && std::equal(lhs.begin(), lhs.end(), rhs.begin(),
                                                  [](auto a, auto b)
                                                  { return a.first == b.first; });
}

void Menu::updater()
{
    int pollSecs = 2;

    while (!quit && !globalQuit)
    {
        if (WIFI_enabled())
        {
            WIFI_connection connection;
            if (WIFI_connectionInfo(&connection) < 0)
            {
                std::this_thread::sleep_for(std::chrono::seconds(pollSecs));
                continue;
            }

            std::vector<WIFI_network> scanResults(SCAN_MAX_RESULTS);
            int cnt = WIFI_scan(scanResults.data(), SCAN_MAX_RESULTS);
            if (cnt < 0)
            {
                std::this_thread::sleep_for(std::chrono::seconds(pollSecs));
                continue;
            }

            std::map<std::string, WIFI_network> scanSsids;
            for (int i = 0; i < cnt; i++)
                scanSsids.emplace(scanResults[i].ssid, scanResults[i]);

            bool menuOpen = false;
            {
                ReadLock r(itemLock);
                for (auto i : items)
                {
                    if (i->isDeferred())
                    {
                        menuOpen = true;
                        break;
                    }
                }
            }

            if (!menuOpen)
            {
                std::string selectedName;
                bool selectionApplied = false;
                std::vector<AbstractMenuItem *> stale;

                {
                    WriteLock w(itemLock);
                    selectedName = getSelectedItemName();
                    for (auto *i : items)
                    {
                        bool keep = (i == toggleItem || i == diagItem || i == btItem);
                        for (auto *s : serviceItems)
                        {
                            if (i == s)
                                keep = true;
                        }
                        if (!keep)
                            stale.push_back(i);
                    }
                    items.clear();
                    items.push_back(toggleItem);
                    items.push_back(diagItem);
                    items.push_back(btItem);
                    items.insert(items.end(), serviceItems.begin(), serviceItems.end());

                    for (auto &[s, r] : scanSsids)
                    {
                        bool connected = false;
                        bool hasCredentials = WIFI_isKnown(r.ssid, r.security);

                        if (strcmp(connection.ssid, r.ssid) == 0)
                            connected = true;

                        MenuList *options;
                        if (connected)
                            options = new MenuList(MenuItemType::List, "Options",
                                                {
                                                    new MenuItem{ListItemType::Button, "Disconnect", "Disconnect from this network.",
                                                                    [&](AbstractMenuItem &item) -> InputReactionHint
                                                                    { WIFI_disconnect(); selectionDirty = true; return Exit; }},
                                                    new ForgetItem(r, selectionDirty)
                                                });
                        else if (hasCredentials)
                            options = new MenuList(MenuItemType::List, "Options", { new ConnectKnownItem(r, selectionDirty), new ForgetItem(r, selectionDirty) });
                        else if (r.security == SECURITY_NONE)
                            options = new MenuList(MenuItemType::List, "Options", { new ConnectKnownItem(r, selectionDirty) });
                        else
                            options = new MenuList(MenuItemType::List, "Options", { new ConnectNewItem(r, selectionDirty) });

                        auto itm = new NetworkItem{r, connected, options};
                        if (connected && !std::string(connection.ip).empty())
                            itm->setDesc(std::string(r.bssid) + " | " + std::string(connection.ip));
                        items.push_back(itm);
                    }
                }
                for (auto *i : stale)
                    delete i;
                MenuList::performLayout((SDL_Rect){0, 0, FIXED_WIDTH, FIXED_HEIGHT});

                selectionApplied = selectByName(selectedName);
                globalDirty |= selectionApplied;
                selectionDirty |= !selectionApplied;
            }
            pollSecs = 2;
        }
        else
        {
            bool menuOpen = false;
            {
                ReadLock r(itemLock);
                for (auto i : items)
                {
                    if (i->isDeferred())
                    {
                        menuOpen = true;
                        break;
                    }
                }
            }
            if (!menuOpen)
            {
                std::vector<AbstractMenuItem *> stale;
                {
                    WriteLock w(itemLock);
                    for (auto *i : items)
                    {
                        bool keep = (i == toggleItem || i == diagItem || i == btItem);
                        for (auto *s : serviceItems)
                        {
                            if (i == s)
                                keep = true;
                        }
                        if (!keep)
                            stale.push_back(i);
                    }
                    items.clear();
                    items.push_back(toggleItem);
                    items.push_back(diagItem);
                    items.push_back(btItem);
                    items.insert(items.end(), serviceItems.begin(), serviceItems.end());
                    selectionDirty = true;
                }
                for (auto *i : stale)
                    delete i;
            }
            pollSecs = 15;
        }

        if (selectionDirty)
        {
            MenuList::performLayout((SDL_Rect){0, 0, FIXED_WIDTH, FIXED_HEIGHT});
            selectionDirty = false;
        }

        std::this_thread::sleep_for(std::chrono::seconds(pollSecs));
    }
}

ConnectKnownItem::ConnectKnownItem(WIFI_network n, bool& dirty)
    : MenuItem(ListItemType::Button, "Connect", "Connect to this network.", [&](AbstractMenuItem &item) -> InputReactionHint{
        ScopedOverlay overlay("Connecting...");
        WIFI_connect(net.ssid, net.security); 
        dirty = true;
        return Exit;
    }), net(n)
{}

ConnectNewItem::ConnectNewItem(WIFI_network n, bool& dirty)
    : MenuItem(ListItemType::Button, "Enter WiFi passcode", "B back. X or on-screen enter confirms. L1 backspace.", DeferToSubmenu, new KeyboardPrompt("Enter WiFi passcode", 
        [&](AbstractMenuItem &item) -> InputReactionHint {
            std::string pass = item.getName();
            if (net.security != SECURITY_NONE && pass.size() < 8) {
                MenuList::showOverlay("Password needs 8+ characters", OverlayDismissMode::DismissOnA);
                return NoOp;
            }
            ScopedOverlay overlay("Connecting...");
            WIFI_connectPass(net.ssid, net.security, pass.c_str());
            dirty = true;
            return Exit;
        })), net(n)
{}

ForgetItem::ForgetItem(WIFI_network n, bool& dirty)
    : MenuItem(ListItemType::Button, "Forget", "Removes credentials for this network.",
        [&](AbstractMenuItem &item) -> InputReactionHint { 
            WIFI_forget(net.ssid, net.security); 
            dirty = true; 
            return Exit;
        }), net(n)
{}


NetworkItem::NetworkItem(WIFI_network n, bool connected, MenuList* submenu)
    : MenuItem(ListItemType::Custom, n.ssid, n.bssid, DeferToSubmenu, submenu), net(n), connected(connected)
{}

void NetworkItem::drawCustomItem(SDL_Surface *surface, const SDL_Rect &dst, const AbstractMenuItem &item, bool selected) const
{
    SDL_Color text_color = uintToColour(THEME_COLOR4_255);
    SDL_Surface *text = TTF_RenderUTF8_Blended(font.tiny, item.getLabel().c_str(), COLOR_WHITE); // always white

    // hack - this should be correlated to max_width
    int mw = dst.w;

    if (selected)
    {
        // gray pill
        GFX_blitPillLightCPP(ASSET_BUTTON, surface, {dst.x, dst.y, mw, SCALE1(PILL_SIZE)});
    }

    // wifi icon
    auto asset =
        net.rssi >= -60 ? ASSET_WIFI :    // anything above 61
        net.rssi >= -70 ? ASSET_WIFI_MED  // -61 and below
                        : ASSET_WIFI_LOW; // -71 and below
    SDL_Rect rect = {0, 0, 12, 12};
    int ix = dst.x + dst.w - SCALE1(OPTION_PADDING + rect.w);
    int y = dst.y + SCALE1(PILL_SIZE - rect.h) / 2;
    SDL_Rect tgt{ix, y};
    GFX_blitAssetColor(asset, NULL, surface, &tgt, THEME_COLOR6);

    // connected
    if(connected) {
        SDL_Rect rect = {0, 0, 12, 12};
        ix = ix - SCALE1(OPTION_PADDING + rect.w);
        int y = dst.y + SCALE1(PILL_SIZE - rect.h) / 2;
        SDL_Rect tgt{ix, y};
        GFX_blitAssetColor(ASSET_CHECKCIRCLE, NULL, surface, &tgt, THEME_COLOR6);
    }
    // encrypted
    else if(net.security != SECURITY_NONE) {
        SDL_Rect rect = {0, 0, 8, 11};
        ix = ix - SCALE1(OPTION_PADDING + rect.w + 2);
        int y = dst.y + SCALE1(PILL_SIZE - rect.h) / 2;
        SDL_Rect tgt{ix, y};
        GFX_blitAssetColor(ASSET_LOCK, NULL, surface, &tgt, THEME_COLOR6);
    }

    if (selected)
    {
        // white pill
        int w = 0;
        TTF_SizeUTF8(font.large, item.getName().c_str(), &w, NULL);
        w += SCALE1(OPTION_PADDING * 2);
        GFX_blitPillDarkCPP(ASSET_BUTTON, surface, {dst.x, dst.y, w, SCALE1(PILL_SIZE)});
        text_color = uintToColour(THEME_COLOR5_255);
    }

    text = TTF_RenderUTF8_Blended(font.large, item.getName().c_str(), text_color);
    SDL_BlitSurfaceCPP(text, {}, surface, {dst.x + SCALE1(OPTION_PADDING), dst.y + SCALE1(1)});
    SDL_FreeSurface(text);
}
