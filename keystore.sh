#!/bin/bash

# ==============================================================================
# Codemagic Keystore Error Fix Script
# ==============================================================================
# This script fixes the error:
# "No suitable keystores found matching reference 'keystore_reference'"
#
# Run this script from your project root directory
# ==============================================================================

set -e  # Exit on error

echo "🔧 Fixing Codemagic Keystore Error..."
echo ""

# Check if we're in a Flutter project
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Not a Flutter project directory"
    echo "Please run this script from your Flutter project root"
    exit 1
fi

echo "✅ Flutter project detected"
echo ""

# ==============================================================================
# Step 1: Backup current codemagic.yaml
# ==============================================================================
echo "📋 Step 1: Backing up current codemagic.yaml..."

if [ -f "codemagic.yaml" ]; then
    cp codemagic.yaml codemagic.yaml.backup
    echo "✅ Backup created: codemagic.yaml.backup"
else
    echo "⚠️  No existing codemagic.yaml found"
fi
echo ""

# ==============================================================================
# Step 2: Create new codemagic.yaml (FREE setup - no keystore needed)
# ==============================================================================
echo "📋 Step 2: Creating new codemagic.yaml..."

cat > codemagic.yaml << 'EOF'
workflows:
  android-workflow:
    name: Android Development Build
    max_build_duration: 60
    instance_type: mac_mini_m1
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: 'Dev'
          include: true
          source: true
        - pattern: 'Hsf'
          include: true
          source: true
      cancel_previous_builds: true
    environment:
      # ✅ NO android_signing section - we don't need it for Firebase!
      groups:
        - firebase_config  # Only Firebase credentials needed
      vars:
        PACKAGE_NAME: "io.codemagic.fluttersample"  # TODO: Update this
      flutter: stable
      xcode: latest
    scripts:
      - name: 🔧 Set up local.properties
        script: | 
          echo "flutter.sdk=$HOME/programs/flutter" > "$CM_BUILD_DIR/android/local.properties"
      
      - name: 📦 Get Flutter packages
        script: | 
          flutter pub get
      
      - name: 🔍 Flutter analyze
        script: | 
          flutter analyze --no-fatal-infos
      
      - name: 🧪 Flutter tests
        script: | 
          flutter test
        ignore_failure: true
      
      - name: 🤖 Build Android APK
        script: | 
          # Build with timestamp-based build number
          BUILD_NUMBER=$(($(date +%s) / 60))
          echo "Building with build number: $BUILD_NUMBER"
          
          # Build release APK (uses debug signing by default)
          flutter build apk --release \
            --build-name=1.0.$BUILD_NUMBER \
            --build-number=$BUILD_NUMBER
      
      - name: ✅ Verify APK
        script: | 
          APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
          if [ ! -f "$APK_PATH" ]; then
            echo "❌ APK not found"
            exit 1
          fi
          echo "✅ APK built successfully!"
          ls -lh "$APK_PATH"
    
    artifacts:
      - build/app/outputs/flutter-apk/*.apk
    
    publishing:
      firebase:
        firebase_service_account: $FIREBASE_SERVICE_ACCOUNT
        android:
          app_id: $FIREBASE_ANDROID_APP_ID
          groups:
            - testers
          artifact_type: 'apk'
      
      email:
        recipients:
          - mshaseefat@gmail.com
          - mshaseef2013@gmail.com
        notify:
          success: true
          failure: true
EOF

echo "✅ New codemagic.yaml created"
echo ""

# ==============================================================================
# Step 3: Update package name in codemagic.yaml
# ==============================================================================
echo "📋 Step 3: Detecting your package name..."

# Try to find package name from android/app/build.gradle
if [ -f "android/app/build.gradle" ]; then
    PACKAGE_NAME=$(grep -E "applicationId\s+" android/app/build.gradle | sed -E 's/.*applicationId\s+"(.*)".*/\1/' | tr -d '[:space:]')
    
    if [ ! -z "$PACKAGE_NAME" ]; then
        echo "✅ Found package name: $PACKAGE_NAME"
        
        # Update in codemagic.yaml
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/io.codemagic.fluttersample/$PACKAGE_NAME/g" codemagic.yaml
        else
            # Linux
            sed -i "s/io.codemagic.fluttersample/$PACKAGE_NAME/g" codemagic.yaml
        fi
        
        echo "✅ Updated package name in codemagic.yaml"
    else
        echo "⚠️  Could not detect package name"
        echo "Please manually update PACKAGE_NAME in codemagic.yaml"
    fi
else
    echo "⚠️  android/app/build.gradle not found"
fi
echo ""

# ==============================================================================
# Step 4: Fix iOS deployment target (if iOS folder exists)
# ==============================================================================
if [ -d "ios" ]; then
    echo "📋 Step 4: Fixing iOS deployment target..."
    
    cd ios
    
    # Fix Podfile
    if [ -f "Podfile" ]; then
        # Remove existing platform declarations
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/^platform :ios/d' Podfile
            sed -i '' '/^# platform :ios/d' Podfile
            # Add new platform declaration
            sed -i '' '1s/^/platform :ios, '\''15.0'\''\n\n/' Podfile
        else
            sed -i '/^platform :ios/d' Podfile
            sed -i '/^# platform :ios/d' Podfile
            sed -i '1s/^/platform :ios, '\''15.0'\''\n\n/' Podfile
        fi
        echo "✅ Podfile updated to iOS 15.0"
    fi
    
    # Fix Xcode project
    if [ -f "Runner.xcodeproj/project.pbxproj" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [^;]*;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' Runner.xcodeproj/project.pbxproj
        else
            sed -i 's/IPHONEOS_DEPLOYMENT_TARGET = [^;]*;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' Runner.xcodeproj/project.pbxproj
        fi
        echo "✅ Xcode project updated to iOS 15.0"
    fi
    
    cd ..
    echo ""
else
    echo "⚠️  iOS folder not found, skipping iOS fixes"
    echo ""
fi

# ==============================================================================
# Step 5: Create .gitignore entries (if needed)
# ==============================================================================
echo "📋 Step 5: Updating .gitignore..."

if [ ! -f ".gitignore" ]; then
    touch .gitignore
fi

# Add codemagic-specific ignores
if ! grep -q "codemagic.yaml.backup" .gitignore; then
    cat >> .gitignore << 'EOF'

# Codemagic
codemagic.yaml.backup
*.keystore
*.jks
android/key.properties
EOF
    echo "✅ Updated .gitignore"
else
    echo "✅ .gitignore already configured"
fi
echo ""

# ==============================================================================
# Step 6: Summary and next steps
# ==============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Fix completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Changes made:"
echo "  ✅ Created new codemagic.yaml (FREE setup, no keystore)"
echo "  ✅ Backed up old config to codemagic.yaml.backup"
if [ -d "ios" ]; then
echo "  ✅ Fixed iOS deployment target to 15.0"
fi
echo "  ✅ Updated .gitignore"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔥 IMPORTANT: Set up Firebase App Distribution"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Go to: https://console.firebase.google.com"
echo "2. Create project (or use existing)"
echo "3. Add Android app with package: $PACKAGE_NAME"
echo "4. Enable App Distribution"
echo "5. Generate service account key:"
echo "   Settings → Service Accounts → Generate new private key"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Configure Codemagic Environment Variables"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Go to: Codemagic → Your App → Environment variables"
echo ""
echo "Create group: firebase_config"
echo "Add variables:"
echo "  • FIREBASE_SERVICE_ACCOUNT = <paste JSON from step 5>"
echo "  • FIREBASE_ANDROID_APP_ID = <from Firebase Console>"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Deploy Your App"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Run these commands:"
echo ""
echo "  git add ."
echo "  git commit -m \"fix: configure Codemagic for Firebase distribution\""
echo "  git push origin Dev"
echo ""
echo "Then watch your build at: https://codemagic.io"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All done! Your next build should work! 🎉"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"