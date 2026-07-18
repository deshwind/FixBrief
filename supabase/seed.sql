-- FixBrief local-development seed data.
--
-- This file contains synthetic users and scenarios only. It is executed after
-- migrations by `supabase db reset`. Never apply it to production. Local test
-- accounts use the password: FixBriefDemo123!

-- Repair catalogue ----------------------------------------------------------

insert into public.repair_categories (
  id, name, slug, icon_token, accent_token, sort_order
) values
  ('40000000-0000-4000-8000-000000000001', 'Cars', 'cars', 'directions_car', 'industrial', 10),
  ('40000000-0000-4000-8000-000000000002', 'Motorcycles', 'motorcycles', 'two_wheeler', 'industrial', 20),
  ('40000000-0000-4000-8000-000000000003', 'Plumbing', 'plumbing', 'plumbing', 'cool_blue', 30),
  ('40000000-0000-4000-8000-000000000004', 'Electrical', 'electrical', 'electrical_services', 'warning', 40),
  ('40000000-0000-4000-8000-000000000005', 'Washing machines', 'washing-machines', 'local_laundry_service', 'cyan', 50),
  ('40000000-0000-4000-8000-000000000006', 'Refrigerators', 'refrigerators', 'kitchen', 'cyan', 60),
  ('40000000-0000-4000-8000-000000000007', 'Cookers and ovens', 'cookers-and-ovens', 'oven', 'warning', 70),
  ('40000000-0000-4000-8000-000000000008', 'Dishwashers', 'dishwashers', 'dishwasher', 'cyan', 80),
  ('40000000-0000-4000-8000-000000000009', 'Air conditioning', 'air-conditioning', 'ac_unit', 'cool_blue', 90),
  ('40000000-0000-4000-8000-000000000010', 'Heating', 'heating', 'heat', 'warning', 100),
  ('40000000-0000-4000-8000-000000000011', 'Computers', 'computers', 'computer', 'cool_blue', 110),
  ('40000000-0000-4000-8000-000000000012', 'Laptops', 'laptops', 'laptop', 'cool_blue', 120),
  ('40000000-0000-4000-8000-000000000013', 'Phones', 'phones', 'smartphone', 'cyan', 130),
  ('40000000-0000-4000-8000-000000000014', 'Tablets', 'tablets', 'tablet', 'cyan', 140),
  ('40000000-0000-4000-8000-000000000015', 'Bicycles', 'bicycles', 'pedal_bike', 'success', 150),
  ('40000000-0000-4000-8000-000000000016', 'Furniture', 'furniture', 'chair', 'industrial', 160),
  ('40000000-0000-4000-8000-000000000017', 'Property damage', 'property-damage', 'home_work', 'danger', 170),
  ('40000000-0000-4000-8000-000000000018', 'Roofing', 'roofing', 'roofing', 'industrial', 180),
  ('40000000-0000-4000-8000-000000000019', 'Doors and windows', 'doors-and-windows', 'door_front', 'industrial', 190),
  ('40000000-0000-4000-8000-000000000020', 'Garden equipment', 'garden-equipment', 'yard', 'success', 200),
  ('40000000-0000-4000-8000-000000000021', 'Power tools', 'power-tools', 'construction', 'warning', 210),
  ('40000000-0000-4000-8000-000000000022', 'Industrial equipment', 'industrial-equipment', 'precision_manufacturing', 'industrial', 220),
  ('40000000-0000-4000-8000-000000000023', 'Other', 'other', 'category', 'neutral', 230)
on conflict (slug) do update set
  name = excluded.name,
  icon_token = excluded.icon_token,
  accent_token = excluded.accent_token,
  sort_order = excluded.sort_order,
  is_active = true,
  deleted_at = null;

insert into public.repair_subcategories (
  id, category_id, name, slug, sort_order
) values
  ('41000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'Engine', 'engine', 10),
  ('41000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000001', 'Brakes', 'brakes', 20),
  ('41000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000001', 'Steering', 'steering', 30),
  ('41000000-0000-4000-8000-000000000004', '40000000-0000-4000-8000-000000000001', 'Suspension', 'suspension', 40),
  ('41000000-0000-4000-8000-000000000005', '40000000-0000-4000-8000-000000000001', 'Electrical', 'electrical', 50),
  ('41000000-0000-4000-8000-000000000006', '40000000-0000-4000-8000-000000000001', 'Battery', 'battery', 60),
  ('41000000-0000-4000-8000-000000000007', '40000000-0000-4000-8000-000000000001', 'Tyres', 'tyres', 70),
  ('41000000-0000-4000-8000-000000000008', '40000000-0000-4000-8000-000000000001', 'Transmission', 'transmission', 80),
  ('41000000-0000-4000-8000-000000000009', '40000000-0000-4000-8000-000000000001', 'Cooling system', 'cooling-system', 90),
  ('41000000-0000-4000-8000-000000000010', '40000000-0000-4000-8000-000000000001', 'Air conditioning', 'air-conditioning', 100),
  ('41000000-0000-4000-8000-000000000011', '40000000-0000-4000-8000-000000000001', 'Warning lights', 'warning-lights', 110),
  ('41000000-0000-4000-8000-000000000012', '40000000-0000-4000-8000-000000000001', 'Unusual noise', 'unusual-noise', 120),
  ('41000000-0000-4000-8000-000000000013', '40000000-0000-4000-8000-000000000001', 'Other', 'other', 130),
  ('41000000-0000-4000-8000-000000000020', '40000000-0000-4000-8000-000000000011', 'Power issue', 'power-issue', 10),
  ('41000000-0000-4000-8000-000000000021', '40000000-0000-4000-8000-000000000011', 'Screen issue', 'screen-issue', 20),
  ('41000000-0000-4000-8000-000000000022', '40000000-0000-4000-8000-000000000011', 'Storage issue', 'storage-issue', 30),
  ('41000000-0000-4000-8000-000000000023', '40000000-0000-4000-8000-000000000011', 'Software issue', 'software-issue', 40),
  ('41000000-0000-4000-8000-000000000024', '40000000-0000-4000-8000-000000000011', 'Network issue', 'network-issue', 50),
  ('41000000-0000-4000-8000-000000000025', '40000000-0000-4000-8000-000000000011', 'Overheating', 'overheating', 60),
  ('41000000-0000-4000-8000-000000000026', '40000000-0000-4000-8000-000000000011', 'Slow performance', 'slow-performance', 70),
  ('41000000-0000-4000-8000-000000000027', '40000000-0000-4000-8000-000000000011', 'Data recovery', 'data-recovery', 80),
  ('41000000-0000-4000-8000-000000000028', '40000000-0000-4000-8000-000000000011', 'Other', 'other', 90),
  ('41000000-0000-4000-8000-000000000030', '40000000-0000-4000-8000-000000000002', 'Engine and drivetrain', 'engine-and-drivetrain', 10),
  ('41000000-0000-4000-8000-000000000031', '40000000-0000-4000-8000-000000000003', 'Leaking pipe', 'leaking-pipe', 10),
  ('41000000-0000-4000-8000-000000000032', '40000000-0000-4000-8000-000000000004', 'Sockets and circuits', 'sockets-and-circuits', 10),
  ('41000000-0000-4000-8000-000000000033', '40000000-0000-4000-8000-000000000005', 'Vibration and movement', 'vibration-and-movement', 10),
  ('41000000-0000-4000-8000-000000000034', '40000000-0000-4000-8000-000000000006', 'Cooling issue', 'cooling-issue', 10),
  ('41000000-0000-4000-8000-000000000035', '40000000-0000-4000-8000-000000000007', 'Heating element', 'heating-element', 10),
  ('41000000-0000-4000-8000-000000000036', '40000000-0000-4000-8000-000000000008', 'Drainage issue', 'drainage-issue', 10),
  ('41000000-0000-4000-8000-000000000037', '40000000-0000-4000-8000-000000000009', 'Not cooling', 'not-cooling', 10),
  ('41000000-0000-4000-8000-000000000038', '40000000-0000-4000-8000-000000000010', 'Boiler issue', 'boiler-issue', 10),
  ('41000000-0000-4000-8000-000000000039', '40000000-0000-4000-8000-000000000012', 'Overheating', 'overheating', 10),
  ('41000000-0000-4000-8000-000000000040', '40000000-0000-4000-8000-000000000013', 'Charging issue', 'charging-issue', 10),
  ('41000000-0000-4000-8000-000000000041', '40000000-0000-4000-8000-000000000014', 'Screen issue', 'screen-issue', 10),
  ('41000000-0000-4000-8000-000000000042', '40000000-0000-4000-8000-000000000015', 'Brakes', 'brakes', 10),
  ('41000000-0000-4000-8000-000000000043', '40000000-0000-4000-8000-000000000016', 'Frame and joints', 'frame-and-joints', 10),
  ('41000000-0000-4000-8000-000000000044', '40000000-0000-4000-8000-000000000017', 'Water damage', 'water-damage', 10),
  ('41000000-0000-4000-8000-000000000045', '40000000-0000-4000-8000-000000000018', 'Leak', 'leak', 10),
  ('41000000-0000-4000-8000-000000000046', '40000000-0000-4000-8000-000000000019', 'Alignment and sealing', 'alignment-and-sealing', 10),
  ('41000000-0000-4000-8000-000000000047', '40000000-0000-4000-8000-000000000020', 'Engine issue', 'engine-issue', 10),
  ('41000000-0000-4000-8000-000000000048', '40000000-0000-4000-8000-000000000021', 'Motor and battery', 'motor-and-battery', 10),
  ('41000000-0000-4000-8000-000000000049', '40000000-0000-4000-8000-000000000022', 'Mechanical fault', 'mechanical-fault', 10),
  ('41000000-0000-4000-8000-000000000050', '40000000-0000-4000-8000-000000000023', 'Other', 'other', 10)
on conflict (category_id, slug) do update set
  name = excluded.name,
  sort_order = excluded.sort_order,
  is_active = true,
  deleted_at = null;

-- Synthetic Auth users -------------------------------------------------------

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  last_sign_in_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-4000-8000-000000000001',
    'authenticated', 'authenticated', 'alex.customer@example.test',
    extensions.crypt('FixBriefDemo123!', extensions.gen_salt('bf')),
    now(), now(), '{"provider":"email","providers":["email"]}',
    '{"full_name":"Alex Morgan"}', now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-4000-8000-000000000002',
    'authenticated', 'authenticated', 'priya.customer@example.test',
    extensions.crypt('FixBriefDemo123!', extensions.gen_salt('bf')),
    now(), now(), '{"provider":"email","providers":["email"]}',
    '{"full_name":"Priya Shah"}', now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '20000000-0000-4000-8000-000000000001',
    'authenticated', 'authenticated', 'sam@northline.example.test',
    extensions.crypt('FixBriefDemo123!', extensions.gen_salt('bf')),
    now(), now(), '{"provider":"email","providers":["email"]}',
    '{"full_name":"Sam North"}', now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '20000000-0000-4000-8000-000000000002',
    'authenticated', 'authenticated', 'leah@homecare.example.test',
    extensions.crypt('FixBriefDemo123!', extensions.gen_salt('bf')),
    now(), now(), '{"provider":"email","providers":["email"]}',
    '{"full_name":"Leah Williams"}', now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '20000000-0000-4000-8000-000000000003',
    'authenticated', 'authenticated', 'noah@techrevive.example.test',
    extensions.crypt('FixBriefDemo123!', extensions.gen_salt('bf')),
    now(), now(), '{"provider":"email","providers":["email"]}',
    '{"full_name":"Noah Chen"}', now(), now(), '', '', '', ''
  )
on conflict (id) do nothing;

insert into auth.identities (
  id,
  user_id,
  provider_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
select
  u.id,
  u.id,
  u.id::text,
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  'email',
  now(),
  now(),
  now()
from auth.users as u
where u.id in (
  '10000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000003'
)
on conflict (provider_id, provider) do nothing;

-- Profiles ------------------------------------------------------------------

update public.profiles set
  role = 'customer', onboarding_status = 'approved', display_name = 'Alex Morgan'
where id = '10000000-0000-4000-8000-000000000001';
update public.profiles set
  role = 'customer', onboarding_status = 'approved', display_name = 'Priya Shah'
where id = '10000000-0000-4000-8000-000000000002';
update public.profiles set
  role = 'repairer', onboarding_status = 'approved', display_name = 'Sam North'
where id = '20000000-0000-4000-8000-000000000001';
update public.profiles set
  role = 'repairer', onboarding_status = 'approved', display_name = 'Leah Williams'
where id = '20000000-0000-4000-8000-000000000002';
update public.profiles set
  role = 'repairer', onboarding_status = 'approved', display_name = 'Noah Chen'
where id = '20000000-0000-4000-8000-000000000003';

insert into public.customer_profiles (
  user_id, full_name, phone_number, location_label, approximate_location,
  preferred_contact
) values
  (
    '10000000-0000-4000-8000-000000000001', 'Alex Morgan', '+447700900001',
    'Manchester M20',
    extensions.st_setsrid(extensions.st_makepoint(-2.23, 53.42), 4326)::extensions.geography,
    'in_app'
  ),
  (
    '10000000-0000-4000-8000-000000000002', 'Priya Shah', '+447700900002',
    'Stockport SK4',
    extensions.st_setsrid(extensions.st_makepoint(-2.16, 53.42), 4326)::extensions.geography,
    'email'
  );

insert into public.repairer_profiles (
  user_id, full_name, business_name, phone_number, business_email,
  business_description, years_experience, qualifications,
  inspection_fee_minor, service_radius_kilometres, business_address,
  business_location, working_hours, emergency_service_available,
  mobile_repair_available, collection_service_available,
  verification_status, verified_at, is_marketplace_visible
) values
  (
    '20000000-0000-4000-8000-000000000001', 'Sam North', 'Northline Auto',
    '+441612000101', 'sam@northline.example.test',
    'Independent vehicle diagnostics and mechanical repair specialist.', 14,
    array['IMI Level 3 Light Vehicle Maintenance'], 4500, 35, 'Trafford Park, Manchester',
    extensions.st_setsrid(extensions.st_makepoint(-2.31, 53.47), 4326)::extensions.geography,
    'Mon-Fri 08:00-18:00, Sat 09:00-14:00', true, true, true,
    'verified', now(), true
  ),
  (
    '20000000-0000-4000-8000-000000000002', 'Leah Williams', 'HomeCare Repairs',
    '+441612000202', 'leah@homecare.example.test',
    'Domestic appliance, plumbing, furniture, and bicycle repair across Greater Manchester.', 11,
    array['City and Guilds Domestic Appliance Servicing'], 3500, 30, 'Levenshulme, Manchester',
    extensions.st_setsrid(extensions.st_makepoint(-2.19, 53.44), 4326)::extensions.geography,
    'Mon-Sat 08:30-17:30', true, true, true,
    'verified', now(), true
  ),
  (
    '20000000-0000-4000-8000-000000000003', 'Noah Chen', 'TechRevive',
    '+441612000303', 'noah@techrevive.example.test',
    'Board-level laptop, computer, and mobile-device diagnostics with data-conscious handling.', 9,
    array['CompTIA A+', 'IPC electronics rework'], 3000, 25, 'Manchester City Centre',
    extensions.st_setsrid(extensions.st_makepoint(-2.24, 53.48), 4326)::extensions.geography,
    'Mon-Fri 09:00-18:00', false, false, true,
    'verified', now(), true
  );

insert into public.repairer_specialisations (
  repairer_id, category_id, subcategory_id, specialisation, years_experience
) values
  ('20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000012', 'Vehicle noise diagnostics', 14),
  ('20000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000003', '41000000-0000-4000-8000-000000000031', 'Leak tracing', 11),
  ('20000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000005', '41000000-0000-4000-8000-000000000033', 'Drum and suspension faults', 9),
  ('20000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000015', '41000000-0000-4000-8000-000000000042', 'Bicycle brake servicing', 7),
  ('20000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000016', '41000000-0000-4000-8000-000000000043', 'Furniture joint repair', 8),
  ('20000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000012', '41000000-0000-4000-8000-000000000039', 'Laptop thermal diagnostics', 9),
  ('20000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000013', '41000000-0000-4000-8000-000000000040', 'Charging-port microsoldering', 8);

insert into public.service_areas (
  repairer_id, area_name, centre, radius_kilometres,
  emergency_service, mobile_repair, collection_service
)
select
  rp.user_id,
  rp.business_address,
  rp.business_location,
  rp.service_radius_kilometres,
  rp.emergency_service_available,
  rp.mobile_repair_available,
  rp.collection_service_available
from public.repairer_profiles as rp;

-- Seven realistic repair-request examples ----------------------------------

insert into public.repair_requests (
  id, customer_id, client_request_id, category_id, subcategory_id,
  item_name, brand, model, vehicle_make, vehicle_model, vehicle_year,
  vehicle_mileage, problem_description, structured_brief, urgency,
  approximate_area, approximate_location, inspection_required,
  mobile_repair_required, status, published_at
) values
  (
    '30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
    '31000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001',
    '41000000-0000-4000-8000-000000000012', 'Family car', 'Ford', 'Focus', 'Ford', 'Focus', 2017,
    68000, 'Clicking noise from the front-left wheel when turning slowly.',
    'Inspect the front-left wheel, steering, CV joint, and nearby suspension components.',
    'within_3_days', 'Manchester M20',
    extensions.st_setsrid(extensions.st_makepoint(-2.23, 53.42), 4326)::extensions.geography,
    true, false, 'published', now() - interval '3 hours'
  ),
  (
    '30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002',
    '31000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000005',
    '41000000-0000-4000-8000-000000000033', 'Washing machine', 'Bosch', 'Series 4', null, null, null,
    null, 'The machine vibrates heavily during the spin cycle and has moved forward twice.',
    'Check levelling, transit bolts, load distribution, suspension, bearings, and counterweights.',
    'within_1_week', 'Stockport SK4',
    extensions.st_setsrid(extensions.st_makepoint(-2.16, 53.42), 4326)::extensions.geography,
    true, true, 'assessment_complete', null
  ),
  (
    '30000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001',
    '31000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000003',
    '41000000-0000-4000-8000-000000000031', 'Kitchen sink pipe', null, null, null, null, null,
    null, 'A slow leak is visible beneath the sink at the compression joint.',
    'Locate and isolate the leak before checking the compression fitting, washer, and pipe alignment.',
    'within_24_hours', 'Manchester M20',
    extensions.st_setsrid(extensions.st_makepoint(-2.23, 53.42), 4326)::extensions.geography,
    false, true, 'published', now() - interval '1 hour'
  ),
  (
    '30000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000002',
    '31000000-0000-4000-8000-000000000004', '40000000-0000-4000-8000-000000000012',
    '41000000-0000-4000-8000-000000000039', 'Work laptop', 'Dell', 'Latitude 5420', null, null, null,
    null, 'The fan runs loudly and the laptop shuts down during video calls.',
    'Inspect vents, fan, thermal interface, background load, and battery condition without exposing user data.',
    'within_3_days', 'Stockport SK4',
    extensions.st_setsrid(extensions.st_makepoint(-2.16, 53.42), 4326)::extensions.geography,
    true, false, 'quote_accepted', now() - interval '10 days'
  ),
  (
    '30000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000001',
    '31000000-0000-4000-8000-000000000005', '40000000-0000-4000-8000-000000000015',
    '41000000-0000-4000-8000-000000000042', 'Commuter bicycle', 'Trek', 'FX 2', null, null, null,
    null, 'The rear brake lever reaches the handlebar and braking feels weak.',
    'Inspect pad wear, cable or hydraulic pressure, rotor/rim condition, and brake adjustment.',
    'within_3_days', 'Manchester M20',
    extensions.st_setsrid(extensions.st_makepoint(-2.23, 53.42), 4326)::extensions.geography,
    false, true, 'published', now() - interval '7 hours'
  ),
  (
    '30000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000002',
    '31000000-0000-4000-8000-000000000006', '40000000-0000-4000-8000-000000000013',
    '41000000-0000-4000-8000-000000000040', 'Mobile phone', 'Google', 'Pixel 7', null, null, null,
    null, 'Charging works only when the cable is held at an angle.',
    'Check the cable, compacted debris, connector wear, and charging-port solder joints.',
    'within_1_week', 'Stockport SK4',
    extensions.st_setsrid(extensions.st_makepoint(-2.16, 53.42), 4326)::extensions.geography,
    true, false, 'published', now() - interval '1 day'
  ),
  (
    '30000000-0000-4000-8000-000000000007', '10000000-0000-4000-8000-000000000001',
    '31000000-0000-4000-8000-000000000007', '40000000-0000-4000-8000-000000000016',
    '41000000-0000-4000-8000-000000000043', 'Dining chair', null, null, null, null, null,
    null, 'One rear leg is loose and a joint opens when weight is applied.',
    'Inspect the joint, surrounding timber, old adhesive, and fixings before deciding whether clamping is sufficient.',
    'flexible', 'Manchester M20',
    extensions.st_setsrid(extensions.st_makepoint(-2.23, 53.42), 4326)::extensions.geography,
    false, false, 'published', now() - interval '2 days'
  );

insert into public.repair_request_symptoms (request_id, kind, description, sort_order) values
  ('30000000-0000-4000-8000-000000000001', 'heard', 'Repeated click while steering at low speed.', 10),
  ('30000000-0000-4000-8000-000000000002', 'vibration', 'Severe vibration during high-speed spin.', 10),
  ('30000000-0000-4000-8000-000000000003', 'seen', 'Water beads around a compression joint.', 10),
  ('30000000-0000-4000-8000-000000000004', 'heat', 'Base and keyboard become unusually hot.', 10),
  ('30000000-0000-4000-8000-000000000005', 'felt', 'Rear lever has very little resistance.', 10),
  ('30000000-0000-4000-8000-000000000006', 'other', 'Cable must be angled for charging.', 10),
  ('30000000-0000-4000-8000-000000000007', 'movement', 'Rear leg moves sideways under light load.', 10);

-- Validated AI snapshots for every example. These are cautious intake aids,
-- not confirmed diagnoses.
insert into public.ai_assessments (
  id, request_id, version, problem_summary, fault_categories, confidence,
  urgency, safety_risk, recommended_professional_type, missing_information,
  stop_using_item, safety_warning, structured_repair_brief, suggested_evidence,
  suggested_inspection_type, input_hash, model_identifier, prompt_version,
  safety_version, validation_status
) values
  ('50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 1,
   'Clicking near the front-left wheel during low-speed turns.', array['drivetrain', 'steering', 'suspension'],
   'medium', 'within_3_days', 'moderate', 'Vehicle technician', array['Whether vibration is present'],
   true, 'Avoid unnecessary driving if steering changes or the noise becomes severe.',
   '{"disclaimer":"AI-assisted assessment — not a confirmed diagnosis.","summary":"Inspect the front-left corner before continued regular use."}',
   array['Short video with sound while turning safely'], 'Workshop inspection', repeat('a', 64), 'seed-model', 'v1', 'v1', 'valid'),
  ('50000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000002', 1,
   'Excessive washing-machine movement during spin.', array['levelling', 'suspension', 'bearing'],
   'medium', 'within_1_week', 'moderate', 'Appliance repairer', array['Whether transit bolts were removed'],
   true, 'Stop the cycle if the machine moves violently or strikes nearby units.',
   '{"disclaimer":"AI-assisted assessment — not a confirmed diagnosis.","summary":"Check installation and internal suspension."}',
   array['Level photo', 'Short spin-cycle video'], 'In-home inspection', repeat('b', 64), 'seed-model', 'v1', 'v1', 'valid'),
  ('50000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000003', 1,
   'Slow leak at a sink compression joint.', array['seal', 'joint alignment', 'pipe damage'],
   'medium', 'within_24_hours', 'moderate', 'Plumber', array['Rate of water accumulation'],
   false, 'Isolate the water supply if the leak worsens or approaches electrical equipment.',
   '{"disclaimer":"AI-assisted assessment — not a confirmed diagnosis.","summary":"Inspect and reseal the visible compression joint."}',
   array['Close-up image while dry'], 'Mobile inspection', repeat('c', 64), 'seed-model', 'v1', 'v1', 'valid'),
  ('50000000-0000-4000-8000-000000000004', '30000000-0000-4000-8000-000000000004', 1,
   'Laptop overheats and shuts down under sustained load.', array['airflow', 'fan', 'thermal interface'],
   'medium', 'within_3_days', 'moderate', 'Computer repairer', array['Recent software or firmware changes'],
   true, 'Back up important data and stop using the device if there is swelling, smoke, or a burning smell.',
   '{"disclaimer":"AI-assisted assessment — not a confirmed diagnosis.","summary":"Perform privacy-conscious thermal diagnostics."}',
   array['Vent photographs', 'Temperature screenshot'], 'Bench inspection', repeat('d', 64), 'seed-model', 'v1', 'v1', 'valid'),
  ('50000000-0000-4000-8000-000000000005', '30000000-0000-4000-8000-000000000005', 1,
   'Rear bicycle brake has weak lever pressure and braking.', array['pad wear', 'cable or hydraulic issue', 'adjustment'],
   'medium', 'within_3_days', 'high', 'Bicycle mechanic', array['Brake type'],
   true, 'Do not ride until effective braking has been restored and checked.',
   '{"disclaimer":"AI-assisted assessment — not a confirmed diagnosis.","summary":"Inspect the complete rear braking system before riding."}',
   array['Brake-pad and caliper photographs'], 'Workshop inspection', repeat('e', 64), 'seed-model', 'v1', 'v1', 'valid'),
  ('50000000-0000-4000-8000-000000000006', '30000000-0000-4000-8000-000000000006', 1,
   'Phone charges only when the connector is held at an angle.', array['debris', 'connector wear', 'port damage'],
   'medium', 'within_1_week', 'low', 'Mobile-device technician', array['Whether multiple known-good cables were tested'],
   false, 'Stop charging if the connector becomes hot, smells unusual, or shows damage.',
   '{"disclaimer":"AI-assisted assessment — not a confirmed diagnosis.","summary":"Inspect the cable and charging port without probing it with metal tools."}',
   array['Well-lit port photograph'], 'Bench inspection', repeat('f', 64), 'seed-model', 'v1', 'v1', 'valid'),
  ('50000000-0000-4000-8000-000000000007', '30000000-0000-4000-8000-000000000007', 1,
   'Dining-chair rear leg joint opens under load.', array['adhesive failure', 'loose fixing', 'timber damage'],
   'medium', 'flexible', 'moderate', 'Furniture repairer', array['Whether the timber is split'],
   true, 'Do not sit on the chair until the joint has been repaired and tested.',
   '{"disclaimer":"AI-assisted assessment — not a confirmed diagnosis.","summary":"Inspect the joint before choosing a clamped repair or replacement component."}',
   array['Joint close-up from two angles'], 'Workshop or mobile inspection', repeat('1', 64), 'seed-model', 'v1', 'v1', 'valid');

insert into public.ai_possible_causes (
  assessment_id, cause, confidence, reasoning_summary, sort_order
) values
  ('50000000-0000-4000-8000-000000000001', 'Outer CV joint wear', 0.620, 'Clicking during turns can be consistent with CV-joint wear, but inspection is required.', 10),
  ('50000000-0000-4000-8000-000000000002', 'Machine not level or unstable load', 0.580, 'Installation and load distribution are common non-diagnostic checks.', 10),
  ('50000000-0000-4000-8000-000000000003', 'Compression washer or alignment issue', 0.700, 'The visible joint location makes its seal a reasonable inspection point.', 10),
  ('50000000-0000-4000-8000-000000000004', 'Restricted airflow or degraded thermal interface', 0.650, 'Heat under load supports a thermal-system inspection.', 10),
  ('50000000-0000-4000-8000-000000000005', 'Brake adjustment or hydraulic pressure problem', 0.680, 'Low lever resistance requires the whole brake system to be checked.', 10),
  ('50000000-0000-4000-8000-000000000006', 'Charging-port debris or wear', 0.660, 'Angle-sensitive charging can indicate poor contact.', 10),
  ('50000000-0000-4000-8000-000000000007', 'Adhesive joint failure', 0.610, 'Visible joint movement supports inspection of glue surfaces and timber.', 10);

-- Quotes, conversations, messages, completed job, and review ----------------

insert into public.quotes (
  id, request_id, repairer_id, status, inspection_fee_minor,
  labour_minimum_minor, labour_maximum_minor, parts_minimum_minor,
  parts_maximum_minor, earliest_availability, estimated_duration_minutes,
  mobile_repair_available, warranty_days, expires_at, additional_comments,
  assumptions, exclusions, submitted_at
) values
  (
    '60000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001', 'submitted', 4500, 9000, 18000, 0, 25000,
    now() + interval '1 day', 120, true, 90, now() + interval '7 days',
    'Provisional range pending physical inspection of the front-left corner.',
    array['Vehicle can be safely moved to the workshop'],
    array['Wheel alignment and unrelated wear are excluded'], now()
  ),
  (
    '60000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000002', 'submitted', 3500, 4500, 9000, 500, 3000,
    now() + interval '4 hours', 90, true, 30, now() + interval '5 days',
    'Provisional estimate for diagnosis and a straightforward joint repair.',
    array['Leak is confined to the visible sink connection'],
    array['Hidden pipe damage is excluded'], now()
  ),
  (
    '60000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000004',
    '20000000-0000-4000-8000-000000000003', 'accepted', 3000, 7500, 14000, 1500, 6000,
    now() - interval '9 days', 180, false, 90, now() + interval '1 day',
    'Accepted provisional thermal-service estimate.',
    array['No board-level damage is found'], array['Data recovery is excluded'], now() - interval '10 days'
  );

select private.ensure_conversation(
  '30000000-0000-4000-8000-000000000004',
  '20000000-0000-4000-8000-000000000003'
);

insert into public.messages (
  conversation_id, sender_id, client_message_id, message_type, body, sent_at
)
select
  c.id,
  '10000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000001',
  'text',
  'The clicking is most noticeable while turning into a parking space.',
  now() - interval '2 hours'
from public.conversations as c
where c.request_id = '30000000-0000-4000-8000-000000000001'
  and c.repairer_id = '20000000-0000-4000-8000-000000000001';

insert into public.messages (
  conversation_id, sender_id, client_message_id, message_type, body, sent_at
)
select
  c.id,
  '20000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000002',
  'text',
  'Thanks. Please avoid unnecessary driving if steering changes; the quote remains provisional until inspection.',
  now() - interval '90 minutes'
from public.conversations as c
where c.request_id = '30000000-0000-4000-8000-000000000001'
  and c.repairer_id = '20000000-0000-4000-8000-000000000001';

insert into public.jobs (
  id, request_id, accepted_quote_id, customer_id, repairer_id, status,
  agreed_minimum_minor, agreed_maximum_minor, completed_at, accepted_at
) values (
  '80000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000004',
  '60000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000003',
  'completed', 12000, 23000, now() - interval '2 days', now() - interval '10 days'
);

update public.conversations set job_id = '80000000-0000-4000-8000-000000000001'
where request_id = '30000000-0000-4000-8000-000000000004'
  and repairer_id = '20000000-0000-4000-8000-000000000003';

insert into public.reviews (
  id, job_id, author_id, reviewed_user_id, direction, overall_rating,
  quality_rating, communication_rating, punctuality_rating, value_rating,
  quote_accuracy_rating, comment
) values (
  '90000000-0000-4000-8000-000000000001',
  '80000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000003',
  'customer_to_repairer', 5, 5, 5, 5, 4, 5,
  'Clear communication, careful handling of my data, and the final cost stayed within the estimate.'
);

-- Stage 7 marketplace ranking inputs ----------------------------------------

update public.repairer_profiles
set
  average_rating = case user_id
    when '20000000-0000-4000-8000-000000000001' then 4.80
    when '20000000-0000-4000-8000-000000000002' then 4.70
    else 5.00
  end,
  review_count = case user_id
    when '20000000-0000-4000-8000-000000000001' then 126
    when '20000000-0000-4000-8000-000000000002' then 89
    else 1
  end,
  completed_job_count = case user_id
    when '20000000-0000-4000-8000-000000000001' then 214
    when '20000000-0000-4000-8000-000000000002' then 147
    else 1
  end,
  response_rate = case user_id
    when '20000000-0000-4000-8000-000000000001' then 94
    when '20000000-0000-4000-8000-000000000002' then 91
    else 100
  end,
  quote_acceptance_rate = case user_id
    when '20000000-0000-4000-8000-000000000001' then 61
    when '20000000-0000-4000-8000-000000000002' then 58
    else 100
  end
where user_id in (
  '20000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000003'
);

insert into public.availability_slots (
  repairer_id, kind, weekday, starts_at, ends_at, timezone
)
select
  repairer.user_id,
  'recurring'::public.availability_kind,
  weekday.value,
  case when repairer.user_id = '20000000-0000-4000-8000-000000000001'
    then '08:00'::time else '08:30'::time end,
  case when repairer.user_id = '20000000-0000-4000-8000-000000000001'
    then '18:00'::time else '17:30'::time end,
  'Europe/London'
from public.repairer_profiles as repairer
cross join generate_series(1, 5) as weekday(value)
where repairer.user_id in (
  '20000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000003'
);

insert into public.availability_slots (
  repairer_id, kind, weekday, starts_at, ends_at, timezone
) values
  (
    '20000000-0000-4000-8000-000000000001', 'recurring', 6,
    '09:00', '14:00', 'Europe/London'
  ),
  (
    '20000000-0000-4000-8000-000000000002', 'recurring', 6,
    '09:00', '15:00', 'Europe/London'
  );

-- Stage 8 quote-comparison examples ----------------------------------------

insert into public.quotes (
  id, request_id, repairer_id, status, inspection_fee_minor,
  callout_fee_minor, labour_minimum_minor, labour_maximum_minor,
  parts_minimum_minor, parts_maximum_minor,
  other_charges_minimum_minor, other_charges_maximum_minor,
  earliest_availability, estimated_duration_minutes,
  collection_available, mobile_repair_available, warranty_days,
  expires_at, additional_comments, assumptions, exclusions, submitted_at
) values
  (
    '60000000-0000-4000-8000-000000000004',
    '30000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000002',
    'submitted', 2500, 3000, 7500, 14500, 2500, 18000, 0, 0,
    now() + interval '18 hours', 150, true, true, 180,
    now() + interval '5 days',
    'Mobile inspection followed by repair where safe and practical.',
    array['The reported noise is limited to the front-left corner'],
    array['Wheel alignment and additional axle wear are excluded'], now()
  ),
  (
    '60000000-0000-4000-8000-000000000005',
    '30000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000003',
    'submitted', 3000, 0, 6500, 12500, 1500, 13500, 0, 0,
    now() + interval '3 days', 180, false, false, 60,
    now() + interval '7 days',
    'Workshop inspection is required before parts are authorised.',
    array['The vehicle can be delivered safely to the workshop'],
    array['Recovery, alignment, and unrelated wear are excluded'], now()
  );

update public.repair_requests
set status = 'quotes_received', updated_at = now()
where id = '30000000-0000-4000-8000-000000000001';
