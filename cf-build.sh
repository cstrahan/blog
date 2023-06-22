# !/bin/bash

# Build script to be used by CloudFlare Pages.

# See:
#  - https://developers.cloudflare.com/pages/platform/build-configuration/
#  - https://developers.cloudflare.com/pages/how-to/build-commands-branches/

if [ "$CF_PAGES" = 1 ]; then
    if [ "$CF_PAGES_BRANCH" = "main" ]; then
        zola build
    else
        zola build -u "$CF_PAGES_URL" --drafts
    fi
fi
