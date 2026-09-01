begin;
select no_plan();
create temporary table epic5_ids(name text primary key,id uuid not null);
grant select,insert on pg_temp.epic5_ids to authenticated;

insert into auth.users(id,email) values
('50000000-0000-0000-0000-000000000001','epic5-student-a@example.invalid'),
('50000000-0000-0000-0000-000000000002','epic5-student-b@example.invalid'),
('50000000-0000-0000-0000-000000000003','epic5-teacher-a@example.invalid'),
('50000000-0000-0000-0000-000000000004','epic5-teacher-b@example.invalid'),
('50000000-0000-0000-0000-000000000005','epic5-admin@example.invalid');
update public.profiles set display_name=case user_id
 when '50000000-0000-0000-0000-000000000001' then 'Student A'
 when '50000000-0000-0000-0000-000000000002' then 'Student B'
 when '50000000-0000-0000-0000-000000000003' then 'Teacher A'
 when '50000000-0000-0000-0000-000000000004' then 'Teacher B' else 'Admin A' end
where user_id::text like '50000000-%';
insert into public.user_roles(user_id,role) values
('50000000-0000-0000-0000-000000000003','teacher'),
('50000000-0000-0000-0000-000000000004','teacher'),
('50000000-0000-0000-0000-000000000005','admin');
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd) values
('50000000-0000-0000-0000-000000000003','epic5-teacher-a','Teacher A','active',true,array['online']::public.teaching_mode[],500),
('50000000-0000-0000-0000-000000000004','epic5-teacher-b','Teacher B','active',true,array['online']::public.teaching_mode[],500);
insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode)
values('50000000-0000-0000-0000-000000000010','50000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000003','active','online');

insert into public.products(id,product_type,status,public_slug,name,currency,base_price_amount,owner_type,owner_teacher_user_id,is_public,is_purchasable,published_at) values
('50000000-0000-0000-0000-000000000020','lesson_package','active','epic5-pack-4','Lesson Package 4','TWD',3200,'teacher','50000000-0000-0000-0000-000000000003',true,true,now()),
('50000000-0000-0000-0000-000000000021','lesson_package','active','epic5-pack-12','Lesson Package 12','TWD',8400,'platform',null,true,true,now());
insert into public.lesson_package_product_configs(product_id,lesson_count,validity_value,validity_unit,lesson_duration_minutes,booking_mode_eligibility) values
('50000000-0000-0000-0000-000000000020',4,5,'weeks',50,'fixed'),
('50000000-0000-0000-0000-000000000021',12,3,'months',50,'both');
insert into public.orders(id,order_number,buyer_user_id,status,currency,subtotal_amount,total_amount,payment_status,source,idempotency_key,paid_at) values
('50000000-0000-0000-0000-000000000030','ONE-20260901-EPIC500001','50000000-0000-0000-0000-000000000001','paid','TWD',3200,3200,'paid','web','50000000-0000-4000-8000-000000000030',now()),
('50000000-0000-0000-0000-000000000031','ONE-20260901-EPIC500002','50000000-0000-0000-0000-000000000001','paid','TWD',8400,8400,'paid','web','50000000-0000-4000-8000-000000000031',now());
insert into public.order_items(id,order_id,product_id,product_type_snapshot,product_name_snapshot,unit_price_amount,quantity,line_subtotal_amount,line_total_amount,seller_type,seller_teacher_user_id) values
('50000000-0000-0000-0000-000000000040','50000000-0000-0000-0000-000000000030','50000000-0000-0000-0000-000000000020','lesson_package','Lesson Package 4',3200,1,3200,3200,'teacher','50000000-0000-0000-0000-000000000003'),
('50000000-0000-0000-0000-000000000041','50000000-0000-0000-0000-000000000031','50000000-0000-0000-0000-000000000021','lesson_package','Lesson Package 12',8400,1,8400,8400,'platform',null);
insert into public.order_fulfillment_events(id,order_id,event_type,payload) values
('50000000-0000-0000-0000-000000000050','50000000-0000-0000-0000-000000000030','order.paid','{}'),
('50000000-0000-0000-0000-000000000051','50000000-0000-0000-0000-000000000031','order.paid','{}');

set local role service_role; select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$select public.process_order_fulfillment_event('50000000-0000-0000-0000-000000000050')$$,'service fulfills paid event');
select lives_ok($$select public.process_order_fulfillment_event('50000000-0000-0000-0000-000000000050')$$,'fulfillment retry is idempotent');
select lives_ok($$select public.process_order_fulfillment_event('50000000-0000-0000-0000-000000000051')$$,'second package fulfills');
reset role;
insert into pg_temp.epic5_ids values
('pack4',(select id from public.entitlements where product_id='50000000-0000-0000-0000-000000000020')),
('pack12',(select id from public.entitlements where product_id='50000000-0000-0000-0000-000000000021'));
select is((select count(*) from public.entitlements where source_fulfillment_event_id='50000000-0000-0000-0000-000000000050'),1::bigint,'one item entitlement per source');
select is((select count(*) from public.lesson_credit_ledger where source_fulfillment_event_id='50000000-0000-0000-0000-000000000050'),1::bigint,'one initial allocation');
select is((select sum(available_delta) from public.lesson_credit_ledger where source_fulfillment_event_id='50000000-0000-0000-0000-000000000050'),4::bigint,'four credits allocated');
select is((select count(*) from public.entitlements where beneficiary_user_id='50000000-0000-0000-0000-000000000001'),2::bigint,'multiple packages supported');
select is((select booking_mode_eligibility from public.entitlements where product_id='50000000-0000-0000-0000-000000000020'),'fixed'::public.lesson_booking_mode_eligibility,'snapshot preserves booking eligibility');

set local role anon; select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select * from public.get_own_lesson_entitlement_summaries()$$,'42501',null,'anonymous cannot execute summary');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.get_own_lesson_entitlement_summaries()),2::bigint,'Student A reads own summaries');
select throws_ok($$insert into public.lesson_credit_ledger(entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code) values((select id from public.entitlements limit 1),'50000000-0000-0000-0000-000000000001','adjustment',99,'forged-operation-key','forged')$$,'42501',null,'Student cannot write ledger');
select lives_ok($$select public.reserve_lesson_credit((select id from pg_temp.epic5_ids where name='pack4'),'50000000-0000-4000-8000-000000000060',null,'future-booking-a')$$,'Student reserves own credit');
select lives_ok($$select public.reserve_lesson_credit((select id from pg_temp.epic5_ids where name='pack4'),'50000000-0000-4000-8000-000000000060',null,'future-booking-a')$$,'same reserve is idempotent');
reset role; insert into pg_temp.epic5_ids values('reservation',(select id from public.lesson_credit_reservations where reservation_key='50000000-0000-4000-8000-000000000060'));
select is((select count(*) from public.lesson_credit_reservations where reservation_key='50000000-0000-4000-8000-000000000060'),1::bigint,'one reservation exists');
set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.release_lesson_credit((select id from pg_temp.epic5_ids where name='reservation'),'booking_cancelled')$$,'release succeeds');
select lives_ok($$select public.release_lesson_credit((select id from pg_temp.epic5_ids where name='reservation'),'booking_cancelled')$$,'release retry is idempotent');
select throws_ok($$select public.reserve_lesson_credit((select id from pg_temp.epic5_ids where name='pack4'),'50000000-0000-4000-8000-000000000062',null,'future-booking-a')$$,'P0001','CREDIT_ALREADY_RESERVED','same Booking cannot reserve twice under a different key');
select throws_ok($$select public.reserve_lesson_credit((select id from pg_temp.epic5_ids where name='pack12'),'50000000-0000-4000-8000-000000000060',null,'future-booking-a')$$,'P0001','CREDIT_RESERVATION_PAYLOAD_MISMATCH','same idempotency key cannot move to another package');

reset role; set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.get_own_lesson_entitlement_summaries()),0::bigint,'Student B cannot see Student A');
select throws_ok($$select public.reserve_lesson_credit((select id from pg_temp.epic5_ids where name='pack4'),'50000000-0000-4000-8000-000000000061',null,'foreign-booking')$$,'42501','Not authorized','Student B cannot reserve Student A credit');

reset role; set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000003',true);
select is((select count(*) from public.get_teacher_student_lesson_entitlement_summaries('50000000-0000-0000-0000-000000000001')),2::bigint,'authorized Teacher sees safe summaries');
select lives_ok($$select public.extend_lesson_package_entitlement((select id from pg_temp.epic5_ids where name='pack4'),'2027-09-01T00:00:00Z','Student needs more time','50000000-0000-4000-8000-000000000070')$$,'authorized Teacher extends package');
select lives_ok($$select public.extend_lesson_package_entitlement((select id from pg_temp.epic5_ids where name='pack4'),'2027-09-01T00:00:00Z','Student needs more time','50000000-0000-4000-8000-000000000070')$$,'extension retry with same payload is idempotent');
select throws_ok($$select public.extend_lesson_package_entitlement((select id from pg_temp.epic5_ids where name='pack4'),'2027-10-01T00:00:00Z','Student needs more time','50000000-0000-4000-8000-000000000070')$$,'P0001','ENTITLEMENT_EXTENSION_PAYLOAD_MISMATCH','extension key cannot be reused with another target expiry');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000004',true);
select throws_ok($$select public.get_teacher_student_lesson_entitlement_summaries('50000000-0000-0000-0000-000000000001')$$,'42501','Not authorized','unrelated Teacher cannot read summary');
select throws_ok($$select public.extend_lesson_package_entitlement((select id from pg_temp.epic5_ids where name='pack4'),now()+interval '2 years','Unauthorized extension','50000000-0000-4000-8000-000000000071')$$,'42501','UNAUTHORIZED_ENTITLEMENT_EXTENSION','unrelated Teacher cannot extend');

reset role; set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000005',true);
select lives_ok($$select public.admin_adjust_lesson_credits((select id from pg_temp.epic5_ids where name='pack4'),1,'Service compensation','50000000-0000-4000-8000-000000000080')$$,'Admin adjusts credit via ledger');
select lives_ok($$select public.admin_adjust_lesson_credits((select id from pg_temp.epic5_ids where name='pack4'),1,'Service compensation','50000000-0000-4000-8000-000000000080')$$,'adjustment retry is idempotent');
select throws_ok($$select public.admin_adjust_lesson_credits((select id from pg_temp.epic5_ids where name='pack4'),2,'Service compensation','50000000-0000-4000-8000-000000000080')$$,'P0001','CREDIT_ADJUSTMENT_PAYLOAD_MISMATCH','adjustment key cannot be reused with another quantity');
reset role;
select is((select count(*) from public.entitlement_expiry_history),1::bigint,'extension history is durable');
select is((select count(*) from public.audit_logs where action='entitlement.credit_adjusted'),1::bigint,'adjustment audit is durable');

insert into public.lessons(
  id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
  starts_at,ends_at,duration_minutes,timezone_anchor,status,location_text
) values(
  '50000000-0000-0000-0000-000000000100','50000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000010',
  'flexible','onsite',now()-interval '2 hours',now()-interval '70 minutes',50,
  'Asia/Taipei','completed','Local test studio'
);
set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.reserve_lesson_credit((select id from pg_temp.epic5_ids where name='pack4'),'50000000-0000-4000-8000-000000000101','50000000-0000-0000-0000-000000000100',null)$$,'Student reserves credit for own Lesson');
reset role; insert into pg_temp.epic5_ids values('consume_reservation',(select id from public.lesson_credit_reservations where reservation_key='50000000-0000-4000-8000-000000000101'));
set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.consume_lesson_credit((select id from pg_temp.epic5_ids where name='consume_reservation'),'50000000-0000-0000-0000-000000000100')$$,'assigned Teacher consumes completed Lesson reservation');
select lives_ok($$select public.consume_lesson_credit((select id from pg_temp.epic5_ids where name='consume_reservation'),'50000000-0000-0000-0000-000000000100')$$,'consume retry is idempotent');
reset role;
select is((select count(*) from public.lesson_credit_ledger where reservation_id=(select id from pg_temp.epic5_ids where name='consume_reservation') and entry_type='consumption'),1::bigint,'double consume creates one ledger entry');

insert into public.entitlements(id,beneficiary_user_id,entitlement_type,status,starts_at,expires_at,product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes) values
('50000000-0000-0000-0000-000000000110','50000000-0000-0000-0000-000000000001','lesson_package','active',now()-interval '1 day',now()+interval '1 month','One Credit Package','both',50),
('50000000-0000-0000-0000-000000000111','50000000-0000-0000-0000-000000000001','lesson_package','active',now()-interval '1 day',now()+interval '1 month','Revoked Package','both',50);
insert into public.lesson_credit_ledger(entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code) values
('50000000-0000-0000-0000-000000000110','50000000-0000-0000-0000-000000000001','allocation',1,'one-credit-allocation','test'),
('50000000-0000-0000-0000-000000000111','50000000-0000-0000-0000-000000000001','allocation',1,'revoke-credit-allocation','test');
set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.reserve_lesson_credit('50000000-0000-0000-0000-000000000110','50000000-0000-4000-8000-000000000112',null,'consume-final-credit')$$,'last available credit can be reserved');
select throws_ok($$select public.reserve_lesson_credit('50000000-0000-0000-0000-000000000110','50000000-0000-4000-8000-000000000113',null,'insufficient-credit')$$,'P0001','INSUFFICIENT_LESSON_CREDITS','reservation cannot make available balance negative');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000005',true);
select lives_ok($$select public.admin_revoke_entitlement('50000000-0000-0000-0000-000000000111','Local revocation test','50000000-0000-4000-8000-000000000114')$$,'Admin revokes entitlement with audit trail');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.reserve_lesson_credit('50000000-0000-0000-0000-000000000111','50000000-0000-4000-8000-000000000115',null,'revoked-credit')$$,'P0001','ENTITLEMENT_NOT_ACTIVE','revoked entitlement cannot reserve');
reset role;
select is((select count(*) from public.audit_logs where action='entitlement.revoked' and target_id='50000000-0000-0000-0000-000000000111'),1::bigint,'revocation audit is durable');

insert into public.orders(id,order_number,buyer_user_id,status,currency,subtotal_amount,total_amount,payment_status,source,idempotency_key) values
('50000000-0000-0000-0000-000000000120','ONE-20260901-EPIC5RETRY','50000000-0000-0000-0000-000000000001','pending','TWD',3200,3200,'unpaid','web','50000000-0000-4000-8000-000000000120'),
('50000000-0000-0000-0000-000000000130','ONE-20260901-EPIC5FAIL1','50000000-0000-0000-0000-000000000001','pending','TWD',3200,3200,'unpaid','web','50000000-0000-4000-8000-000000000130');
insert into public.order_items(id,order_id,product_id,product_type_snapshot,product_name_snapshot,unit_price_amount,quantity,line_subtotal_amount,line_total_amount,seller_type,seller_teacher_user_id) values
('50000000-0000-0000-0000-000000000121','50000000-0000-0000-0000-000000000120','50000000-0000-0000-0000-000000000020','lesson_package','Lesson Package 4',3200,1,3200,3200,'teacher','50000000-0000-0000-0000-000000000003'),
('50000000-0000-0000-0000-000000000131','50000000-0000-0000-0000-000000000130','50000000-0000-0000-0000-000000000020','lesson_package','Lesson Package 4',3200,1,3200,3200,'teacher','50000000-0000-0000-0000-000000000003');
insert into public.order_fulfillment_events(id,order_id,event_type,payload) values
('50000000-0000-0000-0000-000000000122','50000000-0000-0000-0000-000000000120','order.paid','{}'),
('50000000-0000-0000-0000-000000000132','50000000-0000-0000-0000-000000000130','order.paid','{}');

set local role service_role; select set_config('request.jwt.claim.role','service_role',true);
select is(public.process_order_fulfillment_event('50000000-0000-0000-0000-000000000122'),'failed'::public.fulfillment_event_status,'automatic system retry records safe failed status');
reset role;
update public.orders set status='paid',payment_status='paid',paid_at=now() where id='50000000-0000-0000-0000-000000000120';
set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000005',true);
select is(public.admin_retry_order_fulfillment_event('50000000-0000-0000-0000-000000000122'::uuid,'Manual retry after payment reconciliation','50000000-0000-4000-8000-000000000123'),'processed'::public.fulfillment_event_status,'Admin manual retry succeeds');
select is(public.admin_retry_order_fulfillment_event('50000000-0000-0000-0000-000000000122'::uuid,'Manual retry after payment reconciliation','50000000-0000-4000-8000-000000000123'),'processed'::public.fulfillment_event_status,'same manual retry key is idempotent');
select throws_ok($$select public.admin_retry_order_fulfillment_event('50000000-0000-0000-0000-000000000122','Different retry payload','50000000-0000-4000-8000-000000000123')$$,'P0001','FULFILLMENT_RETRY_PAYLOAD_MISMATCH','manual retry key validates payload');
select is(public.admin_retry_order_fulfillment_event('50000000-0000-0000-0000-000000000132'::uuid,'Investigate unfulfilled paid event','50000000-0000-4000-8000-000000000133'),'failed'::public.fulfillment_event_status,'failed Admin retry returns safe failed status');
select is(public.admin_retry_order_fulfillment_event('50000000-0000-0000-0000-000000000132'::uuid,'Investigate unfulfilled paid event','50000000-0000-4000-8000-000000000133'),'failed'::public.fulfillment_event_status,'failed manual retry is idempotent');
reset role;
select is((select count(*) from public.entitlements where source_fulfillment_event_id='50000000-0000-0000-0000-000000000122'),1::bigint,'manual retry creates exactly one entitlement');
select is((select count(*) from public.lesson_credit_ledger where source_fulfillment_event_id='50000000-0000-0000-0000-000000000122'),1::bigint,'manual retry creates exactly one allocation');
select is((select count(*) from public.fulfillment_manual_retry_attempts where fulfillment_event_id='50000000-0000-0000-0000-000000000122'),1::bigint,'successful retry writes one immutable attempt audit');
select is((select count(*) from public.audit_logs where action='fulfillment.manual_retry' and target_id='50000000-0000-0000-0000-000000000122'),1::bigint,'successful retry writes one central audit event');
select is((select count(*) from public.entitlements where source_fulfillment_event_id='50000000-0000-0000-0000-000000000132'),0::bigint,'failed retry creates no entitlement');
select is((select count(*) from public.lesson_credit_ledger where source_fulfillment_event_id='50000000-0000-0000-0000-000000000132'),0::bigint,'failed retry creates no allocation');
select is((select count(*) from public.fulfillment_manual_retry_attempts where fulfillment_event_id='50000000-0000-0000-0000-000000000132' and result='failed' and safe_error_code='ORDER_NOT_PAID'),1::bigint,'failed retry audit persists a safe failure result');
select is((select count(*) from public.audit_logs where action='fulfillment.manual_retry' and target_id='50000000-0000-0000-0000-000000000132'),1::bigint,'failed retry central audit persists');

set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.admin_retry_order_fulfillment_event('50000000-0000-0000-0000-000000000132','Student must be denied','50000000-0000-4000-8000-000000000134')$$,'42501','Not authorized','Student cannot execute manual retry');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.admin_retry_order_fulfillment_event('50000000-0000-0000-0000-000000000132','Teacher must be denied','50000000-0000-4000-8000-000000000135')$$,'42501','Not authorized','Teacher cannot execute manual retry');
reset role;
select is((select count(*) from public.fulfillment_manual_retry_attempts where actor_user_id<>'50000000-0000-0000-0000-000000000005'),0::bigint,'denied callers create no fake Admin audit');

insert into public.entitlements(id,beneficiary_user_id,entitlement_type,status,starts_at,expires_at,product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes) values
('50000000-0000-0000-0000-000000000090','50000000-0000-0000-0000-000000000001','lesson_package','active',now()-interval '2 months',now()-interval '1 month','Expired Package','both',50),
('50000000-0000-0000-0000-000000000091','50000000-0000-0000-0000-000000000001','membership_access','active',now(),now()+interval '1 month','Future Plus',null,null);
insert into public.lesson_credit_ledger(entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code)
values('50000000-0000-0000-0000-000000000090','50000000-0000-0000-0000-000000000001','allocation',1,'expired-allocation-key','test');
set local role authenticated; select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.reserve_lesson_credit('50000000-0000-0000-0000-000000000090','50000000-0000-4000-8000-000000000092',null,'expired-booking')$$,'P0001','ENTITLEMENT_EXPIRED','expired package cannot reserve');
reset role;
select is((select count(*) from public.entitlements where entitlement_type='membership_access'),1::bigint,'future entitlement type is structurally supported');
select is((select count(*) from public.entitlements e where e.source_order_id in(select t.id from public.trial_orders t)),0::bigint,'Trial never becomes a generic package entitlement source');
select is(has_function_privilege('anon','public.reserve_lesson_credit(uuid,text,uuid,text)','EXECUTE'),false,'anonymous has no reserve grant');
select is(has_function_privilege('authenticated','public.process_order_fulfillment_event(uuid)','EXECUTE'),false,'authenticated has no service fulfillment grant');
select is(has_table_privilege('anon','public.entitlements','SELECT'),false,'anonymous has no entitlement table grant');
select is(has_table_privilege('authenticated','public.lesson_credit_ledger','INSERT'),false,'authenticated has no ledger INSERT grant');
select is(has_table_privilege('authenticated','public.lesson_credit_reservations','SELECT'),false,'authenticated has no raw reservation SELECT grant');
select is(has_column_privilege('authenticated','public.entitlements','product_name_snapshot','SELECT'),true,'authenticated has only allowlisted entitlement columns');
select is((select proconfig from pg_proc where oid='public.reserve_lesson_credit(uuid,text,uuid,text)'::regprocedure),array['search_path=""']::text[],'reserve pins empty search_path');
select is(has_function_privilege('anon','public.admin_retry_order_fulfillment_event(uuid,text,text)','EXECUTE'),false,'anonymous has no manual retry grant');
select is(has_function_privilege('service_role','private.fulfill_order_paid_event(uuid,uuid)','EXECUTE'),false,'service role cannot spoof actor through private fulfillment helper');
select is((select count(*) from (values
  ('lesson_package_product_configs'),('order_item_fulfillment_snapshots'),('entitlements'),
  ('lesson_credit_reservations'),('lesson_credit_ledger'),('entitlement_expiry_history'),
  ('fulfillment_manual_retry_attempts')) as t(name)
  where has_table_privilege('service_role','public.'||name,'INSERT')
    or has_table_privilege('service_role','public.'||name,'UPDATE')
    or has_table_privilege('service_role','public.'||name,'DELETE')),0::bigint,'service role has no raw Epic 5 table mutation privileges');
set local role service_role; select set_config('request.jwt.claim.role','service_role',true);
select throws_ok($$insert into public.lesson_credit_ledger(entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code) values('50000000-0000-0000-0000-000000000090','50000000-0000-0000-0000-000000000001','allocation',99,'service-forged-ledger','forged')$$,'42501',null,'service role cannot raw INSERT ledger');
select throws_ok($$update public.lesson_credit_ledger set reason_code='forged'$$,'42501',null,'service role cannot raw UPDATE ledger');
select throws_ok($$delete from public.lesson_credit_ledger$$,'42501',null,'service role cannot raw DELETE ledger');
select throws_ok($$insert into public.entitlement_expiry_history(entitlement_id,new_expires_at,reason,actor_user_id,actor_role,idempotency_key) values('50000000-0000-0000-0000-000000000090',now()+interval '1 year','forged history','50000000-0000-0000-0000-000000000005','admin','service-forged-history')$$,'42501',null,'service role cannot raw INSERT expiry history');
select throws_ok($$update public.entitlement_expiry_history set reason='forged'$$,'42501',null,'service role cannot raw UPDATE expiry history');
select throws_ok($$delete from public.entitlement_expiry_history$$,'42501',null,'service role cannot raw DELETE expiry history');
select throws_ok($$update public.entitlements set beneficiary_user_id='50000000-0000-0000-0000-000000000002'$$,'42501',null,'service role cannot raw change Entitlement authority fields');
reset role;
select throws_ok($$update public.lesson_credit_ledger set reason_code='owner-tamper'$$,'55000','APPEND_ONLY_HISTORY','append-only trigger rejects ledger owner UPDATE');
select throws_ok($$delete from public.lesson_credit_ledger$$,'55000','APPEND_ONLY_HISTORY','append-only trigger rejects ledger owner DELETE');
select throws_ok($$update public.entitlement_expiry_history set reason='owner-tamper'$$,'55000','APPEND_ONLY_HISTORY','append-only trigger rejects expiry history owner UPDATE');
select throws_ok($$delete from public.entitlement_expiry_history$$,'55000','APPEND_ONLY_HISTORY','append-only trigger rejects expiry history owner DELETE');
select throws_ok($$update public.fulfillment_manual_retry_attempts set reason='owner-tamper'$$,'55000','APPEND_ONLY_HISTORY','manual retry audit is immutable');
select throws_ok($$update public.entitlements set product_name_snapshot=product_name_snapshot||' tamper' where id=(select id from pg_temp.epic5_ids where name='pack4')$$,'55000','ENTITLEMENT_AUTHORITY_FIELDS_IMMUTABLE','Entitlement commercial authority fields are immutable');
select throws_ok($$delete from public.entitlements where id=(select id from pg_temp.epic5_ids where name='pack4')$$,'55000','APPEND_ONLY_HISTORY','Entitlement history cannot be deleted');

select * from finish();
rollback;
