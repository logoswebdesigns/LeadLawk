#!/bin/bash

# LeadLawk Authentication System Setup Script
# This script helps set up the production-ready authentication system

echo "🚀 Setting up LeadLawk Authentication System..."

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Please run this script from the Flutter project root directory"
    exit 1
fi

echo "📦 Installing Flutter dependencies..."
flutter pub get

echo "🔧 Generating Freezed models..."
flutter pub run build_runner build --delete-conflicting-outputs

echo "📱 Checking Flutter setup..."
flutter doctor

echo "🐍 Setting up Python backend dependencies..."
cd server
if [ ! -f "requirements.txt" ]; then
    echo "Creating requirements.txt..."
    cat > requirements.txt << EOF
fastapi>=0.104.1
uvicorn[standard]>=0.24.0
sqlalchemy>=2.0.0
alembic>=1.12.0
pydantic>=2.4.0
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
python-multipart>=0.0.6
pyotp>=2.9.0
qrcode[pil]>=7.4.2
user-agents>=2.2.0
geoip2>=4.7.0
python-dotenv>=1.0.0
pytest>=7.4.0
pytest-asyncio>=0.21.0
httpx>=0.25.0
EOF
fi

if command -v python3 &> /dev/null; then
    echo "Installing Python dependencies..."
    python3 -m pip install -r requirements.txt
else
    echo "⚠️  Warning: Python3 not found. Please install Python dependencies manually."
fi

cd ..

echo "🔐 Creating auth configuration template..."
cat > .env.auth.template << EOF
# Authentication Configuration Template
# Copy this to .env and fill in your values

# JWT Configuration
SECRET_KEY=your_very_secure_secret_key_here_change_this
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=30

# Google OAuth Configuration
GOOGLE_CLIENT_ID_WEB=your_google_web_client_id
GOOGLE_CLIENT_ID_IOS=your_google_ios_client_id
GOOGLE_CLIENT_ID_ANDROID=your_google_android_client_id

# Apple OAuth Configuration
APPLE_SERVICE_ID=your_apple_service_id
APPLE_REDIRECT_URI=https://your-domain.com/auth/apple/callback

# Email Service Configuration (choose one)
# SendGrid
SENDGRID_API_KEY=your_sendgrid_api_key
SENDGRID_FROM_EMAIL=noreply@your-domain.com

# AWS SES
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1
SES_FROM_EMAIL=noreply@your-domain.com

# App Configuration
APP_NAME=LeadLawk
APP_DOMAIN=https://your-domain.com
SUPPORT_EMAIL=support@your-domain.com

# Database
DATABASE_URL=sqlite:///./db/leadloq.db

# Security
ACCOUNT_LOCKOUT_ATTEMPTS=5
ACCOUNT_LOCKOUT_MINUTES=30
PASSWORD_MIN_LENGTH=8
EOF

echo "📋 Creating platform-specific setup instructions..."
cat > PLATFORM_SETUP.md << EOF
# Platform-Specific Authentication Setup

## iOS Setup

1. Enable Keychain Sharing in Xcode:
   - Select your target
   - Go to Signing & Capabilities
   - Add Keychain Sharing capability

2. Add biometric usage description to ios/Runner/Info.plist:
   \`\`\`xml
   <key>NSFaceIDUsageDescription</key>
   <string>Use Face ID to authenticate securely</string>
   \`\`\`

3. For Google Sign-In, add URL scheme to Info.plist:
   \`\`\`xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLName</key>
       <string>REVERSED_CLIENT_ID</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>YOUR_REVERSED_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   \`\`\`

## Android Setup

1. Add permissions to android/app/src/main/AndroidManifest.xml:
   \`\`\`xml
   <uses-permission android:name="android.permission.USE_BIOMETRIC" />
   <uses-permission android:name="android.permission.USE_FINGERPRINT" />
   <uses-permission android:name="android.permission.INTERNET" />
   \`\`\`

2. For Google Sign-In, add to android/app/build.gradle:
   \`\`\`gradle
   android {
       defaultConfig {
           minSdkVersion 21
       }
   }
   \`\`\`

## macOS Setup

1. Enable keychain entitlements in macos/Runner/Runner.entitlements:
   \`\`\`xml
   <key>keychain-access-groups</key>
   <array>
     <string>\$(AppIdentifierPrefix)com.your.app</string>
   </array>
   \`\`\`

2. Add biometric usage description to macos/Runner/Info.plist:
   \`\`\`xml
   <key>NSFaceIDUsageDescription</key>
   <string>Use Touch ID to authenticate securely</string>
   \`\`\`

## Windows Setup

1. Enable Windows Hello in windows/runner/Runner.exe.manifest:
   \`\`\`xml
   <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
     <application>
       <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
     </application>
   </compatibility>
   \`\`\`

## Web Setup

1. Configure OAuth redirects for your domain
2. Update CORS settings in backend
3. Test with HTTPS in production
EOF

echo "🧪 Creating authentication test script..."
cat > test_auth.sh << EOF
#!/bin/bash

echo "🧪 Running authentication tests..."

echo "Testing Flutter authentication..."
flutter test test/features/auth/

echo "Testing backend authentication..."
cd server
python -m pytest tests/test_auth.py -v
cd ..

echo "Running integration tests..."
flutter test integration_test/auth_integration_test.dart

echo "✅ All authentication tests completed!"
EOF

chmod +x test_auth.sh

echo "📚 Creating OAuth setup guide..."
cat > OAUTH_SETUP_GUIDE.md << EOF
# OAuth Provider Setup Guide

## Google Sign-In Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google+ API
4. Go to "Credentials" → "Create Credentials" → "OAuth client ID"
5. Configure OAuth consent screen
6. Create client IDs for each platform:
   - Web application
   - iOS application
   - Android application

### Configuration:
- Web: Set authorized redirect URIs
- iOS: Set bundle ID
- Android: Set package name and SHA-1 fingerprint

## Apple Sign-In Setup

1. Go to [Apple Developer Console](https://developer.apple.com/)
2. Go to "Certificates, Identifiers & Profiles"
3. Create a new Service ID for web authentication
4. Configure "Sign In with Apple" for your App ID
5. Set up domain and redirect URLs

### Required:
- App ID with Sign In with Apple enabled
- Service ID for web authentication
- Private key for server-side validation

## Microsoft OAuth Setup (Optional)

1. Go to [Azure Portal](https://portal.azure.com/)
2. Register a new application
3. Configure platform settings for mobile/web
4. Set up redirect URIs
5. Generate client secret

## GitHub OAuth Setup (Optional)

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Create a new OAuth App
3. Set authorization callback URL
4. Generate client secret

## Testing OAuth

Use these test URLs to verify setup:
- Google: https://developers.google.com/oauthplayground
- Apple: Use Xcode simulator or device
- Microsoft: https://docs.microsoft.com/en-us/azure/active-directory/develop/test-setup
- GitHub: Use your application directly
EOF

echo "🎉 Authentication system setup completed!"
echo ""
echo "Next steps:"
echo "1. Copy .env.auth.template to .env and configure your values"
echo "2. Follow PLATFORM_SETUP.md for platform-specific configuration"
echo "3. Set up OAuth providers using OAUTH_SETUP_GUIDE.md"
echo "4. Run ./test_auth.sh to test the authentication system"
echo "5. Read AUTHENTICATION_IMPLEMENTATION_GUIDE.md for detailed implementation"
echo ""
echo "🔐 Your production-ready authentication system is ready!"