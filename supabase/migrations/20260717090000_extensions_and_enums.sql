-- FixBrief Stage 4: extensions, private helper schema, and domain enums.

create schema if not exists extensions;
create schema if not exists private;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists postgis with schema extensions;
create extension if not exists pg_trgm with schema extensions;

create type public.app_user_role as enum ('customer', 'repairer');
create type public.onboarding_status as enum (
  'not_started',
  'in_progress',
  'submitted',
  'approved',
  'rejected'
);
create type public.account_status as enum (
  'active',
  'suspended',
  'deletion_requested',
  'deleted'
);
create type public.preferred_contact_method as enum (
  'in_app',
  'email',
  'phone',
  'sms'
);
create type public.verification_status as enum (
  'unverified',
  'pending',
  'verified',
  'rejected',
  'suspended'
);
create type public.request_status as enum (
  'draft',
  'submitted',
  'assessment_complete',
  'published',
  'under_review',
  'quotes_received',
  'quote_accepted',
  'cancelled',
  'archived'
);
create type public.symptom_kind as enum (
  'seen',
  'heard',
  'felt',
  'smell',
  'heat',
  'vibration',
  'movement',
  'warning_light',
  'error_code',
  'timing',
  'repair_history',
  'other'
);
create type public.symptom_source as enum ('typed', 'voice', 'suggested');
create type public.urgency_level as enum (
  'emergency',
  'asap',
  'within_24_hours',
  'within_3_days',
  'within_1_week',
  'flexible'
);
create type public.risk_level as enum (
  'none',
  'low',
  'moderate',
  'high',
  'critical'
);
create type public.confidence_level as enum ('low', 'medium', 'high');
create type public.media_kind as enum (
  'image',
  'video',
  'audio',
  'error_code',
  'receipt',
  'warranty',
  'document'
);
create type public.upload_status as enum (
  'pending',
  'uploading',
  'ready',
  'failed',
  'quarantined',
  'deleted'
);
create type public.assessment_validation_status as enum (
  'pending',
  'valid',
  'invalid',
  'rejected'
);
create type public.quote_status as enum (
  'draft',
  'submitted',
  'accepted',
  'rejected',
  'withdrawn',
  'expired'
);
create type public.quote_item_type as enum (
  'inspection',
  'call_out',
  'labour',
  'parts',
  'other'
);
create type public.job_status as enum (
  'inspection_requested',
  'inspection_booked',
  'repair_scheduled',
  'repair_in_progress',
  'waiting_for_parts',
  'ready_for_collection',
  'completed',
  'cancelled',
  'disputed'
);
create type public.appointment_kind as enum ('inspection', 'repair', 'collection');
create type public.appointment_status as enum (
  'proposed',
  'confirmed',
  'declined',
  'cancelled',
  'completed',
  'no_show'
);
create type public.availability_kind as enum (
  'recurring',
  'exception',
  'unavailable'
);
create type public.conversation_status as enum ('active', 'closed');
create type public.message_type as enum (
  'text',
  'image',
  'document',
  'repair_evidence',
  'appointment',
  'quote',
  'job_system'
);
create type public.review_direction as enum (
  'customer_to_repairer',
  'repairer_to_customer'
);
create type public.notification_type as enum (
  'new_quote',
  'quote_accepted',
  'quote_rejected',
  'new_message',
  'inspection_proposed',
  'appointment_confirmed',
  'appointment_reminder',
  'job_status_updated',
  'repair_completed',
  'review_requested',
  'quote_expiring',
  'matching_request'
);
create type public.report_reason as enum (
  'spam',
  'harassment',
  'fraud',
  'unsafe_content',
  'inappropriate_content',
  'identity_concern',
  'other'
);
create type public.report_status as enum (
  'submitted',
  'under_review',
  'resolved',
  'dismissed'
);
