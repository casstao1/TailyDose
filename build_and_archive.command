#!/bin/bash
cd /Users/castao/Desktop/PetMed/TailyDose
echo "=== Archiving TailyDose 1.1 ==="
xcodebuild archive \
  -project TailyDose.xcodeproj \
  -scheme TailyDose \
  -configuration Release \
  -archivePath ~/Desktop/TailyDose_1.1.xcarchive \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic
echo ""
echo "=== Archive complete! ==="
echo "Archive saved to ~/Desktop/TailyDose_1.1.xcarchive"
