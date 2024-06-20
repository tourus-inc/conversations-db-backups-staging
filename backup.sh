#!/bin/bash

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""

s3() {
    aws s3 --region "$AWS_DB_BACKUPS_REGION" "$@"
}

s3api() {
    aws s3api "$1" --region "$AWS_DB_BACKUPS_REGION" --bucket "$AWS_DB_BACKUPS_BUCKET_STAGING" "${@:2}"
}

bucket_exists() {
    s3 ls "$AWS_DB_BACKUPS_BUCKET_STAGING" &> /dev/null
}

create_bucket() {
    echo "Bucket $AWS_DB_BACKUPS_BUCKET_STAGING doesn't exist. Creating it now..."

    # create bucket
    s3api create-bucket \
        --create-bucket-configuration LocationConstraint="$AWS_DB_BACKUPS_REGION" \
        --object-ownership BucketOwnerEnforced

    # block public access
    s3api put-public-access-block \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    # enable versioning for objects in the bucket 
    s3api put-bucket-versioning --versioning-configuration Status=Enabled

    # encrypt objects in the bucket
    s3api put-bucket-encryption \
      --server-side-encryption-configuration \
      '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
}

ensure_bucket_exists() {
    if bucket_exists; then
        return
    fi    
    create_bucket
}

pg_dump_database() {
    pg_dump  --no-owner --no-privileges --clean --if-exists --quote-all-identifiers --encoding=utf8 "$DATABASE_URL"
}

upload_to_bucket() {
    # if the zipped backup file is larger than 50 GB add the --expected-size option
    # see https://docs.aws.amazon.com/cli/latest/reference/s3/cp.html
    s3 cp - "s3://$AWS_DB_BACKUPS_BUCKET_STAGING/$AWS_DB_BACKUPS_FILENAME_STAGING.gz"
}

main() {
    ensure_bucket_exists
    echo "Taking backup and uploading it to S3..."
    pg_dump_database | gzip | upload_to_bucket
    echo "Done."
}

main
