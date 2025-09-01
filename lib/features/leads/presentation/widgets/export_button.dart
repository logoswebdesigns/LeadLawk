import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../pages/leads_list_page.dart';

class ExportButton extends ConsumerWidget {
  const ExportButton({super.key});

  Future<void> _exportToExcel(BuildContext context, WidgetRef ref) async {
    // Get current filter states
    final status = ref.read(statusFilterProvider);
    final location = ref.read(locationFilterProvider);
    final industry = ref.read(industryFilterProvider);
    final search = ref.read(searchFilterProvider);
    final hasWebsite = ref.read(hasWebsiteFilterProvider);
    final meetsRating = ref.read(meetsRatingFilterProvider);
    final hasRecentReviews = ref.read(hasRecentReviewsFilterProvider);
    final ratingRange = ref.read(ratingRangeFilterProvider);
    final reviewCountRange = ref.read(reviewCountRangeFilterProvider);
    
    // Track if dialog is showing
    bool dialogShowing = false;
    
    // Show loading indicator
    if (context.mounted) {
      dialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryBlue,
          ),
        ),
      );
    }
    
    try {
      final dio = Dio();
      
      // Build query parameters based on active filters
      final queryParams = <String, dynamic>{};
      
      if (status != null && status != 'ALL') {
        queryParams['status'] = status;
      }
      if (location != null && location.isNotEmpty) {
        queryParams['location'] = location;
      }
      if (industry != null && industry.isNotEmpty) {
        queryParams['industry'] = industry;
      }
      if (search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (hasWebsite != null) {
        queryParams['has_website'] = hasWebsite;
      }
      if (meetsRating == true && ratingRange != null) {
        // Parse rating range like '4+', '3-4', etc.
        if (ratingRange.contains('+')) {
          queryParams['min_rating'] = ratingRange.replaceAll('+', '');
        } else if (ratingRange.contains('-')) {
          queryParams['min_rating'] = ratingRange.split('-')[0];
        }
      }
      if (hasRecentReviews == true && reviewCountRange != null) {
        // Parse review count range like '50+', '20-50', etc.
        if (reviewCountRange.contains('+')) {
          queryParams['min_reviews'] = reviewCountRange.replaceAll('+', '');
        } else if (reviewCountRange.contains('-')) {
          queryParams['min_reviews'] = reviewCountRange.split('-')[0];
        }
      }
      
      // Make API request
      final response = await dio.get(
        'http://localhost:8000/leads/export/excel',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
        ),
      );
      
      // Close loading dialog
      if (context.mounted && dialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShowing = false;
      }
      
      // Save file
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        // Desktop: Use file picker to let user choose save location
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
        final fileName = 'leads_export_$timestamp.xlsx';
        
        try {
          // Use FilePicker to let user choose save location
          String? outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Excel Export',
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );
          
          if (outputFile != null) {
            // Write the file to the chosen location
            final file = File(outputFile);
            await file.writeAsBytes(response.data);
            
            // Show success message with option to open file
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Text('Excel file saved: ${outputFile.split('/').last}'),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          // Open the file
                          final uri = Uri.file(outputFile);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        child: const Text(
                          'Open',
                          style: TextStyle(color: AppTheme.primaryBlue),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.successGreen,
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else {
            // User cancelled the save dialog
            if (context.mounted && dialogShowing) {
              Navigator.of(context, rootNavigator: true).pop();
              dialogShowing = false;
            }
          }
        } catch (e) {
          // Fallback: Try to save to Downloads directory without picker
          try {
            final directory = await getDownloadsDirectory();
            if (directory != null) {
              final filePath = '${directory.path}/$fileName';
              final file = File(filePath);
              await file.writeAsBytes(response.data);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Excel file saved to Downloads: $fileName'),
                    backgroundColor: AppTheme.successGreen,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }
          } catch (fallbackError) {
            // If all fails, show error
            throw Exception('Unable to save file: $fallbackError');
          }
        }
      } else {
        // Mobile: Use share sheet or alternative method
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel export is currently only supported on desktop'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted && dialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShowing = false;
      }
      
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.successGreen.withOpacity(0.8),
            AppTheme.successGreen,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successGreen.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _exportToExcel(context, ref),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.file_download,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Export to Excel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}