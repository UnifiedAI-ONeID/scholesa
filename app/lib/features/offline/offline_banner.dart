import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'offline_queue.dart';
import 'offline_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer2<OfflineService, OfflineQueue>(
      builder: (context, offline, queue, _) {
        if (!offline.isOffline && queue.initialized) {
          // Kick off a flush as soon as we're back online; guard via queue.
          SchedulerBinding.instance.addPostFrameCallback((_) {
            queue.flush(online: true);
          });
        }

        final banner = offline.isOffline
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFef4444), Color(0xFFb91c1c)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        queue.hasPending
                            ? 'Offline with ${queue.pending.length} update(s) queued. We will sync on reconnect.'
                            : 'You are offline. Changes will sync when you reconnect.',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            : null;

        return Stack(
          children: [
            Positioned.fill(child: child),
            if (banner != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: banner),
              ),
          ],
        );
      },
    );
  }
}
