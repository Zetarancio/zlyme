#include "lid_policy.h"

#include <stdio.h>

static int failed;
static int radios_pre;
static int radios_resume;
static int wakealarm_writes;
static int killed;

static void expect(const char *title, int got, int want)
{
	if (got == want)
		return;
	fprintf(stderr, "%s: got %d want %d\n", title, got, want);
	failed++;
}

/* One mem sequence: one radio pre, one radio resume, no wakealarm, no kill. */
static void service(struct zlyme_lid_policy *p, int ev, int guard, int suspend_ok)
{
	if (!zlyme_lid_apply(p, ev, guard))
		return;
	expect("not already busy", p->busy, 1);
	radios_pre++;
	radios_resume++;
	zlyme_lid_suspend_done(p, suspend_ok);
}

static void test_frontend(void)
{
	expect("frontend close", zlyme_frontend_lid_wants_mem(1, 1, 0, 0), 1);
	expect("frontend second close", zlyme_frontend_lid_wants_mem(1, 1, 0, 1), 0);
	expect("frontend guard", zlyme_frontend_lid_wants_mem(1, 1, 1, 0), 0);
	expect("frontend already open", zlyme_frontend_lid_wants_mem(1, 0, 0, 0), 0);
	expect("frontend no edge", zlyme_frontend_lid_wants_mem(0, 1, 0, 0), 0);

	/* keylidmon stays quiet while the frontend owns the screen. */
	{
		struct zlyme_lid_policy p = {0};

		service(&p, ZLYME_LID_EV_MENU, 0, 1);
		p.lid_closed = 1;
		service(&p, ZLYME_LID_EV_CLOSE, 0, 1);
		expect("frontend owner mem", p.mem_requests, 0);
		expect("frontend owner lid", p.lid_requests, 0);
		expect("one mem between owners",
			p.mem_requests + zlyme_frontend_lid_wants_mem(1, 1, 0, 0), 1);
	}
}

static void test_pak(void)
{
	struct zlyme_lid_policy p = {0};

	service(&p, ZLYME_LID_EV_MENU, 0, 1);
	p.lid_closed = 1;
	service(&p, ZLYME_LID_EV_PAK, 0, 1);
	expect("pak launch closed", p.mem_requests, 1);
	expect("pak launch lid", p.lid_requests, 1);
	service(&p, ZLYME_LID_EV_CLOSE, 0, 1);
	expect("queued close", p.mem_requests, 1);
	service(&p, ZLYME_LID_EV_PAK, 0, 1);
	expect("repeat owner", p.mem_requests, 1);

	service(&p, ZLYME_LID_EV_OPEN, 0, 1);
	expect("open is not mem", p.mem_requests, 1);
	service(&p, ZLYME_LID_EV_CLOSE, 0, 1);
	expect("close after open", p.mem_requests, 2);
	service(&p, ZLYME_LID_EV_CLOSE, 0, 1);
	expect("bounce close", p.mem_requests, 2);
}

static void test_power(void)
{
	struct zlyme_lid_policy p = {0};

	service(&p, ZLYME_LID_EV_POWER, 0, 1);
	expect("power before frontend", p.mem_requests, 1);
	expect("power count", p.power_requests, 1);
	expect("power is not a lid request", p.lid_requests, 0);

	service(&p, ZLYME_LID_EV_MENU, 0, 1);
	service(&p, ZLYME_LID_EV_POWER, 0, 1);
	expect("power while frontend owns", p.power_requests, 1);

	service(&p, ZLYME_LID_EV_PAK, 0, 1);
	p.lid_closed = 1;
	service(&p, ZLYME_LID_EV_POWER, 0, 1);
	expect("power with lid closed", p.power_requests, 2);
	expect("power did not add a lid request", p.lid_requests, 0);
	service(&p, ZLYME_LID_EV_CLOSE, 0, 1);
	expect("close after power wake", p.mem_requests, 2);
}

static void test_guard_and_failure(void)
{
	struct zlyme_lid_policy p = {0};

	service(&p, ZLYME_LID_EV_MENU, 0, 1);
	service(&p, ZLYME_LID_EV_PAK, 0, 1);
	service(&p, ZLYME_LID_EV_CLOSE, 0, 0);
	expect("failed suspend once", p.mem_requests, 1);
	service(&p, ZLYME_LID_EV_CLOSE, 0, 1);
	expect("failed suspend does not retry", p.mem_requests, 1);

	service(&p, ZLYME_LID_EV_OPEN, 1, 1);
	service(&p, ZLYME_LID_EV_CLOSE, 1, 1);
	service(&p, ZLYME_LID_EV_POWER, 1, 1);
	expect("guard blocks close", p.lid_requests, 1);
	expect("guard blocks power", p.power_requests, 0);
	expect("guard blocks mem", p.mem_requests, 1);
}

static void test_busy_transition(void)
{
	struct zlyme_lid_policy p = {0};

	service(&p, ZLYME_LID_EV_MENU, 0, 1);
	p.lid_closed = 1;
	expect("enter", zlyme_lid_apply(&p, ZLYME_LID_EV_PAK, 0), 1);
	expect("busy close", zlyme_lid_apply(&p, ZLYME_LID_EV_CLOSE, 0), 0);
	expect("busy power", zlyme_lid_apply(&p, ZLYME_LID_EV_POWER, 0), 0);
	zlyme_lid_suspend_done(&p, 1);
	radios_pre++;
	radios_resume++;
	expect("one transition", p.mem_requests, 1);
}

static void test_observed_open(void)
{
	struct zlyme_lid_policy p = {0};
	int before;

	service(&p, ZLYME_LID_EV_MENU, 0, 1);
	service(&p, ZLYME_LID_EV_PAK, 0, 1);
	service(&p, ZLYME_LID_EV_CLOSE, 0, 1);
	expect("close once", p.mem_requests, 1);
	expect("asleep after close", p.asleep, 1);

	/* Switch reads open. No EV_OPEN was queued. */
	zlyme_lid_observe(&p, 0);
	expect("observed open clears asleep", p.asleep, 0);
	expect("observed open is not mem", p.mem_requests, 1);
	before = p.mem_requests;
	service(&p, ZLYME_LID_EV_CLOSE, 0, 1);
	expect("close after observed open", p.mem_requests, before + 1);
	service(&p, ZLYME_LID_EV_CLOSE, 0, 1);
	expect("one new request", p.mem_requests, before + 1);

	zlyme_lid_observe(&p, 1);
	service(&p, ZLYME_LID_EV_CLOSE, 0, 1);
	expect("observed closed does not stack", p.mem_requests, before + 1);
	zlyme_lid_observe(&p, -1);
	expect("unreadable switch keeps asleep", p.asleep, 1);
}

static void test_boot_lid(void)
{
	struct zlyme_lid_policy p = {0};

	p.lid_closed = 1;
	service(&p, ZLYME_LID_EV_PAK, 0, 1);
	service(&p, ZLYME_LID_EV_CLOSE, 0, 1);
	expect("boot does not lid-suspend", p.mem_requests, 0);
}

int main(void)
{
	test_frontend();
	test_pak();
	test_power();
	test_guard_and_failure();
	test_busy_transition();
	test_observed_open();
	test_boot_lid();

	expect("radio pre", radios_pre, radios_resume);
	expect("wakealarm", wakealarm_writes, 0);
	expect("killed", killed, 0);
	if (radios_pre == 0) {
		fprintf(stderr, "no mem sequence was counted\n");
		failed++;
	}
	if (failed) {
		fprintf(stderr, "LID_FAIL %d\n", failed);
		return 1;
	}
	return 0;
}
