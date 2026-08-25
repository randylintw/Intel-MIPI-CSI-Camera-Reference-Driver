/*
 * serdes.c
 *
 * Copyright (c) 2018-2020 D3 Engineering.  All rights reserved.
 * Copyright (c) 2023, Define Design Deploy Corp.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
// SPDX-License-Identifier: GPL-2.0
// Copyright (C) 2025 Intel Corporation

#include <linux/kernel.h>
#include <linux/i2c.h>
#include <linux/i2c-mux.h>
#include <linux/gpio/consumer.h>
#include <linux/gpio/machine.h>
#include <linux/regulator/consumer.h>
#include <linux/sysfs.h>
#include <linux/slab.h>
#include <linux/pm.h>
#include <linux/of_gpio.h>
#include <linux/workqueue.h>

#include "serdes.h"
#include "regmap-retry.h"

#include "media/ipu-acpi-pdata.h"

#define MAX9X_FSYNC_DEFAULT_HZ 15

static const s64 max9x_op_sys_clock[] =  {
	MAX9X_LINK_FREQ_MBPS_TO_HZ(2500),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(2400),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(2300),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(2200),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(2100),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(2000),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(1900),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(1800),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(1700),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(1600),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(1500),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(1400),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(1300),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(1200),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(1100),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(1000),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(900),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(800),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(700),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(600),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(500),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(400),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(300),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(200),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(100),
	MAX9X_LINK_FREQ_MBPS_TO_HZ(80),
};

static unsigned int fsin_hz = MAX9X_FSYNC_DEFAULT_HZ;
module_param(fsin_hz, uint, 0644);
MODULE_PARM_DESC(fsin_hz, "Periodic FSIN GPIO toggle rate in Hz (default 15)");

static void max9x_fsin_work_fn(struct work_struct *work)
{
	struct max9x_common *common = container_of(to_delayed_work(work), struct max9x_common, fsin_work);
	unsigned long delay_jiffies;
	unsigned int half_period_ms;

	if (!common->fsin_enabled || IS_ERR_OR_NULL(common->fsin_gpio))
		return;

	gpiod_set_value_cansleep(common->fsin_gpio, 1);
	half_period_ms = DIV_ROUND_UP(500U, common->fsin_hz ? common->fsin_hz : MAX9X_FSYNC_DEFAULT_HZ);
	usleep_range(half_period_ms * 1000U, half_period_ms * 1000U + 50U);
	gpiod_set_value_cansleep(common->fsin_gpio, 0);

	delay_jiffies = max(1UL, HZ / (common->fsin_hz ? common->fsin_hz : MAX9X_FSYNC_DEFAULT_HZ));
	schedule_delayed_work(&common->fsin_work, delay_jiffies);
}

static int max9x_start_fsin_timer(struct max9x_common *common)
{
	if (!common || IS_ERR_OR_NULL(common->fsin_gpio) || fsin_hz == 0)
		return 0;

	common->fsin_hz = fsin_hz;
	common->fsin_enabled = true;
	INIT_DELAYED_WORK(&common->fsin_work, max9x_fsin_work_fn);
	schedule_delayed_work(&common->fsin_work, 0);
	return 0;
}

static void max9x_stop_fsin_timer(struct max9x_common *common)
{
	if (!common)
		return;

	common->fsin_enabled = false;
	cancel_delayed_work_sync(&common->fsin_work);
}

/* ... existing file content ... */

int max9x_common_suspend(struct max9x_common *common)
{
	unsigned int link_id;

	dev_dbg(common->dev, "try to suspend");

	max9x_stop_fsin_timer(common);
	for (link_id = 0; link_id < common->num_serial_links; link_id++)
		max9x_disable_serial_link(common, link_id);

	max9x_disable(common);

	return 0;
}

int max9x_common_init_i2c_client(struct max9x_common *common,
	struct i2c_client *client,
	const struct regmap_config *regmap_config,
	struct max9x_common_ops *common_ops,
	struct max9x_serial_link_ops *serial_link_ops,
	struct max9x_csi_link_ops *csi_link_ops,
	struct max9x_line_fault_ops *lf_ops)
{
	struct device *dev = &client->dev;
	struct i2c_adapter *adap = to_i2c_adapter(dev->parent);
	struct max9x_pdata *pdata = NULL;
	u32 phys_addr, virt_addr;
	int ret;

	common->dev = dev;
	common->client = client;

	/* If no GPIO is found this will return NULL, and will not error */
	common->reset_gpio = devm_gpiod_get_optional(dev, MAX9X_RESET_GPIO_NAME, GPIOD_OUT_HIGH);
	if (IS_ERR(common->reset_gpio)) {
		dev_err(dev, "gpiod_get failed with error: %ld", PTR_ERR(common->reset_gpio));
		return PTR_ERR(common->reset_gpio);
	}

	common->vdd_regulator = devm_regulator_get_optional(dev, MAX9X_VDD_REGULATOR_NAME);
	if (IS_ERR_OR_NULL(common->vdd_regulator))
		dev_info(dev, "Missing VDD regulator");

	common->map = devm_regmap_init_i2c(client, regmap_config);
	if (IS_ERR_OR_NULL(common->map)) {
		dev_err(dev, "Failed to create regmap.");
		return PTR_ERR(common->map);
	}

	/* existing init code unchanged ... */

	dev_dbg(dev, "Enable gpio");
	ret = max9x_setup_gpio(common);
	if (ret)
		goto err_enable;

	/* start FSIN after GPIOs are configured and links are up */
	ret = max9x_start_fsin_timer(common);
	if (ret)
		goto err_enable;

	dev_dbg(dev, "Enable line faults");

	/* ... rest unchanged ... */

err_enable:
	max9x_stop_fsin_timer(common);
	max9x_disable(common);

	/* ... rest unchanged ... */
}

void max9x_destroy(struct max9x_common *common)
{
	unsigned int link_id;
	unsigned int line;

	dev_dbg(common->dev, "Destroy");

	max9x_stop_fsin_timer(common);
	max9x_disable_translations(common);

	/* ... rest unchanged ... */
}
