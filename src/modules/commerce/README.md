# Commerce Module

Epic 4 owns generic Product, Order, Order Item, and authoritative checkout boundaries.
It does not create entitlements; paid orders emit a durable `order.paid` outbox event.
Epic 3 `trial_orders` remains its validated source of truth and is not dual-written.
