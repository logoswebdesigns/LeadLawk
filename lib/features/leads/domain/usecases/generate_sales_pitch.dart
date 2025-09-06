/// Generate Sales Pitch Use Case
/// Pattern: Template Method Pattern
/// SOLID: Open/Closed - new pitch templates without modification
library;

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/lead.dart';

abstract class PitchTemplate {
  String generate(Lead lead);
  String get name;
}

class WebsitePitchTemplate implements PitchTemplate {
  @override
  String get name => 'Website Development';
  
  @override
  String generate(Lead lead) {
    final businessName = lead.businessName;
    final hasWebsite = lead.hasWebsite;
    
    if (!hasWebsite) {
      return '''
Hi! I noticed $businessName doesn't have a website yet. 

In today's digital world, 97% of consumers search online before making a purchase. Without a website, you're missing out on potential customers.

We specialize in creating professional websites for local businesses that:
• Rank well on Google
• Convert visitors into customers
• Work perfectly on mobile devices

Would you be interested in a quick 15-minute call to discuss how we can help grow your online presence?
''';
    } else if (lead.pagespeedMobileScore != null && 
               lead.pagespeedMobileScore! < 50) {
      return '''
Hi! I analyzed $businessName's website performance.

Your mobile site scores ${lead.pagespeedMobileScore}/100 on Google's PageSpeed test. This means:
• You're losing 40% of visitors who leave slow sites
• Google ranks faster sites higher in search results
• Your competitors with faster sites are winning customers

We can optimize your site to load 3x faster, improving both rankings and conversions.

Can we schedule a brief call to show you the specific improvements?
''';
    }
    
    return '''
Hi! I've been reviewing $businessName's online presence.

While you have a website, there are opportunities to:
• Improve search engine rankings
• Increase conversion rates
• Enhance mobile experience

Would you like a free website audit to identify growth opportunities?
''';
  }
}

class ReviewManagementPitchTemplate implements PitchTemplate {
  @override
  String get name => 'Review Management';
  
  @override
  String generate(Lead lead) {
    final businessName = lead.businessName;
    final rating = lead.rating ?? 0.0;
    final reviewCount = lead.reviewCount ?? 0;
    
    if (reviewCount < 10) {
      return '''
Hi! I noticed $businessName has only $reviewCount online reviews.

Did you know:
• 93% of consumers read reviews before choosing a business
• Businesses with 10+ reviews see 25% more inquiries
• Regular reviews improve local search rankings

We help businesses build a strong review presence through:
• Automated review requests
• Review response management
• Reputation monitoring

Interested in learning how to get more positive reviews?
''';
    } else if (rating < 4.0) {
      return '''
Hi! I see $businessName has a $rating star rating.

A rating below 4 stars can significantly impact your business:
• 57% of consumers won't use a business rated under 4 stars
• Each star increase = 5-9% revenue increase

Our reputation management service helps:
• Address negative feedback professionally
• Encourage satisfied customers to leave reviews
• Monitor and improve overall ratings

Can we discuss strategies to improve your online reputation?
''';
    }
    
    return '''
Hi! $businessName has built a solid review presence with $reviewCount reviews.

To maintain your competitive edge:
• Keep reviews fresh (recency matters to Google)
• Respond to all feedback
• Convert reviews into marketing content

Would you like to explore advanced reputation strategies?
''';
  }
}

class GenerateSalesPitch {
  final Map<String, PitchTemplate> _templates = {
    'website': WebsitePitchTemplate(),
    'reviews': ReviewManagementPitchTemplate(),
  };
  
  /// Generate pitch using specified template
  Either<Failure, String> generate(
    Lead lead, {
    String template = 'website',
  }) {
    final pitchTemplate = _templates[template];
    
    if (pitchTemplate == null) {
      return Left(ValidationFailure('Unknown pitch template: $template'));
    }
    
    try {
      final pitch = pitchTemplate.generate(lead);
      return Right(pitch);
    } catch (e) {
      return Left(ProcessingFailure('Failed to generate pitch: $e'));
    }
  }
  
  /// Get best template based on lead characteristics
  String recommendTemplate(Lead lead) {
    if (!lead.hasWebsite || 
        (lead.pagespeedMobileScore != null && lead.pagespeedMobileScore! < 50)) {
      return 'website';
    }
    
    if ((lead.reviewCount ?? 0) < 20 || (lead.rating ?? 5.0) < 4.0) {
      return 'reviews';
    }
    
    return 'website'; // Default
  }
  
  /// Register custom pitch template
  void registerTemplate(String name, PitchTemplate template) {
    _templates[name] = template;
  }
  
  /// Get all available templates
  List<String> getAvailableTemplates() {
    return _templates.keys.toList();
  }
}