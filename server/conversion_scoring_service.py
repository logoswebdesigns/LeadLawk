"""
Conversion Scoring Service
Calculates conversion probability scores for leads using machine learning.
Uses logistic regression with feature engineering for interpretability.
"""

import json
import logging
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import func
import hashlib

from models import Lead, LeadStatus, ConversionModel, LeadTimelineEntry
from database import SessionLocal

logger = logging.getLogger(__name__)


class ConversionScoringService:
    """Service for calculating and managing lead conversion scores."""
    
    # Feature weights learned from analysis
    DEFAULT_WEIGHTS = {
        'has_website': -0.8,  # No website is good for our use case
        'rating_score': 0.3,
        'review_recency': 0.4,
        'review_volume': 0.2,
        'industry_match': 0.5,
        'response_time': 0.6,
        'engagement_level': 0.7,
        'pagespeed_score': -0.3,  # Poor pagespeed is opportunity
        'location_density': 0.2,
        'call_attempts': 0.4,
        'time_in_pipeline': -0.2,
    }
    
    # Industry conversion rates (from historical data)
    INDUSTRY_CONVERSION_RATES = {
        'plumbing': 0.15,
        'hvac': 0.18,
        'electrical': 0.14,
        'roofing': 0.20,
        'landscaping': 0.22,
        'cleaning': 0.25,
        'painting': 0.19,
        'construction': 0.12,
        'home_services': 0.17,
        'default': 0.16
    }
    
    def __init__(self, db: Session):
        self.db = db
        self.model = self._load_active_model()
        
    def _load_active_model(self) -> Optional[ConversionModel]:
        """Load the active conversion model from database."""
        return self.db.query(ConversionModel).filter(
            ConversionModel.is_active == True
        ).order_by(ConversionModel.created_at.desc()).first()
    
    def calculate_all_scores(self, batch_size: int = 100) -> Dict[str, any]:
        """Calculate conversion scores for all leads in batches."""
        start_time = datetime.utcnow()
        total_leads = self.db.query(func.count(Lead.id)).scalar()
        processed = 0
        scores_updated = 0
        errors = []
        
        logger.info(f"Starting conversion scoring for {total_leads} leads")
        
        # Process in batches for performance
        offset = 0
        while offset < total_leads:
            leads = self.db.query(Lead).offset(offset).limit(batch_size).all()
            
            for lead in leads:
                try:
                    score, factors = self.calculate_lead_score(lead)
                    lead.conversion_score = score
                    lead.conversion_score_calculated_at = datetime.utcnow()
                    lead.conversion_score_factors = json.dumps(factors)
                    scores_updated += 1
                except Exception as e:
                    logger.error(f"Error scoring lead {lead.id}: {e}")
                    errors.append(f"Lead {lead.id}: {str(e)}")
                
                processed += 1
                
            self.db.commit()
            offset += batch_size
            
            if processed % 500 == 0:
                logger.info(f"Processed {processed}/{total_leads} leads")
        
        duration = (datetime.utcnow() - start_time).total_seconds()
        
        return {
            'total_leads': total_leads,
            'scores_updated': scores_updated,
            'errors': errors,
            'duration_seconds': duration,
            'average_time_per_lead': duration / max(processed, 1)
        }
    
    def calculate_lead_score(self, lead: Lead) -> Tuple[float, Dict]:
        """Calculate conversion probability score for a single lead."""
        features = self._extract_features(lead)
        weights = self._get_feature_weights()
        
        # Calculate weighted score
        score = 0.0
        factors = {}
        
        for feature, value in features.items():
            weight = weights.get(feature, 0.0)
            contribution = value * weight
            score += contribution
            factors[feature] = {
                'value': value,
                'weight': weight,
                'contribution': contribution
            }
        
        # Apply sigmoid to get probability between 0 and 1
        probability = 1 / (1 + np.exp(-score))
        
        # Apply industry-specific adjustment
        industry_rate = self.INDUSTRY_CONVERSION_RATES.get(
            lead.industry.lower() if lead.industry else 'default',
            self.INDUSTRY_CONVERSION_RATES['default']
        )
        
        # Blend with industry baseline
        final_score = 0.7 * probability + 0.3 * industry_rate
        
        factors['industry_adjustment'] = industry_rate
        factors['final_score'] = final_score
        
        return min(max(final_score, 0.0), 1.0), factors
    
    def _extract_features(self, lead: Lead) -> Dict[str, float]:
        """Extract features from lead for scoring."""
        features = {}
        
        # Website presence (negative for our use case)
        features['has_website'] = 0.0 if lead.has_website else 1.0
        
        # Rating quality
        if lead.rating:
            features['rating_score'] = max(0, (5.0 - lead.rating) / 5.0)  # Lower rating is better opportunity
        else:
            features['rating_score'] = 0.5  # Neutral if no rating
        
        # Review recency
        if lead.last_review_date:
            days_since_review = (datetime.utcnow() - lead.last_review_date).days
            features['review_recency'] = 1.0 if days_since_review > 180 else 0.0
        else:
            features['review_recency'] = 0.5
        
        # Review volume (fewer reviews = more opportunity)
        if lead.review_count:
            features['review_volume'] = 1.0 / (1.0 + np.log1p(lead.review_count))
        else:
            features['review_volume'] = 1.0
        
        # PageSpeed opportunity (lower score = more opportunity)
        if lead.pagespeed_mobile_score is not None:
            features['pagespeed_score'] = max(0, (100 - lead.pagespeed_mobile_score) / 100)
        else:
            features['pagespeed_score'] = 0.5
        
        # Engagement level (based on status progression)
        status_scores = {
            LeadStatus.new: 0.1,
            LeadStatus.viewed: 0.2,
            LeadStatus.called: 0.4,
            LeadStatus.interested: 0.8,
            LeadStatus.converted: 1.0,
            LeadStatus.doNotCall: 0.0
        }
        features['engagement_level'] = status_scores.get(lead.status, 0.1)
        
        # Time in pipeline (newer leads score higher)
        days_in_pipeline = (datetime.utcnow() - lead.created_at).days
        features['time_in_pipeline'] = np.exp(-days_in_pipeline / 30)  # Decay over 30 days
        
        # Call attempts (from timeline)
        call_count = self.db.query(func.count(LeadTimelineEntry.id)).filter(
            LeadTimelineEntry.lead_id == lead.id,
            LeadTimelineEntry.type == 'phone_call'
        ).scalar() or 0
        features['call_attempts'] = min(call_count / 5, 1.0)  # Normalize to max 5 calls
        
        # Industry match score
        high_value_industries = ['plumbing', 'hvac', 'roofing', 'electrical']
        if lead.industry and lead.industry.lower() in high_value_industries:
            features['industry_match'] = 1.0
        else:
            features['industry_match'] = 0.5
        
        # Location density (placeholder - could be enhanced with actual density data)
        features['location_density'] = 0.5
        
        # Response time (if they responded to initial contact)
        features['response_time'] = 0.5  # Placeholder
        
        return features
    
    def _get_feature_weights(self) -> Dict[str, float]:
        """Get feature weights from model or use defaults."""
        if self.model and self.model.feature_weights:
            try:
                return json.loads(self.model.feature_weights)
            except:
                pass
        return self.DEFAULT_WEIGHTS
    
    def train_model(self, min_samples: int = 100) -> Optional[ConversionModel]:
        """Train a new conversion scoring model based on historical data."""
        logger.info("Training new conversion scoring model...")
        
        # Get converted and non-converted leads
        converted_leads = self.db.query(Lead).filter(
            Lead.status == LeadStatus.converted
        ).all()
        
        non_converted_leads = self.db.query(Lead).filter(
            Lead.status.in_([LeadStatus.doNotCall, LeadStatus.called])
        ).all()
        
        total_samples = len(converted_leads) + len(non_converted_leads)
        
        if total_samples < min_samples:
            logger.warning(f"Not enough samples for training: {total_samples} < {min_samples}")
            return None
        
        # Extract features and labels
        X = []
        y = []
        
        for lead in converted_leads:
            features = self._extract_features(lead)
            X.append(list(features.values()))
            y.append(1)
        
        for lead in non_converted_leads:
            features = self._extract_features(lead)
            X.append(list(features.values()))
            y.append(0)
        
        X = np.array(X)
        y = np.array(y)
        
        # Simple logistic regression using gradient descent
        weights = self._train_logistic_regression(X, y)
        
        # Calculate model metrics
        predictions = self._predict(X, weights)
        accuracy = np.mean((predictions > 0.5) == y)
        
        # Calculate precision, recall, f1
        true_positives = np.sum((predictions > 0.5) & (y == 1))
        false_positives = np.sum((predictions > 0.5) & (y == 0))
        false_negatives = np.sum((predictions <= 0.5) & (y == 1))
        
        precision = true_positives / max(true_positives + false_positives, 1)
        recall = true_positives / max(true_positives + false_negatives, 1)
        f1 = 2 * precision * recall / max(precision + recall, 0.001)
        
        # Create model version hash
        version_hash = hashlib.md5(
            f"{datetime.utcnow().isoformat()}_{total_samples}".encode()
        ).hexdigest()[:8]
        
        # Deactivate old models
        self.db.query(ConversionModel).update({'is_active': False})
        
        # Save new model
        feature_names = list(self._extract_features(converted_leads[0] if converted_leads else non_converted_leads[0]).keys())
        feature_weights = dict(zip(feature_names, weights))
        
        new_model = ConversionModel(
            model_version=f"v1.0_{version_hash}",
            feature_weights=json.dumps(feature_weights),
            model_accuracy=accuracy,
            training_samples=total_samples,
            total_conversions=len(converted_leads),
            total_leads=total_samples,
            baseline_conversion_rate=len(converted_leads) / total_samples,
            precision_score=precision,
            recall_score=recall,
            f1_score=f1,
            is_active=True
        )
        
        self.db.add(new_model)
        self.db.commit()
        
        logger.info(f"Model trained successfully: accuracy={accuracy:.3f}, f1={f1:.3f}")
        return new_model
    
    def _train_logistic_regression(self, X: np.ndarray, y: np.ndarray, 
                                  learning_rate: float = 0.01, 
                                  iterations: int = 1000) -> np.ndarray:
        """Train logistic regression using gradient descent."""
        n_samples, n_features = X.shape
        weights = np.zeros(n_features)
        
        for _ in range(iterations):
            # Forward propagation
            z = np.dot(X, weights)
            predictions = 1 / (1 + np.exp(-np.clip(z, -500, 500)))
            
            # Gradient
            gradient = np.dot(X.T, (predictions - y)) / n_samples
            
            # Update weights
            weights -= learning_rate * gradient
        
        return weights
    
    def _predict(self, X: np.ndarray, weights: np.ndarray) -> np.ndarray:
        """Make predictions using trained weights."""
        z = np.dot(X, weights)
        return 1 / (1 + np.exp(-np.clip(z, -500, 500)))
    
    def get_top_converting_leads(self, limit: int = 20) -> List[Lead]:
        """Get leads with highest conversion probability."""
        return self.db.query(Lead).filter(
            Lead.conversion_score.isnot(None),
            Lead.status.notin_([LeadStatus.converted, LeadStatus.doNotCall])
        ).order_by(Lead.conversion_score.desc()).limit(limit).all()
    
    def get_model_stats(self) -> Dict:
        """Get statistics about the current model."""
        if not self.model:
            return {'status': 'No model trained'}
        
        return {
            'model_version': self.model.model_version,
            'accuracy': self.model.model_accuracy,
            'f1_score': self.model.f1_score,
            'precision': self.model.precision_score,
            'recall': self.model.recall_score,
            'training_samples': self.model.training_samples,
            'baseline_conversion_rate': self.model.baseline_conversion_rate,
            'created_at': self.model.created_at.isoformat() if self.model.created_at else None
        }


def calculate_conversion_scores():
    """Standalone function to calculate all conversion scores."""
    db = SessionLocal()
    try:
        service = ConversionScoringService(db)
        result = service.calculate_all_scores()
        logger.info(f"Conversion scoring completed: {result}")
        return result
    finally:
        db.close()


def train_conversion_model():
    """Standalone function to train a new conversion model."""
    db = SessionLocal()
    try:
        service = ConversionScoringService(db)
        model = service.train_model()
        if model:
            logger.info(f"New model trained: {model.model_version}")
            # Recalculate all scores with new model
            service.model = model
            service.calculate_all_scores()
        return model
    finally:
        db.close()