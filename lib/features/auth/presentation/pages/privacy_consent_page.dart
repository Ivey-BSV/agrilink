import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';

class PrivacyConsentPage extends StatefulWidget {
  const PrivacyConsentPage({super.key});

  @override
  State<PrivacyConsentPage> createState() => _PrivacyConsentPageState();
}

class _PrivacyConsentPageState extends State<PrivacyConsentPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    final atBottom = current >= (max - 24);
    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: ${DateTime.now().year}',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Information We Collect',
              '''
We collect information that you provide directly to us when you create an account, use our services, or communicate with us. This includes:

• Account Information: When you register, we collect your email address, username, and any other information you choose to provide, such as your full name, location, farm type, and experience level.

• Profile Information: You may choose to provide additional information in your profile, including a bio, profile picture, and other details about your farming activities.

• Content: We collect the content you create and share on our platform, including posts, comments, marketplace listings, and messages.

• Usage Information: We automatically collect information about how you interact with our services, including the pages you visit and the features you use.
''',
            ),
            _buildSection(
              context,
              '2. How We Use Your Information',
              '''
We use the information we collect to:

• Provide, maintain, and improve our services
• Process your transactions and send you related information
• Send you technical notices, updates, and support messages
• Respond to your comments, questions, and requests
• Monitor and analyze trends, usage, and activities
• Personalize and improve your experience
• Detect, prevent, and address technical issues
''',
            ),
            _buildSection(
              context,
              '3. Data Security',
              '''
We take the security of your personal information seriously. Your account information, including passwords, is encrypted and stored securely using industry-standard security measures. We use Supabase, a secure cloud platform, to store and manage your data.

• Passwords are encrypted and cannot be viewed by us or anyone else
• All data transmission is encrypted using secure protocols
• We implement appropriate technical and organizational measures to protect your personal information

However, no method of transmission over the internet or electronic storage is 100% secure. While we strive to use commercially acceptable means to protect your information, we cannot guarantee absolute security.
''',
            ),
            _buildSection(
              context,
              '4. Information Sharing',
              '''
We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances:

• With your consent or at your direction
• To comply with legal obligations or respond to legal requests
• To protect the rights, property, or safety of CAP, our users, or others
• In connection with a merger, acquisition, or sale of assets (with notice to users)

Your profile information, posts, and other public content may be visible to other users of the platform as part of the normal operation of our services.
''',
            ),
            _buildSection(
              context,
              '5. Your Choices and Rights',
              '''
You have the right to:

• Access, update, or delete your personal information through your account settings
• Control what information you share publicly on your profile
• Opt out of certain communications (where applicable)
• Request deletion of your account and associated data

To exercise these rights, please contact us or use the settings available in your account.
''',
            ),
            _buildSection(
              context,
              '6. Data Retention',
              '''
We retain your personal information for as long as your account is active or as needed to provide you services. If you delete your account, we will delete or anonymize your personal information, except where we are required to retain it for legal purposes.

Some information may remain in our records after account deletion, such as aggregated or anonymized data that cannot be used to identify you.
''',
            ),
            _buildSection(
              context,
              '7. Children\'s Privacy',
              '''
Our services are not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately.
''',
            ),
            _buildSection(
              context,
              '8. Changes to This Policy',
              '''
We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date. You are advised to review this Privacy Policy periodically for any changes.
''',
            ),
            _buildSection(
              context,
              '9. Contact Us',
              '''
If you have any questions about this Privacy Policy or our data practices, please contact us through the app or at the contact information provided in the Terms of Use.
''',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isAtBottom ? () => Navigator.pop(context, true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'I Agree',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String content,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content.replaceAll('\n\n', '\n'),
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
