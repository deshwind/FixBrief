-- FixBrief Stage 6: auditable AI assessment metadata and safety invariants.

alter table public.ai_assessments
  add column recommended_specialisations text[] not null default '{}',
  add column inspection_recommendation text,
  add column disclaimer text not null default 'AI-assisted assessment — not a confirmed diagnosis.',
  add column is_fallback boolean not null default false,
  add column provider_response_id text;

alter table public.ai_assessments
  add constraint ai_assessments_disclaimer_exact check (
    disclaimer = 'AI-assisted assessment — not a confirmed diagnosis.'
  ),
  add constraint ai_assessments_high_risk_stop check (
    safety_risk not in ('high', 'critical')
    or (
      stop_using_item
      and nullif(btrim(safety_warning), '') is not null
    )
  ),
  add constraint ai_assessments_provider_response_length check (
    provider_response_id is null or char_length(provider_response_id) <= 200
  );

create index ai_usage_events_recent_user_idx
  on public.ai_usage_events (user_id, created_at desc)
  where operation in ('generate', 'answer');

create index ai_assessments_valid_latest_idx
  on public.ai_assessments (request_id, version desc)
  where validation_status = 'valid';

comment on column public.ai_assessments.is_fallback is
  'True when a conservative non-model response was used after provider failure.';
comment on column public.ai_assessments.provider_response_id is
  'Provider request identifier for server-side support correlation; never exposed as a secret.';
