#!/usr/bin/env bash
set -euo pipefail

: "${GCP_PROJECT_ID:?}"
: "${WEBSITE_BUCKET:?}"
: "${CDN_URL_MAP:?}"
: "${WEBSITE_URL:?}"
: "${DEPLOY_SHA:?}"
[[ "$DEPLOY_SHA" =~ ^[a-f0-9]{40}$ ]] || { echo 'Invalid commit SHA.' >&2; exit 1; }

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
sed "s/__DEPLOY_SHA__/$DEPLOY_SHA/g" "$repo_root/website/index.html" > "$stage/index.html"
cache_control='public,max-age=0,s-maxage=300,must-revalidate'

# Publish the entry page last. Browsers revalidate; CDN caches for five minutes.
gcloud storage cp --recursive "$repo_root/website/assets" "gs://$WEBSITE_BUCKET/" \
  --project="$GCP_PROJECT_ID" --cache-control="$cache_control"
gcloud storage cp "$repo_root/website/404.html" "gs://$WEBSITE_BUCKET/404.html" \
  --project="$GCP_PROJECT_ID" --content-type=text/html --cache-control="$cache_control"
gcloud storage cp "$stage/index.html" "gs://$WEBSITE_BUCKET/index.html" \
  --project="$GCP_PROJECT_ID" --content-type=text/html --cache-control="$cache_control"

# Wait for invalidation. Upload or invalidation errors stop the deployment.
gcloud compute url-maps invalidate-cdn-cache "$CDN_URL_MAP" \
  --project="$GCP_PROJECT_ID" --path='/*' --quiet

for attempt in {1..30}; do
  if curl --fail --silent --show-error --connect-timeout 10 --max-time 20 \
    "${WEBSITE_URL%/}/" -o "$stage/response.html" && \
    grep -Fq "data-release=\"$DEPLOY_SHA\"" "$stage/response.html"; then
    echo "Verified release $DEPLOY_SHA at $WEBSITE_URL"
    exit 0
  fi
  if ((attempt < 30)); then sleep 10; fi
done
echo 'The website did not serve the expected release.' >&2
exit 1
