#include "lifecycle.h"
#include "order.h"

#include <dbus/dbus.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define BUS_NAME "org.shadowblip.InputPlumber"
#define BUS_PATH "/org/shadowblip/InputPlumber"
#define MANAGER_PATH "/org/shadowblip/InputPlumber/Manager"
#define MANAGER_IFACE "org.shadowblip.InputManager"
#define COMPOSITE_IFACE "org.shadowblip.Input.CompositeDevice"
#define BUILTIN_NAME "Miyoo Flip Gamepad"

struct device {
	char *path;
	char *name;
	int has_gamepad;
};

static void log_msg(const char *text)
{
	fprintf(stderr, "zlyme-input: %s\n", text);
}

static DBusConnection *bus_open(void)
{
	DBusError err;
	DBusConnection *conn;

	dbus_error_init(&err);
	conn = dbus_bus_get(DBUS_BUS_SYSTEM, &err);
	if (!conn) {
		log_msg(err.message ? err.message : "system bus unavailable");
		dbus_error_free(&err);
	}
	return conn;
}

static int name_up(DBusConnection *conn)
{
	return dbus_bus_name_has_owner(conn, BUS_NAME, NULL);
}

static DBusMessage *call_msg(DBusConnection *conn, DBusMessage *msg)
{
	DBusError err;
	DBusMessage *reply;

	dbus_error_init(&err);
	reply = dbus_connection_send_with_reply_and_block(conn, msg, 3000, &err);
	dbus_message_unref(msg);
	if (!reply) {
		log_msg(err.message ? err.message : "dbus call failed");
		dbus_error_free(&err);
	}
	return reply;
}

static int set_manage_all(DBusConnection *conn, int enable)
{
	DBusMessage *msg, *reply;
	DBusMessageIter iter, var;
	const char *iface = MANAGER_IFACE;
	const char *prop = "ManageAllDevices";
	dbus_bool_t value = enable ? TRUE : FALSE;

	msg = dbus_message_new_method_call(BUS_NAME, MANAGER_PATH,
					   "org.freedesktop.DBus.Properties", "Set");
	if (!msg)
		return 1;
	dbus_message_iter_init_append(msg, &iter);
	dbus_message_iter_append_basic(&iter, DBUS_TYPE_STRING, &iface);
	dbus_message_iter_append_basic(&iter, DBUS_TYPE_STRING, &prop);
	dbus_message_iter_open_container(&iter, DBUS_TYPE_VARIANT, "b", &var);
	dbus_message_iter_append_basic(&var, DBUS_TYPE_BOOLEAN, &value);
	dbus_message_iter_close_container(&iter, &var);
	reply = call_msg(conn, msg);
	if (!reply)
		return 1;
	dbus_message_unref(reply);
	log_msg(enable ? "ManageAllDevices=true" : "ManageAllDevices=false");
	return 0;
}

static int get_manage_all(DBusConnection *conn, int *enable)
{
	DBusMessage *msg, *reply;
	DBusMessageIter iter, var;
	const char *iface = MANAGER_IFACE;
	const char *prop = "ManageAllDevices";
	dbus_bool_t value;

	msg = dbus_message_new_method_call(BUS_NAME, MANAGER_PATH,
					   "org.freedesktop.DBus.Properties", "Get");
	if (!msg)
		return 1;
	dbus_message_iter_init_append(msg, &iter);
	dbus_message_iter_append_basic(&iter, DBUS_TYPE_STRING, &iface);
	dbus_message_iter_append_basic(&iter, DBUS_TYPE_STRING, &prop);
	reply = call_msg(conn, msg);
	if (!reply)
		return 1;
	if (!dbus_message_iter_init(reply, &iter)) {
		dbus_message_unref(reply);
		return 1;
	}
	dbus_message_iter_recurse(&iter, &var);
	dbus_message_iter_get_basic(&var, &value);
	dbus_message_unref(reply);
	*enable = value ? 1 : 0;
	return 0;
}

static int rescan(DBusConnection *conn)
{
	DBusMessage *msg, *reply;

	msg = dbus_message_new_method_call(BUS_NAME, MANAGER_PATH, MANAGER_IFACE,
					   "RescanDevices");
	if (!msg)
		return 1;
	reply = call_msg(conn, msg);
	if (!reply)
		return 1;
	dbus_message_unref(reply);
	log_msg("rescan");
	return 0;
}

static int stop_path(DBusConnection *conn, const char *path)
{
	DBusMessage *msg, *reply;

	msg = dbus_message_new_method_call(BUS_NAME, path, COMPOSITE_IFACE, "Stop");
	if (!msg)
		return 1;
	reply = call_msg(conn, msg);
	if (!reply)
		return 1;
	dbus_message_unref(reply);
	log_msg("released built-in composite");
	return 0;
}

static void free_devices(struct device *list, int n)
{
	int i;

	for (i = 0; i < n; i++) {
		free(list[i].path);
		free(list[i].name);
	}
	free(list);
}

static char *dup_basic_string(DBusMessageIter *iter)
{
	const char *s = "";

	if (dbus_message_iter_get_arg_type(iter) != DBUS_TYPE_STRING)
		return NULL;
	dbus_message_iter_get_basic(iter, &s);
	return strdup(s);
}

static int array_has_gamepad_target(DBusMessageIter *variant)
{
	DBusMessageIter arr;

	if (dbus_message_iter_get_arg_type(variant) != DBUS_TYPE_ARRAY)
		return 0;
	dbus_message_iter_recurse(variant, &arr);
	while (dbus_message_iter_get_arg_type(&arr) == DBUS_TYPE_STRING) {
		const char *s = "";

		dbus_message_iter_get_basic(&arr, &s);
		if (strstr(s, "/devices/target/gamepad"))
			return 1;
		dbus_message_iter_next(&arr);
	}
	return 0;
}

/* Walk a{sa{sv}} for one object. Returns the composite Name, if any. */
static char *composite_fields(DBusMessageIter *ifaces, int *has_gamepad)
{
	char *name = NULL;

	*has_gamepad = 0;
	while (dbus_message_iter_get_arg_type(ifaces) == DBUS_TYPE_DICT_ENTRY) {
		DBusMessageIter entry, props;
		const char *iface = "";

		dbus_message_iter_recurse(ifaces, &entry);
		if (dbus_message_iter_get_arg_type(&entry) == DBUS_TYPE_STRING)
			dbus_message_iter_get_basic(&entry, &iface);
		dbus_message_iter_next(&entry);
		dbus_message_iter_recurse(&entry, &props);
		if (strcmp(iface, COMPOSITE_IFACE) == 0) {
			while (dbus_message_iter_get_arg_type(&props) == DBUS_TYPE_DICT_ENTRY) {
				DBusMessageIter prop, variant;
				const char *key = "";

				dbus_message_iter_recurse(&props, &prop);
				if (dbus_message_iter_get_arg_type(&prop) == DBUS_TYPE_STRING)
					dbus_message_iter_get_basic(&prop, &key);
				dbus_message_iter_next(&prop);
				dbus_message_iter_recurse(&prop, &variant);
				if (strcmp(key, "Name") == 0 && !name)
					name = dup_basic_string(&variant);
				if (strcmp(key, "TargetDevices") == 0 &&
				    array_has_gamepad_target(&variant))
					*has_gamepad = 1;
				dbus_message_iter_next(&props);
			}
		}
		dbus_message_iter_next(ifaces);
	}
	return name;
}

static int list_composites(DBusConnection *conn, struct device **out, int *n_out)
{
	DBusMessage *msg, *reply;
	DBusMessageIter iter, objects;
	struct device *list = NULL;
	int n = 0;

	*out = NULL;
	*n_out = 0;
	msg = dbus_message_new_method_call(BUS_NAME, BUS_PATH,
					   "org.freedesktop.DBus.ObjectManager",
					   "GetManagedObjects");
	if (!msg)
		return 1;
	reply = call_msg(conn, msg);
	if (!reply)
		return 1;
	if (!dbus_message_iter_init(reply, &iter)) {
		dbus_message_unref(reply);
		return 1;
	}
	dbus_message_iter_recurse(&iter, &objects);
	while (dbus_message_iter_get_arg_type(&objects) == DBUS_TYPE_DICT_ENTRY) {
		DBusMessageIter entry, ifaces;
		const char *path = "";
		char *name;
		int has_gamepad = 0;

		dbus_message_iter_recurse(&objects, &entry);
		if (dbus_message_iter_get_arg_type(&entry) == DBUS_TYPE_OBJECT_PATH)
			dbus_message_iter_get_basic(&entry, &path);
		dbus_message_iter_next(&entry);
		dbus_message_iter_recurse(&entry, &ifaces);
		name = composite_fields(&ifaces, &has_gamepad);
		if (name && strstr(path, "/CompositeDevice")) {
			struct device *grown = realloc(list, (size_t)(n + 1) * sizeof(*list));
			if (!grown) {
				free(name);
				free_devices(list, n);
				dbus_message_unref(reply);
				return 1;
			}
			list = grown;
			list[n].path = NULL;
			list[n].name = name;
			list[n].has_gamepad = has_gamepad;
			list[n].path = strdup(path);
			if (!list[n].path) {
				free_devices(list, n + 1);
				dbus_message_unref(reply);
				return 1;
			}
			n++;
		} else {
			free(name);
		}
		dbus_message_iter_next(&objects);
	}
	dbus_message_unref(reply);
	*out = list;
	*n_out = n;
	return 0;
}

static int find_builtin(struct device *list, int n)
{
	int i;

	for (i = 0; i < n; i++) {
		if (strcmp(list[i].name, BUILTIN_NAME) == 0)
			return i;
	}
	return -1;
}

static int get_order(DBusConnection *conn, char ***paths, int *n_out)
{
	DBusMessage *msg, *reply;
	DBusMessageIter iter, var, arr;
	const char *iface = MANAGER_IFACE;
	const char *prop = "GamepadOrder";
	char **list = NULL;
	int n = 0;

	*paths = NULL;
	*n_out = 0;
	msg = dbus_message_new_method_call(BUS_NAME, MANAGER_PATH,
					   "org.freedesktop.DBus.Properties", "Get");
	if (!msg)
		return 1;
	dbus_message_iter_init_append(msg, &iter);
	dbus_message_iter_append_basic(&iter, DBUS_TYPE_STRING, &iface);
	dbus_message_iter_append_basic(&iter, DBUS_TYPE_STRING, &prop);
	reply = call_msg(conn, msg);
	if (!reply)
		return 1;
	if (!dbus_message_iter_init(reply, &iter)) {
		dbus_message_unref(reply);
		return 1;
	}
	dbus_message_iter_recurse(&iter, &var);
	dbus_message_iter_recurse(&var, &arr);
	while (dbus_message_iter_get_arg_type(&arr) == DBUS_TYPE_STRING) {
		const char *s = "";
		char **grown;

		dbus_message_iter_get_basic(&arr, &s);
		grown = realloc(list, (size_t)(n + 1) * sizeof(*list));
		if (!grown) {
			while (n > 0)
				free(list[--n]);
			free(list);
			dbus_message_unref(reply);
			return 1;
		}
		list = grown;
		list[n++] = strdup(s);
		dbus_message_iter_next(&arr);
	}
	dbus_message_unref(reply);
	*paths = list;
	*n_out = n;
	return 0;
}

static int set_order(DBusConnection *conn, const char **paths, int n)
{
	DBusMessage *msg, *reply;
	DBusMessageIter iter, var, arr;
	const char *iface = MANAGER_IFACE;
	const char *prop = "GamepadOrder";
	int i;

	msg = dbus_message_new_method_call(BUS_NAME, MANAGER_PATH,
					   "org.freedesktop.DBus.Properties", "Set");
	if (!msg)
		return 1;
	dbus_message_iter_init_append(msg, &iter);
	dbus_message_iter_append_basic(&iter, DBUS_TYPE_STRING, &iface);
	dbus_message_iter_append_basic(&iter, DBUS_TYPE_STRING, &prop);
	dbus_message_iter_open_container(&iter, DBUS_TYPE_VARIANT, "as", &var);
	dbus_message_iter_open_container(&var, DBUS_TYPE_ARRAY, "s", &arr);
	for (i = 0; i < n; i++)
		dbus_message_iter_append_basic(&arr, DBUS_TYPE_STRING, &paths[i]);
	dbus_message_iter_close_container(&var, &arr);
	dbus_message_iter_close_container(&iter, &var);
	reply = call_msg(conn, msg);
	if (!reply)
		return 1;
	dbus_message_unref(reply);
	log_msg("player order updated");
	return 0;
}

static const char *name_of(struct device *list, int n, const char *path)
{
	int i;

	for (i = 0; i < n; i++) {
		if (strcmp(list[i].path, path) == 0)
			return list[i].name;
	}
	return NULL;
}

/* Externals keep their relative order. The built-in composite goes last.
 * Writes nothing when the order is already that sequence. */
static int reconcile(DBusConnection *conn)
{
	struct device *devs = NULL;
	char **order = NULL;
	const char **paths, **names, **dst;
	int nd = 0, no = 0, i, j, n = 0, changed, rc = 0;

	if (list_composites(conn, &devs, &nd) != 0)
		return 1;
	if (get_order(conn, &order, &no) != 0) {
		free_devices(devs, nd);
		return 1;
	}
	n = no;
	for (i = 0; i < nd; i++) {
		int seen = 0;
		for (j = 0; j < no; j++) {
			if (strcmp(order[j], devs[i].path) == 0)
				seen = 1;
		}
		if (!seen)
			n++;
	}
	paths = calloc((size_t)n, sizeof(*paths));
	names = calloc((size_t)n, sizeof(*names));
	dst = calloc((size_t)n, sizeof(*dst));
	if (!paths || !names || !dst) {
		free(paths);
		free(names);
		free(dst);
		for (i = 0; i < no; i++)
			free(order[i]);
		free(order);
		free_devices(devs, nd);
		return 1;
	}
	for (i = 0; i < no; i++) {
		paths[i] = order[i];
		names[i] = name_of(devs, nd, order[i]);
		if (!names[i])
			names[i] = "";
	}
	j = no;
	for (i = 0; i < nd; i++) {
		int seen = 0;
		int k;
		for (k = 0; k < no; k++) {
			if (strcmp(order[k], devs[i].path) == 0)
				seen = 1;
		}
		if (!seen) {
			paths[j] = devs[i].path;
			names[j] = devs[i].name;
			j++;
		}
	}
	changed = zlyme_order_builtin_last(paths, names, n, BUILTIN_NAME, dst);
	if (changed)
		rc = set_order(conn, dst, n);
	free(paths);
	free(names);
	free(dst);
	for (i = 0; i < no; i++)
		free(order[i]);
	free(order);
	free_devices(devs, nd);
	return rc;
}

static long mono_ms(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static void builtin_state(struct device *devs, int n, int *present, int *gamepad)
{
	int idx = find_builtin(devs, n);

	*present = idx >= 0;
	*gamepad = idx >= 0 && devs[idx].has_gamepad;
}

static int wait_until(DBusConnection *conn, int want_ready, const char *fail)
{
	long deadline = mono_ms() + 3000;

	for (;;) {
		struct device *devs = NULL;
		int n = 0, present = 0, gamepad = 0, done, slice;
		long now;

		if (list_composites(conn, &devs, &n) != 0)
			return 1;
		builtin_state(devs, n, &present, &gamepad);
		free_devices(devs, n);
		done = want_ready ? zlyme_reclaim_done(present, gamepad)
				  : zlyme_release_done(present, gamepad);
		if (done)
			return 0;
		now = mono_ms();
		if (now >= deadline) {
			log_msg(fail);
			return 1;
		}
		slice = (int)(deadline - now);
		if (slice > 200)
			slice = 200;
		dbus_connection_read_write(conn, slice);
	}
}

static int cmd_release(DBusConnection *conn)
{
	struct device *devs = NULL;
	int n = 0, idx, present = 0, gamepad = 0;

	if (!name_up(conn)) {
		log_msg("InputPlumber is not running");
		return 1;
	}
	if (list_composites(conn, &devs, &n) != 0)
		return 1;
	builtin_state(devs, n, &present, &gamepad);
	idx = find_builtin(devs, n);
	if (zlyme_release_done(present, gamepad)) {
		free_devices(devs, n);
		log_msg("built-in composite already released");
		return 0;
	}
	if (idx < 0 || stop_path(conn, devs[idx].path) != 0) {
		free_devices(devs, n);
		return 1;
	}
	free_devices(devs, n);
	if (wait_until(conn, 0, "built-in release did not finish") != 0)
		return 1;
	log_msg("built-in composite released");
	return 0;
}

static int cmd_reclaim(DBusConnection *conn)
{
	struct device *devs = NULL;
	int n = 0, present = 0, gamepad = 0;

	if (!name_up(conn)) {
		log_msg("InputPlumber is not running");
		return 1;
	}
	if (list_composites(conn, &devs, &n) != 0)
		return 1;
	builtin_state(devs, n, &present, &gamepad);
	free_devices(devs, n);
	if (zlyme_reclaim_done(present, gamepad)) {
		reconcile(conn);
		log_msg("built-in target already ready");
		return 0;
	}
	if (rescan(conn) != 0)
		return 1;
	if (wait_until(conn, 1, "built-in target did not become ready") != 0)
		return 1;
	if (reconcile(conn) != 0)
		return 1;
	log_msg("built-in target ready");
	return 0;
}

/* First-boot recovery: absent InputPlumber is not a failure. */
static int cmd_ensure(DBusConnection *conn)
{
	if (!name_up(conn)) {
		log_msg("InputPlumber is not running; ensure skipped");
		return 0;
	}
	return cmd_reclaim(conn);
}

static int cmd_status(DBusConnection *conn)
{
	int manage = 0;
	struct device *devs = NULL;
	int n = 0, i, present;

	if (!name_up(conn)) {
		printf("unavailable\n");
		return 0;
	}
	if (get_manage_all(conn, &manage) != 0)
		return 1;
	if (list_composites(conn, &devs, &n) != 0)
		return 1;
	present = find_builtin(devs, n) >= 0;
	printf("manage=%d builtin=%s", manage, present ? "virtual" : "released");
	for (i = 0; i < n; i++)
		printf("%s%s", i ? "," : " devices=", devs[i].name);
	printf("\n");
	free_devices(devs, n);
	return 0;
}

static int manager_ready(DBusConnection *conn)
{
	int manage = 0;

	if (!name_up(conn))
		return 0;
	return get_manage_all(conn, &manage) == 0;
}

static int activate(DBusConnection *conn)
{
	if (!zlyme_should_activate(name_up(conn), manager_ready(conn)))
		return 1;
	if (set_manage_all(conn, 1) != 0)
		return 1;
	if (reconcile(conn) != 0)
		log_msg("player order was not applied");
	log_msg("management active");
	return 0;
}

static int cmd_run(DBusConnection *conn)
{
	DBusError err;
	int active = 0;

	dbus_error_init(&err);
	dbus_bus_add_match(conn,
			   "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged'",
			   &err);
	if (dbus_error_is_set(&err)) {
		log_msg(err.message);
		dbus_error_free(&err);
		return 1;
	}
	dbus_bus_add_match(conn,
			   "type='signal',sender='" BUS_NAME "',interface='org.freedesktop.DBus.ObjectManager'",
			   &err);
	if (dbus_error_is_set(&err)) {
		log_msg(err.message);
		dbus_error_free(&err);
		return 1;
	}
	dbus_bus_add_match(conn,
			   "type='signal',sender='" BUS_NAME "',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'",
			   &err);
	if (dbus_error_is_set(&err)) {
		log_msg(err.message);
		dbus_error_free(&err);
		return 1;
	}
	log_msg("waiting for InputPlumber");
	if (activate(conn) == 0)
		active = 1;
	for (;;) {
		DBusMessage *msg;

		dbus_connection_read_write(conn, -1);
		while ((msg = dbus_connection_pop_message(conn)) != NULL) {
			int is_signal = dbus_message_get_type(msg) == DBUS_MESSAGE_TYPE_SIGNAL;
			const char *member = dbus_message_get_member(msg);
			int owner_event = 0;
			int interesting = 0;

			if (is_signal && member && strcmp(member, "NameOwnerChanged") == 0) {
				DBusMessageIter iter;
				const char *name = "";
				const char *old_owner = "";
				const char *new_owner = "";

				if (dbus_message_iter_init(msg, &iter) &&
				    dbus_message_iter_get_arg_type(&iter) == DBUS_TYPE_STRING) {
					dbus_message_iter_get_basic(&iter, &name);
					if (dbus_message_iter_next(&iter))
						dbus_message_iter_get_basic(&iter, &old_owner);
					if (dbus_message_iter_next(&iter))
						dbus_message_iter_get_basic(&iter, &new_owner);
				}
				if (strcmp(name, BUS_NAME) == 0) {
					owner_event = 1;
					if (new_owner[0] == '\0') {
						active = 0;
						log_msg("InputPlumber owner lost");
					} else {
						log_msg("InputPlumber owner appeared");
					}
				}
				(void)old_owner;
			}
			if (is_signal && member &&
			    (strcmp(member, "InterfacesAdded") == 0 ||
			     strcmp(member, "InterfacesRemoved") == 0))
				interesting = 1;
			if (is_signal && member && strcmp(member, "PropertiesChanged") == 0) {
				DBusMessageIter iter;
				const char *iface = "";

				if (dbus_message_iter_init(msg, &iter) &&
				    dbus_message_iter_get_arg_type(&iter) == DBUS_TYPE_STRING)
					dbus_message_iter_get_basic(&iter, &iface);
				if (strcmp(iface, MANAGER_IFACE) == 0)
					interesting = 1;
			}
			dbus_message_unref(msg);
			if (zlyme_should_deactivate(name_up(conn))) {
				active = 0;
				continue;
			}
			if (!active || owner_event) {
				if (activate(conn) == 0)
					active = 1;
				continue;
			}
			if (interesting)
				reconcile(conn);
		}
	}
}

int main(int argc, char **argv)
{
	DBusConnection *conn;
	const char *cmd;

	if (argc != 2) {
		fprintf(stderr, "usage: zlyme-input run|release|reclaim|ensure|status\n");
		return 2;
	}
	cmd = argv[1];
	conn = bus_open();
	if (!conn)
		return 1;
	if (strcmp(cmd, "run") == 0)
		return cmd_run(conn);
	if (strcmp(cmd, "release") == 0)
		return cmd_release(conn);
	if (strcmp(cmd, "reclaim") == 0)
		return cmd_reclaim(conn);
	if (strcmp(cmd, "ensure") == 0)
		return cmd_ensure(conn);
	if (strcmp(cmd, "status") == 0)
		return cmd_status(conn);
	fprintf(stderr, "usage: zlyme-input run|release|reclaim|ensure|status\n");
	return 2;
}
