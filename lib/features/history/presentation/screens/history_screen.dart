import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/models/clipboard_item.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Clipboard history screen showing all received and sent clips
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final _storageService = StorageService.instance;
  final _syncService = SyncService.instance;

  List<ClipboardItem> _allClips = [];
  List<ClipboardItem> _filteredClips = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    final clips = await _storageService.getClipHistory();

    setState(() {
      _allClips = clips;
      _filterClips(_searchQuery);
      _isLoading = false;
    });
  }

  void _filterClips(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredClips = List.from(_allClips);
    } else {
      _filteredClips = _allClips
          .where(
            (clip) => clip.content.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterClips,
                  decoration: InputDecoration(
                    hintText: 'Search clips...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterClips('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // Tab bar
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'From Hub'),
                ],
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All clips tab
          _buildClipsList(_filteredClips),

          // From hub clips tab
          _buildClipsList(_filteredClips.where((c) => c.isFromHub).toList()),
        ],
      ),
      floatingActionButton: _allClips.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showClearHistoryDialog,
              backgroundColor: AppColors.error,
              child: const Icon(Icons.delete_sweep),
            )
          : null,
    );
  }

  Widget _buildClipsList(List<ClipboardItem> clips) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (clips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No clips yet' : 'No matching clips',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Your clipboard history will appear here'
                  : 'Try a different search term',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: clips.length,
        itemBuilder: (context, index) {
          final clip = clips[index];
          return _HistoryClipItem(
            clip: clip,
            onCopy: () => _copyClip(clip),
            onDelete: () => _deleteClip(clip),
          );
        },
      ),
    );
  }

  Future<void> _copyClip(ClipboardItem clip) async {
    final success = await _syncService.copyToClipboard(clip);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Copied to clipboard' : 'Failed to copy'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  void _deleteClip(ClipboardItem clip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Clip'),
        content: const Text('Are you sure you want to delete this clip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _storageService.deleteClip(clip.id);
              await _loadHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to clear all clipboard history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _storageService.clearClipHistory();
              await _loadHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _HistoryClipItem extends StatelessWidget {
  final ClipboardItem clip;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const _HistoryClipItem({
    required this.clip,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    clip.isFromHub ? Icons.download : Icons.upload,
                    size: 16,
                    color: clip.isFromHub
                        ? AppColors.accent
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    clip.isFromHub ? 'From Hub' : 'Sent to Hub',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  if (clip.sourceDevice != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${clip.sourceDevice}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    '• ${clip.formattedTime}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content
              Text(
                clip.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),

              // Copy button
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
