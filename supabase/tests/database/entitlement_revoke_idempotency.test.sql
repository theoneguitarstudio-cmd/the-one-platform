begin;
select no_plan();
\set p16_fixture_include true
\ir entitlement_revoke_booking_consistency_fixture.sql
\unset p16_fixture_include

insert into auth.users(id,email) values(
  '7d000000-0000-0000-0000-000000000003','p16d-super-admin@example.invalid'
);
insert into public.user_roles(user_id,role) values(
  '7d000000-0000-0000-0000-000000000003','super_admin'
);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select is(public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020',
  'P1-6D canonical revoke request','p16d-canonical-revoke-0001'),
  '7b000000-0000-0000-0000-000000000020'::uuid,
  'D1 first revoke returns the canonical Entitlement identity');
reset role;

create temporary table p16d_after_first as
select
  (select count(*) from public.lesson_credit_ledger
    where entitlement_id='7b000000-0000-0000-0000-000000000020'
      and entry_type='revocation') revocation_ledger,
  (select count(*) from public.audit_logs
    where target_id='7b000000-0000-0000-0000-000000000020'
      and action='entitlement.revoked') revoke_audit,
  (select count(*) from public.audit_logs
    where action='entitlement_revoke.booking_reconciled'
      and before_snapshot->>'entitlement_id'='7b000000-0000-0000-0000-000000000020') booking_audit,
  (select count(*) from public.audit_logs
    where action='fixed_cycle.invalidated'
      and before_snapshot->>'entitlement_id'='7b000000-0000-0000-0000-000000000020') cycle_audit,
  (select count(*) from public.audit_logs
    where action='recurring_series.preferred_entitlement_cleared'
      and before_snapshot->>'preferred_entitlement_id'='7b000000-0000-0000-0000-000000000020') pointer_audit;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select is(public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020',
  'P1-6D canonical revoke request','p16d-canonical-revoke-0001'),
  '7b000000-0000-0000-0000-000000000020'::uuid,
  'D1 same-key retry returns the same canonical result');
select is(public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020',
  '  P1-6D canonical revoke request  ','p16d-canonical-revoke-0001'),
  '7b000000-0000-0000-0000-000000000020'::uuid,
  'D1 reason edge whitespace normalizes to the same request');
select throws_ok($$select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020',
  'P1-6D materially different reason','p16d-canonical-revoke-0001')$$,
  'P0001','REVOKE_REQUEST_MISMATCH','D2 same key with another reason is rejected');
select throws_ok($$select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000021',
  'P1-6D canonical revoke request','p16d-canonical-revoke-0001')$$,
  'P0001','REVOKE_REQUEST_MISMATCH','D3 same key with another Entitlement is rejected');
select set_config('request.jwt.claim.sub','7d000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020',
  'P1-6D canonical revoke request','p16d-canonical-revoke-0001')$$,
  'P0001','REVOKE_REQUEST_MISMATCH','D3 same key from another authorized actor is rejected');
reset role;

select ok((select status='active' and revoked_at is null
  from public.entitlements where id='7b000000-0000-0000-0000-000000000021'),
  'D3 mismatched Entitlement request performs no mutation');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select is(public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020',
  'P1-6D later no-op request','p16d-later-revoke-noop-0001'),
  '7b000000-0000-0000-0000-000000000020'::uuid,
  'D4 a new key after revoke returns the stable revoked identity');
reset role;

select is((select revoked_reason from public.entitlements
  where id='7b000000-0000-0000-0000-000000000020'),
  'P1-6D canonical revoke request','D4 later no-op does not rewrite original reason');
select is((select count(*) from public.entitlement_revoke_operations
  where entitlement_id='7b000000-0000-0000-0000-000000000020'),2::bigint,
  'D4 successful request and later no-op have separate operation identities');
select ok((select status='completed'
    and result_payload->>'entitlement_id'='7b000000-0000-0000-0000-000000000020'
    and result_payload->>'already_revoked'='false'
    and completed_at is not null
  from public.entitlement_revoke_operations
  where operation_key='p16d-canonical-revoke-0001'),
  'Operation history stores the canonical successful result');
select ok((select status='completed' and result_payload->>'already_revoked'='true'
  from public.entitlement_revoke_operations
  where operation_key='p16d-later-revoke-noop-0001'),
  'Operation history explicitly records a later already-revoked no-op');

select is((select count(*) from public.lesson_credit_ledger
  where entitlement_id='7b000000-0000-0000-0000-000000000020'
    and entry_type='revocation'),
  (select revocation_ledger from p16d_after_first),'D5 retries create no duplicate ledger movement');
select is((select count(*) from public.audit_logs
  where target_id='7b000000-0000-0000-0000-000000000020'
    and action='entitlement.revoked'),
  (select revoke_audit from p16d_after_first),'D6 retries create no duplicate revoke audit');
select is((select count(*) from public.audit_logs
  where action='entitlement_revoke.booking_reconciled'
    and before_snapshot->>'entitlement_id'='7b000000-0000-0000-0000-000000000020'),
  (select booking_audit from p16d_after_first),'D7 retries create no duplicate Booking reconciliation');
select is((select count(*) from public.audit_logs
  where action='fixed_cycle.invalidated'
    and before_snapshot->>'entitlement_id'='7b000000-0000-0000-0000-000000000020'),
  (select cycle_audit from p16d_after_first),'D8 retries create no duplicate cycle invalidation');
select is((select count(*) from public.audit_logs
  where action='recurring_series.preferred_entitlement_cleared'
    and before_snapshot->>'preferred_entitlement_id'='7b000000-0000-0000-0000-000000000020'),
  (select pointer_audit from p16d_after_first),'D8 retries create no duplicate pointer transition');

select throws_ok($$update public.entitlement_revoke_operations
  set result_payload=jsonb_build_object('tampered',true)
  where operation_key='p16d-canonical-revoke-0001'$$,
  '55000','REVOKE_OPERATION_IMMUTABLE','Completed operation history cannot be rewritten');
select throws_ok($$delete from public.entitlement_revoke_operations
  where operation_key='p16d-canonical-revoke-0001'$$,
  '55000','REVOKE_OPERATION_IMMUTABLE','Operation history cannot be deleted');
select is((select count(*) from (values('anon'),('authenticated'),('service_role')) roles(name)
  where has_table_privilege(name,'public.entitlement_revoke_operations','INSERT,UPDATE,DELETE')),
  0::bigint,'Application roles have no raw operation-history writes');
select is((select count(*) from (values('anon'),('authenticated'),('service_role')) roles(name)
  where has_function_privilege(name,
    'private.claim_entitlement_revoke_operation(text,uuid,uuid,text)','EXECUTE')
    or has_function_privilege(name,
      'private.complete_entitlement_revoke_operation(text,uuid,jsonb)','EXECUTE')),
  0::bigint,'Private idempotency helpers are not executable by application roles');
select ok((select relrowsecurity from pg_class
  where oid='public.entitlement_revoke_operations'::regclass),
  'Operation history has RLS enabled');

select * from finish();
rollback;
