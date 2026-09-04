/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __SBAT6_NCM_TELEMETRY_H
#define __SBAT6_NCM_TELEMETRY_H

#include <linux/types.h>

extern void sbat6_ncm_tx_ntb(unsigned int payload, unsigned int capacity,
				     unsigned int frames, bool flush, bool full);
extern void sbat6_ncm_tx_queue(bool success, bool retry,
				       unsigned int inflight);
extern void sbat6_ncm_tx_complete(unsigned int latency_us,
					  unsigned int gap_us, bool timestamp_valid);
extern void sbat6_ncm_rx_ntb(unsigned int payload, unsigned int datagrams);
extern void sbat6_ncm_rx_unwrap(unsigned int unwraps, unsigned int skb_allocs,
					unsigned int elapsed_us);
extern void sbat6_ncm_rx_complete(unsigned int inflight);
extern void sbat6_ncm_rx_error(bool malformed, bool drop, bool error);

#endif
