#!/bin/bash

# https://codelaser-975050168225.d.codeartifact.eu-central-1.amazonaws.com/maven/CodeLaser/

# Configuration
DOMAIN="codelaser"
DOMAIN_OWNER="975050168225"
REPOSITORY="CodeLaser"
PACKAGE_NAMESPACE="org.e2immu" 
RETENTION_COUNT=3  # Keep this many most recent SNAPSHOT versions
PROFILE=bart

# Get list of packages

PACKAGES=$(aws codeartifact list-packages --profile $PROFILE --domain $DOMAIN --domain-owner $DOMAIN_OWNER --repository $REPOSITORY --namespace $PACKAGE_NAMESPACE --format maven --query 'packages[*].package' --output text)


for PACKAGE in $PACKAGES; do
  echo "Processing package: $PACKAGE"
  
  # Get all versions of the package
  VERSIONS=$(aws codeartifact list-package-versions --profile $PROFILE --domain $DOMAIN --domain-owner $DOMAIN_OWNER --repository $REPOSITORY --namespace $PACKAGE_NAMESPACE --format maven --package $PACKAGE --query 'versions[?contains(version, to_string(`2025`)) == `true`].version' --output text)
  
  echo "Found: $VERSIONS"
  
  # Convert to array and sort by published time (this assumes version naming schema that sorts correctly)
  readarray -t VERSION_ARRAY <<< "$VERSIONS"
  
  # Skip if there are fewer versions than our retention count
  if [ ${#VERSION_ARRAY[@]} -le $RETENTION_COUNT ]; then
    echo "  Fewer than $RETENTION_COUNT SNAPSHOT versions exist for $PACKAGE, skipping..."
    continue
  fi
  
  # Sort versions (this approach works better for Maven SNAPSHOT versioning)
  # The sorting is done by querying AWS again with specific version info
  SORTED_VERSIONS=$(for v in "${VERSION_ARRAY[@]}"; do
    PUBLISHED=$(aws codeartifact describe-package-version --profile $PROFILE --domain $DOMAIN --domain-owner $DOMAIN_OWNER --repository $REPOSITORY --namespace $PACKAGE_NAMESPACE --package $PACKAGE --format maven --package-version "$v" --query 'packageVersion.publishedTime' --output text)
    echo "$PUBLISHED $v"
  done | sort -r | awk '{print $2}')
  
  readarray -t SORTED_VERSION_ARRAY <<< "$SORTED_VERSIONS"
  
  # Determine versions to delete (all but the most recent n)
  TO_DELETE=("${SORTED_VERSION_ARRAY[@]:$RETENTION_COUNT}")
  
  echo "  Keeping ${RETENTION_COUNT} most recent SNAPSHOT versions"
  echo "  Versions to delete: ${#TO_DELETE[@]}"
  
  # Delete old versions
  for VERSION in "${TO_DELETE[@]}"; do
    echo "  Deleting $PACKAGE version $VERSION"
 #   if [ -n "$PACKAGE_NAMESPACE" ]; then
   #   aws codeartifact delete-package-versions --domain $DOMAIN --domain-owner $DOMAIN_OWNER --repository $REPOSITORY --namespace $PACKAGE_NAMESPACE --package $PACKAGE --format maven --versions "$VERSION" --query 'successfulVersions.*' --output text
  #  else
   #   aws codeartifact delete-package-versions --domain $DOMAIN --domain-owner $DOMAIN_OWNER --repository $REPOSITORY --package $PACKAGE --format maven --versions "$VERSION" --query 'successfulVersions.*' --output text
   # fi
  done
done

echo "Cleanup complete!"