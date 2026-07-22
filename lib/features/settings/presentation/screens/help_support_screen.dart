import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help and support'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: FluidBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const LiquidGlassCard(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Immediate safety concern?',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Stop using anything that is smoking, sparking, leaking gas or fuel, structurally unstable, or unsafe to control. Contact the appropriate qualified professional or emergency service.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LiquidGlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Column(
                children: [
                  ExpansionTile(
                    title: Text('Is the AI assessment a diagnosis?'),
                    childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Text(
                        'No. It organises the information you provide and suggests possible causes. A qualified professional must inspect the item.',
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text('Why is my quote provisional?'),
                    childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Text(
                        'The final fault, parts, and labour may change after physical inspection. Any change should be explained before work continues.',
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text('How is my exact address protected?'),
                    childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Text(
                        'Repair professionals initially see only an approximate area. You control exact-address release during an authorised appointment.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LiquidGlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact support',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'For this MVP, email support@fixbrief.example. Production support channels are configured during Stage 12.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: 'support@fixbrief.example'),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Support email copied.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy support email'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => context.push(AppPaths.privacyPolicy),
              child: const Text('Read the privacy policy'),
            ),
          ],
        ),
      ),
    );
  }
}
