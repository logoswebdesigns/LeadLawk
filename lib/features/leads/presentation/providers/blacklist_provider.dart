import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/cache_manager.dart';
import '../../data/datasources/leads_remote_datasource.dart';
import '../providers/repository_providers.dart';

/// Cache key for blacklist data
const _blacklistCacheKey = 'blacklist_data';
const _blacklistCacheDuration = Duration(minutes: 5);

/// Cached blacklist state
class BlacklistState {
  final Set<String> blacklistedNames;
  
  const BlacklistState({
    required this.blacklistedNames,
  });
  
  bool isBlacklisted(String businessName) {
    final normalized = businessName.toLowerCase().trim();
    return blacklistedNames.any((blacklisted) => 
      normalized.contains(blacklisted.toLowerCase()) ||
      blacklisted.toLowerCase().contains(normalized)
    );
  }
  
  factory BlacklistState.fromList(List<Map<String, dynamic>> blacklist) {
    final names = blacklist
        .map((item) => item['business_name'] as String)
        .toSet();
    return BlacklistState(blacklistedNames: names);
  }
}

/// Provider for cached blacklist data using CacheManager
final blacklistProvider = StateNotifierProvider<BlacklistNotifier, AsyncValue<BlacklistState>>((ref) {
  final dataSource = ref.watch(leadsRemoteDataSourceProvider);
  final cacheManager = ref.watch(cacheManagerProvider);
  return BlacklistNotifier(dataSource, cacheManager, ref);
});

class BlacklistNotifier extends StateNotifier<AsyncValue<BlacklistState>> {
  final LeadsRemoteDataSource _dataSource;
  final CacheManager _cacheManager;
  final Ref _ref;
  
  BlacklistNotifier(this._dataSource, this._cacheManager, this._ref) 
      : super(const AsyncValue.loading()) {
    _loadBlacklist();
  }
  
  Future<void> _loadBlacklist() async {
    try {
      // Try to get from cache first
      final cached = _cacheManager.get<List<dynamic>>(_blacklistCacheKey);
      
      if (cached != null) {
        // Use cached data
        final blacklistData = cached.cast<Map<String, dynamic>>();
        state = AsyncValue.data(BlacklistState.fromList(blacklistData));
      } else {
        // Fetch from remote
        await _fetchAndCache();
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  Future<void> _fetchAndCache() async {
    try {
      final blacklist = await _dataSource.getBlacklist();
      
      // Cache the data
      await _cacheManager.set(
        _blacklistCacheKey, 
        blacklist,
        _blacklistCacheDuration,
      );
      
      state = AsyncValue.data(BlacklistState.fromList(blacklist));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  /// Refresh blacklist from remote and update cache
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _fetchAndCache();
  }
  
  /// Invalidate cache when a business is added to blacklist
  Future<void> invalidateCache() async {
    await _cacheManager.remove(_blacklistCacheKey);
    await refresh();
  }
  
  /// Add a business to blacklist and refresh cache
  Future<bool> addToBlacklist(String businessName, String reason) async {
    try {
      final success = await _dataSource.addToBlacklist(businessName, reason);
      if (success) {
        // Invalidate cache and refresh
        await invalidateCache();
      }
      return success;
    } catch (e) {
      return false;
    }
  }
}

/// Provider to check if a specific business is blacklisted
final isBusinessBlacklistedProvider = Provider.family<bool, String>((ref, businessName) {
  final blacklistState = ref.watch(blacklistProvider);
  
  return blacklistState.maybeWhen(
    data: (state) => state.isBlacklisted(businessName),
    orElse: () => false,
  );
});