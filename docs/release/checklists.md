# Production, privacy, and store checklists

Unchecked blocking items mean the app must not be published.

## Production readiness

- [ ] A production Supabase project exists with point-in-time recovery or an
      approved backup strategy.
- [ ] Every migration and pgTAP test passes from a clean database.
- [ ] RLS, storage policies, RPC grants, and role boundaries receive an
      independent security review.
- [ ] Production authentication URLs, SMTP, rate limits, CAPTCHA/abuse
      controls, and redirect allowlists are configured.
- [ ] The AI Edge Function has production secrets, spend limits, timeouts,
      safety monitoring, and a tested provider-outage fallback.
- [ ] Data-export and scheduled-deletion workers are deployed, observable,
      idempotent, and tested through completion.
- [ ] Push transport is configured or push controls are clearly marked
      unavailable; in-app notifications continue to work independently.
- [ ] Staging passes the manual release matrix in `testing.md`.
- [ ] Monitoring covers API failures, Edge Functions, database saturation,
      storage failures, and crash-free sessions without collecting excess data.
- [ ] Support ownership, incident response, backups, restore drills, rollback,
      and status communication are documented.
- [ ] Production environment validation passes and no demo/test endpoint is in
      the release artifact.
- [ ] Versions/build numbers are unique and release notes identify migrations.
- [ ] A signed Android AAB and signed iOS IPA are tested through internal
      distribution before promotion.

## Privacy and safety

- [ ] A qualified lawyer approves the privacy policy, terms, retention periods,
      marketplace responsibilities, AI language, and jurisdictional notices.
- [ ] The public privacy policy describes every collected data type, purpose,
      processor, retention period, export route, deletion route, and contact.
- [ ] App Store privacy answers, the iOS privacy manifest, Google Play Data
      safety, and actual app behaviour agree.
- [ ] No evidence is used for model training without explicit, recorded,
      revocable consent.
- [ ] AI prompts remove names, email, phone, precise address, and unrelated
      metadata before provider processing.
- [ ] Raw voice recordings are deleted after transcription or the clearly
      disclosed retention period.
- [ ] Private evidence uses signed, short-lived access and is unavailable to
      unrelated users and repairers.
- [ ] Precise addresses are released only at the authorised appointment/job
      stage; discovery uses approximate areas.
- [ ] Users can delete evidence, block/report users, request export, and start
      or cancel account deletion.
- [ ] Export and deletion include storage objects, messages, audit/legal
      exceptions, and downstream processors.
- [ ] Permission prompts are contextual and the app remains understandable
      when microphone, photos, speech, or location access is denied.
- [ ] High-risk warnings and the non-diagnosis disclaimer are visible,
      accessible, and tested.
- [ ] Secrets, logs, analytics, crash reports, and support tools are checked for
      personal data leakage.

## Store publication

- [ ] Developer/legal entity, tax, banking, agreements, and store roles are
      complete in Play Console and App Store Connect.
- [ ] App name, package/bundle IDs, category, age/content rating, countries,
      pricing, support URL, marketing URL, and privacy URL are final.
- [ ] Final app icon, adaptive Android icon, launch assets, phone/tablet
      screenshots, captions, description, keywords, and release notes are
      approved and contain no test data.
- [ ] Review credentials use a dedicated least-privilege account with a clear
      walkthrough for both customer and repairer experiences.
- [ ] Google Play Data safety and App Store privacy nutrition labels are
      approved by privacy/legal owners.
- [ ] Android Play App Signing is enabled and the upload key is backed up.
- [ ] Apple certificates/profiles and App Store Connect API keys are protected
      and recovery ownership is recorded.
- [ ] Automated store checks, Android pre-launch report, TestFlight testing,
      accessibility testing, and representative physical-device testing pass.
- [ ] Deep links, password reset, email verification, offline recovery,
      account deletion, support contact, and legal links work in release mode.
- [ ] Export-control/encryption answers are reviewed; the current iOS build
      declares no non-exempt encryption.
- [ ] A phased/staged rollout, monitoring window, rollback criteria, support
      coverage, and post-release owner are scheduled.
