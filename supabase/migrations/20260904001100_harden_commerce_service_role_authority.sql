begin;

-- Commerce mutations must enter through the public SECURITY DEFINER domain
-- RPCs.  The function owner keeps the internal table authority; application
-- service_role callers retain read access and only the explicitly granted RPCs.
revoke insert, update, delete, truncate on table
  public.products,
  public.product_public_catalog,
  public.product_publication_requests,
  public.orders,
  public.order_items,
  public.payments,
  public.payment_submissions,
  public.order_fulfillment_events,
  public.refunds,
  public.lesson_package_product_configs,
  public.order_item_fulfillment_snapshots,
  public.fulfillment_manual_retry_attempts
from service_role;

-- Payment state changes are reachable only through admin_confirm_payment and
-- admin_confirm_cash_payment.  SECURITY DEFINER owner chaining does not require
-- callers to execute this private core directly.
revoke all on function private.confirm_payment_locked(uuid,uuid,text,uuid,text)
  from public, anon, authenticated, service_role;
revoke all on function private.sync_product_public_catalog_row(uuid)
  from public, anon, authenticated, service_role;

-- Preserve the supported service fulfillment entry point explicitly.
grant execute on function public.process_order_fulfillment_event(uuid)
  to service_role;

commit;
