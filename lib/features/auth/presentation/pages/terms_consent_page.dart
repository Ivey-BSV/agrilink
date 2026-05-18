import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';

class TermsConsentPage extends StatefulWidget {
  const TermsConsentPage({super.key});

  @override
  State<TermsConsentPage> createState() => _TermsConsentPageState();
}

class _TermsConsentPageState extends State<TermsConsentPage> {
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
        title: const Text('Terms of Use'),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Use',
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
              '1. Acceptance of Terms',
              '''
By accessing or using CAP (the "Service"), you agree to be bound by these Terms of Use ("Terms"). If you do not agree to these Terms, you may not use the Service.

These Terms apply to all users of the Service, including farmers, agricultural professionals, and anyone who accesses or uses our platform.
''',
            ),
            _buildSection(
              context,
              '2. Description of Service',
              '''
CAP is a community platform designed to connect farmers, share agricultural knowledge, facilitate marketplace transactions, and support collaboration within the farming community. The Service includes features such as:

• Community forums and discussions
• Marketplace for buying and selling agricultural products
• Farm directory and networking
• Event listings and registrations
• Collaboration tools and resources

We reserve the right to modify, suspend, or discontinue any aspect of the Service at any time.
''',
            ),
            _buildSection(
              context,
              '3. User Accounts',
              '''
To use certain features of the Service, you must create an account. When creating an account, you agree to:

• Provide accurate, current, and complete information
• Maintain and update your information to keep it accurate
• Maintain the security of your account credentials
• Accept responsibility for all activities that occur under your account
• Notify us immediately of any unauthorized use of your account

You are responsible for maintaining the confidentiality of your account password. We cannot and will not be liable for any loss or damage arising from your failure to comply with this obligation.
''',
            ),
            _buildSection(
              context,
              '4. User Conduct',
              '''
You agree to use the Service only for lawful purposes and in accordance with these Terms. You agree not to:

• Post, upload, or transmit any content that is illegal, harmful, threatening, abusive, or violates any rights of others
• Impersonate any person or entity or falsely state or misrepresent your affiliation
• Engage in any activity that interferes with or disrupts the Service
• Use the Service to transmit spam, chain letters, or other unsolicited communications
• Collect or harvest information about other users without their consent
• Use automated systems to access the Service without permission
• Violate any applicable local, state, national, or international law

We reserve the right to remove any content that violates these Terms and to suspend or terminate accounts that engage in prohibited conduct.
''',
            ),
            _buildSection(
              context,
              '5. Content and Intellectual Property',
              '''
You retain ownership of any content you post, upload, or share on the Service. By posting content, you grant us a worldwide, non-exclusive, royalty-free license to use, reproduce, modify, and display your content in connection with operating and providing the Service.

You represent and warrant that you own or have the necessary rights to post the content you share and that your content does not infringe on the rights of any third party.

All content, features, and functionality of the Service, including but not limited to text, graphics, logos, and software, are owned by CAP or its licensors and are protected by copyright, trademark, and other intellectual property laws.
''',
            ),
            _buildSection(
              context,
              '6. Marketplace Transactions',
              '''
The Service includes a marketplace feature where users can buy and sell agricultural products. CAP acts as a platform to facilitate these transactions but is not a party to any transaction between users.

• All transactions are between buyers and sellers directly
• We do not guarantee the quality, safety, or legality of items listed
• We are not responsible for any disputes between buyers and sellers
• Users are responsible for complying with all applicable laws regarding the sale of agricultural products
• We reserve the right to remove listings that violate our policies or applicable laws

Users are encouraged to exercise caution and use their best judgment when engaging in marketplace transactions.
''',
            ),
            _buildSection(
              context,
              '7. Privacy',
              '''
Your use of the Service is also governed by our Privacy Policy. Please review our Privacy Policy to understand how we collect, use, and protect your information. By using the Service, you consent to the collection and use of your information as described in the Privacy Policy.
''',
            ),
            _buildSection(
              context,
              '8. Disclaimers and Limitation of Liability',
              '''
THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED. WE DISCLAIM ALL WARRANTIES, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.

We do not warrant that the Service will be uninterrupted, secure, or error-free. We are not responsible for any harm to your computer system, loss of data, or other harm resulting from your use of the Service.

TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM YOUR USE OF THE SERVICE.
''',
            ),
            _buildSection(
              context,
              '9. Indemnification',
              '''
You agree to indemnify, defend, and hold harmless CAP and its officers, directors, employees, and agents from any claims, damages, losses, liabilities, and expenses (including legal fees) arising from:

• Your use of the Service
• Your violation of these Terms
• Your violation of any rights of another
• Your content or any content you submit through the Service
''',
            ),
            _buildSection(
              context,
              '10. Termination',
              '''
We may terminate or suspend your account and access to the Service immediately, without prior notice, for any reason, including if you breach these Terms.

Upon termination, your right to use the Service will cease immediately. You may terminate your account at any time by contacting us or using the account deletion feature in your settings.
''',
            ),
            _buildSection(
              context,
              '11. Changes to Terms',
              '''
We reserve the right to modify these Terms at any time. We will notify users of any material changes by posting the updated Terms on the Service and updating the "Last Updated" date. Your continued use of the Service after such modifications constitutes your acceptance of the updated Terms.

If you do not agree to the modified Terms, you must stop using the Service.
''',
            ),
            _buildSection(
              context,
              '12. Governing Law',
              '''
These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which CAP operates, without regard to its conflict of law provisions.

Any disputes arising from these Terms or your use of the Service shall be resolved in the appropriate courts of that jurisdiction.
''',
            ),
            _buildSection(
              context,
              '13. Contact Information',
              '''
If you have any questions about these Terms of Use, please contact us through the Service or using the contact information provided in the app.
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
