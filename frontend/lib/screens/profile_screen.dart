import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  String _userName = AuthService.userName;
  final String _userEmail = AuthService.userEmail;
  int _housesCount = AuthService.housesCount;
  List<Map<String, dynamic>> _zonesSummary = [];
  bool _isLoadingZones = true;

  @override
  void initState() {
    super.initState();
    _loadFreshData();
  }

  Future<void> _loadFreshData() async {
    setState(() => _isLoadingZones = true);
    try {
      final profile = await AuthService.fetchProfile();
      final zones = await ApiService.fetchZonesSummary();
      if (mounted) {
        setState(() {
          _userName = profile['name'] as String? ?? _userName;
          _housesCount = (profile['registeredHousesCount'] as num?)?.toInt() ?? _housesCount;
          _zonesSummary = zones;
          _isLoadingZones = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingZones = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0D47A1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── 1. Edit Name Dialog (Email is Immutable) ───────────────────────────────
  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Your Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your email address cannot be changed.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Full Name',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await AuthService.updateProfile(newName);
                setState(() {
                  _userName = newName;
                  _isLoading = false;
                });
                _showSnack('Name updated successfully!');
              } catch (e) {
                setState(() => _isLoading = false);
                _showSnack(e.toString(), isError: true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── 2. Zone Manager Modal ──────────────────────────────────────────────────
  void _openZoneManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.location_city_rounded, color: Color(0xFF0D47A1)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Manage Zones',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _zonesSummary.isEmpty
                      ? const Center(
                          child: Text('No zones created yet.', style: TextStyle(color: Color(0xFF94A3B8))),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _zonesSummary.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (itemCtx, i) {
                            final zone = _zonesSummary[i];
                            final name = zone['name'] as String? ?? 'General';
                            final count = zone['count'] as int? ?? 0;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.map_rounded, size: 18, color: Color(0xFF0D47A1)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                                        Text('$count house(s) registered', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  // Edit / Rename Zone
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 20),
                                    tooltip: 'Rename Zone',
                                    onPressed: () => _promptRenameZone(name, count, () {
                                      _loadFreshData();
                                      setModalState(() {});
                                    }),
                                  ),
                                  // Delete Zone
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                    tooltip: 'Delete Zone',
                                    onPressed: () => _promptDeleteZone(name, count, () {
                                      _loadFreshData();
                                      setModalState(() {});
                                    }),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _promptRenameZone(String oldName, int count, VoidCallback onDone) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename "$oldName"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This zone currently contains $count registered house(s). Renaming will update all of them.', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'New Zone Name',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == oldName) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await ApiService.renameZone(oldName, newName);
                _showSnack('Zone renamed to "$newName" successfully!');
                await _loadFreshData();
                onDone();
              } catch (e) {
                _showSnack(e.toString(), isError: true);
              } finally {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _promptDeleteZone(String zoneName, int count, VoidCallback onDone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(child: Text('Delete "$zoneName"?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This zone currently has $count house(s) registered. Please select an option:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                Navigator.pop(ctx);
                _executeDeleteZone(zoneName, deleteHouses: false, onDone: onDone);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF0D47A1)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delete Zone Only (Safe)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          Text('Houses stay safe and move to "General"', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                Navigator.pop(ctx);
                _executeDeleteZone(zoneName, deleteHouses: true, onDone: onDone);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Delete Zone AND All Houses', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 13.5)),
                          Text('Permanently erases all $count house(s)', style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<void> _executeDeleteZone(String zoneName, {required bool deleteHouses, required VoidCallback onDone}) async {
    setState(() => _isLoading = true);
    try {
      await ApiService.deleteZone(zoneName, deleteHouses: deleteHouses);
      _showSnack(deleteHouses ? 'Zone and its houses deleted.' : 'Zone deleted. Houses kept safe.');
      await _loadFreshData();
      onDone();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── 3. Permanent Account Deletion Dialog (Google Play Store Policy) ─────────
  void _showDeleteAccountDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isMatch = controller.text.trim().toLowerCase() == _userEmail.trim().toLowerCase();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.warning_rounded, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFDC2626))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action is irreversible. All your registered EB meters, zones, and session will be permanently deleted from the cloud.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                ),
                const SizedBox(height: 14),
                Text(
                  'To confirm, please enter your email address:\n$_userEmail',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Enter $_userEmail',
                    filled: true,
                    fillColor: const Color(0xFFFFF1F2),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFDA4AF))),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                onPressed: isMatch
                    ? () async {
                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);
                        try {
                          await AuthService.deleteAccount(_userEmail);
                          if (mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                            widget.onLogout();
                          }
                        } catch (e) {
                          setState(() => _isLoading = false);
                          _showSnack(e.toString(), isError: true);
                        }
                      }
                    : null,
                child: const Text('Delete Permanently'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── 4. Contact Support ──────────────────────────────────────────────────────
  Future<void> _contactSupport() async {
    final uri = Uri.parse('mailto:ebwiremanservice@gmail.com?subject=Wireman%20Service%20Support');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnack('Support email: ebwiremanservice@gmail.com');
      }
    } catch (_) {
      _showSnack('Support email: ebwiremanservice@gmail.com');
    }
  }

  // ── 5. Terms & Privacy Bottom Sheet ─────────────────────────────────────────
  void _openTermsAndPrivacy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Terms of Service & Privacy Policy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D47A1))),
                    const SizedBox(height: 6),
                    const Text(
                      '• We collect your email address solely to sync electricity meter locations across your devices.\n'
                      '• Location coordinates are used only to navigate wiremen to customer meter boxes.\n'
                      '• We do not sell or share any user or consumer information with third parties.\n'
                      '• In accordance with Google Play User Data Policy, you may permanently delete your account and all stored records at any time from your profile screen.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 18),
                    const Text('2. Terms of Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D47A1))),
                    const SizedBox(height: 6),
                    const Text(
                      '• Wireman Service is designed for electrical field personnel to organize meter coordinates.\n'
                      '• Field workers are responsible for verifying physical meter locations safely.\n'
                      '• Lifetime Unlimited access is provided to authorized staff.\n'
                      '• For support and inquiries, contact us at: ebwiremanservice@gmail.com',
                      style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLifetime = AuthService.isLifetime;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Header Card ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
                      ],
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(0xFF0D47A1),
                          child: Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'W',
                            style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                              onPressed: _showEditNameDialog,
                              tooltip: 'Edit Name',
                            ),
                          ],
                        ),
                        Text(_userEmail, style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
                        const SizedBox(height: 14),

                        // Subscription Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: isLifetime
                                ? const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)])
                                : const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF2563EB)]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isLifetime ? Icons.bolt_rounded : Icons.star_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                isLifetime ? 'Lifetime Unlimited Pro' : 'Free Tier (10 Houses)',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Stats Row ─────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Houses',
                          value: '$_housesCount',
                          icon: Icons.home_work_rounded,
                          color: const Color(0xFF0D47A1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Zones',
                          value: _isLoadingZones ? '...' : '${_zonesSummary.length}',
                          icon: Icons.map_rounded,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Action Items ──────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.location_city_rounded, color: Color(0xFF0D47A1)),
                          title: const Text('Manage Zones', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${_zonesSummary.length} active zones', style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: _openZoneManager,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.headset_mic_outlined, color: Color(0xFF0284C7)),
                          title: const Text('Support & Feedback', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('ebwiremanservice@gmail.com', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: _contactSupport,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.description_outlined, color: Color(0xFF64748B)),
                          title: const Text('Privacy Policy & Terms', style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: _openTermsAndPrivacy,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout_rounded, color: Color(0xFFD97706)),
                          title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFD97706)),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text('Log Out?'),
                                content: const Text('Are you sure you want to log out of Wireman Service?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      Navigator.pop(context);
                                      widget.onLogout();
                                    },
                                    child: const Text('Log Out'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Danger Zone: Delete Account (Google Play Compliance) ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 18),
                            SizedBox(width: 8),
                            Text('Google Play Policy Compliance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Permanently delete your account, saved houses, and cloud data.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.delete_forever_rounded, size: 18),
                          label: const Text('Delete Account Permanently'),
                          onPressed: _showDeleteAccountDialog,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

