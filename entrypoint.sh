#!/bin/sh -l

ISSUE_ID=$(jq -r '.issue.id' < "$GITHUB_EVENT_PATH")
ISSUE_LABELS=$(jq -r '.issue.labels' < "$GITHUB_EVENT_PATH")
BUG_LABEL=$(echo "$ISSUE_LABELS" | jq -c '[ .[] | select( .name | contains("bug")) ]')

if [ "$BUG_LABEL" == "[]" ]; then
    echo "Issue does not have the 'bug' label. Hence ignoring this issue."
    exit 0
fi


ISSUE_JSON=$(curl -s -X GET -u $GITHUB_ACTOR:$GITHUB_TOKEN "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_ID" \
--header 'Accept: application/vnd.github.v3+json')


PROJECT_URL=$INPUT_PROJECT
COLUMN_NAME=$INPUT_COLUMN_NAME
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
