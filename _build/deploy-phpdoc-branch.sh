#!/usr/bin/env bash

DEPLOYMENT_ID="${TRAVIS_BRANCH//\//_}"
DEPLOYMENT_DIR="$TRAVIS_BUILD_DIR/_build/deploy-$DEPLOYMENT_ID.git"

[ -n "$DEPLOY_REPO_SLUG" ] || export DEPLOY_REPO_SLUG="$TRAVIS_REPO_SLUG"
[ -n "$DEPLOY_REPO_BRANCH" ] || export DEPLOY_REPO_BRANCH="gh-pages"

# get current Pico milestone
VERSION="$(php -r 'require_once(__DIR__ . "/lib/Pico.php"); echo Pico::VERSION;')"
MILESTONE="Pico$([[ "$VERSION" =~ ^([0-9]+\.[0-9]+)\. ]] && echo " ${BASH_REMATCH[1]}")"

# clone repo
github-clone.sh "$DEPLOYMENT_DIR" "https://github.com/$DEPLOY_REPO_SLUG.git" "$DEPLOY_REPO_BRANCH"
[ $? -eq 0 ] || exit 1

cd "$DEPLOYMENT_DIR"

# setup repo
github-setup.sh
[ $? -eq 0 ] || exit 1

# generate phpDocs
generate-phpdoc.sh \
    "$TRAVIS_BUILD_DIR/.phpdoc.xml" \
    "$DEPLOYMENT_DIR/phpDoc/$DEPLOYMENT_ID.cache" "$DEPLOYMENT_DIR/phpDoc/$DEPLOYMENT_ID" \
    "$MILESTONE API Documentation ($TRAVIS_BRANCH branch)"
[ $? -eq 0 ] || exit 1
[ -n "$(git status --porcelain "$DEPLOYMENT_DIR/phpDoc/$DEPLOYMENT_ID.cache")" ] || exit 0

# update phpDoc list
update-phpdoc-list.sh \
    "$DEPLOYMENT_DIR/_data/phpDoc.yml" \
    "$TRAVIS_BRANCH" "branch" "<code>$TRAVIS_BRANCH</code> branch" "$(date +%s)"
[ $? -eq 0 ] || exit 1

# commit phpDocs
echo "Committing changes..."
git add --all \
    "$DEPLOYMENT_DIR/phpDoc/$DEPLOYMENT_ID.cache" "$DEPLOYMENT_DIR/phpDoc/$DEPLOYMENT_ID" \
    "$DEPLOYMENT_DIR/_data/phpDoc.yml"
git commit \
    --message="Update phpDocumentor class docs for $TRAVIS_BRANCH branch @ $TRAVIS_COMMIT" \
    "$DEPLOYMENT_DIR/phpDoc/$DEPLOYMENT_ID.cache" "$DEPLOYMENT_DIR/phpDoc/$DEPLOYMENT_ID" \
    "$DEPLOYMENT_DIR/_data/phpDoc.yml"
[ $? -eq 0 ] || exit 1
echo

# deploy phpDocs
github-deploy.sh "$TRAVIS_REPO_SLUG" "heads/$TRAVIS_BRANCH" "$TRAVIS_COMMIT"
[ $? -eq 0 ] || exit 1
