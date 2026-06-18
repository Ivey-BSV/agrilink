import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/reciprocity_ring_provider.dart';
import 'package:provider/provider.dart';

class OfferDetailPage extends StatefulWidget {
  final Map<String, dynamic> offer;

  const OfferDetailPage({super.key, required this.offer});

  @override
  State<OfferDetailPage> createState() => _OfferDetailPageState();
}

class _OfferDetailPageState extends State<OfferDetailPage> {
  final TextEditingController _interestController = TextEditingController();
  late List<Map<String, dynamic>> _interests;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();

    final interestsData = widget.offer['interests'] as List<dynamic>?;
    _interests = interestsData != null
        ? List<Map<String, dynamic>>.from(interestsData)
        : [];
  }

  @override
  void dispose() {
    _interestController.dispose();
    super.dispose();
  }

  bool get _isOwner {
    final uid = context.read<AuthProvider>().userId;
    final ownerId = widget.offer['user_id'] as String?;
    return uid != null && ownerId != null && uid == ownerId;
  }

  int get _interestPeopleCount =>
      context.read<ReciprocityRingProvider>().getInterestCount({
        ...Map<String, dynamic>.from(widget.offer),
        'interests': _interests,
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.backgroundLight,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Offer Details',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        actions: [
          if (_isOwner)
            IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, color: Colors.black87),
              onPressed: _deleting ? null : _confirmDeleteOffer,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.primaryGreen
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  widget.offer['avatar'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryGreen,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.offer['owner'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.offer['location'] as String? ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    widget.offer['window'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.offer['offer'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          if (widget.offer['description'] != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              widget.offer['description'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                          if (widget.offer['tags'] != null &&
                              (widget.offer['tags'] as List).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (widget.offer['tags'] as List)
                                  .map<Widget>((tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          tag as String,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.favorite_outline,
                          size: 20, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Text(
                        '$_interestPeopleCount ${_interestPeopleCount == 1 ? 'person interested' : 'people interested'}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_interests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.favorite_outline,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No interest yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Be the first to express interest!',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._interests
                        .map((interest) => _buildInterestCard(interest)),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _interestController,
                    decoration: InputDecoration(
                      hintText: 'Express interest or ask a question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryGreen),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _submitInterest(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestCard(Map<String, dynamic> interest) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
              child: Text(
                interest['avatar'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        interest['interested'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        interest['time'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    interest['message'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOffer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this offer?'),
        content: const Text(
          'This removes your offer and all interest messages. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final offerId = widget.offer['id'] as String?;
    if (offerId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this offer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _deleting = true);
    final provider = context.read<ReciprocityRingProvider>();
    final success = await provider.deleteOffer(offerId);
    if (!mounted) return;
    setState(() => _deleting = false);

    if (success) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Offer deleted'),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to delete offer'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _submitInterest() async {
    if (_interestController.text.trim().isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to express interest'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final offerId = widget.offer['id'] as String?;
    if (offerId == null) {
      setState(() {
        _interests.insert(0, {
          'user_id': userId,
          'interested': 'You',
          'avatar': 'Y',
          'message': _interestController.text.trim(),
          'time': 'Just now',
        });
        widget.offer['interests'] = _interests;
      });
      _interestController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Interest expressed! The offer owner will be notified.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final provider = context.read<ReciprocityRingProvider>();
    final success = await provider.addInterest(
      offerId: offerId,
      userId: userId,
      message: _interestController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      final updatedOffers = provider.offers;
      Map<String, dynamic> updatedOffer;
      try {
        updatedOffer = updatedOffers.firstWhere(
          (o) => o['id'] == offerId,
        );
      } catch (e) {
        updatedOffer = widget.offer;
      }

      setState(() {
        final interestsData = updatedOffer['interests'] as List<dynamic>?;
        _interests = interestsData != null
            ? List<Map<String, dynamic>>.from(interestsData)
            : [];
      });

      _interestController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Interest expressed! The offer owner will be notified.'),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to express interest'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
