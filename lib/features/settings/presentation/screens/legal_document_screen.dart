import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:flutter/material.dart';

enum LegalDocument { privacy, terms }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final privacy = document == LegalDocument.privacy;
    return Scaffold(
      appBar: AppBar(
        title: Text(privacy ? 'Privacy policy' : 'Terms and conditions'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: FluidBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            LiquidGlassCard(
              padding: const EdgeInsets.all(18),
              tint: Theme.of(context).colorScheme.tertiaryContainer,
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.gavel_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'MVP legal placeholder — this document requires review by qualified legal counsel before publication.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LiquidGlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: privacy
                    ? const [
                        _LegalSection(
                          title: 'Information we use',
                          body:
                              'FixBrief stores account details, repair descriptions, evidence, quotes, messages, appointments, jobs, and reviews needed to provide the marketplace service.',
                        ),
                        _LegalSection(
                          title: 'AI-assisted processing',
                          body:
                              'Only repair-relevant information should be sent for AI-assisted assessment. Evidence is not used for model training without explicit consent.',
                        ),
                        _LegalSection(
                          title: 'Location and evidence',
                          body:
                              'Approximate areas support matching. Exact addresses and private evidence are released only through authorised workflows and signed access.',
                        ),
                        _LegalSection(
                          title: 'Your choices',
                          body:
                              'You can manage notifications, delete uploaded media, request an export, block users, and schedule account deletion from Settings.',
                        ),
                      ]
                    : const [
                        _LegalSection(
                          title: 'Marketplace role',
                          body:
                              'FixBrief helps customers and independent repair professionals exchange repair information and provisional estimates. It is not the repair provider.',
                        ),
                        _LegalSection(
                          title: 'AI and safety',
                          body:
                              'AI-assisted assessments are not confirmed diagnoses. Users must follow safety warnings and obtain qualified physical inspection.',
                        ),
                        _LegalSection(
                          title: 'Quotes and work',
                          body:
                              'Quotes are provisional estimates. Any change in scope or final cost should be explained and agreed between the parties.',
                        ),
                        _LegalSection(
                          title: 'Acceptable use',
                          body:
                              'Harassment, fraud, unsafe content, unsolicited contact, fake reviews, and attempts to bypass platform security are prohibited.',
                        ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 7),
          Text(body),
        ],
      ),
    );
  }
}
