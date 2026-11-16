import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/payment_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _userName = AuthService.userName;
  final String _userEmail = AuthService.userEmail;
  int _housesCount = AuthService.housesCount;
  List<Map<String, dynamic>> _zonesSummary = [];

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );

    _loadFreshData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadFreshData() async {
    try {
      final profile = await AuthService.fetchProfile();
      final zones = await ApiService.fetchZonesSummary();
      if (mounted) {
        setState(() {
          _userName = profile['name'] as String? ?? _userName;
          _housesCount = (profile['registeredHousesCount'] as num?)?.toInt() ?? _housesCount;
          _zonesSummary = zones;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0F3A78),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Edit Name Dialog ────────────────────────────────────────────────────────
  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Edit Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your email address is permanent and cannot be modified.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Wireman / Field Officer',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F3A78),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  // ── Zone Manager Bottom Sheet ──────────────────────────────────────────────
  void _openZoneManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.78,
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF0F3A78).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.location_city_rounded, color: Color(0xFF0F3A78), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Zone Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            Text('Organize and manage your field sectors', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map_outlined, size: 48, color: Color(0xFF94A3B8)),
                              SizedBox(height: 8),
                              Text('No zones registered yet.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(18),
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
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: const Icon(Icons.location_on_outlined, color: Color(0xFF1565C0), size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                                        const SizedBox(height: 2),
                                        Text('$count house(s) registered', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF1565C0), size: 20),
                                    tooltip: 'Rename Zone',
                                    onPressed: () => _promptRenameZone(name, count, () {
                                      _loadFreshData();
                                      setModalState(() {});
                                    }),
                                  ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Rename "$oldName"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This zone contains $count registered house(s). Renaming will update all of them.', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F3A78)),
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
              'This zone currently has $count house(s) registered. Choose an option:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.pop(ctx);
                _executeDeleteZone(zoneName, deleteHouses: false, onDone: onDone);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF0F3A78)),
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
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.pop(ctx);
                _executeDeleteZone(zoneName, deleteHouses: true, onDone: onDone);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
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
                          Text('Permanently removes all $count house(s)', style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B))),
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

  // ── Account Deletion Dialog (Google Play Compliance) ───────────────────────
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
                  'This action is irreversible. All your registered EB meters, zones, and session will be permanently erased.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                ),
                const SizedBox(height: 14),
                Text(
                  'To confirm, type your registered email address:\n$_userEmail',
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

  // ── Support Email ──────────────────────────────────────────────────────────
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

  // ── Terms & Privacy Bottom Sheet ───────────────────────────────────────────
  void _openTermsAndPrivacy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.78,
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
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F3A78))),
                    SizedBox(height: 8),
                    Text(
                      '• We collect your email address solely to sync electricity meter locations across your devices.\n'
                      '• GPS coordinates are used only to navigate wiremen to customer meter boxes.\n'
                      '• We do not sell or share any user or consumer information with third parties.\n'
                      '• In accordance with Google Play User Data Policy, you may permanently delete your account and all stored records at any time from your profile screen.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
                    ),
                    SizedBox(height: 20),
                    Text('2. Terms of Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F3A78))),
                    SizedBox(height: 8),
                    Text(
                      '• Wireman Service is designed for electrical field personnel to organize meter coordinates.\n'
                      '• Field workers are responsible for verifying physical meter locations safely.\n'
                      '• For support and inquiries, contact us at: ebwiremanservice@gmail.com',
                      style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F3A78),
                        side: const BorderSide(color: Color(0xFF0F3A78)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('View Official Privacy Policy Online'),
                      onPressed: () async {
                        final uri = Uri.parse('https://eb-service.onrender.com/privacy');
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      },
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? _buildSkeletonLoading()
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Classic Modern Hero Header ──────────────────────────────
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: const Color(0xFF0A2540),
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0A2540), Color(0xFF1565C0)],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: -40,
                            right: -30,
                            child: CircleAvatar(radius: 90, backgroundColor: Colors.white.withValues(alpha: 0.04)),
                          ),
                          Positioned(
                            bottom: -50,
                            left: -20,
                            child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withValues(alpha: 0.03)),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 50),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Avatar with ring
                                Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.25),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 36,
                                        backgroundColor: const Color(0xFF0F3A78),
                                        child: Text(
                                          _userName.isNotEmpty ? _userName[0].toUpperCase() : 'W',
                                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: _showEditNameDialog,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _userName,
                                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _userEmail,
                                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                                ),
                                const SizedBox(height: 10),
                                // Plan Badge
                                _buildPlanBadge(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Profile Content Body ────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bento Stats Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildBentoCard(
                                title: 'Registered Houses',
                                value: '$_housesCount',
                                subtitle: 'Consumer meters',
                                icon: Icons.electric_meter_rounded,
                                iconColor: const Color(0xFF0F3A78),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildBentoCard(
                                title: 'Active Zones',
                                value: '${_zonesSummary.length}',
                                subtitle: 'Field sectors',
                                icon: Icons.map_rounded,
                                iconColor: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          'DATA & FIELD SETTINGS',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),

                        // Section 1: Settings
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildSettingTile(
                                icon: Icons.location_city_rounded,
                                iconColor: const Color(0xFF0F3A78),
                                title: 'Zone Management',
                                subtitle: '${_zonesSummary.length} zones registered',
                                onTap: _openZoneManager,
                              ),
                              const Divider(height: 1, indent: 64),
                              _buildSettingTile(
                                icon: Icons.edit_note_rounded,
                                iconColor: const Color(0xFF2563EB),
                                title: 'Edit Name',
                                subtitle: _userName,
                                onTap: _showEditNameDialog,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          'SUPPORT & LEGAL',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),

                        // Section 2: Support
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildSettingTile(
                                icon: Icons.headset_mic_rounded,
                                iconColor: const Color(0xFF0284C7),
                                title: 'Help & Contact Support',
                                subtitle: 'ebwiremanservice@gmail.com',
                                onTap: _contactSupport,
                              ),
                              const Divider(height: 1, indent: 64),
                              _buildSettingTile(
                                icon: Icons.description_outlined,
                                iconColor: const Color(0xFF64748B),
                                title: 'Terms of Service & Privacy',
                                subtitle: 'Play Store compliance',
                                onTap: _openTermsAndPrivacy,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          'SESSION & ACCOUNT',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),

                        // Section 3: Logout & Delete
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildSettingTile(
                                icon: Icons.logout_rounded,
                                iconColor: const Color(0xFFD97706),
                                title: 'Log Out',
                                subtitle: 'End session on this phone',
                                titleColor: const Color(0xFFD97706),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                      title: const Text('Log Out?', style: TextStyle(fontWeight: FontWeight.bold)),
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

                        // Google Play Data Deletion Card
                        Container(
                          padding: const EdgeInsets.all(18),
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
                                  Text(
                                    'Google Play Policy Compliance',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'You can request full and permanent deletion of your account and all associated meter records at any time.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.4),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFDC2626)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                ),
                                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                                label: const Text('Delete Account Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _showDeleteAccountDialog,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Plan Badge Widget ──────────────────────────────────────────────────────
  Widget _buildPlanBadge() {
    final isLifetime = AuthService.isLifetime;

    return GestureDetector(
      onTap: isLifetime ? null : () => PaymentDialog.show(context, onSuccess: _loadFreshData),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isLifetime
              ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
              : const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isLifetime ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6)).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isLifetime ? Icons.bolt_rounded : Icons.star_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              isLifetime ? 'LIFETIME UNLIMITED' : 'FREE TIER • UPGRADE ₹799',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.5),
            ),
            if (!isLifetime) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white70),
            ],
          ],
        ),
      ),
    );
  }

  // ── Bento Card Widget ──────────────────────────────────────────────────────
  Widget _buildBentoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Icon(Icons.trending_up_rounded, color: Color(0xFF10B981), size: 16),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  // ── List Setting Tile Widget ───────────────────────────────────────────────
  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: titleColor ?? const Color(0xFF0F172A))),
                  const SizedBox(height: 1),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  // ── Animated Skeleton Shimmer Loading ──────────────────────────────────────
  Widget _buildSkeletonLoading() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              // Shimmer Header
              Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const [Color(0xFF0A2540), Color(0xFF1565C0)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _shimmerBox(width: 72, height: 72, shape: BoxShape.circle),
                    const SizedBox(height: 12),
                    _shimmerBox(width: 140, height: 18),
                    const SizedBox(height: 8),
                    _shimmerBox(width: 180, height: 12),
                    const SizedBox(height: 12),
                    _shimmerBox(width: 120, height: 22, borderRadius: 20),
                  ],
                ),
              ),

              // Shimmer Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _shimmerBox(height: 110, borderRadius: 20)),
                        const SizedBox(width: 14),
                        Expanded(child: _shimmerBox(height: 110, borderRadius: 20)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _shimmerBox(height: 140, borderRadius: 20),
                    const SizedBox(height: 18),
                    _shimmerBox(height: 140, borderRadius: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox({
    double? width,
    required double height,
    BoxShape shape = BoxShape.rectangle,
    double borderRadius = 12,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + _shimmerAnimation.value, -0.3),
          end: Alignment(1.0 + _shimmerAnimation.value, 0.3),
          colors: const [
            Color(0xFFE2E8F0),
            Color(0xFFF8FAFC),
            Color(0xFFE2E8F0),
          ],
        ),
      ),
    );
  }
}
