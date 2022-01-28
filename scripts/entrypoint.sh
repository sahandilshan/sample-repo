#!/bin/sh -l

echo "HERE"
#jq '.' "$GITHUB_EVENT_PATH" #print  GITHUB_EVENT_PATH

ISSUE_ID=$(jq -r '.issue.id' < "$GITHUB_EVENT_PATH")
ISSUE_LABELS=$(jq -r '.issue.labels' < "$GITHUB_EVENT_PATH")
BUG_LABEL=$(echo "$ISSUE_LABELS" | jq -c '[ .[] | select( .name | contains("bug")) ]')

PEER_VERIFIED_LABEL=$(echo "$ISSUE_LABELS" | jq -c '[ .[] | select( .name | contains("Peer-Verified")) ]')
ISSUE_STATE=$(jq -r '.issue.state' < "$GITHUB_EVENT_PATH")

ADDED_LABEL=$(jq -r '.label.name' < "$GITHUB_EVENT_PATH")

echo "Issue State $ISSUE_STATE"
echo "Peer verified??? $PEER_VERIFIED_LABEL"
echo "Workflow triggered by adding $ADDED_LABEL to the issue."

if [ "$ADDED_LABEL" != "bug"]; then
    echo "Workflow triggered by adding '$ADDED_LABEL' label to the issue. Since this is not triggered by 'bug' label, ignoring this issue."
    exit 0
fi

#if [ "$PEER_VERIFIED_LABEL" != "[]" ]; then
#    echo "Issue is labeled with Peer-Verified. Hence not adding to the Project."
#    exit 0
#fi

#if [ "$BUG_LABEL" == "[]" ]; then
#    echo "Issue does not have the 'bug' label. Hence ignoring this issue."
#    exit 0
#fi


ISSUE_JSON=$(curl -s -X GET -u $GITHUB_ACTOR:$GITHUB_TOKEN "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_ID" \
--header 'Accept: application/vnd.github.v3+json')


PROJECT_URL=$1
COLUMN_NAME=$2

if [ -z "$PROJECT_URL" ]; then
    echo "Please provide a project-url."
    exit 1
fi

if [ -z "$COLUMN_NAME" ]; then
    echo "Please provide the column name."
    exit 1
fi

PROJECT_JSON=$(curl -s -X GET -u $GITHUB_ACTOR:$GITHUB_TOKEN "https://api.github.com/repos/$GITHUB_REPOSITORY/projects" \
--header 'Accept: application/vnd.github.v3+json')
PROJECT_ID=$(echo "$PROJECT_JSON" | jq -r ".[] | select(.html_url == \"$PROJECT_URL\").id")

if [ -z "$PROJECT_ID" ]; then
    echo "Unable to retrieve project id, Please check the given project url [$PROJECT_URL]."
    exit 1
fi

COLUMNS_JSON=$(curl -s -X GET -u $GITHUB_ACTOR:$GITHUB_TOKEN "https://api.github.com/projects/$PROJECT_ID/columns" \
--header 'Accept: application/vnd.github.v3+json')
COLUMN_ID=$(echo "$COLUMNS_JSON" | jq -r ".[] | select(.name == \"$COLUMN_NAME\").id")

if [ -z "$COLUMN_ID" ]; then
    echo "Unable to retrieve column id, Please check the given column_name [$COLUMN_NAME]."
    exit 1
fi

# Add this issue to the project column
curl -s -X POST -u "$GITHUB_ACTOR:$GITHUB_TOKEN" --retry 3 \
    -H 'Accept: application/vnd.github.v3+json' \
    -d "{\"content_type\": \"Issue\", \"content_id\": $ISSUE_ID}" \
    "https://api.github.com/projects/columns/$COLUMN_ID/cards"

time=$(date)
echo ::set-output name=time::$time
