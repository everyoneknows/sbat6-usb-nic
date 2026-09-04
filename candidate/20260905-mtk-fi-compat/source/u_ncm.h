// SPDX-License-Identifier: GPL-2.0
/*
 * u_ncm.h
 *
 * Utility definitions for the ncm function
 *
 * Copyright (c) 2013 Samsung Electronics Co., Ltd.
 *		http://www.samsung.com
 *
 * Author: Andrzej Pietrasiewicz <andrzejtp2010@gmail.com>
 */

#ifndef U_NCM_H
#define U_NCM_H

#include <linux/usb/composite.h>

/*
 * T6A's vendor/MediaTek-family composite ABI has one additional
 * usb_function * member between fd and the callbacks.  Keep this
 * representation private to this candidate; do not modify the kernel
 * composite.h used to compile the rest of the tree.
 */
struct sbat6_usb_function_instance_mtk {
	struct config_group group;
	struct list_head cfs_list;
	struct usb_function_driver *fd;
	struct usb_function *f;
	int (*set_inst_name)(struct usb_function_instance *inst,
				     const char *name);
	void (*free_func_inst)(struct usb_function_instance *inst);
};

static inline struct sbat6_usb_function_instance_mtk *
to_sbat6_fi(struct usb_function_instance *fi)
{
	return (struct sbat6_usb_function_instance_mtk *)fi;
}

static inline struct usb_function_instance *
from_sbat6_fi(struct sbat6_usb_function_instance_mtk *fi)
{
	return (struct usb_function_instance *)fi;
}

struct f_ncm_opts {
	struct sbat6_usb_function_instance_mtk func_inst;
	struct net_device		*net;
	bool				bound;

	struct config_group		*ncm_interf_group;
	struct usb_os_desc		ncm_os_desc;
	char				ncm_ext_compat_id[16];
	/*
	 * Read/write access to configfs attributes is handled by configfs.
	 *
	 * This is to protect the data from concurrent access by read/write
	 * and create symlink/remove symlink.
	 */
	struct mutex			lock;
	int				refcnt;
};

/* Compile-time proof of the private representation and its embedding. */
_Static_assert(sizeof(struct sbat6_usb_function_instance_mtk) == 0xb8,
		       "T6A usb_function_instance compatibility size");
_Static_assert(offsetof(struct sbat6_usb_function_instance_mtk, fd) == 0x98,
		       "T6A usb_function_instance fd offset");
_Static_assert(offsetof(struct sbat6_usb_function_instance_mtk, f) == 0xa0,
		       "T6A usb_function_instance f offset");
_Static_assert(offsetof(struct sbat6_usb_function_instance_mtk,
			       set_inst_name) == 0xa8,
		       "T6A usb_function_instance set_inst_name offset");
_Static_assert(offsetof(struct sbat6_usb_function_instance_mtk,
			       free_func_inst) == 0xb0,
		       "T6A usb_function_instance free_func_inst offset");
_Static_assert(sizeof(struct f_ncm_opts) == 0x1c0,
		       "T6A f_ncm_opts size");
_Static_assert(offsetof(struct f_ncm_opts, net) == 0xb8,
		       "T6A f_ncm_opts net offset");
_Static_assert(offsetof(struct f_ncm_opts, ncm_interf_group) == 0xc8,
		       "T6A f_ncm_opts ncm_interf_group offset");
_Static_assert(offsetof(struct f_ncm_opts, lock) == 0x198,
		       "T6A f_ncm_opts mutex offset");

#endif /* U_NCM_H */
