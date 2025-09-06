import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';

void main() {
  group('Sort functionality', () {
    test('sorts leads by rating correctly', () {
      final leads = [
        Lead(
          id: '1',
          businessName: 'Business A',
          phone: '555-0001',
          location: 'City',
          industry: 'Industry',
          source: 'google_maps',
          status: LeadStatus.new_,
          hasWebsite: true,
          isCandidate: false,
          meetsRatingThreshold: true,
          hasRecentReviews: false,
          rating: 3.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Lead(
          id: '2',
          businessName: 'Business B',
          phone: '555-0002',
          location: 'City',
          industry: 'Industry',
          source: 'google_maps',
          status: LeadStatus.new_,
          hasWebsite: true,
          isCandidate: false,
          meetsRatingThreshold: true,
          hasRecentReviews: false,
          rating: 4.8,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Lead(
          id: '3',
          businessName: 'Business C',
          phone: '555-0003',
          location: 'City',
          industry: 'Industry',
          source: 'google_maps',
          status: LeadStatus.new_,
          hasWebsite: true,
          isCandidate: false,
          meetsRatingThreshold: true,
          hasRecentReviews: false,
          rating: 2.1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Sort by rating (descending by default)
      leads.sort((a, b) {
        final aRating = a.rating ?? 0;
        final bRating = b.rating ?? 0;
        return bRating.compareTo(aRating);
      });

      // Should be sorted highest to lowest
      expect(leads[0].businessName, 'Business B'); // 4.8
      expect(leads[1].businessName, 'Business A'); // 3.5
      expect(leads[2].businessName, 'Business C'); // 2.1
    });

    test('sorts leads alphabetically', () {
      final leads = [
        Lead(
          id: '1',
          businessName: 'Zebra Inc',
          phone: '555-0001',
          location: 'City',
          industry: 'Industry',
          source: 'google_maps',
          status: LeadStatus.new_,
          hasWebsite: true,
          isCandidate: false,
          meetsRatingThreshold: true,
          hasRecentReviews: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Lead(
          id: '2',
          businessName: 'Apple Co',
          phone: '555-0002',
          location: 'City',
          industry: 'Industry',
          source: 'google_maps',
          status: LeadStatus.new_,
          hasWebsite: true,
          isCandidate: false,
          meetsRatingThreshold: true,
          hasRecentReviews: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Lead(
          id: '3',
          businessName: 'Microsoft Ltd',
          phone: '555-0003',
          location: 'City',
          industry: 'Industry',
          source: 'google_maps',
          status: LeadStatus.new_,
          hasWebsite: true,
          isCandidate: false,
          meetsRatingThreshold: true,
          hasRecentReviews: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Sort alphabetically
      leads.sort((a, b) => a.businessName.compareTo(b.businessName));

      // Should be sorted A to Z
      expect(leads[0].businessName, 'Apple Co');
      expect(leads[1].businessName, 'Microsoft Ltd');
      expect(leads[2].businessName, 'Zebra Inc');
    });
  });
}