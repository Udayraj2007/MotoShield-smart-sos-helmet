import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/in_app_notification_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';

class NotificationItemModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final IconData icon;
  final Color accentColor;
  final bool isAlert;
  bool isRead;

  NotificationItemModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.icon,
    required this.accentColor,
    this.isAlert = false,
    this.isRead = false,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilterIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InAppNotificationService.instance.markAllAsRead();
    });
  }

  void _markAllAsRead() {
    InAppNotificationService.instance.markAllAsRead();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ALL NOTIFICATIONS MARKED AS READ',
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0E1424),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearAll() {
    InAppNotificationService.instance.clearAll();
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.instance.showCrashNotification(countdownSeconds: 5);
    InAppNotificationService.instance.addNotification(
      title: 'TEST NOTIFICATION DISPATCHED',
      message:
          'Simulated high-priority accident notification sent to local phone notification tray.',
      icon: Icons.notifications_active_rounded,
      accentColor: const Color(0xFFFF7A59),
      isAlert: true,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'TEST NOTIFICATION DISPATCHED TO PHONE TRAY',
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFF7A59),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ValueListenableBuilder<List<NotificationItemModel>>(
      valueListenable: InAppNotificationService.instance.notificationsNotifier,
      builder: (context, notificationsList, child) {
        final filteredList = notificationsList.where((n) {
          if (_selectedFilterIndex == 1) return n.isAlert;
          if (_selectedFilterIndex == 2) return !n.isAlert;
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: colors.scaffoldBackground,
          appBar: AppBar(
            backgroundColor: colors.scaffoldBackground,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '/ ALERTS & LOGS',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      color: colors.primaryAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (notificationsList.isNotEmpty)
                TextButton(
                  onPressed: _markAllAsRead,
                  child: Text(
                    'READ ALL',
                    style: GoogleFonts.jetBrainsMono(
                      color: colors.primaryAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Action / Filter Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Filter Chips
                      Row(
                        children: [
                          _buildFilterChip(0, 'ALL (${notificationsList.length})', colors),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            1,
                            'ALERTS (${notificationsList.where((n) => n.isAlert).length})',
                            colors,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            2,
                            'SYSTEM (${notificationsList.where((n) => !n.isAlert).length})',
                            colors,
                          ),
                        ],
                      ),
                      if (notificationsList.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.delete_sweep_rounded, color: colors.textSecondary, size: 20),
                          tooltip: 'Clear All',
                          onPressed: _clearAll,
                        ),
                    ],
                  ),
              const SizedBox(height: 16),

              // Notifications List
              Expanded(
                child: filteredList.isEmpty
                    ? _buildEmptyState(colors)
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          return _buildNotificationCard(item, colors);
                        },
                      ),
              ),

              const SizedBox(height: 12),
              // Send Test Notification Button
              ElevatedButton.icon(
                onPressed: _sendTestNotification,
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  'SEND TEST LOCAL NOTIFICATION',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.innerContainerBackground,
                  foregroundColor: colors.primaryAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: colors.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  },
);
}

  Widget _buildFilterChip(int index, String label, AppColors colors) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryAccentBg : colors.innerContainerBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.primaryAccent : colors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: isSelected ? colors.primaryAccent : colors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.innerContainerBackground,
              shape: BoxShape.circle,
              border: Border.all(color: colors.cardBorder),
            ),
            child: Icon(Icons.notifications_off_outlined, color: colors.textSecondary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'No Notifications',
            style: GoogleFonts.spaceGrotesk(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'System alerts and telemetry status updates will appear here.',
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItemModel item, AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.isRead ? colors.cardBackground : colors.innerContainerBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isAlert
              ? const Color(0xFFFF7A59).withValues(alpha: 0.5)
              : (item.isRead ? colors.cardBorder : colors.primaryAccent.withValues(alpha: 0.4)),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.spaceGrotesk(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimeAgo(item.timestamp),
                      style: GoogleFonts.jetBrainsMono(
                        color: colors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.message,
                  style: GoogleFonts.inter(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (!item.isRead) ...[
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: item.accentColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
